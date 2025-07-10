#!/usr/bin/env python3
import sys 
import os
import subprocess
import time 
import random
import pickle
import multiprocessing as mp
import pandas as pd

# To send notification email
## import smtplib
## from email.mime.text import MIMEText
## from email.mime.multipart import MIMEMultipart

## from LogInfo import WaitForPictures
## from Auto_COLDATA_QC import RunCOLDATA_QC, BurninSN

# adding OCR folder to the system path
## sys.path.insert(1, r'C:\\Users\RTS\DUNE-rts-sn-rec')
## import FNAL_CPM as cpm

#from colorama import just_fix_windows_console
#just_fix_windows_console()

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

#start robot
from RTS_CFG import RTS_CFG
## from rts_ssh import subrun
#from rts_ssh import DAT_power_off
#from rts_ssh import Sinkcover
#from rts_ssh import rts_ssh
#from set_rootpath import rootdir_cs
#from cryo_uart import cryobox

############# Global variables #################
### Configure these based on your setup and run

BypassRTS = False
robot_ip = '192.168.121.1'

chiptype = 1 # LArASIC=1, ColdADC=2, COLDATA=3
config_file = 'asic_info.csv'

email_progress = False
email = "rtsfnal@gmail.com"
receiver_email = "tcontrer@fnal.gov"
pw = "vxbg kdff byla bcvs" # FNAL PC specific password

image_directory = "/Users/RTS/RTS_data/images/"
ocr_results_dir = "/Users/RTS/DUNE-rts-sn-rec/Tested/fnal_cpm_results/"

################################################


def send_email(message, subject="ERROR from RTS", sender_email="ningxuyang0202@gmail.com", receiver_email="xning@bnl.gov", password= "tadu prhn atwp tvdb"):
    """
    Sends an email. Prints an error if message failed to send.
    Input:
        message [str]: message to send
        sender_email [str]: email to send from
        receiver_email [str]: email(s) to send to. Separate multiple emails with a comma.
        password [str]: password of senders email
    """
    body = message
    msg = MIMEMultipart()

    msg['From'] = sender_email
    msg['To'] = receiver_email
    msg['Subject'] = subject
    # Attach the body text to the email
    msg.attach(MIMEText(body, 'plain'))
    
    try: 
        with smtplib.SMTP('smtp.gmail.com', 587) as server:
            server.ehlo()
            server.starttls()  # Start TLS encryption
            server.ehlo()
            server.login(sender_email, password)  # Login to the server
            server.send_message(msg)  # Send the email
            print("Email sent successfully!")
    except Exception as e:
        print(f"Failed to send email: {e}")

def FindChipImage(image_dir, tray_nr, col_nr, row_nr):
    """
    Finds the latest bmp image taken of a chip in the 
    given tray, column, and row, and returns the string
    of the file name. This assumes the files start with
    the date and time the image was taken, followed by
    the chip position information. 
    
    Inputs:
        image_dir [str]: directory of chip images
        tray_nr [int]: tray/pallet number (1 or 2)
        col_nr [int]: column number
        row_nr [int]: row number
    """
    # Assumes the naming scheme of the image files
    file_base = f"tr{tray_nr}_col{col_nr}_row{row_nr}_SN.bmp"

    all_files = os.listdir(image_dir)
    image_files = [f for f in all_files if file_base in f]

    # Sory images, latest in time will be last
    image_files.sort()

    return image_files[-1]

def MoveChipsToSockets(rts, chip_positions):
    """
    This function turns the robot motor on, moves all chips from a tray to the sockets, 
    moves the robot back to home, and turns the motor off.
    Inputs:
        queue [Queue]: multiprocessing queue for threading
        chip_positions [dict]: dictionary describing the chip positions in the tray 
                               and where to put them in the DAT board
    """
    rts.MotorOn()
    for i in range(len(chip_positions['dat'])):
        dat = chip_positions['dat'][i]
        dat_socket = chip_positions['dat_socket'][i]
        tray = chip_positions['tray'][i]
        col = chip_positions['col'][i]
        row = chip_positions['row'][i]
        rts.MoveChipFromTrayToSocket(dat, dat_socket, tray, col, row)
    rts.JumpToCamera()
    rts.PumpOff()
    rts.MotorOff()

    return

