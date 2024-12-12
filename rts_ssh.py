import time
import sys
import subprocess
import datetime
import filecmp
import pickle
import os
from DAT_read_cfg import dat_read_cfg
from DAT_InitChk import dat_initchk
from colorama import just_fix_windows_console
from DAT_COLDATA_QC_ana import QC_ANA 
just_fix_windows_console()

wibip = "192.168.121.123"
wibhost = "root@{}".format(wibip)

def subrun(command, timeout = 30, check=True, exitflg = True):
    try:
        result = subprocess.run(command,
                                capture_output=True,
                                text=True,
                                timeout=timeout,
                                shell=True,
                                #stdout=subprocess.PIPE,
                                #stderr=subprocess.PIPE,
                                check=check
                                )
    except subprocess.CalledProcessError as e:
        print ("Call Error", e.returncode)
        if exitflg:
            print ("Call Error FAIL!")
            print ("Exit anyway")
            return None
            #exit()
            

        #continue
    except subprocess.TimeoutExpired as e:
        print ("No reponse in %d seconds"%(timeout))
        if exitflg:
            #print (result.stdout)
            print ("Timoout FAIL!")
            print ("Exit anyway")
            return None
            #exit()

        #continue
    return result


def DAT_power_off():
    logs = {}
    print (datetime.datetime.utcnow(), " : Power DAT down (it takes < 60s)")
    command = ["ssh", wibhost, "cd BNL_CE_WIB_SW_QC; python3 top_femb_powering.py off off off off"]
    result=subrun(command, timeout = 60)
    if result != None:
        if "Done" in result.stdout:
            print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
        else:
            print ("FAIL!")
            print (result.stdout)
            return None
    else:
        print ("FAIL!")
        return None

def DAT_power_on():
    logs = {}
    print (datetime.datetime.utcnow(), " : Power DAT On (it takes < 60s)")
    command = ["ssh", wibhost, "cd BNL_CE_WIB_SW_QC; python3 top_femb_powering.py on off off off"]
    result=subrun(command, timeout = 60)
    if result != None:
        if "Done" in result.stdout:
            print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
        else:
            print ("FAIL!")
            print (result.stdout)
            return None
    else:
        print ("FAIL!")
        return None

def Sinkcover():
    while True:
        ccflg=input("\033[93m Do covers of shielding box close? (Y/N) : \033[0m")
        if ("Y" in ccflg) or ("y" in ccflg):
            break
        else:
            print ("Please close the covers and continue...")

def rts_ssh(dut_skt, root = "C:/DAT_LArASIC_QC/Tested/", duttype="FE" ):

    QC_TST_EN =  True 
    
    logs = {}
    logs['RTS_IDs'] = dut_skt
    x = list(dut_skt.keys())
    if "FE"in duttype or "ADC"in duttype:
        logs['PC_rawdata_root'] = root + "Time_{}_DUT_{:04d}_{:04d}_{:04d}_{:04d}_{:04d}_{:04d}_{:04d}_{:04d}/".format(x[0],
                                                                            dut_skt[x[0]][1]*1000 + dut_skt[x[0]][0], 
                                                                            dut_skt[x[1]][1]*1000 + dut_skt[x[1]][0], 
                                                                            dut_skt[x[2]][1]*1000 + dut_skt[x[2]][0], 
                                                                            dut_skt[x[3]][1]*1000 + dut_skt[x[3]][0], 
                                                                            dut_skt[x[4]][1]*1000 + dut_skt[x[4]][0], 
                                                                            dut_skt[x[5]][1]*1000 + dut_skt[x[5]][0], 
                                                                            dut_skt[x[6]][1]*1000 + dut_skt[x[6]][0], 
                                                                            dut_skt[x[7]][1]*1000 + dut_skt[x[7]][0] 
                                                                            ) 
    else:
        logs['PC_rawdata_root'] = root + "Time_{}_DUT_{:04d}_{:04d}/".format(x[0],
                                                                            dut_skt[x[0]][1]*1000 + dut_skt[x[0]][0], 
                                                                            dut_skt[x[1]][1]*1000 + dut_skt[x[1]][0]
                                                                            )

    logs['PC_WRCFG_FN'] = "./asic_info.csv"
    
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
        tms_items[6  ] = "\033[96m 6: ADC DNL/INL measurement  \033[0m"
        tms_items[7  ] = "\033[96m 7: ADC DAT-DAC SCAN  \033[0m"
        tms_items[8  ] = "\033[96m 8: ADC ENOB measurement \033[0m"
        tms_items[11 ] = "\033[96m 11: ADC ring oscillator frequency readout \033[0m"
        tms_items[12 ] = "\033[96m 12: ADC RANGE test \033[0m"
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
        tms_items[7  ] = "\033[96m 7: COLDATA EFUSE burn-in \033[0m"
        tms_items[9  ] = "\033[96m 9: Turn DAT off \033[0m"
