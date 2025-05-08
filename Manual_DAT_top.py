import sys 
import os
import subprocess
import time 
import datetime
import random
import pickle
from DAT_read_cfg import dat_read_cfg
import filecmp
from colorama import just_fix_windows_console
just_fix_windows_console()
from DAT_chk_cfgfile import dat_chk_cfgfile
from set_rootpath import rootdir_cs
#import colorama
#from colorama import Fore, Back
#colorama.init(autoreset=True)

wibip = "192.168.121.123"
wibhost = "root@{}".format(wibip)

#start robot
from rts_ssh import subrun
from rts_ssh import rts_ssh
from rts_ssh import DAT_power_off

####### Input test information #######
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

try:
    chiptype = int (input ("\033[96m Chips under test. 1-FE, 2-ADC, 3-CD:  \033[95m"))
    if chiptype > 0 and chiptype <= 3:
        pass
    else:
        print ("\033[91m Wrong number, please input number between 1 to 3 \033[0m")
        print ("\033[91m exit anyway")
        exit()
except ValueError:
    print ("\033[91m Not a number, please input number between 1 to 3 \033[0m")
    print ("\033[91m exit anyway \033[0m")
    exit()

if chiptype == 1:
    duttype = "FE"
    rootdir = rootdir_cs(duttype)
elif chiptype == 2:
    duttype = "ADC"
    rootdir = rootdir_cs(duttype)
elif chiptype == 3:
    duttype = "CD"
    rootdir = rootdir_cs(duttype)

env = input ("RT/LN : ")
while True:
    print ("\033[96m Root folder of test data is: "+ "\033[93m" + rootdir + "\033[0m")
    yns = input ("\033[96m Is path correct (Y/N): " + "\033[95m" )
    if "Y" in yns or "y" in yns:
        break
    else:
        print ( "\033[91m Wrong path, please edit set_rootpath.py" + "\033[0m")
        print ( "\033[91m exit anyway" + "\033[0m")
        exit()

pc_wrcfg_fn = "./asic_info.csv"
############################################################

def DAT_QC(rootdir, dut_skt, duttype="FE",  env="RT" ) :
    while True:
        QCresult = rts_ssh(dut_skt, root=rootdir, duttype=duttype, env=env)
        if QCresult != None:
            QCstatus = QCresult[0]
            badchips = QCresult[1]
            break
        else:
            print ("\033[91m " + "139-> terminate, 2->debugging")
            userinput = input ("\033[93m " + "Please contatc tech coordinator")
            if len(userinput) > 0:
                if "139" in userinput :
                    QCstatus = "Terminate"
                    badchips = []
                    break
                elif "2" in userinput[0] :
                    print ("debugging, ")
                    input ("\033[93m " + "click any key to start ASIC QC again...")
    return QCstatus, badchips #badchips range from 0 to7


