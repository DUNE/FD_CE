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
        self.item = 'FE_MON'
        self.tms = '03'
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

        # print(VBGR_Temp_dict)
        # sys.exit()
        return {'BL': BL_df, 'VBGR_Temp': VBGR_Temp_dict, 'DAC_meas': GAIN_INL_DNL_RANGE}

    def run_Ana(self, path_to_statAna=''):
        # stat_ana_df
        stat_ana_df = pd.read_csv(path_to_statAna)
        # print(stat_ana_df)
        # sys.exit()
        items = self.getItems()
        if items==None:
            print('NONE')
            return None
        # print(items)
        
        # BL analysis
        BL_data = items['BL']
        stat_BL = stat_ana_df[stat_ana_df['testItem']=='BL'].copy().reset_index().drop('index', axis=1)
        baselines = stat_BL['cfg'].unique()
        # print(baselines)
        for BL in baselines:
            tmp = stat_BL[stat_BL['cfg']==BL].copy().reset_index().drop('index', axis=1)
            mean_stat = tmp['mean'][0]
            std_stat = tmp['std'][0]
            # print(mean_stat, std_stat)
            # sys.exit()
            mean_stat_bl = []
            std_stat_bl = []
            for ich in range(16):
                mean_stat_bl.append(mean_stat)
                std_stat_bl.append(std_stat)
            BL_data['mean_{}'.format(BL)] = mean_stat_bl
            BL_data['std_{}'.format(BL)] = std_stat_bl
        ## QC result for Baseline
        for BL in baselines:
            BL_cols = [c for c in BL_data.columns if BL in c]
            BL_data['QC_result_{}'.format(BL)]= (BL_data[BL]>= (BL_data['mean_{}'.format(BL)]-3*BL_data['std_{}'.format(BL)])) & (BL_data[BL] <= (BL_data['mean_{}'.format(BL)]+3*BL_data['std_{}'.format(BL)]))
            BL_data.drop(['mean_{}'.format(BL), 'std_{}'.format(BL)], axis=1, inplace=True)
        BL_data['CH'] = BL_data['CH'].apply(lambda x: 'CH{}'.format(x))
        # print(BL_data)

        # VBGR_Temp analysis
        VBGR_Temp_data = items['VBGR_Temp']
        stat_vbgr_temp = stat_ana_df[stat_ana_df['testItem']=='VBGR_Temp']
        VBGR_Temp_data_df = pd.DataFrame([VBGR_Temp_data])
        transformed_vbgr_temp = stat_vbgr_temp.pivot(index='testItem', columns='cfg', values=['mean', 'std']).reset_index()
        transformed_vbgr_temp.columns = ['_'.join(col).strip() if col[0]!='testItem' else 'testItem' for col in transformed_vbgr_temp.columns.values]
        # print(transformed_vbgr_temp)
        combined_vbgr_temp = pd.concat([ VBGR_Temp_data_df, transformed_vbgr_temp ], axis=1)
        combined_vbgr_temp.drop(['unit'], axis=1, inplace=True)
        cols = ['VBGR', 'MON_Temper', 'MON_VBGR']
        for col in cols:
            combined_vbgr_temp['QC_result_{}'.format(col)]= (combined_vbgr_temp[col]>= (combined_vbgr_temp['mean_{}'.format(col)]-3*combined_vbgr_temp['std_{}'.format(col)])) & (combined_vbgr_temp[col] <= (combined_vbgr_temp['mean_{}'.format(col)]+3*combined_vbgr_temp['std_{}'.format(col)]))
            combined_vbgr_temp.drop(['mean_{}'.format(col), 'std_{}'.format(col)], axis=1, inplace=True)
        # print(combined_vbgr_temp)

        # DAC_meas analysis
        DAC_meas_data = items['DAC_meas'].copy()
        stat_DAC_meas = stat_ana_df[stat_ana_df['testItem']=='DAC_meas'].copy()
        # print(DAC_meas_data)
        stat_DAC_meas[['CFG', 'feature']] = stat_DAC_meas['cfg'].astype(str).str.split('-', expand=True)
        stat_DAC_meas.drop('cfg', axis=1, inplace=True)
        
        transformed_stat_DAC = stat_DAC_meas.pivot(index='CFG', columns='feature', values=['mean', 'std']).reset_index()
        transformed_stat_DAC.columns = ['_'.join(col).strip() if col[0]!='CFG' else 'CFG' for col in transformed_stat_DAC.columns.values]
        # print(transformed_stat_DAC)
        # print(type(DAC_meas_data))
        merged_DAC_meas = DAC_meas_data.merge(transformed_stat_DAC, on='CFG', how='outer')
        cols = [col for col in merged_DAC_meas.columns if (col!='CFG') & ('mean' not in col) & ('std' not in col)]
        for col in cols:
            merged_DAC_meas['QC_result_{}'.format(col)]= (merged_DAC_meas[col]>= (merged_DAC_meas['mean_{}'.format(col)]-3*merged_DAC_meas['std_{}'.format(col)])) & (merged_DAC_meas[col] <= (merged_DAC_meas['mean_{}'.format(col)]+3*merged_DAC_meas['std_{}'.format(col)]))
            merged_DAC_meas.drop(['mean_{}'.format(col), 'std_{}'.format(col)], axis=1, inplace=True)
        # print(merged_DAC_meas)

        ## Transform dataframes to data tables
        ## Baselines
        BL_tables = []
        for BL in baselines:
            cols = [c for c in BL_data.columns if (c=='CH') | (BL in c)]
            result = 'PASSED'
            if False in BL_data['QC_result_{}'.format(BL)]:
                result = 'FAILED'
            # print(BL_data['CH'].apply(lambda x: 'CH{}'.format(x)))
            oneBL = list(BL_data['CH'].astype(str).str.cat(BL_data[BL].astype(str), sep='=')) # unit here mV, need to ask why is the values 2x higher than the expected ? I think we saw this before
            # tmp_oneBLresult = ','.join([self.item, 'BL_{}'.format(BL), result, ','.join(oneBL)])
            BL_tables.append(['Test_{}_{}'.format(self.tms,self.item), 'BL_{}'.format(BL), result] + oneBL)
        # print(BL_tables)
        
        # VBGR_Temp
        vbgr_temp_tables = []
        cols = ['VBGR', 'MON_Temper', 'MON_VBGR']
        for col in cols:
            result = 'PASSED'
            if False in combined_vbgr_temp['QC_result_{}'.format(col)]:
                result = 'FAILED'
            combined_vbgr_temp[col] = combined_vbgr_temp[col].apply(lambda x: '{}={}'.format(col, x))
            tmp_result = ['Test_{}_{}'.format(self.tms, self.item), combined_vbgr_temp.iloc[0]['testItem'], result, combined_vbgr_temp.iloc[0][col]]
            vbgr_temp_tables.append(tmp_result)
        # print(vbgr_temp_tables)
        
        # DAC_meas
        DAC_meas_table = []
        configurations = merged_DAC_meas['CFG'].unique()
        for cfg in configurations:
            onecfg_data = merged_DAC_meas[merged_DAC_meas['CFG']==cfg].copy()
            qc_res_cols = [c for c in merged_DAC_meas.columns if 'QC_result' in c]
            result = 'PASSED'
            for cc in qc_res_cols:
                if False in onecfg_data[cc]:
                    result = 'FAILED'
                    break

            features = [cc for cc in onecfg_data.columns if ('QC_result' not in cc) & (cc!='CFG')]
            tmp_result = ['Test_{}_{}'.format(self.tms, self.item), cfg, result]
            for feature in features:
                tmp_result.append( '{}={}'.format(feature, onecfg_data.iloc[0][feature]) )
            DAC_meas_table.append(tmp_result)
        output_table = BL_tables + vbgr_temp_tables + DAC_meas_table
        # print(output_table)
        return output_table

