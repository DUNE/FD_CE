############################################################################################
#   created on 6/9/2024 @ 17:13
#   email: radofanantenan.razakamiandra@stonybrook.edu
#   Decode QC_MON.bin
############################################################################################

import numpy as np
import os, sys, pickle
from utils import printItem, createDirs, dumpJson, linear_fit, BaseClass, gain_inl
import matplotlib.pyplot as plt
import json, statistics
from scipy.stats import norm
import pandas as pd

class FE_MON(BaseClass):
    def __init__(self, root_path: str, data_dir: str, output_path: str):
        self.tms = 3
        printItem(item="FE monitoring")
        super().__init__(root_path=root_path, data_dir=data_dir, output_path=output_path, QC_filename='QC_MON.bin', tms=self.tms)
        if self.ERROR:
            return
        self.mon_params = self.params
        # tmpdata_dir = os.listdir('/'.join([root_path, data_dir]))[0]
        # self.qc_filename = "QC_MON.bin"
        # printItem(item="FE monitoring")
        # # read raw data
        # with open('/'.join([root_path, data_dir, tmpdata_dir, self.qc_filename]), 'rb') as f:
        #     self.raw_data = pickle.load(f)
        # # get parameters (keys in the raw_data)
        # self.mon_params = [key for key in self.raw_data.keys() if key!='logs']
        # # get logs
        # self.logs_dict = self.raw_data['logs']
        # createDirs(logs_dict=self.logs_dict, output_dir=output_path)
        # self.FE_outputDIRs = ['/'.join([output_path, self.logs_dict['FE{}'.format(ichip)], 'QC_FE_MON']) for ichip in range(8)]
        # for d in self.FE_outputDIRs:
        #     try:
        #         os.mkdir(d)
        #     except OSError:
        #         pass

    def getBaselines(self):
        '''
        OUTPUT:
        {
            "chipID0": {
                "200mV": [],
                "900mV": []
            },
            "chipID1": {
                "200mV": [],
                "900mV": []
            },
            ...
        }
        '''
        Baselines = ['MON_200BL', 'MON_900BL']
        bl_dict = {
            'MON_200BL': '200mV',
            'MON_900BL': '900mV'
        }
        out_dict = {self.logs_dict['FE{}'.format(ichip)]: dict() for ichip in range(8)}
        for BL in Baselines:
            print("Item : {}".format(BL))
            all_chips_BL = self.raw_data[BL]
            ## organize the raw_data
            ## ==> [[16channels], [16channels], ...] : each element corresponds to the data for each LArASIC
            tmp_data = [[] for _ in range(8)]
            for ich in range(16):
                chdata = all_chips_BL[ich][1]
                for ichip in range(8):
                    tmp_data[ichip].append(chdata[ichip])
            
            ## Save the LArASIC's data to out_dict
            for ichip in range(8):
                FE_ID = self.logs_dict['FE{}'.format(ichip)]
                out_dict[FE_ID][bl_dict[BL]] = tmp_data[ichip]
        return out_dict

    def getvgbr_temp(self, unitOutput='mV'):
        '''
            Structure of the raw data:
                [[8chips], np.array([8chips])]
                ==> 1st element: VBGR, Mon_Temperature, or Mon_VGBR of 8 chips in ADC bit
                ==> 2nd element: VBGR, Mon_Temperature, or Mon_VGBR of 8 chips in mV
            OUTPUT:
            {
                "chipID0": {
                    "unit": unitOutput,
                    "VBGR": val,
                    "MON_Temper": val,
                    "MON_VBGR": val
                },
                "chipID1": {
                    "unit": unitOutput,
                    "VBGR": val,
                    "MON_Temper": val,
                    "MON_VBGR": val
                },
                ...
            }
        '''
        params = ['VBGR', 'MON_Temper', 'MON_VBGR']
        unitChoice = {
            'mV': 1,
            'ADC_bit': 0
        }
        out_dict = {self.logs_dict['FE{}'.format(ichip)]: {'unit': unitOutput} for ichip in range(8)}
        for param in params:
            print("Item : {}".format(param))
            tmp_data = self.raw_data[param][unitChoice[unitOutput]]
            for ichip in range(8):
                FE_ID = self.logs_dict['FE{}'.format(ichip)]
                out_dict[FE_ID][param] = tmp_data[ichip]
        return out_dict

    def mon_dac(self):
        '''
            Output:
             {
                "chipID0":{
                    "config0": {
                        "DAC": [],
                        "data": []
                    },
                    "config1": {
                        "DAC": [],
                        "data": []
                    },
                    ...
                },
                "chipID1":{
                    "config0": {
                        "DAC": [],
                        "data": []
                    },
                    "config1": {
                        "DAC": [],
                        "data": []
                    },
                    ...
                },
                ...
             }
            where len(DAC) = 64
        '''
        # print(self.raw_data)
        tmpout_dict = dict()
        params = [param for param in self.mon_params if 'DAC' in param]
        for param in params:
            print("configuration : {}".format(param))
            data = self.raw_data[param]
            dac_values = []
            dacperchip = [[] for _ in range(8)]
            for idac in range(64):
                dac_val = data[idac][0]
                chipsperDAC = data[idac][1]
                dac_values.append(dac_val)
                for ichip in range(8):
                    dacperchip[ichip].append(chipsperDAC[ichip])
            config = '_'.join( [p for p in param.split('_') if p!='MON'] )    
            tmpout_dict[config] = {"dac_values": dac_values, "all_chipsdata": dacperchip}
        
        OUT_dict = {self.logs_dict['FE{}'.format(ichip)]: dict() for ichip in range(8)}
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            for config in tmpout_dict.keys():
                OUT_dict[FE_ID][config] = {
                    "DAC": tmpout_dict[config]["dac_values"],
                    "data": tmpout_dict[config]["all_chipsdata"][ichip]
                }
        return OUT_dict
    
    def decodeFE_MON(self):
        if self.ERROR:
            return
        logs = {
            "date": self.logs_dict['date'],
            "testsite": self.logs_dict['testsite'],
            "env": self.logs_dict['env'],
            "note": self.logs_dict['note'],
            "DAT_SN": self.logs_dict['DAT_SN'],
            "WIB_slot": self.logs_dict['DAT_on_WIB_slot']
        }
        BL = self.getBaselines()
        vbgr_temp = self.getvgbr_temp(unitOutput='mV')
        dac_meas = self.mon_dac()
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            print(FE_ID)
            dac_meas_chip = dac_meas[FE_ID]
            for config in dac_meas_chip.keys():
                #### In case a linearity range is needed from the monitoring, refer to this line
                AD_LSB = 2564/4096 # LSB in mV / ADC bit
                GAIN, Yintercept, INL = linear_fit(x=dac_meas_chip[config]['DAC'], y=np.array(dac_meas_chip[config]['data'])*AD_LSB) # y here is in mV
                dac_meas_chip[config]['GAIN'] = np.round(GAIN,4)
                dac_meas_chip[config]['unit_of_gain'] = 'mV/bit' # mV / DAC bit
                dac_meas_chip[config]['INL'] = np.round(INL,4)*100
            oneChipData = {
                "logs" : logs,
                "BL": BL[FE_ID],
                "VBGR_Temp": vbgr_temp[FE_ID],
                "DAC_meas": dac_meas_chip
            }

            dumpJson(output_path=self.FE_outputDIRs[FE_ID], output_name='FE_MON', data_to_dump=oneChipData, indent=4)