if True:
    print ("\033[0m ", datetime.datetime.utcnow(), " : Check if WIB is pingable (it takes < 60s)" )
    timeout = 10 
    command = ["ping", wibip]
    print ("\033[92m ", "COMMAND:", command)
    for i in range(6):
        result = subrun(command=command, timeout=timeout, exitflg=False)
        if i == 5:
            print ("\033[91m " + "Please check if WIB is powered and Ethernet connection,exit anyway")
            exit()
        log = result.stdout
        chk1 = "Reply from {}: bytes=32".format(wibip)
        chk2p = log.find("Received =")
        chk2 =  int(log[chk2p+11])
        if chk1 in log and chk2 >= 1:  #improve it later
            print ("\033[0m ", datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
            break

while True:#
    ynstr = input("\033[93m  Please open the shielding box to check if all LEDs on DAT are OFF! (Y/N) \033[95m")
    if "Y" in ynstr or "y" in ynstr:
        break
    else:
        print ( "\033[0m ", datetime.datetime.utcnow(), " : Power DAT down (it takes < 60s)")
        command = ["ssh", wibhost, "cd BNL_CE_WIB_SW_QC; python3 top_femb_powering.py off off off off"]
        result=subrun(command, timeout = 60)
        if "Done" in result.stdout:
            print ("\033[0m ", datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
        else:
            print ("\033[91m " + "FAIL!" +"\033[0m")
            print (result.stdout)
            print ("\033[91m " + "Exit anyway" +"\033[0m")
            exit()

if True:
    #ynstr = "Y"
    #if "Y" in ynstr or "y" in ynstr:
    print ("\033[0m ", datetime.datetime.utcnow(), "\033[93m   : Please put chips into the sockets carefully \033[0m")
    while True:
        yns = input ("\033[96m Locations of pin#1 of chips are correct (Y/N): " + "\033[95m" )
        if "Y" in yns or "y" in yns:
            break
        else:
            print ( "\033[91m Please re-position chips in socket!" + "\033[0m")

    while True:#
        print ("\033[93m Please update chip serial numbers"+ "\033[0m")
        command = ["notepad.exe", pc_wrcfg_fn]
        result=subrun(command, timeout = None, check=False)
        pf= dat_chk_cfgfile(fcfg = pc_wrcfg_fn, duttype=duttype )
        if pf:
            break
        else:
            yns = input ("\033[96m re-open config file for editting (Y/N): " + "\033[95m" )
            if "Y" in yns or "y" in yns:
                pass
            else:
                print ("\033[91m exit anyway \033[0m")
                print ("\033[91m please restart the test script \033[0m")
                exit()

if False: #included in rts_ssh.py 
    #print ("later use pyqt to pop out a configuration windows")
    print ("\033[0m " , datetime.datetime.utcnow(), " : load configuration file from PC")

    wibdst = "{}:/home/root/BNL_CE_WIB_SW_QC/".format(wibhost)
    command = ["scp", "-r", pc_wrcfg_fn , wibdst]
    result=subrun(command, timeout = None)

    wibsrc = "{}:/home/root/BNL_CE_WIB_SW_QC/asic_info.csv".format(wibhost)
    pcdst = "./readback/"
    command = ["scp", "-r", wibsrc , pcdst]
    result=subrun(command, timeout = None)
    pc_rbcfg_fn = pcdst + "asic_info.csv"

    logsd, fdir =  dat_read_cfg(infile_mode=True,  froot = pc_rbcfg_fn)

    result = filecmp.cmp(pc_wrcfg_fn, pc_rbcfg_fn)
    if result:
        print ("\033[0m " , datetime.datetime.utcnow(), "\033[92m  : SUCCESS!  \033[0m")
    else:
        print ("\033[91m " + "FAIL!" +"\033[0m")
        print ("\033[91m " + "Exit anyway" +"\033[0m")
        exit()

now = datetime.datetime.utcnow()
dut0 = int(now.strftime("%Y%m%d%H%M%S"))&0xFFFFFFFFFFFFFFFF
################STEP1#################################
skts=[0,1,2,3,4,5,6,7]
dut_skt = {str(dut0):(0,1), str(dut0+1):(0,2), str(dut0+2):(0,3), str(dut0+3):(0,4), str(dut0+4):(0,5), str(dut0+5):(0,6), str(dut0+6):(0,7), str(dut0+7):(0,8) }
QCstatus, badchips = DAT_QC(rootdir, dut_skt, duttype, env) 

if "PASS" in QCstatus :
    print (QCstatus)
    print ("\033[92m " + "Well done, please move chips back to tray." +"\033[0m")
elif ("Code#E001" in QCstatus) or ("Terminate" in QCstatus) :
    print (QCstatus, badchips)
    DAT_power_off()
    print ("\033[93m " + "Please contact the tech coordinator" +"\033[0m")
elif "Code#" in QCstatus:
    DAT_power_off()
    print (QCstatus, badchips)
    if len(badchips) > 0:
        for bc in badchips:
            print ("\033[93m " + "chip%d (1-8) is bad, please move it to bad tray and replace it with a new chip"%(bc+1) +"\033[0m")
            while True:
                ytstr = input ("\033[95m " + "Replace (y/n?): ")
                if "Y" in ytstr or "y" in ytstr:
                    break
        print ("\033[93m " +"please restart the test script" +"\033[0m" )
    else:
        print ("\033[93m " +"Please contact the tech coordinator" +"\033[0m")
    
