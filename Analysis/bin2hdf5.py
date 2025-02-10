'''
    Description:
        This script is used to convert the binary data (.bin) to hdf5 format. One output file will
        have the data for 8 ASICs.
        The goal is to only convert the binary file, not decoding it.
    Input:
        - Binary file from the LArASIC QC.
    Output:
        - HDF5 format version of the binary file.
'''

import os, sys
import h5py, pickle
import numpy as np
import matplotlib.pyplot as plt

# from utils import decodeRawData # can be ignored, only used for test

GeneralKeys_inBin = ['WIB_PWR', 'WIB_LINK', 'FE_PWRON', 'ADC_PWRON', 'CD_PWRON'] # not included yet
LogKey = 'logs' # not included yet

def read_bin(filename, path_to_file):
    with open('/'.join([path_to_file, filename]), 'rb') as f:
        data = pickle.load(f)
        return data
    
def write_hdf5(f, data, group_name='/'):
    if group_name!='/':
        grp = f.create_group(group_name)
    else:
        grp = f

    # if type(data)==dict:
    for key,val in data.items():
        # print(key)
        if isinstance(val, dict):
            if key=='rawdata':
                grp_in = grp.create_group(key)
                for ispy_buff, spy_buff_data in val.items():
                    rawdata2grp(rawdata_np_tuple=spy_buff_data, grp=grp_in, dset_name=ispy_buff )
            else:
                write_hdf5(f, val, group_name=f'{group_name}/{key}')
        else:
            if isinstance(val, list):
                val = np.array(val)
            grp.create_dataset(key,data=val)

def get_SpecificKeys(data):
    '''
        This function extracts the keys that are specific to the item being tested during the QC.
    '''
    SpecificKeys_inBin = []
    for key in data.keys():
        if (key not in GeneralKeys_inBin) & (key != LogKey) & (key != 'QCstatus'):
            SpecificKeys_inBin.append(key)
    return SpecificKeys_inBin

def specKeyData2Dict(data, specKeys_list):
    # print(specKeys_list)
    all_data_dict = dict()
    for i, speckey in enumerate(specKeys_list):
        speckeyData = data[speckey]
        fembs = speckeyData[0]
        rawdata = speckeyData[1]
        config = speckeyData[2]
        pwrcons = speckeyData[3]

        # converting the fembs list to numpy array
        fembs_np = np.array(tuple(fembs), dtype=int)

        # converting the rawdata (hex) list to a numpy array where each element is an object type
        all_spybuff = dict()
        N_spybuff = len(rawdata)
        for ispy_buff in range(N_spybuff):
            rawdata_tuple = rawdata2numpy_tuple(rawdata=rawdata, spy_buff=ispy_buff)
            all_spybuff[f'spy_buff{ispy_buff}'] = rawdata_tuple
        
        # converting configurations list (one element) to dictionary
        config_dict = config2dict(config_data=config)

        # converting the power consumptions to numpy array with custom dtype
        new_pwrcons_dict  = {}
        for key, val in pwrcons.items():
            val_np = np.array(tuple(val), dtype=np.dtype([('V', np.float128), ('I', np.float128), ('P', np.float128)]))
            new_pwrcons_dict[key] = val_np
        # new_pwrcons_np = np.array(list(new_pwrcons_dict.items()))
        # print(new_pwrcons_np[0])
        speckeyData_dict = {'fembs': fembs_np, 'pwrcons': new_pwrcons_dict, 'config': config_dict, 'rawdata': all_spybuff}
        # print(f'------{speckey}---{rawdata_tuple}')
        all_data_dict[speckey] = speckeyData_dict
    return all_data_dict

def config2dict(config_data):
    # to maintain the same format as the original data, the output should be a list with just one element which is a tuple with one element
    # cfg_paras_rec.append( (femb_id, copy.deepcopy(self.adcs_paras), copy.deepcopy(self.regs_int8), adac_pls_en, self.cd_sel) )
    # femb_id
    femb_id = config_data[0][0]
    # print(femb_id)
    # adcs_paras
    adcs_paras = config_data[0][1]
    # regs_int8
    regs_int8 = config_data[0][2]
    # adac_pls_en
    adac_pls_en = config_data[0][3]
    # cd_sel
    cd_sel = config_data[0][4]

    out_dict = {'femb_id': femb_id,
                'adc_paras': adcs_paras,
                'regs_int8': regs_int8,
                'adac_pls_en': adac_pls_en,
                'cd_sel': cd_sel}
    return out_dict

