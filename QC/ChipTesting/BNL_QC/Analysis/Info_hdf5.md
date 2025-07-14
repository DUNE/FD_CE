## Binary to HDF5 Converter

## Overview

This script converts binary data files (.bin) from LArASIC QC (Quality Control) to HDF5 format. It's designed to handle data from 8 ASICs in a single output file. The conversion preserves the raw data structure without decoding it.

## Function Descriptions

### `read_bin(filename, path_to_file)`

- **Purpose**: Reads a binary file using pickle
- **Parameters**:
  - `filename`: Name of the binary file
  - `path_to_file`: Directory path containing the file
- **Returns**: Deserialized data from the binary file

### `write_hdf5(f, data, group_name='/')`

- **Purpose**: Writes data to an HDF5 file with hierarchical structure
- **Parameters**:
  - `f`: HDF5 file object
  - `data`: Dictionary containing the data to write
  - `group_name`: HDF5 group path (default: root '/')
- **Process**:
  - Recursively creates groups and datasets in the HDF5 file
  - Handles nested dictionaries by creating corresponding nested groups
  - Creates datasets for non-dictionary values

### `get_allKeys(data)`

- **Purpose**: Extracts and categorizes keys from the input data
- **Returns**: Two lists:
  - `SpecificKeys_inBin`: Keys specific to QC test items
  - `GeneralKeys_inBin`: General configuration and metadata keys
- **Process**: Categorizes keys based on their value types (tuples/lists vs. other types)

### `specKeyData2Dict(data, specKeys_list)`

- **Purpose**: Converts specific key data into a structured dictionary
- **Parameters**:
  - `data`: Input data dictionary
  - `specKeys_list`: List of specific keys to process
- **Returns**: Dictionary containing processed data for each specific key
- **Process**:
  - Converts FEMB data to numpy arrays
  - Processes raw data into spy buffer dictionaries
  - Handles configuration and power consumption data
    - converts power consumption list to numpy array with custom dtype

### `config2dict(config_data)`

- **Purpose**: Converts configuration data into a structured dictionary
- **Parameters**: `config_data`: List containing configuration information
- **Returns**: Dictionary with organized configuration parameters
- **Components**:
  - `femb_id`: FEMB identifier
  - `adc_paras`: ADC parameters
  - `regs_int8`: 8-bit register values
  - `adac_pls_en`: ADAC pulse enable settings
  - `cd_sel`: CD selection parameters

### `rawdata2numpy_dict(rawdata, spy_buff=0)`

- **Purpose**: Converts raw data into numpy arrays and organized dictionaries
- **Parameters**:
  - `rawdata`: Raw data input
  - `spy_buff`: Spy buffer index (default: 0)
- **Returns**: Dictionary containing processed spy buffer data
- **Process**:
  - Converts bytearray data to numpy arrays
  - Organizes buffer data, addresses, and timing information

### `PWRON(pwron_data)`

- **Purpose**: Processes power-on data into structured numpy arrays
- **Parameters**: `pwron_data`: Dictionary containing power measurements
- **Returns**: Dictionary with structured power data
- **Data Structure**: Creates custom numpy dtypes with voltage (V), current (I), and power (P) fields

### `binWithoutRAW2dict(data, FileName='QC_MON.bin')`

- **Purpose**: Converts binary files that don't contain raw data (specifically QC_MON.bin and similar monitoring files) to a structured dictionary format compatible with HDF5
- **Parameters**:
  - `data`: Input data from the binary file (output of the read_bin function)
  - `FileName`: Name of the binary file (default: 'QC_MON.bin'), used to determine processing logic
- **Returns**: Dictionary containing processed data structured for HDF5 conversion
- **Process**:
  - First extracts specific and general keys using the `get_allKeys` function
  - Applies different processing based on file type:
    - For 'MON' files (monitoring data):
      - Creates custom numpy dtype for 8 ASICs (FE0-FE7) with float32 values
      - Specially processes 'VBGR', 'MON_Temper', and 'MON_VBGR' data into structured dictionaries with:
        - 'datas': Raw ADC bit values
        - 'data_v': Values in AD_LSB units (calculated as datas*AD_LSB)
      - Handles 'MON_200BL' and 'MON_900BL' data by creating channel-specific entries (CHN_X) with ASIC measurements
      - Processes DAC-specific data into structured format with DAC_X entries
      - Preserves all general keys unchanged
    - For non-MON files:
      - Filters general keys to include only relevant information (excludes 'QC', 'WIB', 'PC', and 'tms' prefixed keys)
      - Preserves selected general keys with original structure
  - Creates a consistent output dictionary ready for HDF5 storage
