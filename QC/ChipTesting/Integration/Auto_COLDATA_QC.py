"""
Filename: Auto_CODLATA_QC.py
Author: Taylor Contreras (Based on Shanshan Gao's DAT_COLDATA_QC_ana.py)
Date: 2025-06-13
Description: This script includes functions to run QC/QA testing of 
             COLDATA chips automatically, without user input. 
"""

import os
import datetime
from colorama import just_fix_windows_console
just_fix_windows_console()
from BNL_QC.DAT_chk_cfgfile import dat_chk_cfgfile_auto
from BNL_QC.LogInfo import SaveToLog
from BNL_QC.DAT_COLDATA_QC_ana import CD_QC_ANA

wibip = "192.168.121.123"
wibhost = "root@{}".format(wibip)

from BNL_QC.rts_ssh import subrun
from BNL_QC.rts_ssh import rts_ssh
from BNL_QC.rts_ssh import DAT_power_off

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
    QCresult = rts_ssh(dut_skt, root=rootdir, duttype=duttype, env=env, burnin_in_tests=burnin_in_tests, burnin_now=burnin_now, auto=True, config_path="/Users/RTS/FD_CE/QC/ChipTesting/asic_info.csv")
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