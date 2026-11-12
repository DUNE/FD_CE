import time
import sys
import subprocess
import datetime
import filecmp
import pickle
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))
from ChipTesting.BNL_QC_LArASIC.DAT_read_cfg import dat_read_cfg
from ChipTesting.BNL_QC_LArASIC.DAT_InitChk import dat_initchk
from colorama import just_fix_windows_console
from ChipTesting.BNL_QC_LArASIC.DAT_COLDATA_QC_ana import CD_QC_ANA 
just_fix_windows_console()

def countdown(t):
    while t:
        mins, secs = divmod(t, 60)
        timer = '{:02d}:{:02d}'.format(mins, secs)
        print(timer, end='\r')  # Overwrite the line each second
        time.sleep(1)
        t -= 1

wibip = "192.168.121.123"
wibhost = "root@{}".format(wibip)
sshcmd = ["ssh","-o", "ConnectTimeout=60",  "-o", "ServerAliveInterval=20", "-o", "ServerAliveCountMax=2"]

def subrun(command, timeout = 30, check=False, exitflg = True):
    t_start=time.time()
    # print(f'Will run {command}')
    try:
        result = subprocess.run(command,
                                capture_output=True,
                                text=True,
                                timeout=timeout,
                                #shell=True,
                                shell=False,
                                #stdout=subprocess.PIPE,
                                #stderr=subprocess.PIPE,
                                #check=check
                                check=False #Disable check=True and handle errors yourself (recommended)
                                )
        
        if result.returncode != 0:
            print("Command failed:", result.returncode)
            print("STDERR:", result.stderr.strip())
            if exitflg:
                t_end=time.time()
                print(f'Subprocess time: {(t_end - t_start)}')
                print('non-zero return code, exit flag=True')
                # _ = DAT_power_off() 
                return 'Error'
            else:
                print('non-zero return code, exit flag=False')
        t_end=time.time()
        print(f'Subprocess time: {(t_end - t_start)}')
        return result

    #except subprocess.CalledProcessError as e:
    #    print ("Call Error", e.returncode)
    #    if exitflg:
    #        print ("Call Error FAIL!")
    #        print ("Exit anyway")
    #        return None
    #        #exit()
        #continue
    except subprocess.TimeoutExpired as e:
        t_end=time.time()
        print(f'Subprocess time: {(t_end - t_start)}')
        print ("No reponse in %d seconds"%(timeout))
        if exitflg:
            print('Timeout, exit flag=True')
            #print (result.stdout)
            print ("Timeout FAIL!")
            # _ = DAT_power_off()
            print ("Exit anyway")
            print("Timeout stdout:"+repr(e.stdout))
            print("Timeout stderr:"+repr(e.stderr))
            return 'Timeout Error'
            #exit()
        else:
            print('Timeout, exit flag=False')

        #continue

def ssh_test():
    print (datetime.datetime.utcnow(), " : Running ssh connectivity test");
    command = sshcmd + [wibhost, "echo TEST"]

    result = subrun(command)
    if "Timeout Error" == str(result):
        print('ssh test timeout error')
        return False
    print('ssh test passed with no timeout error')
    return True

def DAT_power_off():
    logs = {}
    print (datetime.datetime.utcnow(), " : Power DAT down (it takes < 60s)")
    command = sshcmd + [wibhost, "cd BNL_CE_WIB_SW_QC; python3 top_femb_powering.py off off off off"]
    result=subrun(command, timeout = 60*3)
    if 'Timeout Error' == result:
        print('Timeout!')
        return False
    if result != 'Error':
        if "Done" in result.stdout:
            print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
            return True
        else:
            print ("FAIL!")
            print (result.stdout)
            return False
    else:
        print ("FAIL!")
        return False

def DAT_power_on():
    logs = {}
    print (datetime.datetime.utcnow(), " : Power DAT On (it takes < 60s)")
    command = sshcmd + [ wibhost, "cd BNL_CE_WIB_SW_QC; python3 top_femb_powering.py on off off off"]
    result=subrun(command, timeout = 60*3)
    if 'Error' != result and 'Timeout Error' != result:
        if "Done" in result.stdout:
            print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
        else:
            print ("FAIL!")
            print (result.stdout)
            return None
    else:
        print ("FAIL!")
        return None

