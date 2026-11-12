"""
Created on Sun Aug  8 12:16:00 2026
Author: Joe Walsh (MSU)
Based on cryo_uart.py by Shanshan Gao
"""

import os
import sys
import time
import os.path
import serial
import socket
import select

from colorama import just_fix_windows_console
just_fix_windows_console()
from sendemail import sendemail, sendslack
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

def countdown(t):
    while t:
        mins, secs = divmod(t, 60)
        timer = '{:02d}:{:02d}'.format(mins, secs)
        print(timer, end='\r')  # Overwrite the line each second
        time.sleep(1)
        t -= 1

class cryobox:
    def __init__(self):
        self.cmd_dict={}
        self.cmd_dict[b'0'] = b'Setting STATE to 0 (AutoFill)'
        self.cmd_dict[b'1'] = b'Setting STATE to 1 (IDLE)'
        self.cmd_dict[b'2'] = b'Setting STATE to 2 (TC Warming)'
        self.cmd_dict[b'3'] = b'Setting STATE to 3 (TC LN2 Puddle)'
        self.cmd_dict[b'4'] = b'Setting STATE to 4 (TC LN2 Immersion)'
        self.portno = 3 # 4

#    def cryo_create(self):
#        try:
#            self.ser = serial.Serial('COM4', 9600, timeout=0, parity=serial.PARITY_NONE)
#            print ("cryogenic box is connected")
#        except:
#            print ("could not open COM port, please call tech coordinator to fix it")
#            while True:
#                time.sleep(1)
#                yorn = input ("Fixed? (Y/N)")
#                if "Y" in yorn or "y" in yorn:
#                    break
#                else:
#                    pass
    def cryo_create(self):
        while True:
            try:
                self.ser = serial.Serial('COM%d'%self.portno, 9600, timeout=5, write_timeout=5, parity=serial.PARITY_NONE)
                print("Cryogenic box is connected.")
                time.sleep(0.5)  # Optional: allow hardware to stabilize
                break
            except serial.SerialException:
                print("Could not open COM port. Please : ") 
                print("step 1: Power off cold control box ") 
                print("step 2: Unplug USB cable from cold control box ") 
                print("step 3: Wait 5 seconds ") 
                print("step 4: Turn cold control box back on") 
                print("step 5: Replug USB cable to cold control box") 
                print("Try 1-5 for 3 times, if it doesn't work, call the tech coordinator") 
                # sendemail(subject="RTS: Cryo control box error", message="Please contact tech coordinator (Cryo control box issue)", user_email="walshj29@msu.edu;", inform_tech=True)
                sendslack("[CRYO] ERROR: Serial exception. Please contact tech coordinator (Cryo control box issue) ")
                while True:
                    try: 
                        self.portno = int(input("Input COM Port num (4 by default)?: "))
                    except:
                        self.portno = 3 # 4

                    self.cryo_close()
                    break

                    #yorn = input("Fixed the issue? (Y/N): ").strip().lower()
                    #if yorn == 'y':
                    #    self.cryo_close()
                    #    break
                    #elif yorn == 'n':
                    #    print("Try 1-5 for 3 times, if it doesn't work, call the tech coordinator") 
                    #    sendemail(subject="RTS: Cryo control box error", message="Please contact tech coordinator (Cryo control box issue)", user_email="walshj29@msu.edu;", inform_tech=True)
                    #    print("Waiting... Please fix the issue and try again.")
                    #    time.sleep(1)
                    #else:
                    #    print("Invalid input. Please enter 'Y' or 'N'.")

    def cryo_close(self):
        try: 
            self.ser.close()
            print ("cryogenic box is disconnected")
        except Exception as e:
            print(f"Cryo Control Box Serial close error: {e}")

    def uart_write(self, mode=b'1'):
        while True:
            try: 
                self.ser.write(mode)
                break
            except serial.SerialTimeoutException as e:
                print(f"Cryo Control Box Serial write timeout error: {e}")
                # sendemail(subject="RTS: Cryo control box error", message="Please contact tech coordinator (Cryo control box issue)", user_email="walshj29@msu.edu;", inform_tech=True)
                sendslack("[CRYO] ERROR: Serial timeout. Please contact tech coordinator (Cryo control box issue)")
                while True:
                    yorn = input("Fixed the issue? (Y/N): ").strip().lower()
                    if yorn == 'y':
                        self.cryo_close()
                        self.cryo_create()
                        break
                    elif yorn == 'n':
                        print("Waiting... Please fix the issue and try again.")
                        time.sleep(1)
                    else:
                        print("Invalid input. Please enter 'Y' or 'N'.")
            except Exception as e:
                print(f"Cryo Control Box Unexpected Serial error: {e}")
                print("Please call the tech coordinator to fix it.")
                # sendemail(subject="RTS: Cryo control box error", message="Please contact tech coordinator (Cryo control box issue)", user_email="walshj29@msu.edu;", inform_tech=True)
                sendslack("[CRYO] ERROR: Serial exception. Please contact tech coordinator (Cryo control box issue)")
                while True:
                    yorn = input("Fixed the issue? (Y/N): ").strip().lower()
                    if yorn == 'y':
                        self.cryo_close()
                        self.cryo_create()
                        break
                    elif yorn == 'n':
                        print("Wait... Please fix the issue and try again.")
                        time.sleep(1)
                    else:
                        print("Invalid input. Please enter 'Y' or 'N'.")

    def uart_read(self):
        try:
            val = self.ser.read(4096)
        except Exception as e:
            print(f"Cryo Control Box Serial read error: {e}")
            val = b''
        return val

    def cryo_cmd(self, mode=b'1'):
        rd = b''
        while True:
            self.uart_write(mode)
            for i in range(2):
                time.sleep(1)
                rd = rd + self.uart_read()
            if self.cmd_dict[mode] in rd:
                print ("\033[92m", self.cmd_dict[mode], "\033[0m")
                if mode!=b'0': #readback status
                    self.uart_write(b'm')
                    for i in range(2):
                        time.sleep(1)
                        rd = rd + self.uart_read()
                    if b'State= ' + mode in rd:
                        #print (rd)
                        break
                    else:
                        pass
                else:
                    break
        return rd

    def cryo_fill(self):
        self.cryo_create()
        fill_flg = True
        while fill_flg:
            try:
                print ("Start fill 50L dewar...")
                print ("\033[93m If 22psi dewar is empty, please \033[91m Ctrl + C (only once) \033[0m")
                rd = self.cryo_cmd(mode=b'0')
                t0 = time.time_ns()
                while True:
                    time.sleep(1)
                    tmp = self.uart_read()
                    if tmp!=b'':
                        rd = rd + tmp
                    if b'AutoFill ended. Setting State 2 (Warm/Purge)' in rd:
                        fill_flg = False
                        break
                    t1 = (time.time_ns() - t0 ) // 1e9
                    if t1 >= 600:
                        # sendemail(subject="Warning: LN2 filling over 10 minutes", message="Please check if 22psi dewar is empty.\n If not, type 'y' and enter in the terminal! \n If yes, contact tech coordiantor to replace the 22PSI dewar", user_email="walshj29@msu.edu;", inform_tech=False)
                        sendslack("[CRYO] Warning: LN2 filling taking longer than 10 minutes, Please check if 22psi dewar is empty! Requires intervention to continue filling from transfer dewar")
                        rd = self.cryo_cmd(mode=b'1') #stop filling
                        time.sleep(5)
                        tmp = self.uart_read()
                        time.sleep(5)
                        yorn = input("Continue filling?(y or n) : ")
                        if "Y" in yorn or "y" in yorn:
                            rd = self.cryo_cmd(mode=b'0')
                            t0 = time.time_ns()
                        else:
                            x = 10/0
                    if t1 %30 == 0:
                        print (tmp)
                rd += self.cryo_cmd(mode=b'1')
            except (KeyboardInterrupt,ZeroDivisionError ) as e  :
                fill_flg = True
                rd += self.cryo_cmd(mode=b'1')
                print ("Please shut down valve of 22psi dewar")
                # sendemail(subject="22psi dewar is empty", message="Please contact tech coordinator (22psi dewar is empty)", user_email="walshj29@msu.edu;", inform_tech=True)
                sendslack("[CRYO] Warning: Please contact tech coordinator (22psi dewar is empty) ")
                while True:
                    yorn = input("Is 22pis Dewar \033[91m value CLOSE \033[0m completely?(y or n) : ")
                    if "Y" in yorn or "y" in yorn:
                        while True:
                            confirmed = input("Double confirmed?(Type in exactly: \033[91m confirmed \033[0m) : ")
                            if confirmed == 'confirmed':
                                print ("Please replace the dewar with a full one")
                                while True:
                                    yorn = input("New full dewar in position and hose tighted?(y or n) : ")
                                    if "Y" in yorn or "y" in yorn:
                                        print ("Please open the valve of 22psi dewar")
                                        break
                                break
                        break
                    else:
                        pass