class QC_FE_MON_Ana():
    def __init__(self, root_path: str, output_path: str, chipID=''):
        self.chipID = chipID
        self.root_path = root_path
        self.output_path = output_path
        self.output_fig = '/'.join([output_path, 'fig'])
        try:
            os.mkdir(self.output_fig)
        except:
            pass

    def _FileExist(self, chipdir: str):
        chipDirExist = os.path.isdir(chipdir)
        qcMondirExist = os.path.isdir('/'.join([chipdir, 'QC_MON']))
        feMonFileExist = os.path.isfile('/'.join([chipdir, 'QC_MON/FE_MON.json']))
        return chipDirExist and qcMondirExist and feMonFileExist
    
    def getItems(self):
        path_to_chipID = '/'.join([self.root_path, self.chipID])
        if not self._FileExist(chipdir=path_to_chipID):
            return None
        path_to_file = '/'.join([path_to_chipID, 'QC_MON/FE_MON.json'])
        data = json.load(open(path_to_file))
        logs = data['logs']
        BL_dict = data['BL']
        BL_dict['CH'] = [ich for ich in range(16)]
        BL_df = pd.DataFrame(BL_dict)
        # print(BL_df)

        DAC_meas_dict = data['DAC_meas']
        DAC_meas_df = pd.DataFrame()
        configs = [c for c in DAC_meas_dict.keys()]
        GAIN_INL_DNL_RANGE = {'CFG': [], 'gain': [], 'worstINL': [], 'worstDNL': [], 'linRange': []}
        for icfg, cfg in enumerate(configs):
            tmp_df = {}
            # print(DAC_meas_dict[cfg])
            keys = [c for c in DAC_meas_dict[cfg].keys() if (c=='DAC') | (c=='data')]
            # print(keys)
            for key in keys:
                tmp_df[key] = DAC_meas_dict[cfg][key]
            tmp_df['CFG'] = [cfg for _ in range(len(tmp_df[keys[0]]))]
            tmp_df = pd.DataFrame(tmp_df)
            # print(tmp_df)
            if icfg==0:
                DAC_meas_df = tmp_df
            else:
                DAC_meas_df = pd.concat([DAC_meas_df, tmp_df], axis=0)
            DAC_list = tmp_df['DAC'] # DAC bit
            data_list = tmp_df['data'] # in mV
            AD_LSB = 2564/4096 # 2564 mV / 2^12 ==> mV / ADC bit
            ## units: gain in DAC bit / mV -- need to convert to mV / DAC bit
            ## worstinl * 100 ==> %
            ## linRange in DAC bit
            gain, yintercept, worstinl, linRange, worstdnl = gain_inl(y=DAC_list, x=data_list*AD_LSB, item='', returnDNL=True)

            # GAIN_INL_DNL_RANGE[cfg] = {'gain': 1/gain, 'worstINL': worstinl*100, 'linRange': np.abs(linRange[1]-linRange[0]), 'worstDNL': worstdnl*100} # gain in mV/ADC bit, worstINL and worstDNL in %, linRange in DAC bit
            GAIN_INL_DNL_RANGE['CFG'].append(cfg)
            GAIN_INL_DNL_RANGE['gain'].append(1/gain)
            GAIN_INL_DNL_RANGE['worstINL'].append(worstinl*100)
            GAIN_INL_DNL_RANGE['worstDNL'].append(worstdnl*100)
            GAIN_INL_DNL_RANGE['linRange'].append(np.abs(linRange[1]-linRange[0]))
            # if np.abs(linRange[1]-linRange[0]) ==7:
            #     plt.figure()
            #     plt.scatter(data_list, DAC_list)
            #     plt.show()
            #     sys.exit()
        # print(DAC_meas_df) 
        # sys.exit()
        GAIN_INL_DNL_RANGE = pd.DataFrame(GAIN_INL_DNL_RANGE)
        # sys.exit()
        
        VBGR_Temp_dict = data['VBGR_Temp']

        # print(VBGR_Temp_dict)
        # sys.exit()
        return {'BL': BL_df, 'VBGR_TEMP': VBGR_Temp_dict, 'GAIN_INL': GAIN_INL_DNL_RANGE}

    def run_Ana(self, path_to_statAna=''):
        # stat_ana_df
        stat_ana_df = pd.read_csv(path_to_statAna)
        print(stat_ana_df)
        sys.exit()
        items = self.getItems()
        if items==None:
            print('NONE')
            return None
        BL = items['BL']
        VBGR_Temp_dict = items['VBGR_TEMP']
        GAIN_INL_df = items['GAIN_INL']
        
        

