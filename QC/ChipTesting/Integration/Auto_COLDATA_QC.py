"""
Filename: Auto_CODLATA_QC.py
Author: Taylor Contreras (Based on Shanshan Gao's DAT_COLDATA_QC_ana.py)
Date: 2025-06-13
Description: This script includes functions to run QC/QA testing of 
             COLDATA chips automatically, without user input. 
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

import os
import datetime
from colorama import just_fix_windows_console
just_fix_windows_console()
from ChipTesting.BNL_QC.DAT_chk_cfgfile import dat_chk_cfgfile_auto
from ChipTesting.BNL_QC.LogInfo import SaveToLog

wibip = "192.168.121.123"
wibhost = "root@{}".format(wibip)

from ChipTesting.BNL_QC.rts_ssh import subrun
from ChipTesting.BNL_QC.rts_ssh import rts_ssh
from ChipTesting.BNL_QC.rts_ssh import DAT_power_off

####### Colors for terminal output #######
#Red = '\033[91m'
#Green = '\033[92m'
#Blue = '\033[94m'
#Cyan = '\033[96m'
#White = '\033[97m'
#Yellow = '\033[93m'
#Magenta = '\033[95m'
#Grey = '\033[90m'
#Black = '\033[90m'
#Default = '\033[99m'

def DAT_QC(rootdir, dut_skt, duttype="FE",  env="RT", burnin_in_tests=True, burnin_now=True):
    """
    Runs rts_ssh and returns the results successful.
    Inputs:
        rootdir [str]: directory of ??
        dut_skt [?]: ??
        env [str]: environment of tests (room temp (RT) or cold (LN))
        burnin_in_tests [bool]: Determines if the burn in is included in tests
        burnin_now [bool]: Determines if burnin happens now or in separate command
    Returns:
        QCstatus [?]: ?
        badchips [?]: ?
        logs [dict]: dictionary holding QC test information
    """
    print('Running DAT QC')
    QCresult = rts_ssh(dut_skt, root=rootdir, duttype=duttype, env=env, burnin_in_tests=burnin_in_tests, burnin_now=burnin_now, auto=True, config_path="/Users/ppd-cap-WD-137552/FD_CE/QC/ChipTesting/asic_info.csv")
    if QCresult != None:
        QCstatus = QCresult[0]
        badchips = QCresult[1] #badchips range from 0 to7
        logs = QCresult[2]
        cd_qc_ana = QCresult[3] # class holding qc test results
    else:
        print('Error, QCresult empty')
        exit()

    return QCstatus, badchips, logs, cd_qc_ana 

def BurninSN(logs, cd_qc_ana):
    """
    Burns in the serial number of a COLDATA chip.
    Input: logs [dict]: dictionary holding QC test information
    """
    print('Running BurninSN')
    testid = 7 # defined as burn-in test in DAT_COLDATA_QC_top.py
    command = ["ssh", wibhost, "cd BNL_CE_WIB_SW_QC; python3 DAT_COLDATA_QC_top.py -t {}".format(testid)]
    result=subrun(command, timeout = None) #rewrite with Popen later


    # Check if tests passed or not and if DAT was powered off
    if result != None:
        resultstr = result.stdout
        logs["QC_TestItemID_%03d"%testid] = [command, resultstr]
        if "Pass!" in result.stdout:
            print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
        elif "DAT_Power_On" in result.stdout:
            print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS & Turn DAT on!  \033[0m")
        elif "DAT_Power_Off" in result.stdout:
            print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS & Done!  \033[0m")
        else:
            print ("FAIL!")
            print (result.stdout)
    else:
        print ("FAIL!")
        return

    # Add results to the logs dictionary
    print ("Transfer data to PC...")
    fdir = resultstr[resultstr.find("save_fdir_start_")+16:resultstr.find("_end_save_fdir")] 
    logs['wib_raw_dir'] = fdir
    fs = resultstr[resultstr.find("save_file_start_")+16:resultstr.find("_end_save_file")] 
    fsubdirs = fdir.split("/")
    fn = fs.split("/")[-1]
    fddir =logs['PC_rawdata_root'] + fsubdirs[-2] + "/" 

    # Look for results directory and make one if it does not exists
    if not os.path.exists(fddir):
        try:
            os.makedirs(fddir)
            SaveToLog("QC Test folder created: {fddir}")
        except OSError:
            print ("Error to create folder %s"%fddir)
            print ("Exit anyway")
            return    
        
    # Save data from WIB to PC and save in logs
    fsrc = wibhost + ":" + fs
    command = ["scp", "-r",fsrc , fddir]
    result=subrun(command, timeout = None)
    if result != None:
        print ("data save at {}".format(fddir))
        logs['pc_raw_dir'] = fddir #later save it into log file
        logs["QC_TestItemID_%03d_SCP"%testid] = [command, result]
        logs["QC_TestItemID_%03d_Save"%testid] = logs['pc_raw_dir']
        print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
    else:
        print ("FAIL!")
        return
    
    # Delete the folder on the WIB after saving locally
    fdirdel = logs['wib_raw_dir']
    command = ["ssh", wibhost, "rm -rf {}".format(fdirdel)] 
    result=subrun(command, timeout = 60)
    if result != None:
        print ("WIB folder {} is deleted!".format(fdirdel))

    # Check output from test
    #cd_qc_ana = CD_QC_ANA()
    cd_qc_ana.dat_cd_qc_ana(fdir=logs['pc_raw_dir'], tms=[testid])

    # Turn the DAT board off
    testid = 9
    command = ["ssh", wibhost, "cd BNL_CE_WIB_SW_QC; python3 DAT_COLDATA_QC_top.py -t {}".format(testid)]
    result=subrun(command, timeout = None) #rewrite with Popen later

    return

def RunCOLDATA_QC(duttype, env, rootdir, pc_wrcfg_fn="./asic_info.csv"):
    """
    Runs the QC tests for COLDATA (without burnin) such that no user
    input is required. The config file must be up to date prior to 
    running. The burnin is assumed to occur in a separate function soon after.
    Inputs:
        duttype [str]: type of chip to test (FE, ADC, CD)
        env: [str]: environment to run tests in room temp or cold (RT, LT)
        rootdir [str]: directory for outputing results
    """
    print('--------------->Running COLDATA QC')
    print("\033[96m Root folder of test data is: "+ "\033[93m" + rootdir + "\033[0m")

    # Checking WIB connection
    print("\033[0m ", datetime.datetime.utcnow(), " : Check if WIB is pingable (it takes < 60s)" )
    timeout = 10 
    command = ["ping", wibip]
    print("\033[92m ", "COMMAND:", command)
    for i in range(6):
        result = subrun(command=command, timeout=timeout, exitflg=False)
        if i == 5:
            print("\033[91m " + "Please check if WIB is powered and Ethernet connection,exit anyway")
            exit()
        log = result.stdout
        chk1 = "Reply from {}: bytes=32".format(wibip)
        chk2p = log.find("Received =")
        chk2 =  int(log[chk2p+11])
        if chk1 in log and chk2 >= 1:  #improve it later
            print("\033[0m ", datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
            break

    # Check configuration file
    print(f'Checking config file {pc_wrcfg_fn}')
    #command = ["notepad.exe", pc_wrcfg_fn]
    #result=subrun(command, timeout = None, check=False)
    pf= dat_chk_cfgfile_auto(fcfg = pc_wrcfg_fn, duttype=duttype )
    if not pf:
        print("Error with config file.")
        exit()

    # Get the current time
    now = datetime.datetime.utcnow()
    dut0 = int(now.strftime("%Y%m%d%H%M%S"))&0xFFFFFFFFFFFFFFFF

    ################STEP1#################################
    dut_skt = {str(dut0):(0,1), str(dut0+1):(0,2), str(dut0+2):(0,3), str(dut0+3):(0,4), str(dut0+4):(0,5), str(dut0+5):(0,6), str(dut0+6):(0,7), str(dut0+7):(0,8) }
    QCstatus, badchips, logs, cd_qc_ana = DAT_QC(rootdir, dut_skt, duttype, env, burnin_in_tests=True, burnin_now=False) 

    if "PASS" in QCstatus :
        print(QCstatus)
        print("\033[92m " + "Well done, please move chips back to tray." +"\033[0m")
    elif ("Code#E001" in QCstatus) or ("Terminate" in QCstatus) :
        print(QCstatus, badchips)
        DAT_power_off()
        print("\033[93m " + "Please contact the tech coordinator" +"\033[0m")
    elif "Code#" in QCstatus:
        DAT_power_off()
        print(QCstatus, badchips)
        if len(badchips) > 0:
            for bc in badchips:
                print("\033[93m " + "chip%d (1-8) is bad, please move it to bad tray and replace it with a new chip"%(bc+1) +"\033[0m")
            print("\033[93m " +"please restart the test script" +"\033[0m" )
        else:
            print("\033[93m " +"Please contact the tech coordinator" +"\033[0m")

    return logs, cd_qc_ana

def ReadHWDBLog(filename):
    """
    Reads the HWDB text log output by the QC tests, 
    creates a dictionary of the tests and results.
    Inputs:
        filename [str]: name of the hwdb file to read
    Returns:
        data_dict [dict]: dictionary with QC tests names as keys 
                          and results as values.
    """
  
    with open(filename) as f:
        lines = f.read().splitlines()

    data_dict = {}
    #print("Grabbing data:")
    for line in lines:
        line_split = line.split(":")
        data_dict[line_split[0]] = " ".join(line_split[1:])

    return data_dict

def PassCDVDDIO(test_name, test_result):
    """
    Determines if a CD VDDIO test passes based on a given
    current range for that test.
    Inputs:
        test_name [str]: name of test (should include CUR 0-7)
        test_result [str]: result of CD VDDDIO test, converts to float
    Returns:
        chip_pass [bool]: Pass(True) or Fail (False)
    """
    chip_pass = False

    test_result = float(test_result)

    # 3sigma ranges, calculated in HWDBTools/plotHWDB_FNAL.py
    cur_ranges = {"CUR_0": (26.7,35.7), 
                  "CUR_1":(39.1,50.1), 
                  "CUR_2":(36.9,52.3), 
                  "CUR_3":(49.3,64.4), 
                  "CUR_4":(37.0,52.3), 
                  "CUR_5":(49.6,64.2), 
                  "CUR_6":(46.3,67.5), 
                  "CUR_7":(58.9,76.9)}

    cut_range = (None, None)
    for key in cur_ranges.keys():
        if key in test_name:
            cut_range = cur_ranges[key]

    if test_result > cut_range[0] and test_result < cut_range[1]:
        chip_pass = True
    else:
        print(f"---Failed CD VDDIO range ({cur_ranges[key]}): {test_result}")

    return chip_pass


def PassPLLLock(data_dict):
    """
    Determines if a chip passes or fails the PLL Lock test.
    Input:
        data_dict [dict]: dictionary of chip test names and results
    Returns:
        chip_pass [bool]: Pass(True) or Fail (False)
    """

    # Pass/Fail criteria determined based on statistics and 
    # convenience of programming PLL lock ranges
    low_max = 35
    up_min = 39
    width_min = 10
    chip_pass = False

    # Grab upper/lower bounds from dictionary
    lower_bound = -999
    upper_bound = -999
    for key in data_dict.keys():
        if "Lower" in key: 
            lower_bound = int(data_dict[key])
        elif "Upper" in key:
            upper_bound = int(data_dict[key])

    # If upper/lower bounds were found, check pass/fail criteria
    if lower_bound > 0 and upper_bound > 0:
        width = upper_bound - lower_bound
        if width > width_min and lower_bound < low_max and upper_bound > up_min:
            chip_pass = True

    return chip_pass


def PassFailCOLDATA(db_file_name):
    """
    This function read the hwdb output log right after the QC tests and
    determines if a chip has passed all tests successfully.

    Inputs:
        db_file_name [str]: name of HWDB file
    Returns:
        chip_pass [bool]: Pass(True) or Fail (False)
    """

    data_dict = ReadHWDBLog(db_file_name)
    chip_pass = True

    # Check if 'Fail' is in any tests
    for key in data_dict.keys():
        if 'fail' in data_dict[key].lower():
            print("Failure: ", key, data_dict[key]) 
            chip_pass = False

        if "CD VDDIO" in  key:
            chip_pass = chip_pass and PassCDVDDIO(key, data_dict[key])

    chip_pass = chip_pass and PassPLLLock(data_dict)

    return chip_pass

def WriteChipPassFail(chip_pass, db_file_name):
    """
    Update the hardware database file with the final pass/fail result
    of the given chip.
    Inputs:
        chip_pass [bool]: Pass(True) or Fail (False)
        db_file_name [str]: name of hwdb file
    """

    # Add full pass/fail to hwdb file
    db_file = open(db_file_name, "a")
    if chip_pass:
        print("\n----------PASS-----------\n--Chip passed all tests---\n")
        db_file.write("All Tests: Pass")
    else:
        print("\n-----------FAIL------------\n--Chip did not pass all tests---\n")
        db_file.write("All Tests: Fail")
    db_file.close()

    return

if __name__ == "__main__":

    db_file_name = "hwdb_CD0_dummy.txt"
    #PassFailCOLDATA(db_file_name)
    PassPLLLock(ReadHWDBLog(db_file_name))

    # Grab all files in the given directory
    getnames = os.popen("ls -d ~/RTS_data/*/*/*")
    filenames = getnames.read().splitlines()

    CountPassFailPLLLock(filenames)
    