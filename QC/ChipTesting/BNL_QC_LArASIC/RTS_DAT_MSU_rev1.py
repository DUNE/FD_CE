import sys 
import os
import subprocess
import time 
import random
import pickle
import numpy as np
import pandas as pd
import csv
import datetime

from PIL import Image
import matplotlib.pyplot as plt

# Tosend notification email
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from colorama import just_fix_windows_console
just_fix_windows_console()

from RTS_CFG import RTS_CFG
from rts_ssh import DAT_power_off, DAT_power_on
from rts_ssh import rts_ssh
from set_rootpath import rootdir_cs
from cryo_uart import cryobox
sys.path.append('./SN_recognition/')  
from SN_CLASS import SN_CLASS
from SN_chip_CPM_scan import ocr_chip, ocr_chip_preprocess
from sendemail import sendemail, sendslack
from User_Input import get_user_input
from init_check import init_chk 

from pyqt import ocr_correct_gui

import threading

### Global variables

TRAY_N = 90
BAD_TRAY_SPOT = 1

gui_info={'Name':'', 'Email':'', 'TrayID':'', 'DUTtype':''}
trayno=2
badtrayno=1
sinkno=1
LN2_flg=False
do_tray_scan=False
run_tests=False
dry_run=False
ocr_on_move=False
init_check_on_move=True
user_safeties=True
emails_enabled=False
slack_enabled=False
transfer_data=False
transfer_dir=''

robot_port=int(201)
robot_ip='192.168.121.1'
 #'192.168.0.2'
trayid=''
user_email=''
topdir=''
rootdir=''
duttype=''

# For config
config_file = "./auto_config_file.csv"
config={}

# failures=0
# places=0
# tests=0

def user_yn(options=[], timeout=-1, default=None):
    # Asks user to input Y/N or an specified option and returns 1, 0, -1 (exit) or the specified return
    # Option shoul be ("input value", return_value) where return_value is an integer
    if not (
        isinstance(options, list)
        and all(isinstance(opt, tuple) 
                and len(opt) == 2 
                and isinstance(opt[0], str)
                and isinstance(opt[1], int)
                for opt in options)
    ):
        raise TypeError("options must be a list of 2-tuples")

    yes=['y','yes'] #['y','Y','yes','Yes','YES']
    no=['n','no'] #['n','N','no','No','NO']
    while True:
        if timeout < 0:
            inyn = input("Y/N?: ")
        else: 
            inyn = input_with_timeout("Y/N?: ", timeout, default)
        if not inyn:
            return -2 # This will be default for "pass"
        if inyn.lower() in yes:
            return 1
        if inyn.lower() in no:
            return 0
        if inyn == "-1":
            return -1
        if len(options) > 0:
            # returns tuple second value if input matches first
            return next((ret for opt, ret in options if opt == inyn), None)

def input_with_timeout(prompt, timeout, default=None):
    result = default
    finished = threading.Event()

    def get_input():
        nonlocal result
        try:
            result = input(prompt)
        except EOFError:
            pass

    def countdown():
        remaining = timeout
        while remaining > 0 and not finished.is_set():
            print(f"\r{prompt} (Timer set {timeout}s, {remaining:2d}s remaining) :", end="", flush=True)
            time.sleep(1)
            remaining -= 1

        # Clear the countdown line
        print("\r" + " " * 30 + "\r", end="", flush=True)

    input_thread = threading.Thread(target=get_input, daemon=True)
    timer_thread = threading.Thread(target=countdown, daemon=True)

    input_thread.start()
    timer_thread.start()

    input_thread.join(timeout)

    if not finished.is_set():
        finished.set()# Stop the countdown
        if result == default:
            print(f"\nUsing default: {default!r}")

    timer_thread.join()

    return result


def is_weekday_work_hours():
    now = datetime.datetime.now()  # FIXED
    current_time = now.time()

    is_weekday = 0 <= now.weekday() <= 4
    start_time = datetime.time(8, 00)
    end_time = datetime.time(20, 00)  # FIXED typo

    in_time_range = start_time <= current_time <= end_time
    return is_weekday and in_time_range

### Config functions
def set_config_values():
    config['Name']=gui_info['Name']
    config['Email']=gui_info['Email']
    config['TrayID']=gui_info['TrayID']
    config['DUTtype']=gui_info['DUTtype']
    config['SourceTray']=trayno
    config['BadTray']=badtrayno
    config['SinkNo']=sinkno
    config['TopDir']=topdir
    config['LN2_flg']=LN2_flg
    config['DoScan']=do_tray_scan
    config['RunTests']=run_tests
    config['DryRun']=dry_run
    config['MoveOCR']=ocr_on_move
    config['MoveInitCheck']=init_check_on_move
    config['UserSafeties']=user_safeties
    config['EmailOn']=emails_enabled
    config['SlackOn']=slack_enabled
    config['RobotPort']=robot_port
    config['RobotIP']=robot_ip
    config['TransferData']=transfer_data
    config['TransferDir']=transfer_dir

# Set default config values here, will load in file later
# This is just so fields are right types 
set_config_values()

def read_bool(option):
    if option in ['0', 'n','N','no','No','NO', 'f', 'F', 'false', 'False', 'FALSE']:
        return False
    if option in ['1', 'y','Y','yes','Yes','YES', 't', 'T', 'true', 'True', 'TRUE']:
        return True
    print ("Invalid input string to Bool")
    sys.exit(1)

def get_config_values():
    global gui_info, trayno, badtrayno, sinkno, topdir, LN2_flg, do_tray_scan, run_tests, dry_run, ocr_on_move, init_check_on_move, user_safeties, emails_enabled, slack_enabled, robot_port, robot_ip, transfer_data, transfer_dir
    gui_info.update({'Name':config['Name'], 'Email':config['Email'], 'TrayID':config['TrayID'], 'DUTtype':config['DUTtype']})
    trayno=int(config['SourceTray'])
    badtrayno=int(config['BadTray'])
    sinkno=int(config['SinkNo'])
    topdir = config['TopDir']
    LN2_flg=read_bool(config['LN2_flg'])
    do_tray_scan=read_bool(config['DoScan'])
    run_tests=read_bool(config['RunTests'])
    dry_run=read_bool(config['DryRun'])
    ocr_on_move=read_bool(config['MoveOCR'])
    init_check_on_move=read_bool(config['MoveInitCheck'])
    user_safeties=read_bool(config['UserSafeties'])
    emails_enabled=read_bool(config['EmailOn'])
    slack_enabled=read_bool(config['SlackOn'])
    robot_ip=config['RobotIP']
    robot_port=int(config['RobotPort'])
    transfer_data=read_bool(config['TransferData'])
    transfer_dir=config['TransferDir']

    global user_email, rootdir, trayid
    user_email = gui_info['Email']
    trayid=gui_info['TrayID']
    rootdir=topdir+"Tested/"+trayid+"/"

def toggle_config(key, message):
    print(message)
    while True:
        inyn = input('Y/N? ')
        if inyn in ['y','Y','yes','Yes','YES']:
            config[key]=True
            break
        if inyn in ['n','N','no','No','NO']:
            config[key]=False
            break
        if inyn == "-1":
            print('User force quit!')
            sys.exit(1)

def input_config():
    print('Please enter settings values:')
    gui_info=get_user_input()

    config['Name']=gui_info['Name']
    config['Email']=gui_info['Email']
    config['TrayID']=gui_info['TrayID']
    config['DUTtype']=gui_info['DUTtype']

    toggle_config('DoScan','Do tray scan?')
    toggle_config('RunTests','Run the QC testing?')
    toggle_config('DryRun','Run Dry run (don\'t actually do anything)?')
    toggle_config('MoveOCR','Rerun OCR during move command?')
    toggle_config('UserSafeties','Require human input safeties on?')
    toggle_config('EmailOn','Send emails?')
    toggle_config('SlackOn','Send slack messages?')

    # Should use the top directory listed in rootdir script
    if 'LArASIC' in gui_info['DUTtype'] :
        duttype = "FE"
        config['TopDir'] = rootdir_cs(duttype)
    elif 'ColdADC' in gui_info['DUTtype'] :
        duttype = "ADC"
        config['TopDir']  = rootdir_cs(duttype)
    elif 'COLDATA' in gui_info['DUTtype'] :
        duttype = "CD"
        config['TopDir'] = rootdir_cs(duttype)
    else:
        print ("Wrong DUT type, exit anyway")
        sys.exit()


    write_config()

def print_config():
    for key in list(config.keys()):
        print(f'{key} = {config[key]}')

def read_config():
    print(f'Reading settins from config file {config_file}')
    with open(config_file, newline="") as f:
        reader = csv.reader(f)
        for key, value in reader:
            config[key] = value
    # Set the relevant variables
    get_config_values()

def write_config():
    print(f'Writing settings to config file {config_file}')
    # set_config_values() # Not needed as changes should be made to config first
    # then applied to global variables
    with open(config_file, "w", newline="") as f:
        writer = csv.writer(f)
        for key, value in config.items():
            writer.writerow([key, value])

### Notification functions

def notification(message, user_email, inform_tech=False, p_shifter=False, s_shifter=False, subject="RTS notification"):
    if emails_enabled:
        sendemail(subject=subject, message=message, user_email=user_email, inform_tech=inform_tech, p_shifter=p_shifter, s_shifter=s_shifter)
    if slack_enabled:
        sendslack(message)

def PowerDownDAT(user_email):
    poweroff=False
    for i in [1,2]:
        time.sleep(0.5)
        poweroff = DAT_power_off()
        if poweroff:
            break
        time.sleep(10)
    if not poweroff:
        DAT_debug('DAT power off Timeout',user_email)

### Debug functions

def DAT_debug (QCstatus, user_email):
    print (QCstatus)
    #notification(message="Please contact tech coordinator (DAT issue)", user_email=user_email, p_shifter=False, s_shifter=False, inform_tech=True)
    sendslack("Please contact tech coordinator (DAT issue)")
    while True:#
        #print ("444-> Move chips back to original positions")
        print ("444-> Shutdown RTS and exit anyway")
        print ("6->fixed,")
        userinput = input ("Please contact tech coordinator : ")
        if len(userinput) > 0:
            if "444" in userinput :
                rts.MotorOn()
                rts.JumpToCamera()
                rts.rts_shutdown()
                print ("Exit anyway")
                exit()
                #return "444"
            elif "6" in userinput :
                yorn = input ("Fixed. Are you sure? (y/Y):")
                if "Y" in yorn or "y" in yorn:
                    return "6"