# def WIB_startup():
#     print (datetime.datetime.utcnow(), " : Start WIB initialization (it takes < 30s)")
#     command = sshcmd + [ wibhost, "cd BNL_CE_WIB_SW_QC;  python3 wib_startup.py"]
#     result=subrun(command, timeout = 30)
#     if 'Timeout' in str(result):
#         raise TimeoutError('WIB_startup timed out')
#     if 'Error' != result and 'Timeout Error' != result:
#         if "Done" in result.stdout:
#             print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
#         else:
#             print ("FAIL!")
#             print (result.stdout)
#             raise RuntimeError
#     else:
#         print ("FAIL!")
#         raise RuntimeError


def Sinkcover():
    while True:
        ccflg=input("\033[93m Do covers of shielding box close? (Y/N) : \033[0m")
        if ("Y" in ccflg) or ("y" in ccflg):
            break
        else:
            print ("Please close the covers and continue...")

def rts_ssh(dut_skt, sns=[], root = "C:/DAT_LArASIC_QC/Tested/", duttype="FE", env="RT", testid=0, config_path ="./asic_info.csv" , test_history={}):
    print('Running rts_ssh command')

    # JW: Added to test automation handling
    if testid == -999:
        print('Returning known good test values from rts_ssh')
        QCstatus="PASS"
        bads=[]
        return (QCstatus, bads), test_history
    elif testid == -998:
        print('Returning known bad test values from rts_ssh (chip 3 fails)')
        QCstatus="Code#E002"
        bads=[3]
        return (QCstatus, bads), test_history

    print (f'in rts_ssh, config path is {config_path}')
    if sns:
        print('serials passed =')
        print(sns)
    else:
        print('Will get serials from ocr file')
    logs = {}
    logs['RTS_IDs'] = dut_skt

    if not sns:
        ocrfp = root + "ocr_results.bin"
        with open(ocrfp, 'rb') as fn:
            chip_ocr = pickle.load(fn)

    # x = list(dut_skt.keys())
    # Put in order of sockets?
    x = sorted(dut_skt, key=lambda k: dut_skt[k][1])

    lenx = len(x)
    if "FE"in duttype or "ADC"in duttype:
        logs['PC_rawdata_root'] = root + "Time_{}_DUT_{:04d}_{:04d}_{:04d}_{:04d}_{:04d}_{:04d}_{:04d}_{:04d}/".format(x[0],
                                                                            dut_skt[x[0%lenx]][1]*1000 + dut_skt[x[0%lenx]][0], 
                                                                            dut_skt[x[1%lenx]][1]*1000 + dut_skt[x[1%lenx]][0], 
                                                                            dut_skt[x[2%lenx]][1]*1000 + dut_skt[x[2%lenx]][0], 
                                                                            dut_skt[x[3%lenx]][1]*1000 + dut_skt[x[3%lenx]][0], 
                                                                            dut_skt[x[4%lenx]][1]*1000 + dut_skt[x[4%lenx]][0], 
                                                                            dut_skt[x[5%lenx]][1]*1000 + dut_skt[x[5%lenx]][0], 
                                                                            dut_skt[x[6%lenx]][1]*1000 + dut_skt[x[6%lenx]][0], 
                                                                            dut_skt[x[7%lenx]][1]*1000 + dut_skt[x[7%lenx]][0] 
                                                                            ) 
    else:
        logs['PC_rawdata_root'] = root + "Time_{}_DUT_{:04d}_{:04d}/".format(x[0],
                                                                            dut_skt[x[0%lenx]][1]*1000 + dut_skt[x[0%lenx]][0], 
                                                                            dut_skt[x[1%lenx]][1]*1000 + dut_skt[x[1%lenx]][0]
                                                                            )
    
    logs['PC_WRCFG_FN'] = config_path #"./asic_info.csv"
    csvfp = logs['PC_WRCFG_FN']
    tmps = []
    
    with open(csvfp, 'r') as fp:
        for cl in fp:
            tmp = cl.split(",")
            if "env" in tmp[0]:
                tmp[1] = env
            # JW: MSU has OCR label handled in slightly different way outside of  rts_ssh
            # Need to best udertstand how to unifiy 
            if not sns:
                #print('From BNL ocr binary')
                if "FE" in duttype:
                    if "FE" in tmp[0][0:2]:
                        sktno = int(tmp[0][2])
                        key = dut_skt[x[sktno%lenx]][0] + 1  # IF x is sorted by socket should be no issue?
                        tmp[1] = chip_ocr[key][1]
                        print (key, tmp, sktno)

                        # JW" if ordered list doesn't work?
                        # sktno = int(tmp[0][2]) # From asic_info.csv, i.e will take line FE0, NNN-NNNN and return 0
                        # if lenx != 8:
                        #     key = dut_skt[x[sktno%lenx]][0] + 1 
                        #     # JW: I think this is only appropiate for the surge testing
                        #     # Where the labels don't matter
                        # else:
                        #     # If all 8 chips in dut_skt, should be able to find the 
                        #     # skt number from dut_skt tuples (chip, socket)
                        #     for k in dut_skt.keys():
                        #         if dut_skt[k][1] == sktno:
                        #             key = k
                        # tmp[1] = chip_ocr[key][1]
                        # print (key, tmp, sktno) # , lenx, dut_skt[x[sktno%lenx]][1])             
                        # # if sktno != dut_skt[x[sktno%lenx]][1]:
                        # #     print('Socket numbers do not match!')
            else:
                # JW: I think this will get thr right serial number from the MSU tray scan
                # print('From MSU ocr csv')
                if "FE" in duttype:
                    if "FE" in tmp[0][0:2]:
                        sktno = int(tmp[0][2])
                        key = dut_skt[x[sktno%lenx]][0] + 1
                        tmp[1] = sns[sktno%lenx]
                        print (key, tmp, sktno, lenx)

            if "DUT" in tmp[0][0:3]:
                tmp[1] = duttype
            cln=','.join(tmp)
            tmps.append(cln)

    with open(csvfp, 'w') as fp:
        for cl in tmps:
            fp.write(cl)

    if testid in [91,92,93,94,95,96,97,98]:
        QC_TST_EN =   False
    else:
        QC_TST_EN =  True 

    if testid in [91,92,93,94,95,96,97,98]:
        if "FE" in duttype:
            DUT = 'FE'
        elif "ADC" in duttype:
            DUT = 'ADC'
        elif "CD" in duttype:
            DUT = 'CD'
        print (datetime.datetime.utcnow(), " : check if there is a short")
        if True:
            print (datetime.datetime.utcnow(), " : New Test Item Starts, please wait...")

            if "FE" in DUT:
                command = sshcmd + [ wibhost, "cd BNL_CE_WIB_SW_QC; python3 DAT_LArASIC_QC_top.py -t {}".format(testid)]
            elif "ADC" in DUT:
                command = sshcmd + [ wibhost, "cd BNL_CE_WIB_SW_QC; python3 DAT_ColdADC_QC_top.py -t {}".format(testid)]
            elif "CD" in DUT:
                command = sshcmd + [ wibhost, "cd BNL_CE_WIB_SW_QC; python3 DAT_COLDATA_QC_top.py -t {}".format(testid)]
            for attempt in [1,2]:
                #result=subrun(command, timeout = None) #rewrite with Popen later
                result=subrun(command, timeout = 60*5*attempt) # *20) #rewrite with Popen later
                if 'Timeout Error' != result:
                    break
            if 'Error' !=result and 'Timeout Error' != result:
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
                    print ("Exit anyway")
                    return None, test_history
            else:
                print ("FAIL!")
                return None, test_history
   
            print ("Transfer data to PC...")
            fdir = resultstr[resultstr.find("save_fdir_start_")+16:resultstr.find("_end_save_fdir")] 
            #wib_raw_dir = fdir #later save it into log file
            logs['wib_raw_dir'] = fdir
            fs = resultstr[resultstr.find("save_file_start_")+16:resultstr.find("_end_save_file")] 
            fsubdirs = fdir.split("/")
            fn = fs.split("/")[-1]
            fddir =logs['PC_rawdata_root'] + fsubdirs[-2] + "/" 
    
            if not os.path.exists(fddir):
                try:
                    os.makedirs(fddir)
                except OSError:
                    print ("Error to create folder %s"%fddir)
                    print ("Exit anyway")
                    #sys.exit()
                    return None, test_history
            fsrc = wibhost + ":" + fs
            command = ["scp", "-r",fsrc , fddir]
            #result=subrun(command, timeout = None)
            result=subrun(command, timeout = 60*5)
            if 'Error' != result and 'Timeout Error' != result:
                print ("data save at {}".format(fddir))
                logs['pc_raw_dir'] = fddir #later save it into log file
                logs["QC_TestItemID_%03d_SCP"%testid] = [command, result]
                logs["QC_TestItemID_%03d_Save"%testid] = logs['pc_raw_dir']
                print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
            else:
                print ("FAIL!")
                return None, test_history

            print ("Run quick analysis...")
            QCstatus, bads = dat_initchk(fdir=logs['pc_raw_dir'])
            print (QCstatus, bads)
            fdirdel = logs['wib_raw_dir']
            command = sshcmd + [wibhost, "rm -rf {}".format(fdirdel)] 
            #result=subrun(command, timeout = None)
            result=subrun(command, timeout = 60*5)
            if 'Error' != result and 'Timeout Error' != result:
                print ("WIB folder {} is deleted!".format(fdirdel))
            return (QCstatus, bads), test_history

    
    if QC_TST_EN:
        #[0, 1, 2, 3, 4,5,61, 62, 63, 64, 7,8, 9]
        tms_items = {}
        if "FE" in duttype:
            tms_items[0 ] = "\033[96m 0 : Initilization checkout (not selectable for itemized test item)  \033[0m"
            tms_items[1 ] = "\033[96m 1 : FE power consumption measurement  \033[0m"
            tms_items[2 ] = "\033[96m 2 : FE response measurement checkout  \033[0m" 
            tms_items[3 ] = "\033[96m 3 : FE monitoring measurement  \033[0m"
            tms_items[4 ] = "\033[96m 4 : FE power cycling measurement  \033[0m"
            tms_items[5 ] = "\033[96m 5 : FE noise measurement  \033[0m"
            tms_items[61] = "\033[96m 61: FE calibration measurement (ASIC-DAC)  \033[0m"
            tms_items[62] = "\033[96m 62: FE calibration measurement (DAT-DAC) \033[0m"
            tms_items[63] = "\033[96m 63: FE calibration measurement (Direct-Input) \033[0m"
            tms_items[64] = "\033[96m 64: FE calibration measurement ((ASIC-DAC, 4.7mV/fC) \033[0m"
            tms_items[7 ] = "\033[96m 7 : FE delay run  \033[0m"
            tms_items[8 ] = "\033[96m 8 : FE cali-cap measurement \033[0m"
            tms_items[9 ] = "\033[96m 9 : Turn DAT off \033[0m"
    #        tms_items[10] = "\033[96m 10: Turn DAT (on WIB slot0) on without any check\033[0m"
        elif "ADC" in duttype:
            tms_items[0  ] = "\033[96m 0: Initilization checkout (not selectable for itemized test item) \033[0m"
            tms_items[1  ] = "\033[96m 1: ADC power cycling measurement  \033[0m"
    #        tms_items[2  ] = "\033[96m 2: ADC reserved...  \033[0m"
            tms_items[3  ] = "\033[96m 3: ADC reference voltage measurement  \033[0m"
            tms_items[4  ] = "\033[96m 4: ADC autocalibration check  \033[0m"
            tms_items[5  ] = "\033[96m 5: ADC noise measurement  \033[0m"
            tms_items[7  ] = "\033[96m 7: ADC DAT-DAC SCAN  \033[0m"
            tms_items[11 ] = "\033[96m 11: ADC ring oscillator frequency readout \033[0m"
            tms_items[12 ] = "\033[96m 12: ADC RANGE test \033[0m"
            tms_items[8  ] = "\033[96m 8: ADC ENOB measurement \033[0m"
            tms_items[6  ] = "\033[96m 6: ADC DNL/INL measurement  \033[0m"
            tms_items[9  ] = "\033[96m 9: Turn DAT off \033[0m"
    #        tms_items[10 ] = "\033[96m 10: Turn DAT (on WIB slot0) on without any check\033[0m"
        elif "CD" in duttype:
            tms_items[0  ] = "\033[96m 0: Initilization checkout (not selectable for itemized test item) \033[0m"
            tms_items[1  ] = "\033[96m 1: COLDATA basic functionality checkout  \033[0m"
            tms_items[2  ] = "\033[96m 2: COLDATA primary/secondary swap check  \033[0m"
            tms_items[3  ] = "\033[96m 3: COLDATA power consumption measurement  \033[0m"
            tms_items[4  ] = "\033[96m 4: COLDATA PLL lock range measurement  \033[0m"
            tms_items[5  ] = "\033[96m 5: COLDATA fast command verification  \033[0m"
            tms_items[6  ] = "\033[96m 6: COLDATA output link verification \033[0m"
            if False:
                tms_items[7  ] = "\033[96m 7: COLDATA EFUSE burn-in \033[0m"
            else: 
                print ("Burn-in is ignore")
            tms_items[9  ] = "\033[96m 9: Turn DAT off \033[0m"
    
        logs['tms_items'] = tms_items

        tms = list(tms_items.keys())
        logs['TestIDs'] = tms
    
    #if QC_TST_EN:
    if False:
        print (datetime.datetime.utcnow(), " : Check if WIB is pingable (it takes < 60s)" )
        timeout = 10 
        command = ["ping", wibip]
        print ("COMMAND:", command)
        for i in range(6):
            if i == 5:
                print ("Please check if WIB is powered and Ethernet connection,exit anyway")
                return None, test_history

            result = subrun(command=command, timeout=timeout, exitflg=False)
            if 'Error' != result and 'Timeout Error' != result:
                log = result.stdout
                chk1 = "Reply from {}: bytes=32".format(wibip)
                chk2p = log.find("Received =")
                chk2 =  int(log[chk2p+11])
                if chk1 in log and chk2 >= 1:  #improve it later
                    print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
                    logs['WIB_Pingable'] = log
                    break
    
    if QC_TST_EN:
        for attempt in [1,2]:
            print (datetime.datetime.utcnow(), " : sync WIB time")
            # Get the current date and time
            now = datetime.datetime.utcnow()
            # Format it to match the output of the `date` command
            formatted_now = now.strftime('%a %b %d %H:%M:%S UTC %Y')
            command = sshcmd + [ wibhost, "date -s \'{}\'".format(formatted_now)]
            result=subrun(command, timeout = 30)
            if 'Timeout Error' == result:
                if attempt == 1:
                    print('Will try again in 30 seconds')
                    #time.sleep(30)
                    countdown(30)
                elif attempt == 2:
                    print('Timeout error has occurred twice')
                    print('FAIL!')
                    return None, test_history
            elif 'Error' != result:
                print ("WIB Time: ", result.stdout)
                print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
                logs['WIB_UTC_Date_Time'] = result.stdout
                break
            else:
                print ("FAIL!")
                return None, test_history
   
    if QC_TST_EN:
        print (datetime.datetime.utcnow(), " : Load WIB bin file(it takes < 30s)" )
        if (duttype=="ADC"):
            command = sshcmd + [ wibhost, "fpgautil -b /home/root/BNL_CE_WIB_SW_QC/DAT_QC_WIB_binfiles/wib_top_coldadc_qc_sim.wibbin"]
        else:
            command = sshcmd + [ wibhost, "fpgautil -b /home/root/BNL_CE_WIB_SW_QC/DAT_QC_WIB_binfiles/wib_top_production.wibbin"]
        result=subrun(command, timeout = 30)
        if 'Error' != result and 'Timeout Error' != result:
            if "BIN FILE loaded through FPGA manager successfully" in result.stdout:
                print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
            logs['WIB_bin_file'] = result.stdout
        else:
            print ("FAIL!")
            return None, test_history
    
    if QC_TST_EN:
        print (datetime.datetime.utcnow(), " : Start WIB initialization (it takes < 30s)")
        command = sshcmd + [ wibhost, "cd BNL_CE_WIB_SW_QC;  python3 wib_startup.py"]
        result=subrun(command, timeout = 30)
        if 'Error' != result and 'Timeout Error' != result:
            if "Done" in result.stdout:
                print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
            else:
                print ("FAIL!")
                print (result.stdout)
                return None, test_history
                #exit()
            logs['WIB_start_up'] = result.stdout
        else:
            print ("FAIL!")
            return None, test_history
   
    if QC_TST_EN:
        #print ("later use pyqt to pop out a configuration windows")
        #input ("anykey to continue now")
        print (datetime.datetime.utcnow(), " : load configuration file from PC")
    
        wibdst = "{}:/home/root/BNL_CE_WIB_SW_QC/".format(wibhost)
        command = ["scp", "-r", logs['PC_WRCFG_FN'] , wibdst]
        #result=subrun(command, timeout = None)
        result=subrun(command, timeout = 60*5)
        if 'Error' != result and 'Timeout Error' != result:
            logs['CFG_wrto_WIB'] = [command, result.stdout]
    
            wibsrc = "{}:/home/root/BNL_CE_WIB_SW_QC/asic_info.csv".format(wibhost)
            pcdst = "../BNL_QC_LArASIC/readback/"
            command = ["scp", "-r", wibsrc , pcdst]
            #result=subrun(command, timeout = None)
            result=subrun(command, timeout = 60*5)
            if 'Error' != result and 'Timeout Error' != result:
                logs['CFG_rbfrom_WIB'] = [command, result.stdout]
                logs['PC_RBCFG_fn'] = pcdst + "asic_info.csv"
    
                logsd, fdir =  dat_read_cfg(infile_mode=True,  froot = logs['PC_RBCFG_fn'])
                DUT = logsd['DUT']
    
                result = filecmp.cmp(logs['PC_WRCFG_FN'], logs['PC_RBCFG_fn'])
                if result:
                    print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
                else:
                    print ("FAIL!")
                    print ("Exit anyway")
                    return None, test_history
                    #exit()
            else:
                print ("FAIL!")
                return None, test_history
        else:
            print ("FAIL!")
            return None, test_history

    if QC_TST_EN:
        print (datetime.datetime.utcnow(), " : Start DUT (%s) QC.(takes < 1200s)"%DUT)
        tmsi = 0
        retry_fi = 0
        while True:
            if tmsi >= len(tms):
                break
            
            testid = tms[tmsi]
            print (datetime.datetime.utcnow(), " : New Test Item Starts, please wait...")
            print (tms_items[testid])
            if "FE" in DUT:
                command = sshcmd + [ wibhost, "cd BNL_CE_WIB_SW_QC; python3 DAT_LArASIC_QC_top.py -t {}".format(testid)]
            elif "ADC" in DUT:
                command = sshcmd + [ wibhost, "cd BNL_CE_WIB_SW_QC; python3 DAT_ColdADC_QC_top.py -t {}".format(testid)]
            elif "CD" in DUT:
                command = sshcmd + [ wibhost, "cd BNL_CE_WIB_SW_QC; python3 DAT_COLDATA_QC_top.py -t {}".format(testid)]
            for attempt in [1,2]:
                #result=subrun(command, timeout = None) #rewrite with Popen later
                result=subrun(command, timeout = 60*20) #rewrite with Popen later
                if 'Timeout Error' != result:
                    break
                else:
                    test_history.setdefault(testid, []).append((datetime.datetime.utcnow(),env,'TIMEOUT'))
            if 'Error' != result and 'Timeout Error' != result:
                resultstr = result.stdout
                logs["QC_TestItemID_%03d"%testid] = [command, resultstr]
                if "Pass!" in result.stdout:
                    test_history.setdefault(testid, []).append((datetime.datetime.utcnow(),env,'PASS'))
                    print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
                elif "DAT_Power_On" in result.stdout:
                    test_history.setdefault(testid, []).append((datetime.datetime.utcnow(),env,'DAT POWER ON'))
                    print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS & Turn DAT on!  \033[0m")
                    continue
                elif "DAT_Power_Off" in result.stdout:
                    test_history.setdefault(testid, []).append((datetime.datetime.utcnow(),env,'DAT POWER OFF'))
                    print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS & Done!  \033[0m")
                    break
                else:
                    test_history.setdefault(testid, []).append((datetime.datetime.utcnow(),env,'FAIL'))
                    print ("FAIL!")
                    print (result.stdout)
                    print ("Exit anyway")
                    return None, test_history
                    #exit()
            else:
                print ("FAIL!")
                success=False
                if "FE" in DUT and testid == 1:
                    print('Will try rerunning tests 0 and 1 only again')
                    command = sshcmd + [ wibhost, "cd BNL_CE_WIB_SW_QC; python3 DAT_LArASIC_QC_top.py -t 0"]
                    for attempt in [1,2,3]:
                        _ = DAT_power_off()
                        print(f'Sleep {20*attempt}s')
                        #time.sleep(20*attempt)
                        countdown((20*attempt))
                        print('Run test 0')
                        result=subrun(command, timeout = 60*20)
                        if 'Timeout Error' != result:
                            break
                        else:
                            test_history.setdefault(0, []).append((datetime.datetime.utcnow(),env,'TIMEOUT'))
                            print (f"TIMEOUT TEST 0, attempt {attempt}")
                    print('Result after attempts')
                    print(result)
                    if 'Timeout Error' != result:
                        print('Still a time out!')
                    if 'Error' != result and 'Timeout Error' != result:
                        resultstr = result.stdout
                        logs["QC_TestItemID_000"] = [command, resultstr]

                        if "Pass!" in result.stdout:
                            test_history.setdefault(0, []).append((datetime.datetime.utcnow(),env,'PASS'))
                            print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
                        elif "DAT_Power_On" in result.stdout:
                            test_history.setdefault(0, []).append((datetime.datetime.utcnow(),env,'DAT POWER ON'))
                            print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS & Turn DAT on!  \033[0m")
                            continue
                        elif "DAT_Power_Off" in result.stdout:
                            test_history.setdefault(0, []).append((datetime.datetime.utcnow(),env,'DAT POWER OFF'))
                            print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS & Done!  \033[0m")
                            break
                        else:
                            test_history.setdefault(0, []).append((datetime.datetime.utcnow(),env,'FAIL'))
                            print ("FAIL! (no error) For test 0")
                            print('Exit anyway')
                            _ = DAT_power_off()
                            return None, test_history
                    else:
                        if 'Timeout Error' != result: # timeout will already have been logged
                            test_history.setdefault(0, []).append((datetime.datetime.utcnow(),env,'FAIL'))
                        print('ERROR Fail!')
                        print ("Exit")
                        _ = DAT_power_off()
                        return None, test_history
                        
                    command = sshcmd + [ wibhost, "cd BNL_CE_WIB_SW_QC; python3 DAT_LArASIC_QC_top.py -t 1"]
                    for attempt in [1,2,3]:
                        print(f'Sleep {20*attempt}s')
                        #time.sleep(20*attempt)
                        countdown((20*attempt))
                        print('Run test 1')
                        result=subrun(command, timeout = 60*20)
                        if 'Timeout Error' != result:
                            break
                        else:
                            test_history.setdefault(1, []).append((datetime.datetime.utcnow(),env,'TIMEOUT'))
                            print (f"TIMEOUT TEST 1, attempt {attempt}")
                    print('Result after attempts:')
                    print(result)
                    if 'Timeout Error' !=result:
                        print('Still a time out!')
                    if 'Error' != result and 'Timeout Error' != result:
                        resultstr = result.stdout
                        logs["QC_TestItemID_001"] = [command, resultstr]
                        if "Pass!" in result.stdout:
                            success=True
                            test_history.setdefault(1, []).append((datetime.datetime.utcnow(),env,'PASS'))
                            print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
                        elif "DAT_Power_On" in result.stdout:
                            test_history.setdefault(1, []).append((datetime.datetime.utcnow(),env,'DAT POWER ON'))
                            print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS & Turn DAT on!  \033[0m")
                            continue
                        elif "DAT_Power_Off" in result.stdout:
                            test_history.setdefault(1, []).append((datetime.datetime.utcnow(),env,'DAT POWER OFF'))
                            print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS & Done!  \033[0m")
                            break
                        else:
                            if 'Timeout Error' !=result:
                                test_history.setdefault(1, []).append((datetime.datetime.utcnow(),env,'FAIL'))
                            print ("FAIL! (no error) for test 1")
                            print ("Exit anyway")
                            _ = DAT_power_off()
                            return None, test_history
                    else:
                        test_history.setdefault(1, []).append((datetime.datetime.utcnow(),env,'FAIL'))
                        print ("ERROR FAIL!")
                        print ("Exit")
                        _ = DAT_power_off()
                        return None, test_history
                if not success:
                    return None, test_history
                
                print('Will continue to rest of tests...')
   
            print ("Transfer data to PC...")
            fdir = resultstr[resultstr.find("save_fdir_start_")+16:resultstr.find("_end_save_fdir")] 
            #wib_raw_dir = fdir #later save it into log file
            logs['wib_raw_dir'] = fdir
            fs = resultstr[resultstr.find("save_file_start_")+16:resultstr.find("_end_save_file")] 
            fsubdirs = fdir.split("/")
            fn = fs.split("/")[-1]
            fddir =logs['PC_rawdata_root'] + fsubdirs[-2] + "/" 
    
            if not os.path.exists(fddir):
                try:
                    os.makedirs(fddir)
                except OSError:
                    print ("Error to create folder %s"%fddir)
                    print ("Exit anyway")
                    #sys.exit()
                    return None, test_history
            fsrc = wibhost + ":" + fs
            command = ["scp", "-r",fsrc , fddir]
            #result=subrun(command, timeout = None)
            result=subrun(command, timeout = 60*5)
            if 'Error' != result and 'Timeout Error' != result:
                print ("data save at {}".format(fddir))
                logs['pc_raw_dir'] = fddir #later save it into log file
                logs["QC_TestItemID_%03d_SCP"%testid] = [command, result]
                logs["QC_TestItemID_%03d_Save"%testid] = logs['pc_raw_dir']
                print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
            else:
                print ("FAIL!")
                return None, test_history

            if (testid == 0) and ("RT" in env):
                print ("Run quick analysis...")
                QCstatus, bads = dat_initchk(fdir=logs['pc_raw_dir'])
                print (QCstatus, bads)

                #debugging, to be delete
                #QCstatus = "PASS"
                #bads = []

                if (len(bads) > 0) or ("Code#E" in QCstatus):
                    #if logs['New_chips']:
                    if True:
                        fp = logs['pc_raw_dir'] + "QC.log"
                        with open(fp, 'wb') as fn:
                            pickle.dump(logs, fn)
                    fdirdel = logs['wib_raw_dir']
                    #command = ["rm", "-rf",fdirdel] 
                    command = sshcmd + [ wibhost, "rm -rf {}".format(fdirdel)] 
                    #result=subrun(command, timeout = None)
                    result=subrun(command, timeout = 60*5)
                    if 'Error' != result and 'Timeout Error' != result:
                        print ("WIB folder {} is deleted!".format(fdirdel))
                    return (QCstatus, bads), test_history

            if duttype == "CD":
                cd_qc_ana = CD_QC_ANA()
                cd_qc_ana.env = env
                cd_qc_ana.qc_stats = {}
                cd_qc_ana.dat_cd_qc_ana(fdir=logs['pc_raw_dir'], tms=[testid])
                keys = list(cd_qc_ana.qc_stats.keys())
                retry_fi_pre = retry_fi
                for onekey in keys:
                    if "PASS" not in cd_qc_ana.qc_stats[onekey]:
                        retry_fi = retry_fi  +1
                        break
                if (retry_fi == 1) and (retry_fi != retry_fi_pre):
                    tmsi = tmsi
                    continue
                elif retry_fi >=2:
                    QCstatus = "PASS"
                    bads = []
                    tmsi = tmsi + 1
                    retry_fi = 0
                    #
                else:
                    tmsi = tmsi + 1
                    retry_fi = 0
            else:
                tmsi = tmsi + 1

        fdirdel = logs['wib_raw_dir']
        command = sshcmd + [ wibhost, "rm -rf {}".format(fdirdel)] 
        result=subrun(command, timeout = 60)
        if 'Error' != result and 'Timeout Error' != result:
            print ("WIB folder {} is deleted!".format(fdirdel))

  
    if QC_TST_EN:
        print ("save log info during QC")
        #if logs['New_chips']:
        if True:
            fp = logs['pc_raw_dir'] + "QC.log"
            with open(fp, 'wb') as fn:
                pickle.dump(logs, fn)
        else:
            tmpstr = "".join(str(x) + "_" for x in logs['TestIDs'])
            fp = logs['pc_raw_dir'] + "QC_Retest_{}.log".format(tmpstr)
            print (fp)
            with open(fp, 'wb') as fn:
                pickle.dump(logs, fn)
    
    QCstatus = "PASS"
    bads = []

    return (QCstatus, bads), test_history

if __name__=="__main__":
    result = rts_ssh(dut_skt={20250926130804:(0,0)}, root = "C:/SGAO/ColdTest/Tested/DAT_LArASIC_QC/B006T0001/", duttype="FE", env="RT", chips=1 )
    if 'Error' != result and 'Timeout Error' != result:
        QCstatus = result[0]
        print (QCstatus)
        print (result)


