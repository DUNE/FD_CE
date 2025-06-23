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
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from LogInfo import SaveToLog, ReadLastLog
from Auto_COLDATA_QC import RunCOLDATA_QC, BurninSN

# adding OCR folder to the system path
sys.path.insert(1, r'C:\\Users\RTS\DUNE-rts-sn-rec')
import FNAL_CPM as cpm

from colorama import just_fix_windows_console
just_fix_windows_console()

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

def MoveChipsAndTest(rts, chip_positions, duttype="CD", env="RT", rootdir="C:/Users/RTS/Tested/"):
    """
    This function moves two chips from a tray to the sockets and runs the QC tests for COLDATA.
    Inputs:
        queue [Queue]: multiprocessing queue for threading
        chip_positions [dict]: dictionary describing the chip positions in the tray 
                               and where to put them in the DAT board
        duttype [str]: hardware type to test (CD=COLDATA)
        env [str]: room/cold environment for tests
        rootdir [str]: directory to save results
    """

    for i in range(len(chip_positions['dat'])):
        dat = chip_positions['dat'][i]
        dat_socket = chip_positions['dat_socket'][i]
        tray = chip_positions['tray'][i]
        col = chip_positions['col'][i]
        row = chip_positions['row'][i]
        rts.MoveChipFromTrayToSocket(dat, dat_socket, tray, col, row)

    rts.rts_shutdown()
    print('Done moving')

    #logs = RunCOLDATA_QC(duttype, env, rootdir)

    return #logs

if __name__ == "__main__":
    print("Starting RTS integration script")
    
    logs = {}

    # Log progress of script over email
    if email_progress:
        send_email("Starting RTS!", sender_email=email, receiver_email=receiver_email, password=pw)

    # Connect to the robot
    if not BypassRTS:
        rts = RTS_CFG()
        rts.rts_init(port=201, host_ip=robot_ip) 

    # Dictionary to hold chip positions and chip labels
    chip_positions = {'tray':[2,2], 'col':[1,2], 'row':[4,1], 'dat':[2,2], 'dat_socket':[21,22], 'label':['CD0','CD1']}

    # Start moving chips and then QC testing
    #qc_queue = mp.Queue()
    if not BypassRTS:
        #p_MoveChipsAndTest = mp.Process(target=MoveChipsAndTest, args=(qc_queue, rts, chip_positions))
        rts.MotorOn()
        MoveChipsAndTest(rts, chip_positions)
        #p_MoveChipsAndTest.start()
        print('Commands sent')

    # Check the RobotLog to see if the chip picture is ready before running OCR
    RobotLog_dir = "/Users/RTS/RTS_data/"
    RobotLog_file = "RobotLog.txt"
    robotlog = ReadLastLog(RobotLog_file, RobotLog_dir)
    pictures_ready = False
    pictures = []
    timepassed = 0
    while not pictures_ready:

        robotlog = ReadLastLog(RobotLog_file, RobotLog_dir)
        print("-------- RobotLog:" + robotlog)
        if "Picture of chip in tray taken" in robotlog:
            image_id = robotlog.split(" ")[-1].rstrip("\n")
            if image_id not in pictures:
                pictures.append(image_id)
            #image_id = '20250402112328' # for testing while we can't run full OCR

            # Stop once we have pictures for each chip
            if len(pictures) == len(chip_positions['dat_socket']):
                print('Pictures ready!')
                pictures_ready = True

        # Break if its been too long
        if timepassed > 180:
            print("ERROR: Pictures of chip has still not been taken.")
            break
        time.sleep(0.5)
        timepassed += 0.5
 
    # Queue the OCR process to get SN for each chip
    #ocr_queue = mp.Queue()
    if pictures_ready:
        for i in range(len(pictures)):
            #p_RunOCR = mp.Process(target=cpm.RunOCR, args=(ocr_queue, image_directory, pictures[i], ocr_results_dir,
            #                                               False, chip_positions['label'][i], config_file))
            #p_RunOCR.start() # Start OCR 
            cpm.RunOCR(image_directory, pictures[i], ocr_results_dir,
                       False, chip_positions['label'][i], config_file)
            
            # Use ShowOCRResult to test the process without actually runing OCR
            #p_ShowOCRResult = mp.Process(target=cpm.ShowOCRResult, args=(image_id, ocr_results_dir, ocr_results_dir))
            #p_ShowOCRResult.start()
            #p_ShowOCRResult.join()

    #if not BypassRTS:
    #    p_MoveChipsAndTest.join() # wait till the RTS is done moving chips to shutdown

    # Make sure OCR is done for all pictures
    #[ocr_queue.get() for i in range(len(pictures))]

    print('About to run COLDATA_QC')
    #_ = qc_queue.get() # waiting for process to end
    logs = RunCOLDATA_QC(duttype="CD", env="RT", rootdir="C:/Users/RTS/Tested/")
    #log_path = "/Users/RTS/Tested/Time_20250623190731_DUT_1000_2000/RT_CD_033432506_033392506/QC.log"
    #logs = pd.read_pickle(log_path)

    # Burn in the serial number found from the OCR
    print('About to run burn in')
    #logs = qc_queue.get() # gets the output from the last process queued
    BurninSN(logs) 

    if email_progress:
        send_email("Finished running!", sender_email=email, receiver_email=receiver_email, password=pw)