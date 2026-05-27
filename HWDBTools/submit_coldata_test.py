import datetime
import socket
import os
import os.path
import pwd
import sys
import glob
import subprocess
import array
import dune_ce_hwdb
import argparse

def GetAllTests(test_dir):
    """
    Returns a list of directory names for all tests in the given folder.
    """

    getnames = os.popen(f"ls -d {test_dir}*") 
    filenames = getnames.readlines()
    filenames = [fname.split('\n')[0] for fname in filenames]

    return filenames


def GetTodaysTests(test_dir):
    """
    Returns a list of directories for tests that were run with todays date.

    Input: [str] test_dir: name of directory where all tests are stored
    Returns: [list] todays_tests: list of all tests with todays date in the directory name
    """

    today = datetime.date.today().strftime('%Y%m%d')

    getnames = os.popen(f"ls -d {test_dir}*") 
    filenames = getnames.readlines()
    filenames = [fname.split('\n')[0] for fname in filenames]
    todays_tests = []

    for fname in filenames:
        file_date = fname.split('/')[-1].split('_')[1][:-6]
        print(file_date)
        if today == file_date:
            todays_tests.append(fname)

    print(f'Todays tests: {todays_tests}')

    return todays_tests

def GetLastTest(test_dir):
    """
    Gets the directory of the latest test taken.
    Input: [str] test_dir: name of directory where all tests are stored
    """

    getnames = os.popen(f"ls -d {test_dir}*") 
    filenames = getnames.readlines()
    filenames = [fname.split('\n')[0] for fname in filenames]
    filenames.sort()

    return filenames[-1]

