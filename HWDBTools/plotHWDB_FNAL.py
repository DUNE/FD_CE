# Author: Taylor Contreras

# Reads the hwdb logs from RTS QC tests and plots the CD VDDIO

import matplotlib.pyplot as plt
import os
import numpy as np

# Name of all tests saved to hwdb files
tests = [
    "Test Date",
    "Test Time",
    "Test Location",
    "Operator Name",
    "Test 0 Time",
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
    "U2_CD2",
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

def ReadHWDBLog(filename):
    """
    Reads the HWDB text log output by the QC tests, 
    creates a dictionary of the tests and results.
    Inputs:
        filename [str]: name of the hwdb file to read
    Returns:
        data_dict [dict]: dictionary with QC tests names as keys 
                          and results as values.
    """
  
    with open(filename) as f:
        lines = f.read().splitlines()

    data_dict = {}
    #print("Grabbing data:")
    for line in lines:
        line_split = line.split(":")
        data_dict[line_split[0]] = line_split[1]
        #print(f"{line_split[0]}:{line_split[1]}")

    return data_dict

def GetOneTestResults(file_name, test_name):
    """
    Reads the HWDB log, creating a dictionary of outputs
    and returns the value for the given test_name. 
    Returns none if the test_name is not in the file.
    Inputs:
        file_name [str]: name of the file to read
        test_name [str]: name of the desired test in the hwdb log
    """
    data_dict = ReadHWDBLog(file_name)
    if test_name in data_dict.keys():
        return data_dict[test_name]
    return

def PlotCDVDDIO(files):
    """
    Grabs CD VDDIO results from all given files
    and saves to a histogram.
    Inputs: 
        files [list]: List of string of file names
    """
    colors = ['blue', 'orange', 'green', 'red', 'purple', 'pink', 'olive', 'cyan']

    # Grab cd_vddio values from all given hwdb files
    cd_vddio_data = [[],[],[],[],[],[],[], []]
    for file in files:
        if "hwdb" in file:
            for i in range(8):
                cd_vddio_data[i].append(GetOneTestResults(file, f"CD VDDIO (CUR_{i})"))

    # Filter out tests that do not output a value (failed earilier)
    cd_vddio_data_filtered = [[],[],[],[],[],[],[], []]
    for i in range(len(cd_vddio_data)):
        for j in range(len(cd_vddio_data[0])):
            if cd_vddio_data[i][j]:
                cd_vddio_data_filtered[i].append(float(cd_vddio_data[i][j]))

    cd_vddio_data_filtered = np.array(cd_vddio_data_filtered)
    vddio_sigmas = np.std(cd_vddio_data_filtered, axis=1)
    vddio_means = np.mean(cd_vddio_data_filtered, axis=1)

    # Remove outliers for mean/sigma calculation
    outlier_filter = cd_vddio_data_filtered < 100
    vddio_means = []
    vddio_sigmas = []
    for i in range(len(cd_vddio_data_filtered)):
        vddio_means.append(np.mean(cd_vddio_data_filtered[i][outlier_filter[i]]))
        vddio_sigmas.append(np.std(cd_vddio_data_filtered[i][outlier_filter[i]]))

    # Plot the data
    for i in range(len(cd_vddio_data_filtered)):
        plt.hist(cd_vddio_data_filtered[i], range=(0,350), bins=350, color=colors[i])
        plt.xlabel(f"CD VDDIO (CUR_{i})")
        plt.ylabel("Number of QC Tests")
        #plt.show()
        plt.savefig(f"cd_vddio_cur{i}_hist.png")
        plt.close()

    for i in range(len(cd_vddio_data_filtered)):
        plt.hist(cd_vddio_data_filtered[i], label=f"CUR_{i}", range=(0,350), bins=350, alpha=1, color=colors[i])
    plt.xlabel(f"CD VDDIO")
    plt.ylabel("Number of QC Tests")
    plt.legend()
    plt.yscale("log")
    #plt.show()
    plt.savefig(f"cd_vddio_curs_hist.png")
    plt.close()

    for i in range(len(cd_vddio_data_filtered)):
        plt.hist(cd_vddio_data_filtered[i], label=f"CUR_{i}", range=(0,80), bins=80, alpha=1, color=colors[i])
        plt.axvline(vddio_means[i] - 3*vddio_sigmas[i], color=colors[i], linestyle='dashed')
        plt.axvline(vddio_means[i] + 3*vddio_sigmas[i], color=colors[i], linestyle='dashed')
        
        print(f"Cuts for CUR_{i}=({vddio_means[i] - 3*vddio_sigmas[i]:.1f},{vddio_means[i] + 3*vddio_sigmas[i]:.1f})")
    plt.xlabel(f"CD VDDIO")
    plt.ylabel("Number of QC Tests")
    plt.title("Dashed Lines: 3 STD")
    plt.legend()
    #plt.show()
    plt.savefig(f"cd_vddio_curs_hist_zoom.png")
    plt.close()


    return

def PlotPLLLock(files):
    """
    Grabs PLL upper and lower bound results from 
    all given files and saves to a histogram.
    Inputs: 
        files [list]: List of string of file names
    """

    # Grab pll low from all given hwdb files
    pll_low_data = []
    for file in files:
        if "hwdb" in file:
            pll_low_data.append(GetOneTestResults(file, "PLL Lock Range (Lower Bound)"))

    pll_up_data = []
    for file in files:
        if "hwdb" in file:
            pll_up_data.append(GetOneTestResults(file, "PLL Lock Range (Upper Bound)"))

    # Filter out tests that do not output a value (failed earilier)
    pll_low_data_filtered = []
    pll_up_data_filtered = []
    for i in range(len(pll_low_data)):
        if pll_low_data[i] and pll_up_data[i]:
            pll_low_data_filtered.append(float(pll_low_data[i]))
            pll_up_data_filtered.append(float(pll_up_data[i]))
        else:
            print('Invalid entry:', pll_low_data[i], pll_up_data[i])

    # Convert to numpy array for easier manipulation
    pll_low_data_filtered = np.array(pll_low_data_filtered)
    pll_up_data_filtered = np.array(pll_up_data_filtered)

    # Plot the data
    plt.hist(pll_low_data_filtered, bins=13, range=(24,37), label="Lower Bound")
    plt.xlabel("PLL Lock Lower Bound")
    plt.ylabel("Number of QC Tests")
    #plt.show()

    plt.hist(pll_up_data_filtered, bins=7, range=(40,47), label="Upper Bound")
    plt.xlabel("PLL Lock Lower Bound")
    plt.ylabel("Number of QC Tests")

    plt.xticks(np.arange(24, 47, 2.0))
    plt.legend()
    plt.savefig("pll_lock_low_up.png")
    plt.close()

    print(len(pll_low_data_filtered), len(pll_up_data_filtered))

    plt.hist2d(pll_low_data_filtered, pll_up_data_filtered, cmin=1)
    plt.xlabel("PLL Lock Lower Bound")
    plt.ylabel("PLL Lock Upper Bound")
    plt.colorbar(label="Number of QC Tests")
    plt.savefig("pll_lock_low_up_2D.png")
    plt.close()

    plt.hist(pll_up_data_filtered - pll_low_data_filtered, bins=6, range=(12,18))
    plt.ylabel("Number of QC Tests")
    plt.xlabel("PLL Lock Range")
    plt.savefig("pll_lock_range.png")

    print(len(pll_low_data_filtered))

    return

def PassCDVDDIO(test_name, test_result):
    chip_pass = False

    test_result = float(test_result)

    # 3sigma ranges, calculated in HWDBTools/plotHWDB_FNAL.py
    cur_ranges = {"CUR_0": (26.7,35.7), 
                  "CUR_1":(39.1,50.1), 
                  "CUR_2":(36.9,52.3), 
                  "CUR_3":(49.3,64.4), 
                  "CUR_4":(37.0,52.3), 
                  "CUR_5":(49.6,64.2), 
                  "CUR_6":(46.3,67.5), 
                  "CUR_7":(58.9,76.9)}

    cut_range = (None, None)
    for key in cur_ranges.keys():
        if key in test_name:
            cut_range = cur_ranges[key]

    if test_result > cut_range[0] and test_result < cut_range[1]:
        chip_pass = True
    else:
        print(f"---Failed CD VDDIO range ({cur_ranges[key]}): {test_result}")

    return chip_pass

def CountFailedCDVDDIO(filenames):
    """
    Prints various statistics related to the CD VDDIO 
    QC tests for intial and actual failures.
    Inputs:
        filenames [list]: A list of str names of files to loop over
    """

    # Dictionary to hold statistics of each current test and total
    cur_fails = {"CUR_0": 0, 
                 "CUR_1": 0,   
                 "CUR_2": 0,  
                 "CUR_3": 0,  
                 "CUR_4": 0,   
                 "CUR_5": 0,  
                 "CUR_6": 0,   
                 "CUR_7": 0,   
                 "n_curs":[],
                 "prev_fails":0,
                 "new_pass":0}
    
    for file in filenames:
        if "hwdb" in file:
            data_dict = ReadHWDBLog(file)

            # Loop through data to find CD VDDIO tests
            # and check the total number (should be 0 or 8)
            n_curs = 0 # checks that total tests are 0 or 8
            new_fail = False # keeps track of failures for printing purposes
            og_fail = False # keeps track of original CD VDDIO failuires (before 3sigma cuts)

            for key in data_dict.keys():
                if "Power Consumption" in key:
                    if 'fail' in data_dict[key].lower():
                        print("Failure: ", key, data_dict[key]) 
                        if not og_fail:
                            cur_fails["prev_fails"] += 1
                        og_fail = True

                if "CD VDDIO" in key:
                    n_curs += 1
                    this_pass = PassCDVDDIO(key, data_dict[key])

                    # Save num fails for each current setting
                    for cur_key in cur_fails.keys():
                        if cur_key in key:
                            if not this_pass:
                                cur_fails[cur_key] += 1
                                print(f"Failed {cur_key}: {file}")
                                new_fail = True

            cur_fails["n_curs"].append(n_curs)

            if og_fail and not new_fail:
                print("----> Previous Fail is now a Pass")
                cur_fails["new_pass"] += 1
                for key in data_dict.keys():
                    if "CD VDDIO" in key:
                        print(f"-------{key}:{data_dict[key]}")

            if new_fail or og_fail:
                print("") # skip line for clearer terminal printing

    print(cur_fails)
    print("Total chips tested:", len(cur_fails["n_curs"]))

    return

def PassPLLLock(data_dict):
    """
    Determines if a chip passes or fails the PLL Lock test.
    Input:
        data_dict [dict]: dictionary of chip test names and results
    Returns:
        chip_pass [bool]: Pass(True) or Fail (False)
    """

    # Pass/Fail criteria determined based on statistics and 
    # convenience of programming PLL lock ranges
    low_max = 35
    up_min = 39
    width_min = 10
    chip_pass = False

    # Grab upper/lower bounds from dictionary
    lower_bound = -999
    upper_bound = -999
    for key in data_dict.keys():
        if "Lower" in key: 
            lower_bound = int(data_dict[key])
        elif "Upper" in key:
            upper_bound = int(data_dict[key])

    # If upper/lower bounds were found, check pass/fail criteria
    if lower_bound > 0 and upper_bound > 0:
        width = upper_bound - lower_bound
        if width > width_min and lower_bound < low_max and upper_bound > up_min:
            chip_pass = True

    return chip_pass

def CountPassFailPLLLock(filenames):

    nfails = 0
    for file in filenames:
        if "hwdb" in file:
            data_dict = ReadHWDBLog(file)
            chip_pass = PassPLLLock(data_dict)
            if not chip_pass:
                nfails += 1
    print(f"Num PLL Lock failures: {nfails}")

    return

if __name__ == '__main__':

    # Grab all files in the given directory
    getnames = os.popen("ls -d ~/RTS_data/*/*/*")
    filenames = getnames.read().splitlines()

    PlotPLLLock(filenames)
    PlotCDVDDIO(filenames)