class QC_FE_MON_StatAna(QC_FE_MON_Ana):
    def __init__(self, root_path: str, output_path: str):
        super().__init__(root_path=root_path, output_path=output_path)

    def getdata(self):
        list_chipID = os.listdir(self.root_path)
        out_dict = {'BL': pd.DataFrame(), 'VBGR_Temp': dict(), 'DAC_meas': pd.DataFrame()}
        i = 0
        for chipID in list_chipID:
            self.chipID = chipID
            chip_dict = self.getItems()
            if chip_dict==None:
                continue
            # print(chip_dict)
            # sys.exit()
            BL = chip_dict['BL']
            vbgr_temp = chip_dict['VBGR_Temp']
            gain_inl = chip_dict['DAC_meas']
            if i==0:
                # BL_keys = BL.columns
                # for blkey in BL_keys:
                #     out_dict['BL'][blkey] = np.array(BL[blkey])
                out_dict['BL'] = BL.copy()
                VT_keys = [k for k in vbgr_temp.keys() ]

                for k in VT_keys:
                    out_dict['VBGR_Temp'][k] = [vbgr_temp[k]]
                out_dict['DAC_meas'] = gain_inl.copy()
                i = 1
            else:
                # for blkey in BL.columns:
                #     out_dict['BL'][blkey] = np.append(out_dict['BL'][blkey], np.array(BL[blkey]))
                out_dict['BL'] = pd.concat([out_dict['BL'], BL.copy()], axis=0)
                VT_keys = [k for k in vbgr_temp.keys()]
                for k in VT_keys:
                    out_dict['VBGR_Temp'][k].append(vbgr_temp[k])
                out_dict['DAC_meas'] = pd.concat([out_dict['DAC_meas'], gain_inl.copy()], axis=0)
                # break
        # print(out_dict['VBGR_Temp'])
        output_dict = {'BL': out_dict['BL'].reset_index().drop('index', axis=1), 'VBGR_Temp': pd.DataFrame(out_dict['VBGR_Temp']), 'DAC_meas': out_dict['DAC_meas'].reset_index().drop('index', axis=1)}
        return output_dict
    
    def get_mean_std(self, tmpdata):
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
        return median, std

    def run_Ana(self):
        data = self.getdata()

        output_dict = {'testItem': [], 'cfg': [], 'mean': [], 'std': []}
        ## BL analysis
        BL_data = data['BL']
        for BL in ['200mV', '900mV']:
            tmpdata = np.array(BL_data[BL], dtype=float)
            mean, std = self.get_mean_std(tmpdata=tmpdata)
            output_dict['testItem'].append('BL')
            output_dict['cfg'].append(BL)
            output_dict['mean'].append(mean)
            output_dict['std'].append(std)

        ## VBGR_Temp analysis
        VBGR_Temp_data = data['VBGR_Temp']
        keys = [c for c in VBGR_Temp_data.columns if c!='unit']
        for key in keys:
            tmpdata = np.array(VBGR_Temp_data[key], dtype=float)
            mean, std = self.get_mean_std(tmpdata=tmpdata)
            output_dict['testItem'].append('VBGR_Temp')
            output_dict['cfg'].append(key)
            output_dict['mean'].append(mean)
            output_dict['std'].append(std)

        ## GAIN_INL analysis
        GAIN_INL_data = data['DAC_meas']
        configurations = GAIN_INL_data['CFG'].unique()
        for cfg in configurations:
            currentdata = GAIN_INL_data[GAIN_INL_data['CFG']==cfg]
            features = [c for c in currentdata.columns if c!='CFG']
            for feature in features:
                feature_data = np.array(currentdata[feature], dtype=float)
                mean, std = self.get_mean_std(tmpdata=feature_data)
                cfg_feature = '-'.join([cfg, feature])
                output_dict['testItem'].append('DAC_meas')
                output_dict['cfg'].append(cfg_feature)
                output_dict['mean'].append(mean)
                output_dict['std'].append(std)
        OUTPUT_DF = pd.DataFrame(output_dict)
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
    # root_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    # output_path = '../../Analysis'
    root_path = '../../out_B010T0004_'
    output_path = '../../analyzed_B010T0004_'
    # list_chipID = os.listdir(root_path)
    # for chipID in list_chipID:
    #     ana_femon = QC_FE_MON_Ana(root_path=root_path, output_path=output_path, chipID=chipID)
    #     ana_femon.run_Ana(path_to_statAna='/'.join([output_path, 'StatAna_FE_MON.csv']))
    #     sys.exit()
    femon_stat = QC_FE_MON_StatAna(root_path=root_path, output_path=output_path)
    femon_stat.run_Ana()