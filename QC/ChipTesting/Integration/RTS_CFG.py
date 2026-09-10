import socket # for socket 
import sys 
import time 

class RTS_CFG():
    def __init__(self):
        self.s = None
        self.msg = None

    def rts_init(self, port=2001, host_ip='192.168.0.2'): # default port for socket 
        while True:
            try: 
                self.s = socket.socket(socket.AF_INET, socket.SOCK_STREAM) 
                print ("Socket successfully created")
            except socket.error as err: 
                print ("socket creation failed with error %s" %(err))
             
            # connecting to the server 
            self.s.connect((host_ip, port))
 
            print("the socket has successfully connected to ",host_ip) 
            self.msg=self.s.recv(1024).decode()
            self.msg = self.msg.strip()
            
            if self.msg != "RTS ready":
                print("***ERROR! Bad responce from server: [",self.msg,"]")
                self.s.close()
                while True:
                    tmp = input ("Exit (E) or Retry (R):")
                    if "E" in  tmp:
                        exit()
                    elif "R" in tmp:
                        break
                    else:
                        pass
            else:
                break
        return self.msg

    def RootDirSet(self, rootdir): #
        while True:
            try:
                msg = "RootDir"
                self.s.send(msg.encode())
                self.s.send(b"\r\n") 

                self.msg = rootdir
                self.s.send(self.msg.encode())
                self.s.send(b"\r\n")

                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "set" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')
       
    def MotorOn(self): #
        while True:
            try:
                msg = "MotorOn"
                self.s.send(msg.encode())
                self.s.send(b"\r\n") 
                self.msg = self.s.recv(1024).decode() 
                self.msg = self.msg.strip()
                print (self.msg)
                if "On" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def MotorOff(self): #
        while True:
            try:
                msg = "MotorOff"
                self.s.send(msg.encode())
                self.s.send(b"\r\n") 
                self.msg = self.s.recv(1024).decode() 
                self.msg = self.msg.strip()
                print (self.msg)
                if "Off" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def CoverStatus(self): #
        if True:
            try:
                msg = "CoverStatus"
                self.s.send(msg.encode())
                self.s.send(b"\r\n") 
                self.msg = self.s.recv(1024).decode() 
                self.msg = self.msg.strip()
                print (self.msg)
                #if "199" in self.msg:
                #    break
                #else:
                #    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')
            return self.msg

    def JumpToCamera(self): #
        while True:
            try:
                msg = "JumpToCamera"
                self.s.send(msg.encode())
                self.s.send(b"\r\n") 
                self.msg = self.s.recv(1024).decode() 
                self.msg = self.msg.strip()
                print (self.msg)
                if msg in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def PumpOff(self): #
        while True:
            try:
                msg = "PumpOff"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "Off" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def MoveChipFromTrayToSocket(self, DAT_nr, socket_nr, tray_nr, col_nr, row_nr):
        tryi = 0
        while True:
            try:
                print ("Move Chip From Tray#{},col#{},row#{} To DAT#{},Socket{}".format(tray_nr, col_nr, row_nr, DAT_nr, socket_nr))
                self.msg = "MoveChipFromTrayToSocket"
                self.s.send(self.msg.encode())
                self.s.send(b"\r\n")

                self.s.send(str(DAT_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(socket_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(tray_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(col_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(row_nr).encode())
                self.s.send(b"\r\n")
    
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print("msg: ", self.msg)
                #try:
                if True:
                    status = int(self.msg)
                    if (status < 0) and (status != -200) :
                        tryi = tryi + 1 
                        print ("Move chip to orignal position")
                        self.JumpToTray(tray_nr, col_nr, row_nr)    
                        self.DropToTray()    
                        self.JumpToCamera()
                        self.rts_idle() 
                        time.sleep (1)
                        self.MotorOn() 
                    else:
                        break
                    if tryi > 2:
                        break
                    else:
                        print ("Try again")
                        continue
                #except:
                #    print ("whyereeeee")
                #    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')
        return status

    def MoveChipFromSocketToTray(self, DAT_nr, socket_nr, tray_nr, col_nr, row_nr, duttype="FE"):
        if "FE" in duttype:
            sktn = socket_nr
        elif "ADC" in duttype:
            sktn = socket_nr + 10
        elif "CD" in duttype:
            tray_nr = (tray_nr&0x03) + 10
            sktn = (socket_nr&0x03)+20
        else:
            sktn = socket_nr

        tryi = 0
        while True:
            try:
                print ("Move Chip From DAT#{},Socket{} To Tray#{},col#{},row#{}".format(DAT_nr, socket_nr, tray_nr, col_nr, row_nr))
                self.msg = "MoveChipFromSocketToTray"
                self.s.send(self.msg.encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(DAT_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(socket_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(tray_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(col_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(row_nr).encode())
                self.s.send(b"\r\n")
    
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print("msg: ", self.msg)
                try:
                    status = int(self.msg)
                    if (status < 0) and (status != -200) :
                        tryi = tryi + 1
                        # print ("Move chip to orignal position")
                        # self.JumpToSocket(DAT_nr, socket_nr)    
                        # self.InsertIntoSocket()    
                        # self.JumpToCamera()
                        # self.rts_idle() 
                        # time.sleep (1)
                        # self.MotorOn() 
                        # Still going to attempt to place in tray
                        checkstatus = self.CheckTrayOccupancy(tray_nr, col_nr, row_nr)
                        if checkstatus != 0:
                            print('Target tray position is occupied!')
                            self.rts_idle()
                            time.sleep(1)
                            self.MotorOn()
                            return -999
                        self.JumpToTray(tray_nr, col_nr, row_nr)
                        self.DropToTray()
                        self.JumpToCamera()
                        self.rts_idle()
                        time.sleep(1)
                        self.MotorOn()
                        return 0
                    else:
                        break

                    if tryi > 2:
                        break
                    else: 
                        print ("Try again")
                        continue
                except:
                    time.sleep(1)

                try:
                    status = int(self.msg)
                    break
                except:
                    time.sleep(1)

                status = int(self.msg)
                break
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')
        return status

    def MoveChipFromTrayToTray(self, stray_nr, scol_nr, srow_nr, dtray_nr, dcol_nr, drow_nr):
        i = 0
        origpos = False
        tryi = 0
        while True:
            print ("Move Chip From  Tray#{},col#{},row#{} To Tray#{},col#{},row#{}".format(stray_nr, scol_nr, srow_nr, dtray_nr, dcol_nr, drow_nr))
            i = i + 1
            self.msg = "MoveChipFromTrayToTray"
            self.s.send(self.msg.encode())
            self.s.send(b"\r\n")
    
            self.s.send(str(stray_nr).encode())
            self.s.send(b"\r\n")
    
            self.s.send(str(scol_nr).encode())
            self.s.send(b"\r\n")
    
            self.s.send(str(srow_nr).encode())
            self.s.send(b"\r\n")

            self.s.send(str(dtray_nr).encode())
            self.s.send(b"\r\n")
    
            self.s.send(str(dcol_nr).encode())
            self.s.send(b"\r\n")
    
            self.s.send(str(drow_nr).encode())
            self.s.send(b"\r\n")

            self.msg = self.s.recv(1024).decode()
            self.msg = self.msg.strip()
            print("msg: ", self.msg)
            try:
                status = int(self.msg)
                if (status < 0) and (status != -200) :
                    print ("Move chip to orignal position")
                    tryi = tryi + 1
                    i=i-1
                    self.JumpToTray(stray_nr, scol_nr, srow_nr)    
                    self.DropToTray()    
                    self.JumpToCamera()
                    self.rts_idle() 
                    time.sleep (1)
                    self.MotorOn() 
                    continue
                else:
                    break

                if tryi > 2:
                    break
                else:
                    print ("Try again")
                    continue
            except:
                time.sleep(1)
                continue

            if status >=0 :
                break
            else:
                if origpos:
                    print ("Error")
                    break
                cn = (drow_nr-1)*15+dcol_nr-1 + 1
                dcol_nr = cn%15 + 1
                drow_nr = cn//15 + 1
                print (cn , dcol_nr, drow_nr, i)
                if (cn >= 20) :
                    input ("please check..., any key to put the chip back to orignal position")
                    dtray_nr = stray_nr
                    dcol_nr = scol_nr
                    drow_nr = srow_nr
                    origpos = True
        return status

    def ReseatChipInSocket(self, DAT_nr, socket_nr, duttype="FE"):
        if "FE" in duttype:
            sktn = socket_nr
        elif "ADC" in duttype:
            sktn = socket_nr + 10
        elif "CD" in duttype:
            sktn = (socket_nr&0x03)+20
        else:
            sktn = socket_nr

        tryi = 0
        while True:
            try:
                print ("Reseat chip in socket DAT#{},Socket{}".format(DAT_nr, socket_nr))
                self.msg = "ReseatChipInSocket"
                self.s.send(self.msg.encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(DAT_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(socket_nr).encode())
                self.s.send(b"\r\n")
                
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print("msg: ", self.msg)
                try:
                    status = int(self.msg)
                    if (status < 0) and (status != -200) :
                        tryi = tryi + 1
                        print ("Reseat chip in socket")
                        self.JumpToSocket(DAT_nr, socket_nr)    
                        self.InsertIntoSocket()    
                        self.JumpToCamera()
                        self.rts_idle() 
                        time.sleep (1)
                        self.MotorOn() 
                    else:
                        break

                    if tryi > 2:
                        break
                    else: 
                        print ("Try again")
                        continue
                except:
                    time.sleep(1)

                try:
                    status = int(self.msg)
                    break
                except:
                    time.sleep(1)

                status = int(self.msg)
                break
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')
        return status

    def rts_idle(self): 
        while True:
            try:
                print ("Quiet")
                self.msg = "Quiet"
                self.s.send(self.msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                print ("Wait 5 seconds")
                if "Quiet" in self.msg:
                    time.sleep(5)
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def rts_shutdown(self): 
        while True:
            try:
                self.PumpOff()

                self.msg = "Shutdown"
                self.s.send(self.msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                break
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

        print("Closing socket connection...")
        time.sleep(3)
        self.s.close()
    
    def rts_disconnect(self): 
        while True:
            try:
                self.msg = "Disconnect"
                self.s.send(self.msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                break
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

        print("Closing socket connection...")
        time.sleep(3)
        self.s.close()
        
    def JumpToTray(self, tray_nr, col_nr, row_nr):
        while True:
            try:
                print ("Move Chip To Tray#{},col#{},row#{}".format(tray_nr, col_nr, row_nr))
                msg = "JumpToTray"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(tray_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(col_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(row_nr).encode())
                self.s.send(b"\r\n")
    
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if msg in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def isChipInTray(self, tray_nr, col_nr, row_nr):
        while True:
            try:
                print ("check if chip is on Tray#{},col#{},row#{}".format(tray_nr, col_nr, row_nr))
                msg = "isChipInTray"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(tray_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(col_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(row_nr).encode())
                self.s.send(b"\r\n")
    
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                try:
                    if int(self.msg) >= 0:
                        return False
                    else:
                        return True
                except ValueError:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def DropToTray(self): #
        while True:
            try:
                msg = "DropToTray"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "DropToTray" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def JumpToSocket(self, DAT_nr, socket_nr):
        while True:
            try:

                print ("Move Chip To DAT#{},Socket{}".format(DAT_nr, socket_nr))
                msg = "JumpToSocket"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(DAT_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(socket_nr).encode())
                self.s.send(b"\r\n")
    
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if msg in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def InsertIntoSocket(self): #
        while True:
            try:
                msg = "InsertIntoSocket"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "InsertIntoSocket" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def ScanTray_Lar(self, rootdir): #
        while True:
            try:
                msg = "ScanTray_Lar"
                self.s.send(msg.encode())
                self.s.send(b"\r\n") 

                self.msg = rootdir
                self.s.send(self.msg.encode())
                self.s.send(b"\r\n")

                rmsg = ''
                while True:
                    self.msg = self.s.recv(1024).decode() 
                    self.msg = self.msg.strip()
                    if "DONE" in self.msg:
                        rmsg += self.msg 
                        rmsg = rmsg.replace('\r', '')
                        rmsg = rmsg.replace('\n', '')
                        with open(rootdir  + "/chips_on_tray.txt", "w") as fp:
                            fp.write(rmsg) 
                        return rmsg  
                    else:
                        if len(self.msg) > 0:
                            rmsg += self.msg 
                        else:
                            time.sleep(0.02)

            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def ScanTray(self, TrayNr, TrayID):
        while True:
            try:
                msg = "ScanTray"
                self.s.send(msg.encode())
                self.s.send(b"\r\n") 

                self.msg = str(TrayNr)
                self.s.send(self.msg.encode())
                self.s.send(b"\r\n")

                self.msg = TrayID
                self.s.send(self.msg.encode())
                self.s.send(b"\r\n")

                rmsg = ''
                while True:
                    self.msg = self.s.recv(1024).decode() 
                    self.msg = self.msg.strip()
                    if "DONE" in self.msg:
                        rmsg += self.msg 
                        rmsg = rmsg.replace('\r', '')
                        rmsg = rmsg.replace('\n', '')
                        # with open(rootdir  + "/chips_on_tray.txt", "w") as fp:
                        #     fp.write(rmsg) 
                        return rmsg
                    else:
                        if len(self.msg) > 0:
                            rmsg += self.msg 
                        else:
                            time.sleep(0.02)

                
            except ConnectionAbortedError:
                print

    def OccupancyChecksOn(self):
       while True:
            try:
                msg = "OccupancyChecksOn"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "OccupancyChecksOn" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def OccupancyChecksOff(self):
       while True:
            try:
                msg = "OccupancyChecksOff"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "OccupancyChecksOff" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2') 

    def CheckTrayOccupancy(self, tray_nr, col_nr, row_nr):
        while True:
            try:
                print ("Get occupancy of Tray#{},col#{},row#{}".format(tray_nr, col_nr, row_nr))
                msg = "CheckTrayOccupancy"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(tray_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(col_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(row_nr).encode())
                self.s.send(b"\r\n")
    
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                try:
                    if int(self.msg) == 0 or int(self.msg) == 1 or int(self.msg) == -2 :
                        return int(self.msg)
                except ValueError:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def CheckSocketOccupancy(self, dat_nr, socket_nr):
        while True:
            try:
                print ("Get occupancy of DAT#{},socket#{},".format(dat_nr, socket_nr))
                msg = "CheckSocketOccupancy"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(dat_nr).encode())
                self.s.send(b"\r\n")
    
                self.s.send(str(socket_nr).encode())
                self.s.send(b"\r\n")

                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                try:
                    if int(self.msg) == 0 or int(self.msg) == 1 or int(self.msg) == -2 :
                        return int(self.msg)
                except ValueError:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')
    
    # do pin analysis 
    def PinAnalysisOn(self):
       while True:
            try:
                msg = "PinAnalysisOn"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "PinAnalysisOn" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')      

    def PinAnalysisOff(self):
       while True:
            try:
                msg = "PinAnalysisOff"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "PinAnalysisOff" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')           

    # Some options for socket placement
    def SocketCorrectionOn(self):
       while True:
            try:
                msg = "SocketCorrectionOn"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "SocketCorrectionOn" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')
    
    def SocketCorrectionOff(self):
       while True:
            try:
                msg = "SocketCorrectionOff"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "SocketCorrectionOff" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def ChipToChipCorrectionOn(self):
       while True:
            try:
                msg = "ChipToChipCorrectionOn"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "ChipToChipCorrectionOn" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def ChipToChipCorrectionOff(self):
       while True:
            try:
                msg = "ChipToChipCorrectionOff"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "ChipToChipCorrectionOff" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2') 

    def DoPlaceAtSocket(self):
       while True:
            try:
                msg = "DoPlaceAtSocket"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "DoPlaceAtSocket" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def DoDropAtSocket(self):
       while True:
            try:
                msg = "DoDropAtSocket"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "DoDropAtSocket" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')
            
    def ClampThenVacuumOffAtSocket(self):
       while True:
            try:
                msg = "ClampThenVacuumOffAtSocket"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "ClampThenVacuumOffAtSocket" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def VacuumOffThenClampAtSocket(self):
       while True:
            try:
                msg = "VacuumOffThenClampAtSocket"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "VacuumOffThenClampAtSocket" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def FastSocketClamping(self):
       while True:
            try:
                msg = "FastSocketClamping"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "FastSocketClamping" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def SoftSocketClamping(self):
       while True:
            try:
                msg = "SoftSocketClamping"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "SoftSocketClamping" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')

    def UseSiteFileRobotConfigOptions(self):
        while True:
            try:
                msg = "UseSiteFileRobotConfigOptions"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")
                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print (self.msg)
                if "UseSiteFileRobotConfigOptions" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')         
    
    def TestRobotConfigOptions(self, select_site):
       while True:
            try:
                print (f"TestRobotConfigOptions {select_site}")
                msg = "TestOptionsFromServer"
                self.s.send(msg.encode())
                self.s.send(b"\r\n")

                self.s.send(str(select_site).encode())
                self.s.send(b"\r\n")

                self.msg = self.s.recv(1024).decode()
                self.msg = self.msg.strip()
                print ("msg: ", self.msg)
                response = int(self.msg)
                if "0" or "1" in self.msg:
                    break
                else:
                    time.sleep(1)
            except ConnectionAbortedError:
                print ("ConnectionAbortedError")
                self.rts_init(port=2001, host_ip='192.168.0.2')