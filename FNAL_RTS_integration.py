import sys 
import os
import subprocess
import time 
import random
import pickle
import multiprocessing as mp

# To send notification email
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from LogInfo import SaveToLog, ReadLastLog

# adding OCR folder to the system path
sys.path.insert(1, r'C:\\Users\RTS\DUNE-rts-sn-rec')
import FNAL_CPM as cpm

from colorama import just_fix_windows_console
just_fix_windows_console()

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

    tray = 2
    col = 1
    row = 1
    dat = 2
    dat_socket = 21

    if not BypassRTS:
        p_MoveChipFromTrayToSocket = mp.Process(target=rts.MoveChipFromTrayToSocket, args=(dat, dat_socket, tray, col, row))
        rts.MotorOn()
        p_MoveChipFromTrayToSocket.start()
    print('Commands sent')

    # Check the RobotLog to see if the chip picture is ready before running OCR
    RobotLog_dir = "/Users/RTS/RTS_data/"
    RobotLog_file = "RobotLog.txt"
    robotlog = ReadLastLog(RobotLog_file, RobotLog_dir)
    picture_ready = False
    timepassed = 0
    while not picture_ready:

        robotlog = ReadLastLog(RobotLog_file, RobotLog_dir)
        #print("-------- RobotLog:" + robotlog)
        if "Picture of chip in tray taken" in robotlog:
            picture_ready = True
            image_id = robotlog.split(" ")[-1].rstrip("\n")
            #image_id = '20250402112328' # for testing while we can't run full OCR

        # Break if its been too long
        if timepassed > 180:
            print("ERROR: Picture of chip has still not been taken.")
            break
        time.sleep(0.5)
        timepassed += 0.5
 
    if picture_ready:
        p_RunOCR = mp.Process(target=cpm.RunOCR, args=(image_directory, image_id, ocr_results_dir))
        p_RunOCR.start() # Start OCR 
        p_RunOCR.join() # waits till process is done
        
        # Use ShowOCRResult to test the process without actually runing OCR
        #p_ShowOCRResult = mp.Process(target=cpm.ShowOCRResult, args=(image_id, ocr_results_dir, ocr_results_dir))
        #p_ShowOCRResult.start()
        #p_ShowOCRResult.join()

    if not BypassRTS:
        p_MoveChipFromTrayToSocket.join() # wait till the RTS is done moving chips to shutdown
        rts.rts_shutdown()

    if email_progress:
        send_email("Finished running!", sender_email=email, receiver_email=receiver_email, password=pw)