#                raise
        self.cryo_close()

        return rd

    def cryo_warmup(self, waitminutes = 20):
        self.cryo_create()
        rd = self.cryo_cmd(mode=b'2')
        self.cryo_close()
        print ("Please wait %d minutes..."%waitminutes)
        # time.sleep(waitminutes*60)
        countdown(waitminutes*60)
        self.cryo_create()
        rd = self.cryo_cmd(mode=b'1')
        self.cryo_close()
        return rd

    def cryo_lowlevel(self, waitminutes = 10):
        self.cryo_create()
        rd = self.cryo_cmd(mode=b'3')
        self.cryo_close()
        print ("Please wait %d minutes..."%waitminutes)
        # time.sleep(waitminutes*60)
        countdown(waitminutes*60)

    def cryo_highlevel(self, waitminutes = 5):
        self.cryo_create()
        rd = self.cryo_cmd(mode=b'4')
        self.cryo_close()
        print ("Please wait %d minutes..."%waitminutes)
        #time.sleep(waitminutes*60)
        countdown(waitminutes*60)

class cryo_Server():
    def __init__(self):
        self.ip = None
        self.port = None
        self.propagate_status = None

        self.cryo_serial = None

    def poll_status():
        pass

    def server_init(self, host_ip="127.0.0.1", port=5000):
        self.ip = host_ip
        self.port = port
        self.propagate_status = False

        self.cryo_serial = cryobox()

        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
            server.bind((self.ip, self.port))
            server.listen()

            server.setblocking(False)

            print("Server listening")

            clients = []

            while True:
                # Wait for incoming connections/data, but only for 0.1 seconds
                readable, _, _ = select.select(
                    [server] + clients,
                    [],
                    [],
                    0.1
                )

                for sock in readable:

                    # New client connection
                    if sock is server:
                        client, address = server.accept()
                        client.setblocking(False)
                        clients.append(client)

                        print(f"Client connected: {address}")

                    # Data from an existing client
                    else:
                        data = sock.recv(1024)

                        if not data:
                            clients.remove(sock)
                            sock.close()
                            continue

                        command = data.decode().strip()

                        print(f"Received: {command}")

                        if command == "FILL":
                            print("Filling storage dewar from transfer dewar...")
                            self.cryo_fill()
                            response = "OK\n"

                        elif command == "LOW":
                            print("Filling chamber to low level (DAT not submerged)...")
                            self.cryo_lowlevel()
                            response = "OK\n"

                        elif command == "HIGH":
                            print("Filling chamber to high level (DAT submerged)...")
                            self.cryo_highlevel()
                            response = "OK\n"

                        elif command == "WARM":
                            print("Draining and purging chamber...")
                            self.cryo_warmup()
                            response = "OK\n"

                        elif command == "STATUS":
                            response = "RUNNING\n"

                        else:
                            response = "UNKNOWN COMMAND\n"

                        sock.sendall(response.encode())

                # This happens regardless of whether a command arrived
                self.poll_status()

    def cryo_fill(self):
        pass

    def cryo_lowlevel(self, waitime):
        self.cryo_serial.cryo_create()
        rd = self.cryo_serial.cryo_cmd(mode=b'3')
        t0 = time.time_ns()
        while True:
            time.sleep(1)
            tmp = self.cryo_serial.uart_read()
            if tmp!=b'':
                rd = rd + tmp
                


        pass

    def cryo_highlevel(self):
        pass

    def cryo_warmup(self):
        pass

class cryo_client():
    # For sending requests from the automation code
    def __init__(self):    
        self.server_ip=None
        self.server_port=None

    def client_init(self, server_ip="127.0.0.1", server_port = 5000):
        self.server_ip=None
        self.server_port=None

    def send_command(self, command):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as client:
            client.connect((self.server_ip, self.server_port))
            client.sendall(command.encode())

        return client.recv(1024).decode()