#        tms_items[10 ] = "\033[96m 10: Turn DAT (on WIB slot0) on without any check\033[0m"

    logs['tms_items'] = tms_items
    
    if QC_TST_EN:
        tms = list(tms_items.keys())
        #print (datetime.datetime.utcnow(), "\033[93m   : Please put chips into the sockets carefully \033[0m")
        #print ("Please update chip serial numbers")
        #command = ["notepad.exe", logs['PC_WRCFG_FN']]
        #result=subrun(command, timeout = None, check=False)
        #from DAT_chk_cfgfile import dat_chk_cfgfile
        #pf= dat_chk_cfgfile(fcfg = logs['PC_WRCFG_FN'], duttype=duttype )
        #if pf:
        logs['New_chips'] = True
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
                return None

            result = subrun(command=command, timeout=timeout, exitflg=False)
            if result != None:
                log = result.stdout
                chk1 = "Reply from {}: bytes=32".format(wibip)
                chk2p = log.find("Received =")
                chk2 =  int(log[chk2p+11])
                if chk1 in log and chk2 >= 1:  #improve it later
                    print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
                    logs['WIB_Pingable'] = log
                    break
    
    if QC_TST_EN:
        print (datetime.datetime.utcnow(), " : sync WIB time")
        # Get the current date and time
        now = datetime.datetime.utcnow()
        # Format it to match the output of the `date` command
        formatted_now = now.strftime('%a %b %d %H:%M:%S UTC %Y')
        command = ["ssh", wibhost, "date -s \'{}\'".format(formatted_now)]
        result=subrun(command, timeout = 30)
        if result != None:
            print ("WIB Time: ", result.stdout)
            print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
            logs['WIB_UTC_Date_Time'] = result.stdout
        else:
            print ("FAIL!")
            return None
   
    if QC_TST_EN and (duttype=="ADC"):

        print (datetime.datetime.utcnow(), " : Load WIB bin file(it takes < 30s)" )
        command = ["ssh", wibhost, "fpgautil -b /boot/wib_top_0506.bin"]
        result=subrun(command, timeout = 30)
        if result != None:
            if "BIN FILE loaded through FPGA manager successfully" in result.stdout:
                print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
            logs['WIB_bin_file'] = result.stdout
        else:
            print ("FAIL!")
            return None
    
    if QC_TST_EN:
        print (datetime.datetime.utcnow(), " : Start WIB initialization (it takes < 30s)")
        command = ["ssh", wibhost, "cd BNL_CE_WIB_SW_QC;  python3 wib_startup.py"]
        result=subrun(command, timeout = 30)
        if result != None:
            if "Done" in result.stdout:
                print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
            else:
                print ("FAIL!")
                print (result.stdout)
                return None
                #exit()
            logs['WIB_start_up'] = result.stdout
        else:
            print ("FAIL!")
            return None
   
    if QC_TST_EN:
        #print ("later use pyqt to pop out a configuration windows")
        #input ("anykey to continue now")
        print (datetime.datetime.utcnow(), " : load configuration file from PC")
    
        wibdst = "{}:/home/root/BNL_CE_WIB_SW_QC/".format(wibhost)
        command = ["scp", "-r", logs['PC_WRCFG_FN'] , wibdst]
        result=subrun(command, timeout = None)
        if result != None:
            logs['CFG_wrto_WIB'] = [command, result.stdout]
    
            wibsrc = "{}:/home/root/BNL_CE_WIB_SW_QC/asic_info.csv".format(wibhost)
            pcdst = "./readback/"
            command = ["scp", "-r", wibsrc , pcdst]
            result=subrun(command, timeout = None)
            if result != None:
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
                    return None
                    #exit()
            else:
                print ("FAIL!")
                return None
        else:
            print ("FAIL!")
            return None

    
    if QC_TST_EN:
        print (datetime.datetime.utcnow(), " : Start DUT (%s) QC.(takes < 1200s)"%DUT)
        tmsi = 0
        qc = QC_ANA()
        retry_fi = 0
        while True:
            if tmsi >= len(tms):
                break
            
            testid = tms[tmsi]
            print (datetime.datetime.utcnow(), " : New Test Item Starts, please wait...")
            print (tms_items[testid])
            if "FE" in DUT:
                command = ["ssh", wibhost, "cd BNL_CE_WIB_SW_QC; python3 DAT_LArASIC_QC_top.py -t {}".format(testid)]
            elif "ADC" in DUT:
                command = ["ssh", wibhost, "cd BNL_CE_WIB_SW_QC; python3 DAT_ColdADC_QC_top.py -t {}".format(testid)]
            elif "CD" in DUT:
                command = ["ssh", wibhost, "cd BNL_CE_WIB_SW_QC; python3 DAT_COLDATA_QC_top.py -t {}".format(testid)]
            result=subrun(command, timeout = None) #rewrite with Popen later
            if result != None:
                resultstr = result.stdout
                logs["QC_TestItemID_%03d"%testid] = [command, resultstr]
                if "Pass!" in result.stdout:
                    print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
                elif "DAT_Power_On" in result.stdout:
                    print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS & Turn DAT on!  \033[0m")
                    continue
                elif "DAT_Power_Off" in result.stdout:
                    print (datetime.datetime.utcnow(), "\033[92m  : SUCCESS & Done!  \033[0m")
                    break
                else:
                    print ("FAIL!")
                    print (result.stdout)
                    print ("Exit anyway")
                    return None
                    #exit()
            else:
                print ("FAIL!")
                return None
    
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
                    print ("Error to create folder %s"%save_dir)
                    print ("Exit anyway")
                    #sys.exit()
                    return None
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
                return None

            if (testid == 0):
                print ("Run quick analysis...")
                QCstatus, bads = dat_initchk(fdir=logs['pc_raw_dir'])
                #debugging, to be delete
                #QCstatus = "PASS"
                #bads = []

                if len(bads) > 0 :
                    if logs['New_chips']:
                        fp = logs['pc_raw_dir'] + "QC.log"
                        with open(fp, 'wb') as fn:
                            pickle.dump(logs, fn)
                    fdirdel = logs['wib_raw_dir']
                    #command = ["rm", "-rf",fdirdel] 
                    command = ["ssh", wibhost, "rm -rf {}".format(fdirdel)] 
                    result=subrun(command, timeout = None)
                    if result != None:
                        print ("WIB folder {} is deleted!".format(fdirdel))
                    return (QCstatus, bads)

            #if duttype == "CD":
            if False: #debugging for LN, to be delete
                qc.qc_stats = {}
                qc.dat_cd_qc_ana(fdir=logs['pc_raw_dir'], tms=[testid])
                keys = list(qc.qc_stats.keys())
                retry_fi_pre = retry_fi
                for onekey in keys:
                    if "PASS" not in qc.qc_stats[onekey]:
                        retry_fi = retry_fi  +1
                        break
                if (retry_fi == 1) and (retry_fi != retry_fi_pre):
                    tmsi = tmsi
                    continue
                elif retry_fi >=2:
                    QCstatus = "Fail"
                    bads = [0, 1]

                    if len(bads) > 0 :
                        if logs['New_chips']:
                            fp = logs['pc_raw_dir'] + "QC.log"
                            with open(fp, 'wb') as fn:
                                pickle.dump(logs, fn)
                        fdirdel = logs['wib_raw_dir']
                        command = ["ssh", wibhost, "rm -rf {}".format(fdirdel)] 
                        result=subrun(command, timeout = None)
                        if result != None:
                            print ("WIB folder {} is deleted!".format(fdirdel))
                        return (QCstatus, bads)
                else:
                    tmsi = tmsi + 1
                    retry_fi = 0
            else:
                tmsi = tmsi + 1

        fdirdel = logs['wib_raw_dir']
        command = ["ssh", wibhost, "rm -rf {}".format(fdirdel)] 
        result=subrun(command, timeout = 60)
        if result != None:
            print ("WIB folder {} is deleted!".format(fdirdel))
   
    #if True:
    if QC_TST_EN:
        print ("save log info during QC")
        if logs['New_chips']:
            fp = logs['pc_raw_dir'] + "QC.log"
            with open(fp, 'wb') as fn:
                pickle.dump(logs, fn)
        else:
            tmpstr = "".join(str(x) + "_" for x in logs['TestIDs'])
            fp = logs['pc_raw_dir'] + "QC_Retest_{}.log".format(tmpstr)
            print (fp)
            with open(fp, 'wb') as fn:
                pickle.dump(logs, fn)
    
#    print ("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
#    else:
#    print ("LArASIC QC analysis script from Rado will add here")
    QCstatus = "PASS"
    bads = []
    #chip_passed = [0,1,2,3,4,5,6,7]
    #chip_failed = []

    return QCstatus, bads 

if __name__=="__main__":
   fdirdel = "/home/root/BNL_CE_WIB_SW_QC/tmp_data/RT_CD_031702417_031752417/"
   command = ["ssh", wibhost, "rm -rf {}".format(fdirdel)] 
   print (command)
   result=subrun(command,timeout=20)
   if result != None:
       print ("WIB folder {} is deleted!".format(fdirdel))

