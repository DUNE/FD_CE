import sys 
import os
import subprocess
import time 
import datetime
import random
import pickle
import csv
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

def ReadTrayScan(TrayID):
    '''
    Opens output of robot tray scan and loads into a dictionary
    with information about the OCR processing
    '''
    tray_scan_file = rootdir+"../TrayCatalogs/Scans/TrayScan_" + TrayID + ".csv"
    if not os.path.exists(tray_scan_file):
        print(f'No tray file for {TrayID} found')
        return None
    print (f'File found for {TrayID} at {tray_scan_file}')
    scan_contents={}
    scan_tray=[]
    scan_col=[]
    scan_row=[]
    scan_occupied=[] 
    scan_image=[]
    scan_processed=[] 
    scan_serial=[]
    scan_warnings=[]
    scan_checked=[]
    with open(tray_scan_file, newline='') as f:
        reader=csv.DictReader(f)
        for row in reader:
            scan_tray.append(dict(row)['tray'])
            scan_col.append(dict(row)['col'])
            scan_row.append(dict(row)['row'])
            scan_occupied.append(dict(row)['occupied'])
            scan_image.append(dict(row)['image'])
            scan_processed.append(dict(row)['processed'])
            scan_serial.append(dict(row)['serial'])
            scan_warnings.append(dict(row)['warnings'])
            scan_checked.append(dict(row)['checked'])
    scan_contents={'tray':scan_tray, 'col':scan_col, 'row':scan_row, 'occupied':scan_occupied, 'image':scan_image, 'processed':scan_processed, 'serial':scan_serial, 'warnings':scan_warnings, 'checked':scan_checked}
    return scan_contents

def GetSNs(TrayID, cols, rows, ScanFile={}):
    if not ScanFile:
        ScanFile = ReadTrayScan(TrayID)
    sns=[]
    for i in range(len(cols)):
        for j in range(len(ScanFile['col'])):
            if str(cols[i]) == ScanFile['col'][j] and str(rows[i]) == ScanFile['row'][j]:
                print(f'tray {TrayID} col {ScanFile['col'][j]} row {ScanFile['col'][j]} : serial {ScanFile['serial'][j]}')
                sns.append(ScanFile['serial'][j])
                break
    return sns

def DAT_QC(rootdir, dut_skt, sns, duttype="FE",  env="RT" ) :
    while True:
        QCresult, _ = rts_ssh(dut_skt, sns, root=rootdir, duttype=duttype, env=env)
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
chips= [1,2,3,4,5,6,7,8]
cols = [1,1,1,1,1,1,2,2]
rows = [1,2,3,4,5,6,1,2]
skts=[0,1,2,3,4,5,6,7]
dut_skt={}
# dut_skt = {str(dut0):(chips[0],skts[0]),
#            str(dut0+1):(chips[1],skts[1]),
#            str(dut0+2):(chips[2],skts[2]),
#            str(dut0+3):(chips[3],skts[3]),
#            str(dut0+4):(chips[4],skts[4]),
#            str(dut0+5):(chips[5],skts[5]),
#            str(dut0+6):(chips[6],skts[6]),
#            str(dut0+7):(chips[7],skts[7]), }

for i in range(0, len(chips)):
    dut_skt[str(dut0+i)] = (chips[i], skts[i])

# # JW: slightly hacky way to get serial numbers for chps from MSU tray scan file - relies on config file having correct TrayID
# index_f = pc_wrcfg_fn
# info={}
# with open(index_f, 'r') as fp:
#     for cl in fp:
#         tmp = cl.split(",")
#         tmp = tmp[:-1]
#         info[tmp[0]] = tmp[1]

# print(f'TrayID is listed as {info['Tray_ID']}')
# sns = GetSNs(info['Tray_ID'], cols, rows)

# JW: Very hacky work around for use with BNL OCR output manually
# TODO: add bnl pickle file parsing option
sns = ['002-03163',
       '002-03146',
       '002-03127',
       '002-03168',
       '002-06260',
       '002-06272',
       '002-03162',
       '002-03147']

# print ('Serial numbers from OCR file to pass:')
# print(sns)
# print (' Serial numbers in config file :')
# for i in skts:
#     field='FE'+str(skts[i])
#     print(info[field])

print('Will test sockets')
for i, (key, d_s)  in enumerate(dut_skt.items()):
    print(f'Tray chip {d_s[0]} in socket {d_s[1]} with serial {sns[i]} with unique testid {key}')


print('Ready to start?')
while True:
    inyn=input('Y/N?')
    if inyn in ['y','Y','yes','Yes','YES']:
        break
    if inyn in ['n','N','no','No','NO']:
        sys.exit(1)

QCstatus, badchips = DAT_QC(rootdir, dut_skt, sns, duttype, env)

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
    