def SubmitCOLDATAtest(username, test_dirs, test_loc="FNAL"):
    """
    Submits COLDATA tests to the hardware database (production or development).

    Inputs:
        [str] username: name of user submitting tests. Must have permission to upload.
        [list] test_dirs: list of strings of directory names, for each tests to be submitted
        [str] test_loc: Locatation where the tests were done, must match the HWDB site name
    """

    # String of test names or test info in COLDATA hwdb files to be submitted
    tests_str = [        
        "Test Date",
        "Test Time",
        "Test Location",
        "Operator Name",
        "Test 0 Time",
        "All Tests",
        "ASICDAC_CALI_CHK",
        "Test 1 Time",
        "CD0_GPIO",
        "CD1_GPIO",
        "SPI_config",
        "FAST_CMD_Reset",
        "Post-Hard_Reset",
        "Post-Soft_Reset",
        "Test 2 Time",
        "U1_Left_CMOS",
        "U1_Left_LVDS",
        "U2_Right_CMOS",
        "U2_Right_LVDS",
        "ADCs_U1_Left_primary",
        "Data_U1_Left_primary",
        "ADCs_U2_Right_primary",
        "Data_U2_Right_primary",
        "Test 3 Time",
        "PC0_BAND_0x20_PLS",
        "PC1_BAND_0x25_PLS",
        "PC2_BAND_0x26_PLS",
        "PC0_BAND_0x20_Power",
        "PC1_BAND_0x25_Power",
        "PC2_BAND_0x26_Power",
        "PC3_LVDS_CUR_0x0_PLS",
        "PC4_LVDS_CUR_0x2_PLS",
        "PC5_LVDS_CUR_0x7_PLS",
        "PC3_LVDS_CUR_0x0_Power",
        "PC4_LVDS_CUR_0x2_Power",
        "PC5_LVDS_CUR_0x7_Power",
        "Test 4 Time",
        "PLL_Locked",
        "Test 5 Time",
        "FC_ACT_rst_adcs",
        "FC_ACT_CLR_SAVES",
        "FC_ACT_SAVE_STATUS",
        "FC_ACT_Pre_EDGE_SYNC",
        "FC_ACT_Post_EDGE_SYNC",
        "FC_ACT_Post_EDGE_SYNC_IDLE",
        "FC_ACT_RST_LARASIC",
        "Test 6 Time",
        "ADC_pattern_LVDS_CUR_0 Pulse Response",
        "ADC_pattern_LVDS_CUR_1 Pulse Response",
        "ADC_pattern_LVDS_CUR_2 Pulse Response",
        "ADC_pattern_LVDS_CUR_3 Pulse Response",
        "ADC_pattern_LVDS_CUR_4 Pulse Response",
        "ADC_pattern_LVDS_CUR_5 Pulse Response",
        "ADC_pattern_LVDS_CUR_6 Pulse Response",
        "ADC_pattern_LVDS_CUR_7 Pulse Response",
        "ADC_pattern_LVDS_CUR_0 Power Consumption",
        "ADC_pattern_LVDS_CUR_1 Power Consumption",
        "ADC_pattern_LVDS_CUR_2 Power Consumption",
        "ADC_pattern_LVDS_CUR_3 Power Consumption",
        "ADC_pattern_LVDS_CUR_4 Power Consumption",
        "ADC_pattern_LVDS_CUR_5 Power Consumption",
        "ADC_pattern_LVDS_CUR_6 Power Consumption",
        "ADC_pattern_LVDS_CUR_7 Power Consumption",
        "Test 7 Time",
        "U1_CD1",
        "U2_CD2",]
    tests_vals = [
        "CD VDDA",
        "CD VDDD",
        "FE VDDA",
        "CD VDDIO (CUR_0)",
        "CD VDDIO (CUR_1)",
        "CD VDDIO (CUR_2)",
        "CD VDDIO (CUR_3)",
        "CD VDDIO (CUR_4)",
        "CD VDDIO (CUR_5)",
        "CD VDDIO (CUR_6)",
        "CD VDDIO (CUR_7)",
        "CD VDDCORE",
        "PLL Lock Range (Lower Bound)",
        "PLL Lock Range (Upper Bound)"
    ]
    tests = tests_str + tests_vals

    # Grab the database type (PROD or DEV)
    db_type = os.environ.get('HWDBSELECT')
    print(f'Submitting to {db_type} database')
    
    # Loop through all tests to be submitted
    for fname in test_dirs:
        filename = os.popen(f"ls -d {fname}/*").readlines()[0].strip('\n')
        print(f'Current file: {filename}')
        datasheet0 = [[None for _ in range(len(tests))] for _ in range(2)]
        datasheet1 = [[None for _ in range(len(tests))] for _ in range(2)]

        for i in range(len(tests)):
            datasheet0[0][i] = tests[i]
            datasheet1[0][i] = tests[i]

        filename = filename.rstrip()
        sn = filename.split("_")
        print(f"File contents: {sn}, len={len(sn)}")
        time = sn[1]
        date = time[0:4]+"/"+time[4:6]+"/"+time[6:8]
        testtime = time[8:10]+":"+time[10:12]
        #print(len(sn[6]))
        serial0 = sn[6][-4:] + "-" + sn[6][0:-4]
        serial1 = sn[7][-4:] + "-" + sn[7][0:-4]
        while len(serial0) < 10:
            serial0 = serial0[0:5] + "0" + serial0[5:]
        while len(serial1) < 10:
            serial1 = serial1[0:5] + "0" + serial1[5:]
        #if(len(sn[6]) == 9):
        #    serial0 = sn[6][5:9] + "-" + sn[6][0:5]
        #    serial1 = sn[7][5:9] + "-" + sn[7][0:5]
        #elif(len(sn[6]) == 8):
        #    serial0 = sn[6][4:8] + "-0" + sn[6][0:4]
        #    serial1 = sn[7][4:8] + "-0" + sn[7][0:4]
        testtype = sn[4][5:8]
        #print (serial0, serial1, testtime, date, testtype)
        testfilename0 = filename+ "/hwdb_CD0.txt"
        testfilename1 = filename+ "/hwdb_CD1.txt" 

        print(f'testfilename: {testfilename0}')
        if os.path.exists(testfilename0): # and time.startswith("20250918") :
            datasheet0[1][0] = date
            datasheet0[1][1] = testtime
            datasheet0[1][2] = test_loc
            datasheet0[1][3] = username
            datasheet1[1][0] = date
            datasheet1[1][1] = testtime
            datasheet1[1][2] = test_loc
            datasheet1[1][3] = username
            
            plotfiles = "ls "+filename+"/*.png"       
            getplotfiles = os.popen(plotfiles)
            filelist = getplotfiles.readlines()
    #        print (testfile)
            
            with open(testfilename0) as f:
                for line in f:
    #                print(line.strip())
                    test = line.strip()
                    #print(test)
                    index = None
                    value = None
                    test2 = test.split(":")
                    if test2[0] in tests:
                        index = tests.index(test2[0])
                        value = test2[1].split(" ")
                        #print(index, value, test2)
                    if index != None and value != None:
                        if test2[0] in tests_str:
                            if len(test2) == 3:
                                datasheet0[1][index] = test2[2].lstrip(' ')
                            elif len(test2) == 4:
                                datasheet0[1][index] = test2[1].lstrip(' ')+ ":" + test2[2] + ":" + test2[3] 
                            else:
                                datasheet0[1][index] = value[1]
                        else:
                            datasheet0[1][index] = value[1]

            
            with open(testfilename1) as f:
                for line in f:
    #                print(line.strip())
                    test = line.strip()
                    #print('tests=',test)
                    index = None
                    value = None
                    test2 = test.split(":")
                    #print(test2, test2[0])
                    if test2[0] in tests:
                        index = tests.index(test2[0])
                        value = test2[1].split(" ")
                    #print(index, value, test2[0])
                    if index != None and value != None:
                        #print(index, test2[0], 'test in tests_str:', [test2[0] in tests_str], 'tests in tests_val', [test2[0] in tests_vals])
                        if test2[0] in tests_str: # tests value is a string
                            if len(test2) == 3:
                                datasheet1[1][index] = test2[2].lstrip(' ')
                            elif len(test2) == 4:
                                datasheet1[1][index] = test2[1].lstrip(' ')+ ":" + test2[2] + ":" + test2[3]
                            else:
                                datasheet1[1][index] = value[1]
                        else:
                            datasheet1[1][index] = value[1]                          
                        
            if (testtype == "rt") or (testtype == "RT"):
                if db_type == "PROD":
                    testname = "RoomT QC Test" 
                elif db_type == "DEV":
                    testname = "QC Test (RoomT)" 
                else:
                    print(f"ERROR: db_type '{db_type}' not recognized")
                
            #print(testtype, testname)
            if(datasheet0[1][len(tests)-1] != None):
                
                for test, result in zip(datasheet1[0],datasheet1[1]):
                    print(test, result)
                    
                print('About to enter item...')

                if db_type == "DEV":
                    manufacturer = 59
                elif db_type == "PROD":
                    manufacturer = 15

                box_arrival_date = "2023-08-10 12:00:00" # when the chips arrived at current site
                dune_ce_hwdb.EnterItemToHWDB("coldata_e4prb2", serial0, test_loc, "US", "", manufacturer, "", box_arrival_date) 
                print('About to enter test...')
                print(serial0, testname, datasheet0)
                dune_ce_hwdb.EnterTestToHWDB("coldata_e4prb2", serial0, testname, "No comment", datasheet0)
                print('About to enter file to test...')
                dune_ce_hwdb.EnterFileToTest("coldata_e4prb2", serial0, testname, datasheet0, filelist)
                
                dune_ce_hwdb.EnterItemToHWDB("coldata_e4prb2", serial1,test_loc, "US", "", manufacturer, "", box_arrival_date)
                dune_ce_hwdb.EnterTestToHWDB("coldata_e4prb2", serial1, testname, "No comment", datasheet1)
                dune_ce_hwdb.EnterFileToTest("coldata_e4prb2", serial1, testname, datasheet1, filelist)
                print('Finished uploading...')

                # Call patch here (if pass or retesting, or if warm and cold testing)
                # TO DO

            else:
                print("ERROR: Failed to load all tests", datasheet0)

    print('Finished!')