def MoveChipsToTray(rts, chip_positions):
    """
    This function turns the robot motor on, moves all chipsfrom the sockets to the tray, 
    moves the robot back to home, and turns the motor off.
    Inputs:
        queue [Queue]: multiprocessing queue for threading
        chip_positions [dict]: dictionary describing the chip positions in the tray 
                               and where to put them in the DAT board
    """
    rts.MotorOn()
    for i in range(len(chip_positions['dat'])):
        dat = chip_positions['dat'][i]
        dat_socket = chip_positions['dat_socket'][i]
        tray = chip_positions['tray'][i]
        col = chip_positions['col'][i]
        row = chip_positions['row'][i]
        rts.MoveChipFromSocketToTray(dat, dat_socket, tray, col, row)
    rts.JumpToCamera()

    return

def RTS_Cyle(rts, chip_positions, ocr_results_dir, config_file):
    """
    Runs an entire cycle of chip testing: move chips from the tray to the sockets,
    performs OCR to get serial numbers, runs the QC tests, burn the SN into the 
    chip, and moves the chips back to the tray. 
    Inputs:
        rts [RTS_CFG]: a class defining the rts and functions used to move the robot
        chip_positions [dict]: dictionary of chip positions and socket labels
        ocr_results_dur [str]: directory of ocr output
        config_file [str]: directory and file name of RTS config file.
    """

    # Move all chips to sockets
    if not BypassRTS:
        MoveChipsToSockets(rts, chip_positions)

    # Check the RobotLog to see if the chip pictures are ready before running OCR
    print('Waiting for chip pictures...')
    pictures_ready, pictures = WaitForPictures(chip_positions, threading=False)
 
    # Queue the OCR process to get SN for each chip
    sn_ready = True
    if pictures_ready:
        print('Pictures ready!')
        for i in range(len(pictures)):
            success = cpm.RunOCR(image_directory, pictures[i], ocr_results_dir,
                                 True, chip_positions['label'][i], config_file)
            sn_ready = sn_ready and success # only True if all RunOCR's are successful
    # Kill Ollama used by OCR (TODO: Why does Ollama not close after OCR is done??)
    subrun("taskkill /F /IM ollama.exe")

    print('About to run COLDATA_QC')
    logs = RunCOLDATA_QC(duttype="CD", env="RT", rootdir="C:/Users/RTS/Tested/")

    # Burn in the serial number found from the OCR
    if sn_ready:
        print('About to run burning in of SN')
        BurninSN(logs) 
    else:
        print('OCR failed, skipping burning in  of SN.')

    # Move all chips to tray
    if not BypassRTS:
        MoveChipsToTray(rts, chip_positions)

    return

if __name__ == "__main__":
    print("Starting RTS integration script")
    start_time = time.time()
    
    # Log progress of script over email
    if email_progress:
        send_email("Starting RTS!", sender_email=email, receiver_email=receiver_email, password=pw)

    if not BypassRTS:
        rts = RTS_CFG()
        rts.rts_init(port=201, host_ip=robot_ip) 

    # Dictionary to hold chip positions and chip labels 
    chip_positions = {'tray':[2,2], 'col':[1,1], 'row':[2,3], 'dat':[2,2], 'dat_socket':[21,22], 'label':['CD0','CD1']}

    RTS_Cyle(rts, chip_positions, ocr_results_dir, config_file)

    if not BypassRTS:
        rts.rts_shutdown()

    if email_progress:
        send_email("Finished running!", sender_email=email, receiver_email=receiver_email, password=pw)

    end_time = (time.time() - start_time) / 60 # convert to minutes
    print(f"--- FNAL_RTS_integration.,py took {end_time} minutes to run ---")