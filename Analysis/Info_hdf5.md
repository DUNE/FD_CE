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

### `bin2dict(data)`

- **Purpose**: Main conversion function that processes the entire binary data structure
- **Parameters**: `data`: Input binary data
- **Returns**: Fully processed dictionary ready for HDF5 conversion
- **Process**:
  - Separates and processes general and specific keys
  - Handles power-on data specially
  - Combines all processed data into a single dictionary

## Usage Example

```python
root_path = '../../path/to/data'
binFileName = 'QC_INIT_CHK.bin'
hdf5_name = binFileName.split('.')[0] + '.hdf5'

with h5py.File(f'path/to/{hdf5_name}', 'w') as f:
    data = read_bin(filename=binFileName, path_to_file=root_path)
    data = bin2dict(data=data)
    write_hdf5(f=f, data=data)
```

## Dependencies

- `h5py`: For HDF5 file operations
- `numpy`: For numerical operations and array handling
- `pickle`: For reading binary data

## HDF5 Datastructure

*  CHK refers to checkout

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