if __name__ == '__main__':

    #SubmitCOLDATAtest("tcontrer", test_dir="/mnt/c/Users/ppd-cap-WD-137552/Tested/Time_20260310191936_DUT_1000_2000/", test_loc="FNAL")

    parser = argparse.ArgumentParser()

    parser.add_argument("-u", "--Username", help="Username of tester")
    parser.add_argument("-d", "--Directory", help="Name of results directory")
    parser.add_argument("-l", "--Location", help="Location of RTS")
    parser.add_argument("-t", "--TestType", help="Test type to submit. Options are latest (l), todays tests (t) or all in the directory (a)")
    args = parser.parse_args()

    if args.Username == None:
        print('ERROR: Must supply username')
        exit()

    if args.Directory == None:
        test_dir = "/mnt/c/Users/ppd-cap-WD-137552/Tested/"
        print(f'Running with FNAl specific directory {test_dir}...')
    else:
        test_dir = args.Directory

    if args.Location == None:
        test_loc = "FNAL"
    else:
        test_loc = args.Location
   
    print('Testtype', args.TestType)
    if args.TestType == None or args.TestType == "l":
        test_dirs = [GetLastTest(args.Directory)]
    elif args.TestType == "t":
        test_dirs = GetTodaysTests(test_dir)
    elif args.TestType == "a":
        print('subbmitting all tests')
        test_dirs = GetAllTests(test_dir)
        print(test_dirs)
    else:
        print(f'ERROR: testtype {args.TestType} not recognized.')
        exit()

    SubmitCOLDATAtest(args.Username, test_dirs, test_loc)
