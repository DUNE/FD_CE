#!/usr/bin/env python3
import sys 
import os
import subprocess
import time 
import random
import pickle
import multiprocessing as mp
import pandas as pd
import csv

# To send notification email
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from BNL_QC.LogInfo import WaitForPictures
from Integration.Auto_COLDATA_QC import RunCOLDATA_QC, BurninSN
from Integration.FNAL_RTS_integration import RTS_Cycle, send_email

# adding OCR folder to the system path
sys.path.insert(1, r'C:\\Users\RTS\DUNE-rts-sn-rec')
import FNAL_CPM as cpm

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
from BNL_QC.RTS_CFG import RTS_CFG
from BNL_QC.rts_ssh import subrun
#from rts_ssh import DAT_power_off
#from rts_ssh import Sinkcover
#from rts_ssh import rts_ssh
#from set_rootpath import rootdir_cs
#from cryo_uart import cryobox

############# Global variables #################
### Configure these based on your setup and run

BypassRTS = True
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



if __name__ == "__main__":
    print("Starting RTS integration script")
    start_time = time.time()
    
    # Log progress of script over email
    if email_progress:
        send_email("Starting RTS!", sender_email=email, receiver_email=receiver_email, password=pw)

    rts = False
    if not BypassRTS:
        rts = RTS_CFG()
        rts.rts_init(port=201, host_ip=robot_ip) 

    # Dictionary to hold chip positions and chip labels 
    chip_positions = {'tray':[2,2], 'col':[3,3], 'row':[1,2], 'dat':[2,2], 'dat_socket':[21,22], 'label':['CD0','CD1']}

    RTS_Cycle(rts, chip_positions, ocr_results_dir, config_file, run_ocr=False, do_burnin=False, BypassRTS=True)
    #MoveBadChipsToTray(rts, chip_positions, 'BadTray.csv')

    if not BypassRTS:
        rts.rts_shutdown()

    if email_progress:
        send_email("Finished running!", sender_email=email, receiver_email=receiver_email, password=pw)

    end_time = (time.time() - start_time) / 60 # convert to minutes
    print(f"--- FNAL_RTS_integration.py took {end_time} minutes to run ---")