def rawdata2numpy_tuple(rawdata, spy_buff=0):
    spy_buff_data = rawdata[spy_buff]
    # Structure of the spy_buff_data
    '''
        It is a tuple with 4 elements:
            a. 1st element: [bytearray, None, None, None, None, None, None]
            b. 2nd, 3rd, 4th elements: 0, 32767, 0 (need to determine what are those values)
        Conversion steps:
            1. Convert the 1st element to a numpy array where 1st element is 
    '''
    out_spy_buff_data = []
    for tmpdata in spy_buff_data:
        if type(tmpdata)==list:
            data = tmpdata
            out_data = []
            for d in data:
                if d==None:
                    out_data.append(np.nan)
                else:
                    out_data.append(np.frombuffer(d, dtype=np.uint8))
            # print(out_data)
            out_spy_buff_data.append(out_data)
        else:
            # print(tmpdata)
            out_spy_buff_data.append(tmpdata)
    return tuple(out_spy_buff_data)

def rawdata2grp(rawdata_np_tuple, grp, dset_name):
    '''
        The raw data to be saved in a group here corresponds to a data for one spy buffer.
        It is a tuple with 4 elements:
            1. 1st element: [[...], [....], None, None, None, None, None, None] The None values are encoded to be np.nan (None doesn't exist in hdf5)
            2. 2nd, 3rd, and 4th elements: 0, 32767, 0
    '''
    grp_in = grp.create_group(dset_name)
    
    # First element - array/None list
    array_list = rawdata_np_tuple[0]
    dt = h5py.special_dtype(vlen=np.uint8)
    dset = grp_in.create_dataset('data_arrays', (len(array_list),), dtype=dt)
    mask = [isinstance(x, np.ndarray) for x in array_list]
    
    for i, item in enumerate(array_list):
        if mask[i]:
            dset[i] = item
    grp_in.create_dataset('data_mask', data=mask)
    
    # Integer values
    grp_in.create_dataset('values', data=list(rawdata_np_tuple[1:]))

################# Conversion back to HEX #############################################################
def hdf5_oneSpyBuff2HEX(hdf5_spy_buffData):
    '''
        We need to convert back to bytearray in order to be able to use the script wib_dec developed before.
    '''
    spy_buff_data = hdf5_spy_buffData
    grp = spy_buff_data
    arrays = grp['data_arrays'][:]
    mask = grp['data_mask'][:]
    array_list = [bytearray(arrays[i].tobytes()) if mask[i] else None for i in range(len(arrays))]
    values = grp['values'][:]
    spy_buff_HEX = (array_list,) + tuple(values)
    return spy_buff_HEX

def hdf5Rawdata2HEX(wholeHDF5data, specKey):
    '''
        Convert the hdf5 data (spy_buffer) to hex
    '''
    hdf5Rawdata = wholeHDF5data[specKey]['rawdata']
    hdf5Rawdata_inHEX = []
    for spy_buff_i, spy_buff_data in hdf5Rawdata.items():
        spy_buff_HEX = hdf5_oneSpyBuff2HEX(hdf5_spy_buffData=spy_buff_data)
        hdf5Rawdata_inHEX.append(spy_buff_HEX)
    return hdf5Rawdata_inHEX
###############################################################################################



## ------------- LOGS ----------------------------------------------------------------------------
# IS NOT USED YET
def getLogs(data, LogKey, path_to_QClog):
    '''
        Retrieve the logs from the test item binary data.
        Match the chip ID in the logs with the timestamp corresponding to each chip (from QC.log).
        RTS_IDs : from the QC.log
        RTS_IDs format: 
            {
                timestamp : (x, y) where x and y are positions of the chip in a tray and in the DAT board respectively.
            }
    '''
    testItemLog = data[LogKey]
    with open(path_to_QClog, 'rb') as f:
        qclog = pickle.load(f)
    rtsIDs = qclog['RTS_IDs']
    rtsIDs_dtype = np.dtype([('timestamp', np.int32), ('posTray', np.int32), ('posDAT', np.int32)])
    rtsIDs_list = [(tmts, pos[0], pos[1]) for tmts, pos in rtsIDs.items()]
    rtsIDs_object = np.array(rtsIDs_list, dtype=rtsIDs_dtype)
##-------------------------------------------------------------------------------------------------

if __name__ == '__main__':
    root_path = '../../B010T0004_/Time_20240703122319_DUT_0000_1001_2002_3003_4004_5005_6006_7007/RT_FE_002010000_002020000_002030000_002040000_002050000_002060000_002070000_002080000'
    binFileName = 'QC_INIT_CHK.bin'
    hdf5_name = binFileName.split('.')[0] + '.hdf5'
    with h5py.File(hdf5_name, 'w') as f:
        # initial test
        data = read_bin(filename=binFileName, path_to_file=root_path)
        speckey_list = get_SpecificKeys(data=data)
        data = specKeyData2Dict(data=data, specKeys_list=speckey_list)
        write_hdf5(f=f, data=data)

    # f = h5py.File(hdf5_name, 'r')
    # raw = hdf5Rawdata2HEX(wholeHDF5data=f, specKey='ASICDAC_47mV_CHK')
    # data = decodeRawData(fembs=[0], rawdata=raw)
    # print(len(data))
    # plt.figure()
    # plt.plot(data[7][0])
    # plt.show()