def RTS_debug (info, user_email, status=None, trayno=None, trayc=None, trayr=None, sinkno=None, sktn=None, tray2no=None, tray2c=None, tray2r=None):
    #notification(message="Please contact tech coordinator (RTS issue)", user_email=user_email, p_shifter=False, s_shifter=False, inform_tech=True)
    sendslack("Please contact tech coordinator (RTS issue)")
    print ("Please check the error information on EPSON RC")

    if "T2S" in info:
        print ("Chip is moved from Tray") 
        print ("Chip on orignial TrayNo(1-2)={}, Col(1-15)={}, Row(1-6)={}".format(trayno, trayc, trayr)) 
    elif "S2T" in info:
        print ("Chip is moved from Socket") 
        print ("Chip on orignial Sinkno(1-2)={}, Skt(1-8)={} ".format(sinkno, sktn)) 
    elif "T2T" in info:
        print ("Chip is moved from Tray to Tray")
        print ("Chip on orignial TrayNo(1-2)={}, Col(1-15)={}, Row(1-6)={}".format(trayno, trayc, trayr)) 
        # print ("Chip on target TrayNo(1-2)={}, Col(1-15)={}, Row(1-6)={}".format(tray2no, tray2c, tray2r)) 
    elif "RESEAT" in info:
        print('Reseat failed in socket Sinkno(1-2)={}, Skt(1-8)={}'.format(sinkno, sktn))
        print('Please manually reseat')
    while True:
        print ("444-> Shutdown RTS and exit anyway")
        #print ("1->move chip to Tray#1_Col#15_Row#6")
        #print ("2->move chip to orignal position")
        print ("6->fixed,")

        userinput = input ("Please contact tech coordinator : ")
        if len(userinput) > 0:
            if "444" in userinput :
                rts.MotorOn()
                rts.JumpToCamera()
                rts.rts_shutdown()
                print ("Exit anyway")
                exit()
            elif "6" in userinput[0] :
                # input ("Make sure the chip back to orginal position and click anykey")
                print('Is chip back in original position?')
                inyn=0
                while inyn != 1:
                    inyn = user_yn()
                    if inyn == -1:
                        print('-1 corresponds to shutting down the RTS - Are you sure?')
                        if inyn == 1 or inyn == -1:
                            print ("Exiting RTS")
                            rts.MotorOn()
                            rts.JumpToCamera()
                            rts.rts_shutdown()
                            exit()                            
                if "OCR" not in info:
                    rts.MotorOn()
                break


### Some useful indexing function from MSUcode (modified for duttype)
# MSU code iterates over chips column by column.
# I.e. does the first column of 6 (4) chips for LArASIC/ColdADC (COLDATA)
# Then gets the next chips from the next column.
# So from tray 2 is (2, 1, 1) then (2, 1, 2) etc.
def GetChipIndex(col, row, duttype):
    if "CD" in duttype:
        return ((col -1) * 4 + row) -1
        # return ((col -1) * 10 + row) -1
    else: 
        return ((col -1) * 6 + row) -1
        # return ((col -1) * 15 + row) -1    