class QC_FE_MON_StatAna(QC_FE_MON_Ana):
    def __init__(self, root_path: str, output_path: str):
        super().__init__(root_path=root_path, output_path=output_path)

    def getItems(self): ### need to update this function to use the getItems in QC_FE_MON_Ana. It will be easier to read that way and we will have access to more information
        list_chipID = os.listdir(self.root_path)
        out_dict = dict()
        i = 0
        keys = []
        unit_gain = ''
        unit_vbgrtemp = ''
        for chipID in list_chipID:
            path_to_chipID = '/'.join([self.root_path, chipID])
            if not self._FileExist(chipdir=path_to_chipID):
                continue
            path_to_file = '/'.join([path_to_chipID, 'QC_MON/FE_MON.json'])
            data = json.load(open(path_to_file))
            if i==0:
                keys = [k for k in data.keys() if k!='logs']
                for key in keys:
                    out_dict[key] = dict()
                for key in keys:
                    if key != 'DAC_meas':
                        out_dict[key] = {k: np.array([]) for k in data[key].keys() if k!='unit'}
                        subkeys_noDAC = [k for k in data[key].keys() if k!='unit']
                        # get the unit vbgr and temperature
                        if key=='VBGR_Temp':
                            if len(unit_vbgrtemp)==0:
                                unit_vbgrtemp = data[key]['unit']
                        #
                        for subkey in subkeys_noDAC:
                            tmpdata = data[key][subkey]
                            if type(tmpdata)!=str:
                                out_dict[key][subkey] = np.append(out_dict[key][subkey], tmpdata)
                    else:
                        configs = data[key].keys()
                        out_dict[key] = {cfg: dict() for cfg in configs}
                        for cfg in configs:
                            subkeys = [k for k in data[key][cfg].keys() if (k!='data' and k!='DAC' and k!='unit_of_gain')]
                            # get the unit of gain
                            if len(unit_gain)==0:
                                unit_gain = data[key][cfg]['unit_of_gain']
                            out_dict[key][cfg] = {subkey: np.array([]) for subkey in subkeys}
                            for subkey in subkeys:
                                tmpdata = data[key][cfg][subkey]
                                out_dict[key][cfg][subkey] = np.append(out_dict[key][cfg][subkey], tmpdata)
            else:
                for key in keys:
                    if key != 'DAC_meas':
                        subkeys_noDAC = list(out_dict[key].keys())
                        for subkey in subkeys_noDAC:
                            tmpdata = data[key][subkey]
                            if type(tmpdata)!=str:
                                out_dict[key][subkey] = np.append(out_dict[key][subkey], tmpdata)
                    else:
                        configs = out_dict[key].keys()
                        for cfg in configs:
                            subkeys = out_dict[key][cfg].keys()
                            for subkey in subkeys:
                                tmpdata = data[key][cfg][subkey]
                                out_dict[key][cfg][subkey] = np.append(out_dict[key][cfg][subkey], tmpdata)
                # print(out_dict)
                # sys.exit()
            i += 1
        # keys[1] = 'DAC_meas'
        # testSubkey = list(out_dict[keys[1]].keys())[1]
        # print(len(out_dict[keys[1]][testSubkey]))
        # plt.figure()
        # plt.hist(out_dict[keys[1]][testSubkey]['INL'], bins=284)
        # plt.xlabel('_'.join([keys[1], testSubkey]))
        # # plt.xlim([1500, 1575])
        # plt.show()
        return out_dict, unit_gain, unit_vbgrtemp
    
    def run_Ana(self):
        ##############################################################
        print('FE MONITORING Statistical analysis...')
        ##############################################################
        keys = ['BL', 'VBGR_Temp', 'DAC_meas']
        data, unit_gain, unit_vbgrtemp = self.getItems()
        # print(data[keys[0]].keys())
        # print(unit_gain, unit_vbgrtemp)

        items = []
        configurations = []
        means = []
        stdevs = []
        for key in keys:
            # The case of DAC_meas is different because we have the configuration information in that case
            if key!='DAC_meas':
                subkeys = list(data[key].keys())
                for subkey in subkeys:
                    tmpdata = data[key][subkey]
                    median = statistics.median(tmpdata)
                    std = statistics.stdev(tmpdata)
                    xmin, xmax = np.min(tmpdata), np.max(tmpdata)
                    # # make the distribution symmetric
                    # dmean_min = np.abs(median-xmin)
                    # dmean_max = np.abs(median-xmax)
                    # dmin = dmean_min
                    # if dmin > dmean_max:
                    #     dmin = dmean_max
                    # pmins = np.where((np.array(tmpdata)<=dmin-median) | (np.array(tmpdata)>=dmin+median))[0]
                    # tmpdata = np.delete(np.array(tmpdata), pmins)
                    # xmin, xmax = np.min(tmpdata), np.max(tmpdata)
                    # median, std = statistics.median(tmpdata), statistics.stdev(tmpdata)
                    for _ in range(100):
                        if xmin < median-3*std:
                            posMin = np.where(tmpdata==xmin)[0]
                            # del tmpdata[posMin]
                            tmpdata = np.delete(np.array(tmpdata), posMin)
                        if xmax > median+3*std:
                            posMax = np.where(tmpdata==xmax)[0]
                            # del tmpdata[posMax]
                            tmpdata = np.delete(np.array(tmpdata), posMax)

                        xmin, xmax = np.min(tmpdata), np.max(tmpdata)
                        median, std = statistics.median(tmpdata), statistics.stdev(tmpdata)
                    median, std = np.round(median, 4), np.round(std, 4)
                    items.append(key)
                    configurations.append(subkey)
                    means.append(median)
                    stdevs.append(std)
                    x = np.linspace(xmin, xmax, len(tmpdata))
                    p = norm.pdf(x, median, std)
                    plt.figure()
                    Nbins = len(tmpdata)//256
                    unit = ''
                    if key=='VBGR_Temp':
                        unit = unit_vbgrtemp
                        Nbins = len(tmpdata)//16
                    plt.hist(tmpdata, bins=Nbins, density=True)
                    
                    plt.plot(x, p, 'r', label='mean = {} {}, std = {} {}'.format(median, unit, std, unit))
                    plt.xlabel('-'.join([key, subkey]));plt.ylabel('#')
                    # plt.show()
                    plt.legend()
                    plt.savefig('/'.join([self.output_fig, 'QC_FE_MON_{}_{}.png'.format(key, subkey)]))
                    plt.close()
                    # plt.figure()
                    # plt.hist(tmpdata, bins=len(tmpdata)//128)
                    # plt.show()
                    # sys.exit()
            else:
                configs = list(data[key].keys())
                for cfg in configs:
                    subkeys = list(data[key][cfg].keys())
                    for subkey in subkeys:
                        tmpdata = data[key][cfg][subkey]
                        median = statistics.median(tmpdata)
                        std = statistics.stdev(tmpdata)
                        xmin, xmax = np.min(tmpdata), np.max(tmpdata)
                        for _ in range(100):
                            if xmin < median-3*std:
                                posMin = np.where(tmpdata==xmin)[0]
                                # del tmpdata[posMin]
                                tmpdata = np.delete(np.array(tmpdata), posMin)
                            if xmax > median+3*std:
                                posMax = np.where(tmpdata==xmax)[0]
                                # del tmpdata[posMax]
                                tmpdata = np.delete(np.array(tmpdata), posMax)

                            xmin, xmax = np.min(tmpdata), np.max(tmpdata)
                            median, std = statistics.median(tmpdata), statistics.stdev(tmpdata)
                        median, std = np.round(median, 4), np.round(std, 4)

                        items.append(key)
                        configurations.append('-'.join([cfg, subkey]))
                        means.append(median)
                        stdevs.append(std)
                        
                        x = np.linspace(xmin, xmax, len(tmpdata))
                        p = norm.pdf(x, median, std)
                        plt.figure()
                        plt.hist(tmpdata, bins=len(tmpdata)//64, density=True)
                        unit = ''
                        if subkey=='GAIN':
                            unit = unit_gain
                        plt.plot(x, p, 'r', label='mean = {} {}, std = {} {}'.format(median, unit, std, unit))
                        plt.xlabel('-'.join([key, cfg, subkey]));plt.ylabel('#')
                        # plt.show()
                        plt.legend()
                        plt.savefig('/'.join([self.output_fig, 'QC_FE_MON_{}_{}_{}.png'.format(key, cfg, subkey)]))
                        plt.close()
        OUTPUT_DF = pd.DataFrame({'testItem': items, 'cfg': configurations, 'mean': means, 'std': stdevs})
        OUTPUT_DF.to_csv('/'.join([self.output_path, 'StatAna_FE_MON.csv']), index=False)



if __name__ == '__main__':
    # root_path = '../../Data_BNL_CE_WIB_SW_QC'
    output_path = '../../Analyzed_BNL_CE_WIB_SW_QC'

    # list_data_dir = [dir for dir in os.listdir(root_path) if '.zip' not in dir]
    # root_path = '../../B010T0004'
    # root_path='/media/rado/New Volume'
    # parent_dir = ['/'.join([root_path, d]) for d in os.listdir(root_path) if 'B0' in d]
    
    # for p in parent_dir:
    #     # list_data_dir = [dir for dir in os.listdir(root_path) if (os.path.isdir('/'.join([root_path, dir]))) and (dir!='images')]
    #     list_data_dir = [dir for dir in os.listdir(p) if (os.path.isdir('/'.join([p, dir]))) and (dir!='images')]
    #     for data_dir in list_data_dir:
    #         # we expect 13 elements in a folder
    #         subfolder = '/'.join([p, data_dir])
    #         subsubfolder = os.listdir(subfolder)[0]
    #         newsubfolder = '/'.join([subfolder, subsubfolder])
    #         lfiles_testItems = os.listdir(newsubfolder)
    #         if len(lfiles_testItems)==13:
    #             # print(newsubfolder)
    #             # fe_Mon = FE_MON(root_path=root_path, data_dir=data_dir, output_path=output_path)
    #             fe_Mon = FE_MON(root_path=p, data_dir=data_dir, output_path=output_path)
    #             fe_Mon.decodeFE_MON()
    #             sys.exit()
    #         else:
    #             print(len(lfiles_testItems))
    #########
    root_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    output_path = '../../Analysis'
    list_chipID = os.listdir(root_path)
    for chipID in list_chipID:
        ana_femon = QC_FE_MON_Ana(root_path=root_path, output_path=output_path, chipID=chipID)
        ana_femon.run_Ana(path_to_statAna='/'.join([output_path, 'StatAna_FE_MON.csv']))
    # femon_stat = QC_FE_MON_StatAna(root_path=root_path, output_path=output_path)
    # femon_stat.run_Ana()