- **Data Structures**:
  - Custom dtype for ASICs: `np.dtype([(f'FE{ichip}', np.float32) for ichip in range(8)])`
  - MON data dictionary format: `{'datas': numpy_array, 'data_v': numpy_array}`
  - Baseline/DAC value format: `{f'CHN_{channel_number}': numpy_array}` or `{f'DAC_{dac_number}': numpy_array}`

### `bin2dict(data)`

- **Purpose**: Main conversion function that processes the entire binary data structure
- **Parameters**: `data`: Input binary data
- **Returns**: Fully processed dictionary ready for HDF5 conversion
- **Process**:

  - Separates and processes general and specific keys
  - Handles power-on data specially
  - Combines all processed data into a single dictionary

### Adding an attribute to the data structure

An attribute for each variables in the hdf5 file can be included anywhere in the script. Since the file saves a dictionary  (most of the time dictionaries inside dictionaries), the attribute can be added in a dictionary by giving it the key **"attrs"** and a **dictionary (key: val)** as a value. This new dictionary can be anything you want/need.

**Example:**

```python
new_pwrcons_dict  = {}
for key, val in pwrcons.items():
   val_np = np.array(tuple(val), dtype=np.dtype([('V', np.float32), ('I', np.float32), ('P', np.float32)]))
   new_pwrcons_dict[key] = val_np
new_pwrcons_dict['attrs'] = {'Info': 'Power consumption for each ASIC for each power rail',
                                         'unit_V': 'V',
                                         'unit_I': 'mA',
                                         'unit_P': 'mW'}

```

## Usage Example

```python
root_path = '../../path/to/data'
list_bin_files = os.listdir(root_path)
    for binFileName in list_bin_files:
        hdf5_name = binFileName.split('.')[0] + '.hdf5'
        with h5py.File('/'.join(['HDF5_data_path', hdf5_name]), 'w') as f:
            data = read_bin(filename=binFileName, path_to_file=root_path)
            try:  
                data0 = bin2dict(data=data)
                write_hdf5(f=f, data=data0)
            except:
                data1 = binWithoutRAW2dict(data=data, FileName=binFileName)
                write_hdf5(f=f, data=data1)
```

## How to read the hdf5 file and extract the information we need

The function **read_hdf5** is an example of code reading the hdf5 file 'QC_INIT_CHK.hdf5' and extract the power consumed by one LArASIC for one configuration. It also decode one trigger data and plot the corresponding waveforms.

A function named "wib_dec_onetrigger" was created in the scripts dunedaq.py and spymemory_decode_copy.py in order to decode the trigger data.

```python
import matplotlib.pyplot as plt
def read_HDF5(path_to_file=None):
    with h5py.File(path_to_file, 'r') as hdf:
        data_config0 = hdf['ASICDAC_47mV_CHK']
        #
        # READ POWER CONSUMPTION OF ONE ASIC for one configuration
        pwrcons_VDDA_FE0 = data_config0['pwrcons']['FE0_VDDA']
        print(pwrcons_VDDA_FE0.dtype)
        print(f"P = {pwrcons_VDDA_FE0['P']} mW, I = {pwrcons_VDDA_FE0['I']} mA, V = {pwrcons_VDDA_FE0['V']} V")
        #
        # decode one trigger data
        fembs = data_config0['fembs']
        triggerdata  = data_config0['rawdata']['trigger0']
        decoded_triggerdata = wib_dec_onetrigger(triggerdata=triggerdata, fembs=fembs)
        chresp = decoded_triggerdata[0]
        plt.figure()
        plt.plot(chresp[0])
        plt.show()
```

## Dependencies

- `h5py`: For HDF5 file operations
- `numpy`: For numerical operations and array handling
- `pickle`: For reading binary data

## HDF5 Datastructure

* CHK refers to checkout
* ASICDAC: DAC in the LArASIC
* DATDAC: DAC on the DAT board
* DIRECT_PLS : direct pulse
* ADC_PWRON :
* CD_PWRON :
* FE_PWRON :
* WIB_PWR
* logs:

  * ADC0-7 : serial numbers of the 8 ColdADC
  * CD0, CD1: serial numbers of the 2 COLDATA
  * DAT_SN : DAT serial number
  * DAT_on_WIB_slot: WIB slot used for the DAT
  * DUT : device under test. FE for the current case.
  * FE0-7 : serial numbers of the 8 LArASIC.
  * TrayID : ID number of the Tray from where the chips were picked.
  * date : date of the test.
  * env: environment, RT for Room Temperature; LN for Liquid nitrogen.
  * note : additional note.
  * tester : name of the tester.
  * testsite : test site.
* For the power cycle data, the numbers 0 to 7 refers to the number cycles.
* The keys in QC_PWR, QC_CHKRES, and QC_RMS are information directly from the datasheet.

  * TP refers to Peak Time.
  * The configurable gain 4.7mV/fC is often written as 47mV.
