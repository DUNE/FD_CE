import sqlite3
import time

class RTS_DB():

    dbinstance = None

    def __new__(cls, *args, **kwargs):
        if cls.dbinstance is None:
            cls.insatnce = super().__new__(RTS_DB)
        return cls.instance

    def __init__(self, db_name="rts.db"):
        self.name = db_name
        self.con = sqlite3.connect(db_name)
        self.cur = self.con.cursor()

        self.con.execute("PRAGMA foreign_keys = ON")

    def __del__(self):
        self.cur.close
        self.con.close()

    def connect(self):
        try:
            self.con = sqlite3.connect("rts.db")
        except sqlite3.Error as e:
            pass

    def CreateAllTables(self):
        self.CreateSiteTable(self)
        self.CreateShifterTable(self)
        self.CreateShiftTable(self)
        self.CreateShiftLog(self)
        self.CreateDATtable(self)
        self.CreateDATinfo(self)
        self.CreateTrayTable(self)
        self.CreateTrayHistory(self)
        self.CreateChipTable(self)
        self.CreateChipHistory(self)
        self.CreateTestTable(self)
        self.CreateTestHistory(self)
        self.CreateCryoInfo(self)
        self.CreateRTSinfo(self)
        self.CreateImageTable(self)
        self.CreatePlacementTables(self)

    def CreateSiteTable(self):

        self.cur.execute(f"""CREATE TABLE IF NOT EXISTS sites(
                            db_site_id INTEGER PRIMARY KEY AUTOINCREMENT, 
                            site TEXT, 
                            hwdb_id INTEGER, 
                            contact_shifter_id TEXT,
                            
                            FOREIGN KEY(contact_shifter) REFERENCES shifters(shifter_id));""")

    def AddSite(self, site, hwdb_id, contact):
        # First get the shifter_id or add the contact as a shifter

    def RemoveSite(self):

    def UpdateSite(self):


    # List of users and their emails
    def CreateShifterTable(self):

        self.cur.execute("""CREATE TABLE IF NOT EXISTS shifters(
                            db_shifter_id INTEGER PRIMARY KEY AUTOINCREMENT, 
                            shifter TEXT, 
                            email TEXT, 
                            category TEXT, 
                            db_deleted_at INTEGER, 
                            db_replaced_by INTEGER);""")

    def AddShifter(self):

    def RemoveShifter(self):

    def UpdateShifter(self):


    # list of shifts
    def CreateShiftTable(self):

        self.cur.execute("""CREATE TABLE IF NOT EXISTS shift(
                            db_shift_id INTEGER PRIMARY KEY AUTOINCREMENT,
                            db_shifter_id INTEGER, 
                            start_time INTEGER, 
                            end_time INTEGER, 
                            category TEXT,
                            info TEXT,
                            db_deleted_at INTEGER,
                            db_replaced_by INTEGER,

                            FOREIGN KEY (db_shifter_id) REFERENCES shifters(db_shifter_id));""")

    def AddShift(self):

    def RemoveShift(self):

    def UpdateShift(self):



    # list of shift updates
    ## author is not foreign key as I want freedom for non-shifter to log engtries
    # and I'm not sure if the constraint of the shift itself would impact this?
    def CreateShiftLog(self):

        self.cur.execute("""CREATE TABLE IF NOT EXISTS shift_log(
                            db_shift_log_id INTEGER PRIMARY KEY AUTOINCREMENT,
                            db_shift_id INTEGER,
                            author INTEGER,
                            ts INTEGER,
                            category TEXT,
                            subsystem TEXT,
                            info TEXT,
                            db_deleted_at INTEGER,
                            db_replaced_by INTEGER,
                            
                            FOREIGN KEY (db_shift_id) REFERENCES shifts(db_shift_id));""")

    def AddShiftLogEntry(self):

    def RemoveShiftLogEntry(self):

    def UpdateShiftLogEntry(self):



    def CreateDATtable(self):

        self.cur.execute(f"""CREATE TABLE IF NOT EXISTS dats(
                            db_dat_id INTEGER PRIMARY KEY AUTOINCREMENT, 
                            version TEXT, 
                            serial TEXT, 
                            init_ts INTEGER, 
                            db_site_id INTEGER, 
                            sink INTEGER, 
                            db_deleted_at INTEGER, 
                            db_replaced_by INTEGER,
                            
                            FOREIGN KEY(db_site_id) REFERENCES sites(db_site_id));""")

    def AddDATBoard(self):

    def RemoveDATBoard(self):

    def UpdateDATBoard(self):



    # information relating to the dat board other than test results
    def CreateDATinfo(self):

        self.cur.execute("""CREATE TABLE IF NOT EXISTS dat_info(
                            db_update_id  INTEGER PRIMARY KEY AUTOINCREMENT, 
                            db_dat_id INTEGER, 
                            ts INTEGER, 
                            category TEXT, 
                            info TEXT, 
                            db_deleted_at INTEGER,
                            
                            FOREIGN KEY (db_dat_id) REFERENCES dats(db_dat_id));""")

    def AddDATInfo(self):

    def RemoveDATInfo(self):



    # chips=", ".join(f"chip_{i} TEXT" for i in range(1, 91))

    # list of trays and the chips in them
    # Primary key is combination of tray ID and first timestamp
    # production states if these are production chips or not
    ## Columns
    # db_tray_id - internal reference id for the tray entry in the table
    # tray_id - the alphanumeric tray ID asigned by the user (M000T0000)
    # init_ts - time of entry into table
    # db_deleted_at - time of any soft deletion in case entry is replaced
    # db_replaced_by - index of replacement entry after deletion
    def CreateTrayTable(self):

        self.cur.execute(f"""CREATE TABLE IF NOT EXISTS trays(
                            db_tray_id INTEGER PRIMARY KEY AUTOINCREMENT, 
                            trayid TEXT, 
                            init_ts INTEGER, 
                            production INTEGER,
                            db_deleted_at INTEGER, 
                            db_replaced_by INTEGER);""")

    def Add(self):

    def Remove(self):

    def Update(self):

    # tray history/progression
    ### Columns
    # db_tray_update - internal reference id for the update entry
    # db_tray_id - corresponding id of tray in in trays table
    # update_ts - time of update entry
    # untested - number of untested chips
    # pass - number of chips tested and passed
    # fail - number of chips tested and failed
    # status - overall status of tray (under test/finished/shipped etc)
    # db_deleted_at - only used if we're ignoring some chip tests i.e. during setup
    def CreateTrayHistory(self):

        self.cur.execute("""CREATE TABLE IF NOT EXISTS tray_hist(
                            db_tray_update INTEGER PRIMARY KEY AUTOINCREMENT, 
                            db_tray_id INTEGER, 
                            update_ts INTEGER, 
                            untested INTEGER, 
                            pass INTEGER, 
                            fail INTEGER, 
                            status TEXT, 
                            db_site_id INTEGER,
                            db_deleted_at INTEGER,
                            
                            FOREIGN KEY (db_tray_id) REFERENCES table(db_tray_id),
                            FOREIGN KEY (db_site_id) REFERENCES table(db_site_id)
                            );""")


    def Add(self):
        
    def Remove(self):

    def Update(self):

    # list of all chips and their source tray
    # may not be necessary given the tray table?
    # Alternatively, don't need to list every chip in tray list
    # as it is included here...
    ### columns
    # db_chip_id - internal reference id for the chip
    # chip_id asic_type:version:wafer:serial should be unique
    # source_tray - the tray ID (alpha numeric)
    # tray_position - the position on the tray 1-90
    # init_ts - timestamp of first inclusion in table
    # db_deleted_at - for soft deletion
    # db_replaced_by - id of new entry if soft deleted for new chip entry
    def CreateChipTable(self):

        self.cur.execute("""CREATE TABLE IF NOT EXISTS chips(
                            db_chip_id INTEGER PRIMARY KEY AUTOINCREMENT, 
                            chip_id TEXT, 
                            asic_type TEXT, 
                            version TEXT, 
                            wafer TEXT, 
                            serial TEXT, 
                            source_tray TEXT, 
                            tray_position INTEGER, 
                            init_ts INTEGER, 
                            info TEXT, 
                            db_deleted_at INTEGER, 
                            db_replaced_by INTEGER,
                            
                            FOREIGN KEY (source_tray) REFERENCES trays(db_tray_id));""")


    def Add(self):
        
    def Remove(self):

    def Update(self):

    # list of chip status over time
    ## Columns
    # db_chip_update -unique id for the update in the db
    # db_chip_id - id from chips table
    # update_ts - timstamp of entry
    # current_tray - source or bad tray ID, or DAT board if currently under test
    # current_pos - current position on tray or socket number
    # latest_test_warm - id of latest warm test
    # latest_test_cold - id of latest cold test
    # status - current status (untested/passed/fail/shipped)
    # info - any other info
    # db_deleted_at - for soft deletion
    def CreateChipHistory(self):

        self.cur.execute("""CREATE TABLE IF NOT EXISTS chip_hist(
                            db_chip_update INTEGER PRIMARY KEY AUTOINCREMENT, 
                            db_chip_id INTEGER, 
                            update_ts INTEGER, 
                            current_tray_id INTEGER, 
                            current_dat_id INTEGER, 
                            current_pos INTEGER, 
                            latest_warm INTEGER, 
                            latest_cold INTEGER, 
                            status TEXT, 
                            info TEXT, 
                            db_deleted_at INTEGER,
                            
                            FOREIGN KEY (db_chip_id) REFERENCES chips(db_chip_id),
                            FOREIGN KEY (current_tray_id) REFERENCES trays(db_tray_id),
                            FOREIGN KEY (current_dat_id) REFERENCES dats(db_dat_id));""")


    def Add(self):
        
    def Remove(self):

    def Update(self):

    # list of tests and their info
    ## cols
    # db_test_id - internal reference id for the test
    # testid - external test ID from automation software
    # ts - timestamp of test entry
    # dat - dat serial number 
    def CreateTestTable(self):
        
        self.cur.execute("""CREATE TABLE IF NOT EXISTS tests(
                            db_test_id INTEGER PRIMARY KEY AUTOINCREMENT, 
                            testid TEXT, 
                            ts INTEGER, 
                            db_dat_id INTEGER, 
                            socket INTEGER, 
                            db_chip_id INTEGER, 
                            env TEXT, 
                            category TEXT, 
                            result TEXT, 
                            info TEXT, 
                            db_deleted_at INTEGER, 

                            FOREIGN KEY (db_chip_id) REFERENCES chips(db_chip_id), 
                            FOREIGN KEY (db_dat_id) REFERENCES dats(db_dat_id));""")

    def Add(self):
        
    def Remove(self):

    def Update(self):

    # Robot commands and status/info
    def CreateTestHistory(self):

        self.cur.execute("""CREATE TABLE IF NOT EXISTS robot_info(
                            db_update_id INTEGER PRIMARY KEY AUTOINCREMENT, 
                            ts INTEGER, 
                            category TEXT, 
                            info TEXT, 
                            db_deleted_at INTEGER);""")


    def Add(self):
        
    def Remove(self):

    def Update(self):
        
    # Cryo commands and status/info
    def CreateCryoInfo(self):

        self.cur.execute("""CREATE TABLE IF NOT EXISTS cryo_info(
                            db_update_id INTEGER PRIMARY KEY AUTOINCREMENT, 
                            cryo_no INTEGER, 
                            ts INTEGER, 
                            category TEXT, 
                            info TEXT, 
                            db_deleted_at INTEGER);""")


    def Add(self):
        
    def Remove(self):

    def Update(self):

    # General RTS status and automation/integration
    def CreateRTSinfo(self):

        self.cur.execute("""CREATE TABLE IF NOT EXISTS rts_info(
                            db_update_id INTEGER PRIMARY KEY AUTOINCREMENT, 
                            db_shifter_id INTEGER, 
                            ts INTEGER, 
                            category TEXT, 
                            info TEXT, 
                            db_deleted_at INTEGER);""")


    def Add(self):
        
    def Remove(self):

    def Update(self):

    def CreateImageTable(self):
        self.cur.execute("""CREATE TABLE IF NOT EXISTS images(
                            db_image_id INTEGER PRIMARY KEY AUTOINCREMENT,
                            file TEXT,
                            ts INTEGER,
                            category TEXT,
                            db_chip_id INTEGER,
                            db_dat_id INTEGER,
                            socket INTEGER,
                            db_deleted_at INTEGER,

                            FOREIGN KEY (db_chip_id) REFERENCES chips(db_chip_id),
                            FOREIGN KEY (db_dat_id) REFERENCES dats(db_dat_id));""")


    def Add(self):
        
    def Remove(self):

    def Update(self):

    def CreatePlacementTables(self):
        dats=[1,2]
        sockets=[1,2,3,4,5,6,7,8]
        for d in dats:
            for s in sockets:
                # placements
                self.cur.execute(f"""CREATE TABLE IF NOT EXISTS placement_{d}_{s}()
                                db_place_id INTEGER PRIMARY KEY AUTOINCREMENT, 
                                ts INT, 
                                operation TEXT, 
                                pointx REAL, 
                                pointy REAL, 
                                pointu REAL, 
                                measx REAL, 
                                measy REAL, 
                                measu REAL,
                                sockcorx REAL,
                                sockcory REAL, 
                                sockcoru REAL, 
                                scorposx REAL, 
                                scorposy REAL, 
                                scorposu REAL, 
                                lastchipx REAL, 
                                lastchipy REAL, 
                                lastchipu REAL, 
                                currchipx REAL, 
                                currchipy REAL, 
                                currchipu REAL, 
                                chipcorx REAL, 
                                chipcory REAL, 
                                chipcoru REAL,
                                placex REAL,
                                placey REAL,
                                placeu REAL, 
                                db_deleted_at INTEGER""")

                # alignment measurements 
                self.cur.execute(f"""CREATE TABLE IF NOT EXISTS alignment_{d}_{s}()
                                db_place_id INTEGER PRIMARY KEY AUTOINCREMENT, 
                                ts INT, 
                                operation TEXT, 
                                sockx REAL, 
                                socky REAL, 
                                socku REAL, 
                                chipx REAL, 
                                chipy REAL, 
                                chipu REAL,
                                offx REAL,
                                offy REAL, 
                                offu REAL, 
                                corrx REAL, 
                                corry REAL, 
                                corru REAL, 
                                db_deleted_at INTEGER""")                


    def Add(self):
        
    def Remove(self):

    def Update(self):

             
    # def CreateTable(self):
    #     self.cur.execute("""CREATE TABLE IF NOT EXISTS name(
    #                         db_id INTEGER PRIMARY KEY AUTOINCREMENT,
    #                         field TYPE,
    #                         field2 TYPE,
    #                         db_deleted_at INTEGER,
    #                         db_replaced_by INTEGER,
        
    #                         FOREIGN KEY (key) REFERENCES table(key));""")


    # def Add(self):
        
    # def Remove(self):

    # def Update(self):