def GetChipCol(index, duttype):
    if "CD" in duttype:
        return ((index) // 4)+1
        # return ((index) % 10)+1
    else:
        return ((index) // 6)+1
        # return ((index) % 15)+1

def GetChipRow(index, duttype):
    if "CD" in duttype:
        return ((index) % 4)+1
        # return ((index) // 10)+1
    else:
        return ((index) % 6)+1
        # return ((index) // 15)+1

def CheckCoversOpen():
    # Checks both covers are open so safe to move robot
    print('Checking sink cover status')
    cover_sts = "-198"
    while ("-198" in cover_sts) and ("197" not in cover_sts):
        cover_sts = rts.CoverStatus(0) # Make sure both covers are open
        print (cover_sts)

        if ("-198" not in cover_sts) and ("197" not in cover_sts):
            print('ERROR! bad cover status code returned by robot')
            #notification(subject = "Bad cover status code", message="[CRYO] ERROR: Bad cover/lid status code ", user_email=user_email, inform_tech=True)# ,  p_shifter=p_shifter, s_shifter=s_shifter, ) 
            sendslack("[CRYO] ERROR: Bad cover/lid status code ")
        if "-198" in cover_sts:
            time.sleep(2)
            cover_sts_1 = rts.CoverStatus(1)
            if "-198" in cover_sts_1:
                print('Please open sink 1 ROBOT LEFT (Right as viewed from front of RTS)')
            cover_sts_2 = rts.CoverStatus(2)
            if "-198" in cover_sts_2:
                print('Please open sink 2 ROBOT RIGHT (Left as viewed from front of RTS)')
            print('Are both covers open?')
            inyn = user_yn() # will wait for response
            print(f'User input = {inyn}')
            time.sleep(2)
            cover_sts = rts.CoverStatus(0)
            print(cover_sts)
            if inyn == 1 and "197" in cover_sts:
                print('The covers are open')
                return True
            if inyn == 1 and "-198" in cover_sts:
                print('User indicated covers are open, but switch indicates covers are closed')
                print('CONFIRM: Are the covers OPEN [y/n]')
                inyn = user_yn()
                if inyn == 1:
                    print('ERROR: Switch still indicates at least one cover is closed! Please contact tech coordinator (cryo error)')
                    print('Will disconnect, please address switch issue in RC+')
                    rts.rts_disconnect()
                    sys.exit(1)         
            if inyn == 0 and "197" in cover_sts:
                print('User indicated covers are closed, but switch indicates covers are open')
                print('Are the covers OPEN [y/n]')
                inyn = user_yn()
                if inyn == 1:
                    print('The covers are open')
                    return True                    
                if inyn == 0:
                    print('ERROR: Switch indicates cover is in fact open! Please contact tech coordinator (cryo error)')
                    print('Will disconnect, please address switch issue in RC+')
                    rts.rts_disconnect()
                    sys.exit(1)
            if inyn == 0 and "-198" in cover_sts:
                print('Please open both covers!')
        elif "197" in cover_sts:
            print('Covers are open')
            return True
        else:
            print(f'WARNING: Should not be getting here cover_sts = {cover_sts}')
    if "197" in cover_sts:
        return True
    else:
        return False

def CheckCoverClosed(sinkno):
    # For cryo operation
    if sinkno == 1:
        side = "ROBOT LEFT (Right as viewed from front of RTS)"
    elif sinkno == 2:
        side = "ROBOT RIGHT (Left as viewed from front of RTS)"
    else:
        print(f'BAD sinkno : {sinkno}')

    print('Checking sink cover status')
    cover_sts = "197"
    while ("197" in cover_sts) or (not "-198" in cover_sts):
        time.sleep(2)
        cover_sts = rts.CoverStatus(sinkno)
        print (cover_sts)

        if ("-198" not in cover_sts) and ("197" not in cover_sts):
            print('ERROR! bad cover status code returned by robot')
            #notification(subject = "Bad cover status code", message="[CRYO] ERROR: Bad cover/lid status code ", user_email=user_email, inform_tech=True)# ,  p_shifter=p_shifter, s_shifter=s_shifter, inform_tech=True)
            sendslack("[CRYO] ERROR: Bad cover/lid status code ")
        if "197" in cover_sts:
            print(f'Please cover sink {sinkno}: {side}')
            print('Is sink cover closed?')
            inyn = user_yn() # will wait for response
            print(f'User input: {inyn}')
            time.sleep(2)
            cover_sts = rts.CoverStatus(sinkno)
            print (cover_sts)
            if inyn == 1 and "-198" in cover_sts:
                print('The cover is closed')
                return True
            if inyn == 1 and "197" in cover_sts:
                print(f'User indicated sink {sinkno} cover is closed but switch indicates it is open')
                print('CONFIRM: Is the cover CLOSED [y/n]')
                inyn = user_yn()
                if inyn == 1:
                    print('ERROR: Switch still indicates cover is open! Please contact tech coordinator (cryo error)')
                    print('Will disconnect, please address switch issue in RC+')
                    rts.rts_disconnect()
                    sys.exit(1)  
            if inyn == 0 and "-198" in cover_sts:
                print('User indicated cover is open, but switch indicates cover is closed')
                print('Is the cover CLOSED [y/n]')
                inyn = user_yn()
                if inyn == 1:
                    return True
                if inyn == 0:
                    print('ERROR: Switch indicates cover is in fact closed! Please contact tech coordinator (cryo error)')
                    print('Will disconnect, please address switch issue in RC+')
                    rts.rts_disconnect()
                    sys.exit(1)
            if inyn == 0 and "197" in cover_sts:
                print(f'Please close the cover for sink {sinkno} {side}!')                

        elif "-198" in cover_sts:
            print('The cover is closed')
            return True
        else:
            print(f'WARNING: Should not be getting here! cover_sts = {cover_sts}')

    if "-198" in cover_sts:
        return True
    else:
        return False

def MovetoSocket(sinkno, duts, ids_dict,  skts=[0,1,2,3,4,5,6,7], duttype="FE", do_initcheck=True, chips_preloaded=False) :
    print ("DUTtype", duttype)
    dut_skt = {}
    ids_bads = {}
    #make sure DAT is powered off
    PowerDownDAT(user_email)

    # Check RTS lid is open 
    if not CheckCoversOpen():
        print('Lid status could not be resolved! Contact tech coordinator')
        # notification(subject ="Cryo lid error", message="Cryo lid status could not be resolved by user.", user_email=user_email, p_shifter=False, s_shifter=False, inform_tech=True)
        sendslack("Cryo lid status could not be resolved by user.")
        rts.rts_disconnect()
        sys.exit(1)

    rts.MotorOn()
    rts.PumpOn()
    time.sleep(5)
    rts.PumpOff()

    # TODO JW: should local LN2_flag called here in DAT_QC always be false?
    # Since the lid isn't shut and the chamber filled till later?

    tmpi = 0
    tmpj = 0

    too_many_bad_place=False
    bad_place_threshold=5
    if "CD" in duttype:
        consecutive_place_failures=[0]*2
    else:
        consecutive_place_failures=[0]*8


    if not chips_preloaded:

        # print('Load new chips?')
        # while True:
        #     inyn = user_yn()
        #     if inyn == 1:
        #         break
        #     if inyn == -1:
        #         sys.exit(1)


        while tmpi < len(skts):
            skt = skts[tmpi]
            if len(duts)>0:
                print('Getting chipi from duts (untested)')
                chipi = duts[0]
                duts=duts[1:]
            else:
                print('Getting chipi from ids_dict (already tested good?)')
                ids_g = list(ids_dict.keys())
                chipi = ids_dict[ids_g[tmpj]][0]
                tmpj=tmpj+1

            print(f'chipi = {chipi}')

            # if "CD" in duttype:
            #     trayc=(chipi%10) +1
            #     trayr=(chipi//10) +1
            # else:
            #     trayc=(chipi%15) +1
            #     trayr=(chipi//15) +1

            trayc = GetChipCol(chipi, duttype)
            trayr = GetChipRow(chipi, duttype)

            sktn = skt + 1
            
            print('Will run: ')
            print(f'MoveChipFromTraytoSocket({trayno}, {trayc}, {trayr}, {sinkno}, {sktn}, {duttype})')
            # print('Proceed?')
            # inyn = user_yn()
            # if inyn != 1:
            #     rts.rts_disconnect()
            #     sys.exit(1)

            status = rts.MoveChipFromTrayToSocket(trayno, trayc, trayr, sinkno, sktn, duttype) 

            if status == -27: # Misalignment
                print (f'ERROR: Please manually reseat chip in socket ({sinkno},{sktn}) (index from 1)')
                print('Have you reseated the chip?')
                inyn = user_yn()
                if inyn == 1:
                    status = 0
                elif inyn == -1:
                    print('Exiting')
                    rts.disconnect()
                    sys.exit(1)
                else: 
                    print('Will continue to bad placement status handling')

            if status < 0:
                print (f'Robot place status returned as {status}')
                print (f"Current dut_skt (length {len(dut_skt)}):")
                print(dut_skt)
                # If there are too many issues with any of the sockets, send a notification

                if i in badchips:
                    consecutive_place_failures[skt] += 1
                    print(f'{consecutive_place_failures[skt]}th consecutive place failure on socket {sktn} (index from 1)')
                else:
                    consecutive_qc_failures[skt] = 0

                if consecutive_qc_failures[skt] > bad_qc_threshold:
                    print(f'ERROR: Too many place failures in a row on socket {sktn} (index from 1)')
                    too_many_bad_place=True
                else:
                    too_many_bad_place=False

                if too_many_bad_place:
                    RTS_debug("T2S",user_email,  status, trayno, trayc, trayr, sinkno, sktn)
                    print('Will proceed, if next chip fails "too many bad place" status will remain true')

                if len(duts) == 0: #use the next good chip
                    continue
                else:
                    RTS_debug ("T2S",user_email,  status, trayno, trayc, trayr, sinkno, sktn)
                    tmpi = tmpi
                    duts=[chipi] + duts
                    continue
            else:
                dut_skt[rts.msg] = (chipi, skt) # tray position (indexed from 0? and skt number), not sure how dut_skt is indexed...
                current_ids = rts.msg # this is the timestamp of the move command
                print (f"Current dut_skt (length {len(dut_skt)}):")
                print(dut_skt)
                if "CD" in duttype:
                    if len(skts) < 2:
                        chips =2
                    else:
                        chips = len(dut_skt)
                else:
                    if len(skts) < 8:
                        chips =8
                    else:
                        chips = len(dut_skt)
                print(f'chips varable now = {chips}')

                if do_initcheck:
                    # JW: As far as I can tell, if LN2_flg is true it will try to fill the sink
                    # which we don't want here, so explicily setting to false!

                    # QCstatus, badchips, _, _ = DAT_QC(user_email, dut_skt,duttype, LN2_flg=LN2_flg, testid=90+chips)  
                    QCstatus, badchips, _, _ = DAT_QC(user_email, dut_skt,duttype, LN2_flg=False, testid=90+chips, sinkno=sinkno)  
                    time.sleep(0.2)

                    PowerDownDAT(user_email)

                    if chips == 8: #recheck surge current
                        time.sleep(3)
                        # QCstatus, badchips, _, _ = DAT_QC(user_email, dut_skt,duttype, LN2_flg=LN2_flg, testid=90+chips)  
                        QCstatus, badchips, _, _  = DAT_QC(user_email, dut_skt,duttype, LN2_flg=False, testid=90+chips, sinkno=sinkno)  
                        PowerDownDAT(user_email)
                    
                    if ("Code#E001" in QCstatus) : 
                        # JW: First try reseat
                        status = rts.ReseatChipInSocket(DAT_nr=sinkno, socket_nr=sktn, duttype=duttype)
                        # status = -27
                        if status < 0:
                            print('PLEASE MANUALLY RESEAT')
                            RTS_debug ("RESEAT", user_email, status, trayno, trayc, trayr, sinkno, sktn)
                        #     continue
                        # else:
                        # QCstatus, badchips, _, _ = DAT_QC(user_email, dut_skt,duttype, LN2_flg=LN2_flg, testid=90+chips)
                        QCstatus, badchips, _, _ = DAT_QC(user_email, dut_skt,duttype, LN2_flg=False, testid=90+chips, sinkno=sinkno)
                        PowerDownDAT(user_email)

                    if any(badchips):
                        consecutive_place_failures[skt] += 1
                        print(f'{consecutive_place_failures[skt]}th consecutive place failure on socket {skt+1} (index from 1)')
                    else:
                        consecutive_qc_failures[skt] = 0
                    if consecutive_qc_failures[skt] > bad_qc_threshold:
                        print(f'ERROR: Too many place failures in a row on socket {skt+1} (index from 1)')
                        too_many_bad_qc=True
                    else:
                        too_many_bad_qc=False
                    if too_many_bad_qc:
                        # RTS_debug("T2S",user_email,  status, trayno, trayc, trayr, sinkno, sktn)
                        DAT_debug(QCstatus, user_email)
                        print('Will proceed, if next chip fails "too many bad place" status will remain true')
                        
                    
                    if ("Code#E001" in QCstatus) : #move back to original positions and then move back
                        
                        while True: 
                            status = rts.MoveChipFromSocketToTray(sinkno, sktn, trayno, trayc, trayr, duttype)
                            if status < 0:
                                RTS_debug ("S2T", user_email, status, trayno, trayc, trayr, sinkno, sktn)
                                continue
                            else:
                                dut_skt.pop(current_ids, None)  

                            status = rts.MoveChipFromTrayToSocket(trayno, trayc, trayr, sinkno, sktn,duttype)    
                            if status < 0:
                                RTS_debug ("T2S", user_email, status, trayno, trayc, trayr, sinkno, sktn)
                                continue
                            else:
                                dut_skt[rts.msg] = (chipi, skt)
                                current_ids = rts.msg
                                chips = len(dut_skt)
                                break

                        # QCstatus, badchips, _, _ = DAT_QC(user_email, dut_skt,duttype, LN2_flg=LN2_flg, testid=90+chips)  
                        QCstatus, badchips, _, _ = DAT_QC(user_email, dut_skt,duttype, LN2_flg=False, testid=90+chips, sinkno=sinkno)  
                        PowerDownDAT(user_email)
                        if ("Code#E001" in QCstatus) : #move back to bad tray 
                            ids = current_ids
                            ids_bads[ids] = dut_skt[ids]
                            removekey = ids
                            dut_skt.pop(removekey, None)  
                            ids_g = list(dut_skt.keys())
                            while True: 
                                FindSpotOnBadTray(user_email)
                                bad_dut_order = BAD_TRAY_SPOT - 1

                                trayc = GetChipCol(bad_dut_order, duttype)
                                trayr = GetChipRow(bad_dut_order, duttype)                            
            
                                status = rts.MoveChipFromSocketToTray(sinkno, sktn, badtrayno, trayc, trayr, duttype)
                                if status < 0:
                                    RTS_debug ("S2T", user_email, status, trayno, trayc, trayr, sinkno, sktn)
                                    continue
                                else:
                                    chips = len(dut_skt) #how many chips in sockets
                                    print(f'{chips} chips loaded, will run (current?) check')
                                    if chips > 0:
                                        # QCstatus, badchips, _, _ = DAT_QC(user_email, dut_skt,duttype, LN2_flg=LN2_flg, testid=90+chips)  
                                        QCstatus, badchips, _, _ = DAT_QC(user_email, dut_skt,duttype, LN2_flg=False, testid=90+chips, sinkno=sinkno)  
                                        PowerDownDAT(user_email)
                                        if ("Code#E001" in QCstatus) : 
                                            DAT_debug (QCstatus, user_email)
                                    break
                            tmpi= tmpi
                            duts= duts #bad chip is removed
                            continue
                        else:
                            tmpi = tmpi + 1 
                    else:
                        tmpi = tmpi + 1
                else:
                    tmpi = tmpi + 1

        SaveLoadedChipInfo(trayno,sinkno,dut_skt,duttype)
    else:
        print('Using preloaded chip information')
        print('Need to get chip socket alignment values or they won\'t be in robot memory')
        
        status = rts.MeasureAllAlignments(sinkno)
        if status == -28:
            print('Unable to measure alignment')
            rts.rts_disconnect()
            sys.exit(1)

        preloaded_file = topdir + "/chips_in_dat.csv"
        preloaded = pd.read_csv(preloaded_file)
        p_traycol=preloaded['Column'].tolist()
        p_trayrow=preloaded['Row'].tolist()
        p_timestamps=preloaded['Timestamp'].tolist()
        p_sockets=preloaded['Socket'].tolist()
        for index, row in preloaded.iterrows():
            if row['DAT']==sinkno:
                dut_skt[row['Timestamp']]=(GetChipIndex(row['Column'],row['Row'],"FE"),(row['Socket']-1))
                # print('duts=')
                # print (duts)
                # print (f'timstamp = {row['Timestamp']}')
                # print (f"removing {GetChipIndex(row['Column'],row['Row'],"FE")} from duts")
                duts.remove(GetChipIndex(row['Column'],row['Row'],"FE"))
    
    # Now all chips should be placed, do survey?
    sendslack("Please confirm the alignment of chips at RTS PC")
    needs_realign=[]
    while True:
        needs_realign=[]
    
        # Do some processing/storing of values?

        # Get and display images
        needs_realign, alignments = UserAlignCheck(sinkno)

        if len(needs_realign) == 0:
            print ('No chips need realigning')
            break

        print ('Following chips need realigning') 
        print (needs_realign)

        for chip in needs_realign:
            if needs_realign[chip] is None:
                print(f'Will reseat socket {chip} to target alignment')
                status = rts.ReseatChipInSocket(sinkno, chip, duttype="FE")
            else:
                print(f'Will reseat socket {chip} to user provided correction')
                status = rts.ReseatChipInSocketWithOffset(sinkno, chip, needs_realign[chip][0],needs_realign[chip][1],needs_realign[chip][2], duttype="FE")

            if status < 0 :
                RTS_debug ("RESEAT", user_email=user_email, sinkno=sinkno, sktn=chip)

    rts.rts_idle()
    print('At end of MoveToSocket command, dut_skt =  ')
    print(dut_skt)
    return duts, dut_skt, ids_bads, alignments

def SaveLoadedChipInfo(sourcetray,sinkno,dut_skt,duttype):
    filename = topdir + "/chips_in_dat.csv"
    print(f'Saving information for chips loaded into sockets in {filename}')
    timestamp= []
    tray=[]
    col=[]
    row=[]
    dat=[]
    socket=[]

    for entry in dut_skt.keys():
        timestamp.append(entry)
        tray.append(sourcetray)
        col.append(GetChipCol(dut_skt[entry][0],duttype))
        row.append(GetChipRow(dut_skt[entry][0],duttype))
        dat.append(sinkno)
        socket.append(dut_skt[entry][1]+1)

    info={
        'Timestamp':timestamp,
        'Tray':tray,
        'Column':col,
        'Row':row,
        'DAT':dat,
        'Socket':socket    
    }

    pd.DataFrame(info).to_csv(filename,index=False)

def DeleteLoadedChipInfo():
    filename = topdir + "/chips_in_dat.csv"
    if os.path.exists(filename):
        print(f'Deleting loaded chip information file at {filename}')
        os.remove(filename)
    else:
        print(f'No loaded chip info file to delete at {filename}')

def MovetoTray(sinkno, duts, dut_skt, QCstatus, badchips, duttype="FE", LN2_flg=False) :
    global BAD_TRAY_SPOT, TRAY_N, trayno
    ids_goods = {}
    ids_bads = {}

    ids_g = list(dut_skt.keys())
    PowerDownDAT(user_email)
    rts.MotorOn()
    rts.PumpOn()
    time.sleep(5)
    rts.PumpOff()


    if "CD" in duttype:
        SKT_N = 2
    else:
        SKT_N = 8

    # Would check lid here, but I think if "Terminate" is in the status it wants to recheck the QC status at cold?

    #if "Terminate" in QCstatus: #move back to original positions
    if ("Terminate" in QCstatus) : #move back to original positions
        rts.rts_idle()
        admincode = DAT_debug (QCstatus, user_email)
        if "2" in admincode:
            # JW: TODO check if this should have LN2_flg set to true. Seems odd to me
            QCstatus, badchips, _, _ = DAT_QC(user_email, dut_skt,duttype, LN2_flg=LN2_flg, sinkno=sinkno)  
            PowerDownDAT(user_email)
        elif "444" in admincode:
            RTS_debug ("DAT", user_email )
        rts.MotorOn()
        rts.PumpOn()
        time.sleep(5)
        rts.PumpOff()

        # Check RTS lid is open 
        if not CheckCoversOpen():
            print('Lid status could not be resolved! Contact tech coordinator')
            #notification(subject ="Cryo lid error", message="Cryo lid status could not be resolved by user.", user_email=user_email, p_shifter=False, s_shifter=False, inform_tech=True)
            sendslack("Cryo lid status could not be resolved by user.")
            rts.rts_disconnect()
            sys.exit(1)
            
        tmpi = 0
        while tmpi < SKT_N:
            for ids in ids_g:
                if dut_skt[ids][1] == tmpi:
                    chipi=dut_skt[ids][0]
                    sktn =dut_skt[ids][1] + 1
                    break
            # if "CD" in duttype:
            #     trayc=(chipi%10) +1
            #     trayr=(chipi//10) +1
            # else:
            #     trayc=(chipi%15) +1
            #     trayr=(chipi//15) +1

            trayc = GetChipCol(chipi, duttype)
            trayr = GetChipRow(chipi, duttype)

            status = rts.MoveChipFromSocketToTray(sinkno, sktn, trayno, trayc, trayr, duttype)

            if status < 0:
                RTS_debug ("S2T", user_email, status, trayno, trayc, trayr, sinkno, sktn)
                tmpi = tmpi
                continue
            else:
                tmpi = tmpi + 1

        tmps = []
        for ids in ids_g:
            tmps.append(dut_skt[ids][0])
        tmps = sorted(tmps)
        duts = tmps + duts

        return duts, {}, ids_goods, ids_bads
    else:
        # no more DAT_QC calls, safe to make sure lid is open
        # Check RTS lid is open 
        if not CheckCoversOpen():
            print('Lid status could not be resolved! Contact tech coordinator')
            # notification(subject ="Cryo lid error", message="Cryo lid status could not be resolved by user.", user_email=user_email, p_shifter=False, s_shifter=False, inform_tech=True)
            sendslack("Cryo lid status could not be resolved by user.")
            rts.rts_disconnect()
            sys.exit(1)

        if "Code#" in QCstatus:
            tmpi = 0
            while tmpi < len(badchips):
                skt = badchips[tmpi]
                for ids in ids_g:
                    if dut_skt[ids][1] == skt:
                        chipi=dut_skt[ids][0]
                        sktn =dut_skt[ids][1] + 1
                        ids_bads[ids] = dut_skt[ids]
                        removekey = ids
                        dut_skt.pop(removekey, None)  
                        ids_g = list(dut_skt.keys())
                        break
                FindSpotOnBadTray(user_email)
                bad_dut_order = BAD_TRAY_SPOT - 1
                # if "CD" in duttype:
                #     trayc=(bad_dut_order%10) +1
                #     trayr=(bad_dut_order//10) +1
                # else:
                #     trayc=(bad_dut_order%15) +1
                #     trayr=(bad_dut_order//15) +1

                trayc = GetChipCol(bad_dut_order, duttype)
                trayr = GetChipRow(bad_dut_order, duttype)    

                status = rts.MoveChipFromSocketToTray(sinkno, sktn, badtrayno, trayc, trayr, duttype)

                if status < 0:
                    RTS_debug ("S2T", user_email, status, trayno, trayc, trayr, sinkno, sktn)
                    tmpi = tmpi
                    continue
                else:
                    ids_bads[rts.msg] = (chipi, skt)
                    BAD_TRAY_SPOT +=1
                    tmpi = tmpi + 1
            return duts,dut_skt , ids_goods, ids_bads

        if "PASS" in QCstatus:
            tmpi = 0
            while tmpi < SKT_N:
                for ids in ids_g:
                    if dut_skt[ids][1] == tmpi:
                        chipi=dut_skt[ids][0]
                        sktn =dut_skt[ids][1] + 1
                        break
                # if "CD" in duttype:
                #     trayc=(chipi%10) +1
                #     trayr=(chipi//10) +1
                # else:
                #     trayc=(chipi%15) +1
                #     trayr=(chipi//15) +1

                trayc = GetChipCol(chipi, duttype)
                trayr = GetChipRow(chipi, duttype)

                if tmpi in badchips:
                    FindSpotOnBadTray(user_email)
                    bad_dut_order = BAD_TRAY_SPOT - 1
                    # if "CD" in duttype:
                    #     trayc=(bad_dut_order%10) +1
                    #     trayr=(bad_dut_order//10) +1
                    # else:
                    #     trayc=(bad_dut_order%15) +1
                    #     trayr=(bad_dut_order//15) +1

                    trayc = GetChipCol(bad_dut_order, duttype)
                    trayr = GetChipRow(bad_dut_order, duttype)  

                    status = rts.MoveChipFromSocketToTray(sinkno, sktn, badtrayno, trayc, trayr, duttype)
                else:
                    status = rts.MoveChipFromSocketToTray(sinkno, sktn, trayno, trayc, trayr, duttype)

                if status < 0:
                    RTS_debug ("S2T", user_email, status, trayno, trayc, trayr, sinkno, sktn)
                    tmpi = tmpi
                    continue
                else:
                    if tmpi in badchips:
                        skt = tmpi 
                        for ids in ids_g:
                            if dut_skt[ids][1] == skt:
                                ids_bads[ids] = dut_skt[ids]
                                removekey = ids
                                dut_skt.pop(removekey, None)  
                                ids_bads[rts.msg] = (chipi, skt)
                                ids_g = list(dut_skt.keys())
                                break
                        BAD_TRAY_SPOT +=1
                    else:
                        ids_goods[rts.msg] = (chipi,tmpi)
                    tmpi = tmpi + 1

            return duts, dut_skt, ids_goods, ids_bads

### OCR 

def Tray_SCAN_OCR(TrayID):
    global BAD_TRAY_SPOT
    ocrbin_fp = rootdir + "ocr_results.bin"
    if os.path.isfile(ocrbin_fp) :
        print('OCR found, will load in')
        with open(ocrbin_fp, 'rb') as fn:
            chip_ocr  = pickle.load(fn)
    else:
        print('No OCR file found, scanning tray...')
        print ('Use robot to scan tray?')
        inyn = user_yn()
        if inyn == 1:
            rts.MotorOn()
            rts.JumpToCamera()
            time.sleep(1)
            print ("Wait a few minutes until the scanning is done")
            rts.ScanTray(TrayNr=trayno, TrayID=TrayID, topdir=topdir) # rootdir=rootdir)
            rts.JumpToCamera()
            rts.rts_idle()
        elif inyn == -1:
            sys.exit()
        else:
            print('You didn\'t run the robot')
            imgdir = rootdir + "images/"
            if not os.listdir(rootdir):
                print(f'tray directory is empty!: {rootdir}')
                sys.exit(1)
            else:
                if not os.listdir(imgdir):
                    print(f'tray image directory is empty!: {imgdir}')
                    sys.exit(1)         

                print(f'Files found in {imgdir}')
                print('Show list?')
                inyn=user_yn()
                if inyn == 1:
                    dir_list = os.listdir(imgdir)
                    print (dir_list)
        print(f'Run OCR on files in {rootdir+"images"}')
        inyn = user_yn()
        if inyn == 1:
            print('Running OCR...')
            sn=SN_CLASS()
            chip_ocr = sn.chip_ocr(rootdir) # chip_ocr will find image subdirectory
            print('Tray scan OCR step finished')
        elif inyn == -1:
            print('Exiting')
            sys.exit(1)
        else:
            print('Did not run OCR, returning None')
            return None, None

    bad_chip_ds = {} 
    for key in list(chip_ocr.keys()):
        if (not chip_ocr[key][0]) and (len(chip_ocr[key]) == 8) :
            bad_chip_ds[key]= chip_ocr[key] 

    if len(bad_chip_ds) > 0:
        sys.path.append('./SN_recognition/')  
        # notification(subject ="Correct OCR Error", message="!WARNING! Please check the pop-up windows to correct OCR error.", user_email=user_email, p_shifter=False, s_shifter=False, inform_tech=True)
        sendslack("!WARNING! Please check the pop-up windows to correct OCR error.")
        chip_ds = ocr_correct_gui(bad_chip_ds)
        chip_ocr.update(chip_ds)
        for key in chip_ds.keys():
            print (key, chip_ocr[key])
        print('Saving updated OCR results')
        with open(ocrbin_fp, 'wb') as fn:
            pickle.dump(chip_ocr,fn)

    badchips = {} 
    for key in list(chip_ocr.keys()):
        if not chip_ocr[key][0] :
            badchips[key]= chip_ocr[key]

    print('Move bad OCR chips to bad tray?')
    inyn = user_yn()
    if inyn == -1:
        rts.rts_disconnect()
        sys.exit(1)
    if inyn != 1:
        return None, None
   
    BAD_TRAY_SPOT = 1
    for key in list(chip_ocr.keys()):
        if not chip_ocr[key][0] :
            if ("Failed" in chip_ocr[key][-2]) and ("Moved" in chip_ocr[key][-1]): #already removed
                continue
            tray_slot = key
            # trayc = (tray_slot-1)%15 + 1
            # trayr = (tray_slot-1)//15 + 1

            trayc = GetChipCol(tray_slot-1, duttype)
            trayr = GetChipRow(tray_slot-1, duttype)

            FindSpotOnBadTray(user_email)
            # bad_trayc = (BAD_TRAY_SPOT-1)%15 + 1
            # bad_trayr = (BAD_TRAY_SPOT-1)//15 + 1

            bad_trayc = GetChipCol(BAD_TRAY_SPOT-1, duttype)
            bad_trayr = GetChipRow(BAD_TRAY_SPOT-1, duttype)
            
            while True:
                status = rts.MoveChipFromTrayToTray(trayno, trayc, trayr, badtrayno, bad_trayc,bad_trayr)    
                if status > 0 :
                    #print (f'remove {key}, {chip_ocr[key]}')
                    #chip_ocr.pop(key) #remove it from bad chip
                    chip_ocr[key] = chip_ocr[key] + ["Failed_in_OCR"] + [f'Moved_to_bad_tray_slot_{BAD_TRAY_SPOT}']
                    print (chip_ocr[key])
                    with open(ocrbin_fp, 'wb') as fn:
                        pickle.dump(chip_ocr, fn)
                    BAD_TRAY_SPOT += 1
                    break
                else:
                    RTS_debug ("T2T", user_email, status , trayno=trayno, trayc=trayc, trayr=trayr, tray2no=badtrayno, tray2c=bad_trayc,tray2r=bad_trayr)
    
    return chip_ocr, ocrbin_fp 

#### MSU style image showing for chips

def show_chip_image(image, label, SN):
    print(f'plotting image for chip {label} with SN:{SN}')
    print(f'Image:{image}')
    fig, ax = plt.subplots(figsize=(12, 6))
 
    # Open image
    img = Image.open(image)       
    ax.imshow(img)
    ax.set_title(label)
    ax.text(0.5, -0.1, SN, transform=ax.transAxes, ha='center', va='top', fontsize=10)
    ax.axis("off")

    plt.tight_layout()
    plt.show()

def show_batch_chip_images(images, labels, SNs, duttype):
    print(f'showing {len(images)} images')
    print(f'showing {len(labels)} labels')
    print(f'showing {len(SNs)} sns')

    if "CD" in duttype:
        nTrayRows = 4
        nTrayCols = 10
    else:
        nTrayRows = 6
        nTrayCols = 15

    nTrayChips = nTrayCols * nTrayRows 

    figrow = 2
    figcol = 4
    if len(images) <= 2:
        figrow=1
        figcol=2
    elif len(images) <= 6:
        figcol = 3
    elif len(images) == nTrayChips:
        figrow = nTrayRows
        figcol = nTrayCols

    fig, axes = plt.subplots(figrow, figcol, figsize=(12, 6))
    axes = axes.flatten()

    for i, ax in enumerate(axes):
        # Open image
        if i >= len(images):
            break
        img = Image.open(images[i])       
        ax.imshow(img)
        ax.set_title(labels[i])
        ax.text(0.5, -0.1, SNs[i], transform=ax.transAxes, ha='center', va='top', fontsize=10)
        ax.axis("off")

    plt.tight_layout()
    plt.show(block=False)
    plt.pause(0.5)

    updated = False
    print('Are the serial numbers correct?')
    while True:
        inyn=input('(Y/N)?')
        if inyn in ('y', 'Y', 'yes', 'Yes'):
            break
        if inyn in ('n', 'N', 'no', 'No'):
            print('Enter serial numbers (y to skip, -1 to quit):')
            for chip in range(0, len(labels)):
                inSN = input(f'{labels[chip]} : ')
                if inSN == "-1":
                    sys.exit(1)
                if inSN in ('y', 'Y'):
                    continue
                SNs[chip] = str(inSN)
            print('Check updated plot!')
            updated = True
            break

    plt.close()
    plt.pause(0.2)
    time.sleep(0.1)

    if updated:
        SNs = show_batch_chip_images(images, labels, SNs, duttype)

    return SNs

def UserAlignCheck(sinkno):

    # filename = rootdir + "/measurements/AlignCheck_" + label + "_DAT" + str(sinkno) + ".csv"

    filename = topdir + "/SocketAlign_xyu.csv"

    alignments = pd.read_csv(filename)

    dats=alignments['DAT'].tolist()
    s=alignments['Socket'].tolist()
    rawimages=alignments['Image'].tolist()

    xalign=alignments['DelX'].tolist()
    yalign=alignments['DelY'].tolist()
    ualign=alignments['DelU'].tolist()

    figrow = 2
    figcol = 4
    if len(rawimages) <= 2:
        figrow=1
        figcol=2

    sockets=[]
    images = []
    print (rawimages)

    for sck in range(len(rawimages)):
        if int(dats[sck])!= sinkno:
            continue
        if not rawimages[sck]:
            continue
        if "C" not in rawimages[sck]:
            continue
        sockets.append(s[sck])
        images.append(CropAlignmentImage(rawimages[sck]))
        alignments['ProcImage']=images[-1]

    # Store the processed image names 
    alignments.to_csv(filename, index=False)

    fig, axes = plt.subplots(figrow, figcol, figsize=(12, 6))
    axes = axes.flatten()

    for i, ax in enumerate(axes):
        # Open image
        if i >= len(images):
            break
        img = Image.open(images[i])       
        ax.imshow(img,cmap='gray')
        ax.set_title(sockets[i])
        ax.axis("off")

    plt.tight_layout()
    plt.show(block=False)
    plt.pause(0.5)

    needs_realigned={}
    print('Are the chips aligned?')
    while True:
        inyn=input('(Y/N)?')
        if inyn in ('y', 'Y', 'yes', 'Yes'):
            break
        if inyn in ('n', 'N', 'no', 'No'):
            print('Which chips are aligned? Enter values separated by a comma, and any correction as a vector of three doubles `socket(DelX,DelY,DelU)`:')
            
            while True:
                user_in = input('Enter numbers: ')

                try:
                    needs_realigned = parse_reseat_input(user_in)
                    print(needs_realigned)
                    break
                except ValueError as e:
                    print(f"Invalid input: {e}")

                

                # try:
                #     needs_realigned={int(i.strip()) for i in user_in.split(',')}
                #     break
                # except:
                #     print('Please enter comma separated integer values')
                        
                # isaligned = input(f'{sockets[chip]} : ')
                # while True:
                #     if isaligned == "-1":
                #         sys.exit(1)
                #     if isaligned in ('y', 'Y', 'yes', 'Yes'):
                #         break
                #     if isaligned in ('n', 'N', 'no', 'No'):
                #         needs_realigned.append(sockets[chip]) # Check if iterating from 0 or 1
                #         break
            break
    
    plt.close()
    plt.pause(0.2)
    time.sleep(0.1)

    return needs_realigned, alignments

import re
def parse_reseat_input(user_input):
    result = {}

    pattern = (
        r'\s*(-?\d+)'
        r'(?:\(\s*'
        r'(-?\d+(?:\.\d*)?(?:[eE][+-]?\d+)?)\s*,\s*'
        r'(-?\d+(?:\.\d*)?(?:[eE][+-]?\d+)?)\s*,\s*'
        r'(-?\d+(?:\.\d*)?(?:[eE][+-]?\d+)?)'
        r'\s*\))?\s*(?:,|$)'
    )

    matches = list(re.finditer(pattern, user_input))

    # Check that the entire input was matched
    if not matches or ''.join(m.group(0) for m in matches).replace(' ', '') != user_input.replace(' ', ''):
        raise ValueError("Invalid input format, must provide socket number and optional vector of three corrections e.g. 1,3(-0.1,0.0,0.2),5")

    for match in matches:
        key = int(match.group(1))

        if match.group(2) is None:
            value = None
        else:
            value = tuple(float(match.group(i)) for i in range(2, 5))

        if key in result:
            raise ValueError(f"Duplicate socket specified: {key}")

        result[key] = value

    return result

def UpdateAlignmentsTestResults(alignments, cryo_cycle_ran, badchips):
    for entry in range(len(alignments)):
        if int(alignments['DAT'][entry]) == sinkno:
            if int(alignments['Socket'][entry]-1) in badchips:
                alignments['Warm']= 1 if cryo_cycle_ran else -1
                alignments['Cold']=-1 if cryo_cycle_ran else 0
            else:
                alignments['Warm']= 1
                alignments['Cold']= 1 if cryo_cycle_ran else 0
    return alignments
    

# def AppendAlignmentHistory(alignments):
#     filename = topdir + "/SocketAlign_xyu_history.csv"
#     if not os.path.exists(filename):
#         print(f'WARNING: ALIGNMENT FILE DOES NOT EXIST AT {filename}')
#         print('CREATING ONE')

#     alignments.to_csv(filename, mode="a", header=not os.path.exists(filename),index=False)

def UpdateAlignmentHistory(alignments):
    filename = topdir + "/SocketAlign_xyu_history.csv"

def CropAlignmentImage(image_name):

    directory = os.path.dirname(image_name)
    filename, extension = os.path.splitext(os.path.basename(image_name))

    output_name = os.path.join(
        directory, f"{filename}_cropped{extension}"
    )

    w = 326 *1.5 #  680
    h = 326 *1.5 #  680 
    x = 1279 # 1120 # 890 12
    y = 959 # 792 #  600 
    crop_box = (x - w/2, y-h/2, x + w/2, y + h/2)
    with Image.open(image_name) as image:
        cropped = image.crop(crop_box)
        cropped.save(output_name)

    return output_name  

### Utils
def FindSpotOnBadTray(user_email):
    global BAD_TRAY_SPOT, TRAY_N, badtrayno
    while True:
        if BAD_TRAY_SPOT >= TRAY_N:
            # notification(message="!WARNING! Tray#1 (bac chips) is full, please replace with a new empty tray. ",user_email=user_email, p_shifter=False, s_shifter=False, inform_tech=True)
            sendslack("!WARNING! Tray#1 (bac chips) is full, please replace with a new empty tray. ")
            print ("\033[91m !WARNING! Tray#1 (bac chips) is full: \033[0m")
            yorn = input ("\033[91m Replace with a new tray? (y/Y): \033[0m")
            if "Y" in yorn or "y" in yorn:
                BAD_TRAY_SPOT = 1
        # bad_trayc = (BAD_TRAY_SPOT-1)%15 + 1
        # bad_trayr = (BAD_TRAY_SPOT-1)//15 + 1

        bad_trayc = GetChipCol(BAD_TRAY_SPOT-1, duttype)
        bad_trayr = GetChipRow(BAD_TRAY_SPOT-1, duttype)

        # flg = rts.isChipInTray(badtrayno,bad_trayc, bad_trayr)
        flg = rts.CheckTrayOccupancy(badtrayno, bad_trayc, bad_trayr)
        if not flg:#no chip in it
            break
        #return BAD_TRAY_SPOT
        else:
            BAD_TRAY_SPOT += 1

### DAT testing

def DAT_QC(user_email, dut_skt, duttype="FE", LN2_flg = True, testid=0, sinkno=2, test_history={}) :
    cold_cycle_ran=False
    print(f'Running DAT_QC with testid = {testid}')

    while True:
        QCresult, test_history = rts_ssh(dut_skt, root=rootdir, duttype=duttype, env="RT", testid=testid, test_history=test_history)
        PowerDownDAT(user_email)
        time.sleep(1)
        if QCresult != None:
            QCstatus = QCresult[0]
            if "CD" in duttype:
                badchips =[]
                if (0 in QCresult[1]) or (1 in QCresult[1]) or (2 in QCresult[1]) or (3 in QCresult[1]):
                    badchips.append(0)
                if (4 in QCresult[1]) or (5 in QCresult[1]) or (6 in QCresult[1]) or (7 in QCresult[1]):
                    badchips.append(1)
            else:
                badchips = QCresult[1]
            break
        else:        
            print('No QC status returned, will power cycle DAT board')
            time.sleep(10)
            DAT_power_on()
            time.sleep(10)
            PowerDownDAT(user_email)
            time.sleep(10)
            print ("139-> terminate, 2->debugging")
            # notification(message="Please contact tech coordinator (QC error)", user_email=user_email, inform_tech=True)
            sendslack("Please contact tech coordinator (QC error)")
            userinput = input ("Please contact tech coordinator")
            if len(userinput) > 0:
                if "139" in userinput :
                    QCstatus = "Terminate"
                    badchips = []
                    break
                elif "2" in userinput[0] :
                    print ("debugging, ")
                    input ("click any key to start ASIC QC again...")
    if (len(badchips) > 0) or ("Code#P001" in QCstatus) or ("Terminate" in QCstatus):
        return QCstatus, badchips, cold_cycle_ran, test_history #badchips range from 0 to7
    print_timing('Warm test finished')
    # TODO add some specific termination for user "Terminate" option in debug
    if LN2_flg:
        coldbadchips=[]
        p_shifter=True
        s_shifter=False
        cover_sts = rts.CoverStatus(sinkno)
        print (cover_sts)
        # cover_closed = CheckCoverClosed(sinkno)
        # notification(subject = "Please close RTS chamber cover", message="Please close the chamber cover. ", user_email=user_email, inform_tech=False)#, p_shifter=p_shifter, s_shifter=s_shifter)
        sendslack("Please close the chamber cover. ")
        #yorn = input ("\033[96m Do you want to perform cold test? (Y/N) :\033[0m")
        t0 = int(time.time())
        while True:
            # cover_sts = rts.CoverStatus(sinkno)
            cover_closed = CheckCoverClosed(sinkno)
            #if "-198" in cover_sts:
            if cover_closed:
                print ("Cover is close! Start the cold test in 10 seconds")
                # notification(subject = "A genius just closed cover", message="Next call is ~ 1 hour later. ", user_email=user_email, inform_tech=False)#, p_shifter=p_shifter, s_shifter=s_shifter)
                sendslack("Cover is closed, Next call is ~ 1 hour later. ")
                s_shifter=False
                time.sleep(10)
                break
            else:
                time.sleep(10)
                t1 = int(time.time()) - t0
                if (t1 > 600) :
                    if not is_weekday_work_hours()  :
                        pass
                    else:
                        t0 =time.time() 
                        s_shifter=True
                        # notification(subject = "Reminder: Please close RTS chamber cover", message="Please close the chamber cover. ", user_email=user_email, inform_tech=False)#, p_shifter=p_shifter, s_shifter=s_shifter)
                        sendslack("@channel Reminder: Please close RTS chamber cover")
        cover_closed = CheckCoverClosed(sinkno)
        if not cover_closed:
            print('Cover is not closed but out of weekday hours.')
            print('Should not be here, have you closed the lid?')
            # notification(subject = "Lid open but trying cryo out of hours!", message="[CRYO] ERROR: For some reason the RTS is trying to run a cryo test out of hours ", user_email=user_email, inform_tech=True)#, p_shifter=p_shifter, s_shifter=s_shifter)
            sendslack("[CRYO] ERROR:  Lid open but trying cryo out of hours!")
            inyn = user_yn()
            if inyn == 1:
                pass
            if inyn == 0 or inyn == -1:
                rts.rts_disconnect()
                sys.exit(1)
        print_timing('Cryo lid closed')

        PowerDownDAT(user_email)

        # TODO Add some handling for not being able to fill dewar?
        # Can cryo return some status code to say the transfer dewar is full
        try:
            cryo.cryo_fill()
        except KeyboardInterrupt:
            print ("####################")
        cold_cycle_ran=True
        cryo.cryo_lowlevel(waitminutes=10)
        cryo.cryo_highlevel(waitminutes=5)
        print_timing('Cryo chamber filled and DAT submerged')

        attempt = 1
        while True:
            print(f'Beggining QC test attempt {attempt}')
            LNQCresult, test_history = rts_ssh(dut_skt, root=rootdir, duttype=duttype, env="LN" )
            if LNQCresult != None:
                print('Cold test returned result')
                LNQCstatus = LNQCresult[0]
                if "CD" in duttype:
                    coldbadchips =[]
                    if (0 in LNQCresult[1]) or (1 in LNQCresult[1]) or (2 in LNQCresult[1]) or (3 in LNQCresult[1]):
                        coldbadchips.append(0)
                    if (4 in LNQCresult[1]) or (5 in LNQCresult[1]) or (6 in LNQCresult[1]) or (7 in LNQCresult[1]):
                        coldbadchips.append(1)
                else:
                    coldbadchips = LNQCresult[1]
                break

            else:
                print('Error, no LNQCResult')
                print('If failed on command 1 this is likely a misalignment issue!')
                print('Will issue power down command just in case...')
                PowerDownDAT(user_email)
                time.sleep(30)
                print('Will Power cycle (40s)')
                DAT_power_on()
                time.sleep(10)
                PowerDownDAT(user_email)
                print('Wait another 30s to make sure board fully powered down')
                time.sleep(30)
                
                if attempt != 1:
                    sendslack("Bad test at cold, see RTS (QC error)")
                    print ("Repeat test? (Y/N/D) 'No' or Time out will proceed to drain and move onto next chips")
                    print('D - Debug')
                    inyn = user_yn([('D',-3)],timeout=60*5,default="N")
                    if inyn == -3:
                        print('DEBUG MODE')
                        while True:
                            in_c = input('Enter "CONTINUE" to continue')
                            if in_c == "CONTINUE":
                                break

                        print ("Exiting debug mode: Repeat test? (Y/N) 'No' or Time out will proceed to drain and move onto next chips")
                        inyn = user_yn(timeout=60*2,default="N")
                        
                    if inyn !=1:
                        QCstatus="Code#E001" # TODO check appropriate error code
                        badchips=[0,1,2,3,4,5,6,7]
                        break
                attempt += 1
                print('Will attempt test again!')
                time.sleep(5)
                # # First try just tests 0 and 1?
                # LNQCresult, test_history = rts_ssh(dut_skt, root=rootdir, duttype=duttype, env="LN",testid=0)

                # LNQCresult, test_history = rts_ssh(dut_skt, root=rootdir, duttype=duttype, env="LN",testid=1)

        print_timing('Cold test finished')
        if len(coldbadchips):
            print(f'Cold test badchips =')
            print(coldbadchips)
            print('[WARNING] Currently I don\'t think the automation script handles bad chips at cold?')

        PowerDownDAT(user_email)

        cryo.cryo_warmup(waitminutes=30)
        print_timing('Chamber warm up finished')
        s_shifter=False
        cover_sts = rts.CoverStatus(sinkno)
        print (cover_sts)
        # notification(subject = "Please open RTS chamber cover", message="Cold test is done, please open the sink cover", user_email=user_email, inform_tech=False)#, p_shifter=p_shifter, s_shifter=s_shifter)
        sendslack("Cold test is done, please open the sink cover")
        t0 = int(time.time())
        while True:
            # cover_sts = rts.CoverStatus(sinkno)
            # if "197" in cover_sts:
            covers_open = CheckCoversOpen()
            if covers_open:
                print ("Cover is open! Activate robot in 10 seconds")
                # notification(subject = "A genius just opened cover", message="Next call is ~40 minutes later. ", user_email=user_email, inform_tech=False)#, p_shifter=p_shifter, s_shifter=s_shifter)
                sendslack("Cover is open, Next call is ~40 minutes later. ")
                s_shifter=False
                time.sleep(10)
                break
            else:
                time.sleep(10)
                t1 = int(time.time()) - t0
                if (t1 > 600) :
                    if not is_weekday_work_hours()  :
                        pass
                    else:
                        t0 =time.time() 
                        s_shifter=True
                        # notification(subject = "Reminder: Please open RTS chamber cover", message="Please open the chamber cover. ", user_email=user_email, inform_tech=False)#, p_shifter=p_shifter, s_shifter=s_shifter)
                        sendslack("@channel Reminder: Please open RTS chamber cover")
                cover_closed = CheckCoverClosed(sinkno)
        if not covers_open:
            print('Cover is not open but out of weekday hours.')
            print('Should not be here, have you opened the lid?')
            #notification(subject = "Lid closed but trying robot out of hours!", message="[CRYO] ERROR: For some reason the RTS is trying to finish automated cryo test out of hours ", user_email=user_email, inform_tech=True)#, p_shifter=p_shifter, s_shifter=s_shifter)
            sendslack("Lid closed but attempting to move robot while out of hours")
            inyn = user_yn()
            if inyn == 1:
                pass
            if inyn == 0 or inyn == -1:
                rts.rts_disconnect()
                sys.exit(1)        
    print_timing('Chamber reopened')
    return QCstatus, badchips, cold_cycle_ran, test_history #badchips range from 0 to7

def print_timing(label,newCycle=False):
    global gTimeLastStep, gTimeLastCycle
    timeNow = int(time.time())
    total = timeNow - gTime0
    step = timeNow - gTimeLastStep
    gTimeLastStep = timeNow
    print(f'STEP: ({label}) took {str(datetime.timedelta(seconds=step))}, total time {str(datetime.timedelta(seconds=total))}')
    if newCycle:
        cycle = timeNow - gTimeLastCycle
        gTimeLastCycle = timeNow
        print(f'CYCLE: took {str(datetime.timedelta(seconds=cycle))}')


def initialize():

    gTime0 = int(time.time())
    gTimeLastStep = gTime0
    gTimeLastCycle = gTime0

    print("*********************************")
    print(" STARTING RTS AUTOMATION PROGRAM")
    print("*********************************")

    rts = RTS_CFG()
    cryo = cryobox()

    use_config=False
    if os.path.exists(config_file):
        print(f'Config file found at {config_file}')
        print('Load config file?')
        while True:
            inyn = input('Y/N? ')
            if inyn in ['y','Y','yes','Yes','YES']:
                use_config = True
                break
            if inyn in ['n','N','no','No','NO']:
                break
            if inyn == "-1":
                print('User force quit!')
                sys.exit(1)

    if not use_config:
        print('Would you like to specify a config file to load?')
        while True:
            inyn = input('Y/N? ')
            if inyn in ['y','Y','yes','Yes','YES']:
                use_config = True
                config_file=input("Specify config file: ")
            if inyn in ['n','N','no','No','NO']:
                break
            if inyn == "-1":
                print('User force quit!')
                sys.exit(1)

    if use_config:
        read_config()
    else:
        print('No config file specified, please input values using gui')
        print('Default general values will be set')
        input_config()
    print('Config values:')
    print_config()
    print('Gui info:')
    print(gui_info)
    logs={}
    logs.update(gui_info)

    if 'LArASIC' in gui_info['DUTtype'] :
        duttype = "FE"
        topdir = rootdir_cs(duttype)
        TRAY_N = 90
    elif 'ColdADC' in gui_info['DUTtype'] :
        duttype = "ADC"
        topdir  = rootdir_cs(duttype)
        TRAY_N = 90
    elif 'COLDATA' in gui_info['DUTtype'] :
        duttype = "CD"
        topdir = rootdir_cs(duttype)
        TRAY_N = 40
    else:
        print ("Wrong DUT type, exit anyway")
        sys.exit()

    if topdir != config['TopDir']:
        print('Make sure config file TopDir field matches path in rootdir_cs()')
        print(f'From config = {config['TopDir']}')
        print(f'From root_cs({duttype}) = {topdir}')
        print('Set to match now?')
        inyn = user_yn()
        if inyn == 1:
            config['TopDir'] = topdir
            rootdir = topdir+"Tested/"+trayid+"/"
            write_config()
        else:
            print('Please make them match!')
            sys.exit(1)

    logs["TrayID"] = trayid
    logs["TrayNo"] = trayno
    logs["BadTrayNo"] = badtrayno
    logs["SinkNo"] = sinkno
    logs["rootdir"] = rootdir

    print(f'TrayID = {trayid}')
    print(f'TrayNo = {trayno}')
    print(f'BadTrayNo = {badtrayno}')
    print(f'SinkNo = {sinkno}')
    print(f'topdir = {topdir}')
    print(f'rootdir = {rootdir}')

    if rootdir != (topdir+"Tested/"+trayid+"/"):
        print('Rootdir not set correctily')
        sys.exit(1)

    if not os.path.exists(rootdir):
        try:
            os.makedirs(rootdir)
        except OSError:
            print ("Error to create folder %s"%rootdir)
            sys.exit(1)
    else:
        print ("File exist, If new tray please make sure the tray ID is unique")

    # sys.exit() # HERE TESTING EXIT
    print (f'Do tray scan: {do_tray_scan}')
    print (f'Run tests: {run_tests}')
    print (f'Do tray scan or run tests: {(do_tray_scan or run_tests)}')
    print (f'Dry run: {dry_run}')
    print (f'Not dry run: {(not (dry_run))}')
    print (f'(Do tray scan or run tests) and (not dry run) : {((do_tray_scan or run_tests) and (not dry_run))}')


    print('Setting asic_info values')
    csvaifp="C:/Users/neutrino/RTS_Integration/FD_CE/QC/ChipTesting/BNL_QC_LArASIC/asic_info.csv"
    tmps=[]
    with open(csvaifp,'r') as aifp:
        for cl in aifp:
            tmp = cl.split(",")
            if "tester" in tmp[0]:
                tmp[1]=config['Name']
            elif "Email" in tmp[0]:
                tmp[1]=config['Email']
            elif "Tray_ID" in tmp[0]:
                tmp[1]=config['TrayID']
            cln=','.join(tmp)
            tmps.append(cln)
    with open(csvaifp,'w') as aifp:
        for cl in tmps:
            aifp.write(cl)


    print("*********************************")
    # print('Forcing LN2_flg to be false')
    # LN2_flg = False
    print(f'LN2_flg = {LN2_flg}')
    print("*********************************")      

    print_timing('Preamble', False)

def main(rts, cryo, slack):

    # notification(subject="RTS Init", message="RTS is beginning automation",user_email=user_email, inform_tech=False, p_shifter=False, s_shifter=False)
    sendslack("RTS is beginning automation")
    if (do_tray_scan or run_tests) and not dry_run:
        print('Connecting to robot...')
        rts.msg = "10000000000"
        rts.rts_init(port=robot_port, host_ip=robot_ip)
        # rts.RootDirSet(rootdir=rootdir)
        rts.SetTrayID(TrayID=trayid)
        print ('will check trayID correctly set')
        check_trayid = rts.CheckTrayID()
        print(f'Robot trayid = {check_trayid}')
        if check_trayid != trayid:
            print('Invalid tray id set in robot')
    else:
        print('Skipping robot init')
    print((do_tray_scan and (not dry_run)))
    if do_tray_scan and not dry_run:
        print('Getting OCR')
        chip_ocr, ocrbin_fp = Tray_SCAN_OCR(trayid)
    else:
        print('Skipping ocr')
        # Still need to make sure we are using the right tray id directory
        correct_trayid = False
        while not correct_trayid:
            robot_trayid = rts.CheckTrayID()
            if robot_trayid != trayid:
                rts.SetTrayID(trayid)
            else:
                correct_trayid = True

    if not chip_ocr:
        print('No chip dictionary from tray scan')
        sys.exit(1)

    print ("Getting list of tray positions with untested chips and good OCR from ocr file")
    duts = []
    for key in list(chip_ocr.keys()):
        if  (chip_ocr[key][0]) and (len(chip_ocr[key])==8) and ("PASS" not in chip_ocr[key][-1]):
                duts.append(key-1)

    print_timing('Scan/load tray ocr', False)

    print(f'There are {len(duts)} chips in the tray to test')

    print('The entries are ')
    print(duts)

    status = 0
    # TODO joe figure out what exactly these are
    ids_dict = {} #good chips ID with time that chips are moved from tray to socket
    ids_dict_good = {} #good chips ID with time that chips are moved from socket to tray # not sure what diff here is?
    ids_dict_bad = {} #[BAD?] chips ID with time that chips are moved from socket to tray
    # My guess is ids_dict is all untested chips, not good chips
    # ids_dict_good is self explanatory, good chips (which have already been tested)
    # ids_dict_bad is bad chips

    print('Getting IDS of chips (which have been tested? or moved?) from log file ')
    for sroot, sdir, sfs in os.walk(rootdir):
        break
    for logf in sfs:
        if '_log.bin' in logf:
            with open(rootdir + "/" + logf, 'rb') as fn:
                slogs = pickle.load(fn)
                if "RTS_MSG_S2R_P" in slogs:
                   ids_dict.update( slogs["RTS_MSG_S2R_P"]  ) # TODO JOE See where this comes from originally 

    print(f'There are {len(ids_dict)} entries in the ids_dict')

    logs["duts"] = duts 
    logs["ocr"] = chip_ocr

    # if not run_tests:
    #     print('Tray has been scanned')

    #     print ("**********save ID info*************")
    #     #ids_k = list(dut_skt.keys())
    #     #if len(ids_k) > 0:
    #     if True:
    #         fp = rootdir + datetime.datetime.now().strftime("%m_%d_%Y_%H_%M_%S") + "_log.bin"
    #         if not os.path.isfile(fp) :
    #             # JW: Can't save this here, as ids_goods is filled after move to tray! post testing
    #             logs["RTS_MSG_S2R_P"] = ids_goods
    #             with open(fp, 'wb') as fn:
    #                 pickle.dump(logs, fn)
    #     sys.exit(0)

    print('Will now prepare to run tests')

    if "CD" in duttype:
        skts=[0,1]
    else:
        skts=[0,1,2,3,4,5,6,7]
    print('Will use sockets:')
    print(skts)

    dut_skt = {}

    too_many_bad_qc=False
    bad_qc_threshold=5
    if "CD" in duttype:
        consecutive_qc_failures=[0]*2
    else:
        consecutive_qc_failures=[0]*8

    if not run_tests:
        rts.rts_disconnect()
        sys.exit(0)

    use_chips_in_dat=False

    if os.path.exists("C:/Users/neutrino/LArASIC_Testing/chips_in_dat.csv"):
        print(f'Preloaded chip file found at {config_file}')
        print('Use preloaded chip file?')
        while True:
            inyn = input('Y/N? ')
            if inyn in ['y','Y','yes','Yes','YES']:
                use_chips_in_dat = True
                break
            if inyn in ['n','N','no','No','NO']:
                break
            if inyn == "-1":
                print('User force quit!')
                sys.exit(1)
    else:
        print ("NO PRELOADED CHIP FILE FOUND")

    Undone_Flag = False # I think this sets the chip test status back to untested if there is a failure?
    NIGHT_ON = False
    print ('Ignore "first" cycle time, it just covers the preamble')
    while (len(duts) > 0) or Undone_Flag :
        print_timing('Cycle start', True)
        print('Beginning cycle')

        duts, dut_skt_n, ids_bads, alignments = MovetoSocket(sinkno, duts,ids_dict, skts=skts,duttype=duttype,chips_preloaded=use_chips_in_dat,do_initcheck=init_check_on_move) 
        use_chips_in_dat=False # Set back to false after getting past first chips
        print_timing('Move chips to socket')
        for key in list(ids_bads.keys()):
            ocr_key = ids_bads[key][0] + 1
            chip_ocr[ocr_key] = [False] + chip_ocr[ocr_key][1:] + [f'Failed_in_QC'] + [f'Moved_to_bad_tray_slot']
        with open(ocrbin_fp, 'wb') as fn:
            pickle.dump(chip_ocr, fn)

        print ("Remain chips on tray: ", duts)
        print ("dut_skt = ")
        print(dut_skt)

        manual_sn_check_only=False

        if ocr_on_move:
            print('Are you there? Would you like to manually check OCR instead of rerunning?')
            inyn = user_yn(timeout=120)
            if inyn == 1:
                manual_sn_check_only=True
                print('Will show you the pictures to check now')
            if inyn == -1:
                print('No user input, will rerun OCR for consistency check')
        else:
            manual_sn_check_only=True

        sn_images=[]
        sn_labels=[]
        sns=[]
        sn_chipi=[]
        for key in list(dut_skt_n.keys()):
            dut_chip_dir = "/".join([rootdir, 'images', 'Move_SN'])
#           dut_chip_fn =  f'{key}_SN.bmp'
            # print('dut_skt_n contents')
            # print(dut_skt_n)

            chipi = dut_skt_n[key][0] # JW is this right?
            # if "CD" in duttype:
            #     trayc=(chipi%10) +1
            #     trayr=(chipi//10) +1
            # else:
            #     trayc=(chipi%15) +1
            #     trayr=(chipi//15) +1

            trayc = GetChipCol(chipi, duttype)
            trayr = GetChipRow(chipi, duttype)

            dut_chip_fn =  f'{key}_tr{trayno}_col{trayc}_row{trayr}_SN.bmp'
            sn_ocr_imgdir = "/".join([rootdir, 'images', 'SN_OCR'])
            if not os.path.exists(sn_ocr_imgdir):  # Check if the folder already exists
                os.mkdir(sn_ocr_imgdir)

            print (f'Searching for SN file {dut_chip_dir + "/" + dut_chip_fn}')
            if os.path.isfile(dut_chip_dir + "/" + dut_chip_fn):
                print('Found')
                tray_slot = dut_skt_n[key][0]+1 #start from 1
                ocr_sn = chip_ocr[tray_slot][1]
                ocr_chip_fn =  f'SN_{ocr_sn}_Tray_{tray_slot}_{key}.bmp'.replace("-","_")
                ocr_image_dir = sn_ocr_imgdir + "/" + ocr_chip_fn

                # JW 2026/06/25: Removed second OCR pass, for now will ask user to confirm
                # existing OCR from tray scan matches photo from move command
                # TODO see what is going on with directories here...
                # Maybe change robot code to put things in a file called XXX_SN, and then
                # post processing can go in XXX_SN_OCR? for Move and Scan?

                # Preprocess just does the cropping and stores the relevant image.

                if ocr_on_move and (not manual_sn_check_only):
                    ocr_info = ocr_chip(image_fp = dut_chip_dir, image_fn = dut_chip_fn, ocr_image_dir = ocr_image_dir, degree=0, valid_flg=False)
                    if ocr_sn not in ocr_info:
                    #if False: #bypass the online check now
                        print ("Chip to be tested have different SN from the tray scanning!")
                        print (f"OCR while scaning tray: {ocr_sn}, OCR while moving to socket: {ocr_info}")
                        p_shifter=True
                        s_shifter=False
                        #if not NIGHT_ON: #pass if it is warm test at night
                        switch_hr = int(datetime.datetime.now().strftime("%H"))
                        # if (switch_hr >= 15) and (not LN2_flg) and ((len(duts) > 0) or Undone_Flag ): 
                        #     notification(subject = "Chip SN mismatch, ignore for the automatic testing", message=f"OCR result {ocr_info} is different from Chip SN {ocr_sn}", user_email=user_email, inform_tech=False, p_shifter=p_shifter, s_shifter=s_shifter)
                        # else:
                        # notification(subject = "Chip SN mismatch, please check the pop-up window", message=f"OCR result {ocr_info} is different from Chip SN {ocr_sn}", user_email=user_email, inform_tech=False)#, p_shifter=p_shifter, s_shifter=s_shifter)
                        sendslack(f"OCR result {ocr_info} is different from Chip SN {ocr_sn}")
                        from sn_match_gui import run_sn_match_gui
                        yorn = run_sn_match_gui(image_path=ocr_image_dir, text=f"Is chip SN {ocr_sn} ?")
                        if yorn:
                            pass
                        else:
                            RTS_debug ("OCR",user_email)
                        ##### End of else statement if ignoring during automation i.e. running overnight
                else:
                    ocr_chip_preprocess(image_fp = dut_chip_dir, image_fn = dut_chip_fn, ocr_image_dir = ocr_image_dir, degree=0)

                sn_images.append(ocr_image_dir)
                sn_labels.append(dut_skt_n[key][1])
                sns.append(ocr_sn)
                sn_chipi.append(dut_skt_n[key][0]) # tray_slot - 1) # ocr_chip index from 0? i.e. tray_slot = dut_skt_n[key][0]+1

            else:
                print(f'File does not exist at {dut_chip_dir + "/" + dut_chip_fn}')

        if manual_sn_check_only:
            if not ocr_on_move:
                # Assume if ocr_on_move has been overrided the user is sat at the computer
                # so only send notification if ocr_on_move is turned off
                # notification(subject="OCR check", message="Please confirm the tray scan OCR matches the images from the move command",user_email=user_email, inform_tech=False, p_shifter=False, s_shifter=False) #TODO joe check p_shifter/s_shifter here 
                sendslack("Please confirm the tray scan OCR matches the images from the move command")
            print('Please check the tray scan SNs match the images from the move command')
            # Check the OCR
            new_sns = show_batch_chip_images(sn_images, sn_labels, sns, duttype)
            si = 0
            for s in range(0, len(new_sns)):
                # print (f'For socket {s} chip {sn_chipi[s]} old sn: {chip_ocr[sn_chipi[s]+1][1]} -> new sn: {new_sns[s]}')
                if new_sns[s] != sns[s]:
                    print(f'Updating tray chip {sn_chipi[s]} sn from {chip_ocr[sn_chipi[s]+1][1]} to {new_sns[s]}')
                    chip_ocr[sn_chipi[s]+1] [1]= new_sns[s]
                    if si == 0:
                        print('If the chip does not match the OCR, there could be an issue in the automation logic')
                        print('Exit RTS?')
                        inyn = user_yn()
                        if inyn == 1 or inyn == -1:
                            rts.rts_disconnect()
                            sys.exit(1)
                    si += 1
        
        with open(ocrbin_fp, 'wb') as fn:
            pickle.dump(chip_ocr, fn)

        print_timing('OCR checks') 

        dut_skt.update(dut_skt_n)
        print ("Chips to be tested: ", dut_skt)
        # notification(message="Chips to be tested: " + ','.join(map(str, dut_skt.values())), user_email=user_email)
        cryo_cycle_ran=False
        test_history={}
        if True:
            QCstatus, badchips, cryo_cycle_ran, test_history = DAT_QC(user_email, dut_skt,duttype, LN2_flg, sinkno=sinkno) 
            PowerDownDAT(user_email)
        else:
            pass
            QCstatus = "PASS"
            badchips = []
        # print (QCstatus, "Badchips:", badchips)

        print_timing('Main test sequence') 

        # TODO joe check error codes here, E002?
        attempt = 1
        nattempts=2
        manual_attempts=0
        nmanual_attempts=1
        realign=0
        # If cryo cycle has been ran, skip any reseat and move to next chips
        while (not cryo_cycle_ran) and badchips and (attempt <= nattempts) and (manual_attempts < nmanual_attempts):

            print('Reseat needed')
            inyn=-2
            rts.MotorOn()

            if attempt < nattempts:
                print('Would you like to manually reseat? (Will auto reseat after 15s)')
                inyn = user_yn(timeout=15)
            elif attempt == nattempts:
                print('Would you like to manually reseat? (Will skip after 3 minutes with no response)')
                inyn = user_yn(timeout=60*3)

            # TODO JW: if cold testing, maybe move on to next set of chips if they passed warm
            # but not cold. Unfortunately warm and cold tests are combined here ...
            # Also want ot think about if all warm tests need ot be ran again, or just test 0/1 warm then cold
            if inyn == 1:
                rts.JumpToCamera()
                #notification(message="Please manually reseat all chips in DAT board (QC error)", user_email=user_email, inform_tech=True)#, p_shifter=p_shifter, s_shifter=s_shifter)
                sendslack("Please manually reseat chips in DAT board (QC error)")
                print("Please manually reseat chips!")
                print("Have the chips been reseated?")
                print("Make sure to press the reset button on the door and press 'continue' in the RC+ run window")
                inyn = user_yn()
                if inyn == 1:
                    manual_attempts += 1
                    print('Will recheck QC test')
                    QCstatus, badchips, cold_cycle_ran, test_history = DAT_QC(user_email, dut_skt,duttype, LN2_flg, sinkno=sinkno) 
                    PowerDownDAT(user_email)
                elif inyn == -1:
                    print('USER ABORTED RTS PROGRAM')
                    rts.rts_disconnect()
                    sys.exit(1)
                else:
                    print('Will remove chips and place them in bad tray')
                    break
            else:
                # if attempt > 1: # TODO needs testing and alignments need setting
                #     realign = 1
                print (QCstatus, "Badchips:", badchips)
                print(f'Will attempt again. Attempt no. {attempt}')
                if badchips == [0,1,2,3] or badchips == [4,5,6,7] or badchips == [0,1,2,3,4,5,6,7]:
                    print('Will reseat all chips!')
                    for i in [0,1,2,3,4,5,6,7]:
                        # need to pass socket as 1, 2, 3.. 8 not 0, .. 7
                        status = rts.ReseatChipInSocket(DAT_nr=sinkno, socket_nr=i+1, duttype=duttype)
                        #status = -27
                        if status < 0:
                            RTS_debug ("RESEAT", user_email, status, sinkno=sinkno, sktn=(i+1))
                    rts.JumpToCamera()
                    QCstatus, badchips, cold_cycle_ran, test_history = DAT_QC(user_email, dut_skt,duttype, LN2_flg, sinkno=sinkno) 
                    PowerDownDAT(user_email)
                else:
                    print('Will reseat bad chips')
                    for i in badchips:
                        status = rts.ReseatChipInSocket(DAT_nr=sinkno, socket_nr=i+1, duttype=duttype)
                        # status = -27
                        if status < 0:
                            RTS_debug ("RESEAT", user_email, status,sinkno=sinkno, sktn=(i+1))
                    rts.JumpToCamera()
                    QCstatus, badchips, cold_cycle_ran, test_history = DAT_QC(user_email, dut_skt,duttype, LN2_flg, sinkno=sinkno) 
                    PowerDownDAT(user_email)

            # If there are too many issues with any of the sockets, send a notification
            for i in range(len(consecutive_qc_failures)):
                if i in badchips:
                    consecutive_qc_failures[i] += 1
                    print(f'{consecutive_qc_failures[i]}th consecutive QC test failure on socket {i+1} (index from 1)')
                else:
                    consecutive_qc_failures[i] = 0
                if consecutive_qc_failures[i] > bad_qc_threshold:
                    print(f'ERROR: Too many QC failures in a row on socket {i+1} (index from 1)')
                    too_many_bad_qc=True
                else:
                    too_many_bad_qc=False
            if too_many_bad_qc:
                DAT_debug(QCstatus, user_email)
                print('Will proceed, if next chip fails "too many bad QC tests" status will remain true')

            attempt += 1

        # TODO Add updates to alignment dictionary and store in history, see where else needed above?
        # Want BEFORE any reseats update the alignment!
        # alignments = UpdateAlignmentsTestResults(alignments, cryo_cycle_ran, badchips)

        if cryo_cycle_ran and badchips:
            print('Cryo cycle ran but test failed, moving chips to bad tray and moving to next batch')
        elif badchips:
            print(f'Still fails after {nattempts} attempts, moving bad chips back to tray')

        print_timing('Secondary test sequence') 

        duts, dut_skt, ids_goods, ids_bads= MovetoTray(sinkno, duts, dut_skt, QCstatus, badchips, duttype=duttype, LN2_flg=LN2_flg) 
        DeleteLoadedChipInfo()
        ids_dict_good.update(ids_goods)
        ids_dict_bad.update(ids_bads)

        print_timing('Move to tray') 

        for key in list(ids_goods.keys()):
            ocr_key = ids_goods[key][0] + 1
            chip_ocr[ocr_key] = chip_ocr[ocr_key] + [f'PASS_QC'] 
        for key in list(ids_bads.keys()):
            ocr_key = ids_bads[key][0] + 1
            chip_ocr[ocr_key] = [False] + chip_ocr[ocr_key][1:] + [f'Failed_in_QC'] + [f'Moved_to_bad_tray_slot']
        with open(ocrbin_fp, 'wb') as fn:
            pickle.dump(chip_ocr, fn)


        if "PASS" not in QCstatus :
            if len(badchips) > 0:
                skts=badchips
            if len(duts) == 0:
                Undone_Flag = True
        else: #PASS
            Undone_Flag = False
            ids_dict.update(dut_skt)
            dut_skt = {}
            if "CD" in duttype:
                skts=[0,1]
            else:
                skts=[0,1,2,3,4,5,6,7]

        print ("**********save ID info*************")
        #ids_k = list(dut_skt.keys())
        #if len(ids_k) > 0:
        if True:
            fp = rootdir + datetime.datetime.now().strftime("%m_%d_%Y_%H_%M_%S") + "_log.bin"
            if not os.path.isfile(fp) :
                logs["RTS_MSG_R2S_P"] = dut_skt 
                logs["RTS_MSG_S2R_P"] = ids_goods
                logs["RTS_MSG_S2R_F"] = ids_bads
                with open(fp, 'wb') as fn:
                    pickle.dump(logs, fn)
        switch_hr = int(datetime.datetime.now().strftime("%H"))
        if (switch_hr >= 15) and (LN2_flg) and ((len(duts) > 0) or Undone_Flag ): 
            NIGHT_ON = True
            # notification(subject ="Please replace the tray for warm test at night!", message="Please put aside current tray for cold test. \n Then place a new tray for warm test only at night!", user_email=user_email, inform_tech=True)#, p_shifter=True, s_shifter=True)
            sendslack("Please put aside current tray for cold test. \n Then place a new tray for warm test only at night!")
            break
        else:
            NIGHT_ON = False

        print('Would you like to stop the program now? (Will continue if no response)')
        inyn = user_yn(timeout=20)
        if inyn == -2 or inyn == 0:
            print('Continuing to next batch')
            pass
        elif inyn == 1:
            print('Exiting program after this loop')
            break
        elif inyn == -1:
            print('USER ABORT COMMAND PASSED')
            print('Will exit program without post cycle processing')
            rts.rts_disconnect()
            sys.exit(1)
        else:
            # Shoudn't really get here but just for safety
            print('[INVALID USER INPUT - USER INPUT NOW REQUIRED]')
            print('Would you like to stop the program now?')
            inyn=user_yn()
            if inyn == 1:
                break
            elif inyn == 0:
                pass
            else:
                print('USER ABORT COMMAND PASSED OR INVALID INPUT')
                print('Will exit program without post cycle processing')
                rts.rts_disconnect()
                sys.exit(1)

        print_timing('End of cycle') 

    rts.rts_shutdown()

    print ("save RTC infomation")
    from RTS_record import RTS_MANIP
    manip = RTS_MANIP()
    manip.manip_fp = topdir+"/manip.csv"
    manip.rootdir = rootdir
    rts_r = manip.read_manipfp()
    rts_msgs = manip.read_rtsmsgfp()
    for rts_msg_wfp in rts_msgs:
        manip.manip_extract(rts_r, rts_msg_wfp)

    if not NIGHT_ON:
        if transfer_data:
            from move_data import copy_and_delete_folder
            src_root=rootdir +"/../"
            src_folder= trayid
            dst_root=transfer_dir #r"S:/RTS_DAT_LArASIC_QC/" #TODO Joe add transferdesitination
            copy_and_delete_folder(src_root, src_folder, dst_root)
            
        print ("Done")
        # notification(subject ="Congratulations! The tray is done...", message="Please remove the tested tray and place a new tray with label.", user_email=user_email, inform_tech=True)#, p_shifter=True, s_shifter=True)
        sendslack("RTS automation complete!")

####
# State handling in event of crash
###
statefile="./automation_state.bin"
AUTOSTATE=None

def update_state(key,value):

    # Save AUTOSTATE
    AUTOSTATE[key]=value
    with open(statefile, 'wb') as file:
        pickle.dump(AUTOSTATE, file)

    pass

def read_state():

    global AUTOSTATE

    if not os.path.exists(statefile):
        AUTOSTATE={}
        AUTOSTATE['INIT']=None

    with open(statefile,'rb') as file:
        AUTOSTATE=pickle.load(file)

###
# AUTOSTATE Stages
# INIT - Loading in information from file


if __name__ == "__main__":

    # Do some setup here like setting up the slackbot

    read_state()
    if AUTOSTATE['INIT'] is None:
        initialize_rts()


    # TODO, some errors are probably automatically recoverable
    # Though we should make sure they don't happen in the first place
    # complete=False
    # attempt=0
    # while not complete and attempt < 2:
    #     attempt+=1

    try:
        main()
        notification('')
    except Exception as e:
        print('Automation failed, ')
        print(repr(e))
        notification('')

        print("Print automation state information?")
        while True:
            inyn=input('Y/N?: ')
            if inyn.lower() in ['y','yes']:
                print (AUTOSTATE)
                break
            if inyn.lower() in ['n','no']:
                break