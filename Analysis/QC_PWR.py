############################################################################################
#   created on 5/28/2024 @ 15:38
#   email: radofanantenan.razakamiandra@stonybrook.edu
#   Analyze the data in QC_PWR.bin
############################################################################################

import datetime
import os, sys, csv
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import json, pickle
from utils import printItem, createDirs, dumpJson, decodeRawData, LArASIC_ana, BaseClass
from utils import BaseClass_Ana

class QC_PWR(BaseClass):
    '''
        Raw data ("QC_PWR.bin") from one DAT board -> 8x decoded data for each LArASIC
    '''
    def __init__(self, root_path: str, data_dir: str, output_dir: str):
        printItem('FE power consumption measurement')
        self.item = "QC_PWR"
        super().__init__(root_path=root_path, data_dir=data_dir, output_path=output_dir, tms=1, QC_filename='QC_PWR.bin')
        if self.ERROR:
            return
        #
        self.param_meanings = {
            'SDF0': 'seBuffOFF',
            'SDF1': 'seBuffON',
            'SNC0': '900mV',
            'SNC1': '200mV',
            'SDD0': 'sedcBufOFF',
            'SDD1': 'sedcBufON'
        }
        self.period = 500

    def isParamInRange(self, paramVal=0, rangeParam=[0, 0]):
        flag = True
        if (paramVal>rangeParam[0]) & (paramVal<rangeParam[1]):
            flag = True
        else:
            flag = False
        return flag

    def getPowerConsumption(self):
        data_by_config = {self.logs_dict['FE{}'.format(ichip)]: {} for ichip in range(8)}
        for param in self.params:
            for KEY_feid in data_by_config.keys():
                data_by_config[KEY_feid][param] = dict()
        
        for param in self.params:
            print('configuration : {}'.format(param))
            data_oneconfig = self.raw_data[param][3]
            for ichip in range(8):
                FE_ID = self.logs_dict['FE{}'.format(ichip)]
                for val in data_oneconfig.keys():
                    if 'FE{}'.format(ichip) in val:
                        keyname = val.split('_')[1]
                        if keyname=="VPPP":
                            keyname = "VDDP"
                        data_by_config[FE_ID][param][keyname] = data_oneconfig[val]
        return data_by_config

    def decode_FE_PWR(self, getWaveforms=True):
        if self.ERROR:
            return
        print('----> Power consumption')
        data_by_config = self.getPowerConsumption()

        pwr_all_chips = dict()
        for ichip in range(8):
            oneChip_data = {
                "V": {"900mV": {}, "200mV": {}, "unit": "V"},
                "I": {"900mV": {}, "200mV": {}, "unit": "mA"},
                "P": {"900mV": {}, "200mV": {}, "unit": "mW"}
            }
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            for param in self.params:
                configs = [conf for conf in param.split('_') if conf!='PWR']
                BL = self.param_meanings[configs[2]]
                outputConfig = '_'.join([self.param_meanings[configs[0]], self.param_meanings[configs[1]]])
                data_config = data_by_config[FE_ID][param]
                V = {}
                I = {}
                P = {}
                for pwr_rail in ['VDDA', 'VDDO', 'VDDP']:
                    V[pwr_rail] = np.round(data_config[pwr_rail][0], 4)
                    I[pwr_rail] = np.round(data_config[pwr_rail][1], 4)
                    P[pwr_rail] = np.round(data_config[pwr_rail][2], 4)
                oneChip_data["V"][self.param_meanings[configs[2]]][outputConfig] = V
                oneChip_data["I"][self.param_meanings[configs[2]]][outputConfig] = I
                oneChip_data["P"][self.param_meanings[configs[2]]][outputConfig] = P

            pwr_all_chips[FE_ID] = oneChip_data

        # update data with the link to the plots and save everything in a json file
        chResponseAllChips = self.analyzeChResponse(getWaveforms=getWaveforms)
        for ichip, chip_id in enumerate(pwr_all_chips.keys()):
            FE_output_dir = self.FE_outputDIRs[chip_id]
           
            tmpdata_onechip = pwr_all_chips[chip_id]
  
            # oneChip_data = {
            #     "logs":{
            #         "date": self.logs_dict['date'],
            #         "testsite": self.logs_dict['testsite'],
            #         "env": self.logs_dict['env'],
            #         "note": self.logs_dict['note'],
            #         "DAT_SN": self.logs_dict['DAT_SN'],
            #         "WIB_slot": self.logs_dict['DAT_on_WIB_slot']
            #     }
            # }
            # logs = self.get_Info_logs()
            # logs['item_name'] = self.item
            # oneChip_data = {
            #     "logs": {key : val for key, val in logs.items()}
            # }
            oneChip_data = {
                'logs' : {
                    "item_name" : self.item,
                    "RTS_timestamp" : self.logs_dict['FE{}'.format(ichip)],
                    'Test Site' : self.logs_dict['testsite'],
                    'RTS_Property_ID' : 'BNL001',
                    'RTS chamber' : 1,
                    'DAT_ID' : self.logs_dict['DAT_SN'],
                    'DAT rev' : self.logs_dict['DAT_Revision'],
                    'Tester' : self.logs_dict['tester'],
                    'DUT' : self.logs_dict['DUT'],
                    'Tray ID' : [d for d in self.input_dir.split('/') if 'B0' in d][0],
                    'SN' : '',
                    'DUT_location_on_tray' : self.logs_dict['position']['on Tray']['FE{}'.format(ichip)],
                    'DUT_location_on_DAT' : self.logs_dict['position']['on DAT']['FE{}'.format(ichip)],
                    'Chip_Mezzanine_1_in_use' : 'ADC_XXX_XXX',
                    'Chip_Mezzanine_2_in_use' : 'CD_XXXX_XXXX',
                    "date": self.logs_dict['date'],
                    "env": self.logs_dict['env'],
                    "note": self.logs_dict['note'],
                    "DAT_SN": self.logs_dict['DAT_SN'],
                    "WIB_slot": self.logs_dict['DAT_on_WIB_slot']
                }
            }
            Baselines = ['200mV', '900mV']
            params = ['V', 'I', 'P']
            params_units = {'V': 'V', 'I': 'mA', 'P': 'mW'}
            configs_out = tmpdata_onechip['V']['900mV'].keys()
            for BL in Baselines:
                for config in configs_out:
                    tmpconfig = '_'.join([BL, config])
                    oneChip_data[tmpconfig] = {}
        
            for BL in Baselines:
                for config in configs_out:
                    tmpconfig = '_'.join([BL, config])
                    oneChip_data[tmpconfig]['CFG_info'] = {}
                    for param in params:
                        oneChip_data[tmpconfig][param] = tmpdata_onechip[param][BL][config]
                    oneChip_data[tmpconfig]['unitPWR'] = params_units
                    oneChip_data[tmpconfig]['pedestal'] = chResponseAllChips[chip_id][tmpconfig]["pedrms"]['pedestal']['data']
                    oneChip_data[tmpconfig]['rms'] = chResponseAllChips[chip_id][tmpconfig]['pedrms']['rms']['data']
                    oneChip_data[tmpconfig]['pospeak'] = chResponseAllChips[chip_id][tmpconfig]['pulseResponse']['pospeak']['data']
                    oneChip_data[tmpconfig]['negpeak'] = chResponseAllChips[chip_id][tmpconfig]['pulseResponse']['negpeak']['data']
            dumpJson(output_path=FE_output_dir, output_name="QC_PWR_data", data_to_dump=oneChip_data)

    def analyzeChResponse(self, getWaveforms=True):
        '''
            For each configuration corresponds a raw data of the channel response. 
            This method aims to analyze the channel response during the power measuremet
        '''
        print('---> Channel Response')
        outdata = {self.logs_dict['FE{}'.format(ichip)]: {} for ichip in range(8)}
        for param in self.params:
            print('configuration : {}'.format(param))
            fembs = self.raw_data[param][0]
            raw_data = self.raw_data[param][1]
            decodedData = decodeRawData(fembs=fembs, rawdata=raw_data, period=self.period)
            ## decodedData is the decoded data for 8 chips
            ## One can use it if a further analysis on the channel response is needed during the power measurement
            for ichip in range(8):
                tmp_config = [c for c in param.split('_') if c!='PWR']
                config = {'SNC': tmp_config[2], "SDD": tmp_config[0], 'SDF': tmp_config[1]} # SNC : baseline 200mV or 900mV
                suffixFilename = '_'.join([self.param_meanings[config['SNC']], self.param_meanings[config['SDD']], self.param_meanings[config['SDF']]])
                # suffixFilename = '_'.join(tmp_config)
                chipID = self.logs_dict['FE{}'.format(ichip)]
                larasic = LArASIC_ana(dataASIC=decodedData[ichip], output_dir=self.FE_outputDIRs[chipID], chipID=chipID, tms=1, param=suffixFilename, generateQCresult=False, generatePlots=True, period=self.period)
                data_asic = larasic.runAnalysis(getWaveforms=getWaveforms, getPulseResponse=True)
                outdata[chipID][suffixFilename] = data_asic
        return outdata

class QC_PWR_analysis(BaseClass_Ana):
    '''
        This class is written to analyze the decoded data for each ASIC.
    '''
    def __init__(self, root_path: str, chipID: str, output_path: str):
        self.item = 'QC_PWR'
        self.tms = '01'
        super().__init__(root_path=root_path, chipID=chipID, item=self.item, output_path=output_path)
        self.output_dir = '/'.join([self.output_dir, self.item])
        try:
            os.mkdir(self.output_dir)
        except OSError:
            pass
        # print(self.params)

    def get_cfg(self, config: str, separateBL=False):
        splitted = config.split('_')
        if separateBL:
            BL = splitted[0]
            cfg = '\n'.join(splitted[1:])
            return BL, cfg
        else:
            cfg = ''
            if 'mV' in splitted[0]:
                cfg = '\n'.join(splitted[1:])
            else:
                cfg = '\n'.join(splitted)
            return cfg
    
    def get_V(self):
        v_vdda_dict = {'data': {}, 'unit': 'V'}
        v_vddo_dict = {'data': {}, 'unit': 'V'}
        v_vddp_dict = {'data': {}, 'unit': 'V'}
        for param in self.params:
            data = self.getoneConfigData(config=param)
            vdda = data['V']['VDDA']
            vddo = data['V']['VDDO']
            vddp = data['V']['VDDP']
            unitV = data['unitPWR']['V']
            v_vdda_dict['data'][param] = vdda
            v_vddo_dict['data'][param] = vddo
            v_vddp_dict['data'][param] = vddp
        return v_vdda_dict, v_vddo_dict, v_vddp_dict

    def get_I(self):
        I_vdda_dict = {'data': {}, 'unit': 'mA'}
        I_vddo_dict = {'data': {}, 'unit': 'mA'}
        I_vddp_dict = {'data': {}, 'unit': 'mA'}
        for param in self.params:
            data = self.getoneConfigData(config=param)
            vdda = data['I']['VDDA']
            vddo = data['I']['VDDO']
            vddp = data['I']['VDDP']
            # print(vddo, vddp)
            unitI = data['unitPWR']['I']
            I_vdda_dict['data'][param] = vdda
            I_vddo_dict['data'][param] = vddo
            I_vddp_dict['data'][param] = vddp
        return I_vdda_dict, I_vddo_dict, I_vddp_dict
    
    def get_P(self):
        P_vdda_dict = {'data': {}, 'unit': 'mW'}
        P_vddo_dict = {'data': {}, 'unit': 'mW'}
        P_vddp_dict = {'data': {}, 'unit': 'mW'}
        P_total_dict = {'data': {}, 'unit': 'mW'}
        for param in self.params:
            data = self.getoneConfigData(config=param)
            vdda = data['P']['VDDA']
            vddo = data['P']['VDDO']
            vddp = data['P']['VDDP']
            unitP = data['unitPWR']['P']
            P_vdda_dict['data'][param] = vdda
            P_vddo_dict['data'][param] = vddo
            P_vddp_dict['data'][param] = vddp
            P_total_dict['data'][param] = vdda + vddo + vddp
        return P_vdda_dict, P_vddo_dict, P_vddp_dict, P_total_dict

    def plot_PWR(self, data_dict_list: list, xlabel: str, ylabel: str, item_to_plot: str):
        colors = [('r', 'm'), ('b', 'black'), ('g', 'y'), ('r', 'gray')]
        plt.figure(figsize=(10, 8))
        i = 0
        for item, data_dict in data_dict_list:
            # print(data_dict['data'].keys())
            # config_list = [self.get_cfg(config=c) for c in list(data_dict['data'].keys())]
            # data = list(data_dict['data'].values())
            # plt.plot(config_list, data, marker='.', markersize=15, label=item)
            BL_200mV = [c for c in data_dict['data'].keys() if '200mV' in c]
            cfg200mV = [self.get_cfg(config=c) for c in BL_200mV]
            BL_900mV = [c for c in data_dict['data'].keys() if '900mV' in c]
            cfg900mV = [self.get_cfg(config=c) for c in BL_900mV]
            data200mV = {c : data_dict['data'][c] for c in BL_200mV}
            data900mV = {c : data_dict['data'][c] for c in BL_900mV}
            plt.plot(cfg200mV, list(data200mV.values()), marker='.', markersize=15, label='{} : BL 200mV'.format(item), color=colors[i][0])
            plt.plot(cfg900mV, list(data900mV.values()), marker='*', markersize=7, label='{} : BL 900mV'.format(item), color=colors[i][1])
            i += 1
        plt.xlabel(xlabel, fontdict={'weight': 'bold'}, loc='right')
        plt.ylabel(ylabel, fontdict={'weight': 'bold'}, loc='top')
        plt.title(item_to_plot)
        plt.legend()
        plt.grid(True)
        plt.savefig('/'.join([self.output_dir, 'PWR_' + item_to_plot + '.png']))
        plt.close()
        # sys.exit()

    def PWR_consumption_ana(self):
        V_vdda, V_vddo, V_vddp = self.get_V()
        I_vdda, I_vddo, I_vddp = self.get_I()
        P_vdda, P_vddo, P_vddp, P_total = self.get_P()
        V_list = [('vdda', V_vdda), ('vddo', V_vddo), ('vddp', V_vddp)]
        I_list = [('vdda', I_vdda), ('vddo', I_vddo), ('vddp', I_vddp)]
        P_list = [('vdda', P_vdda), ('vddo', P_vddo), ('vddp', P_vddp), ('Total Power', P_total)]
        # print(I_list)
        # sys.exit()
        #
        outdata = {'testItem': [], 'cfgs': [], 'cfg_item': [], 'value': []}
        for i in range(len(V_list)):
            Vvdd_cfg = V_list[i][0]
            v_item = 'V (V/LArASIC)'
            Vvdd_meas = V_list[i][1]['data']
            for key, val in Vvdd_meas.items():
                outdata['testItem'].append(v_item)
                outdata['cfgs'].append(key)
                outdata['cfg_item'].append(Vvdd_cfg)
                outdata['value'].append(val)
            #
            Pvdd_cfg = P_list[i][0]
            P_item = 'P (mW/LArASIC)'
            Pvdd_meas = P_list[i][1]['data']
            for key, val in Pvdd_meas.items():
                outdata['testItem'].append(P_item)
                outdata['cfgs'].append(key)
                outdata['cfg_item'].append(Pvdd_cfg)
                outdata['value'].append(val)
            #
            Ivdd_cfg = I_list[i][0]
            I_item = 'I (mA/LArASIC)'
            Ivdd_meas = I_list[i][1]['data']
            for key, val in Ivdd_meas.items():
                outdata['testItem'].append(I_item)
                outdata['cfgs'].append(key)
                outdata['cfg_item'].append(Ivdd_cfg)
                outdata['value'].append(val)
        chresp_dict = {'testItem': [], 'cfgs': [], 'cfg_item': [], 'chn': [], 'value': []}
        for item in ['rms', 'pedestal', 'pospeak', 'negpeak']:
            chres_data = self.ChResp_ana(item=item, returnData=True)
            for config, listval in chres_data.items():
                testItems = ['ChResp' for _ in range(len(listval))]
                cfgs = [config for _ in range(len(listval))]
                cfg_item = [item for _ in range(len(listval))]
                chns = [i for i in range(len(listval))]
                values = listval
                # chresp_dict = {'testItem': testItems, 'cfgs': cfgs, 'cfg_item': cfg_item, 'chn': chns, 'value': values}
                chresp_dict['testItem'] += testItems
                chresp_dict['cfgs'] += cfgs
                chresp_dict['cfg_item'] += cfg_item
                chresp_dict['chn'] += chns
                chresp_dict['value'] += values
        
        chresp_df = pd.DataFrame(chresp_dict)
        pwr_cons_df = pd.DataFrame(outdata)
        pwr_cons_df.to_csv('/'.join([self.output_dir, self.item+'.csv']), index=False)
        # Generate plots
        self.plot_PWR(data_dict_list=V_list, xlabel='Configurations', ylabel='Voltage ({}/LArASIC)'.format(V_vdda['unit']), item_to_plot='Voltage')
        self.plot_PWR(data_dict_list=I_list, xlabel='Configurations', ylabel='Current ({}/LArASIC)'.format(I_vdda['unit']), item_to_plot='Current')
        self.plot_PWR(data_dict_list=P_list, xlabel='Configurations', ylabel='Power ({}/LArASIC)'.format(P_vdda['unit']), item_to_plot='Power')
        # self.plot_PWR(data_dict_list=[('Total power consumption', P_total)], xlabel='Configurations', ylabel='Total power ({})'.format(P_total['unit']), item_to_plot='Total_power_cons')
        return pwr_cons_df, chresp_df
    
    def ChResp_ana(self, item='rms', returnData=True):
        '''
            item could be 'pedestal', 'rms'
        '''
        chipData = {'200mV': {}, '900mV': {}}
        colors = ['r', 'b']
        ylim = []
        if item=='rms':
            ylim = [0, 25]
        elif item=='pedestal':
            ylim = [500, 10000]
        itemData = dict()
        for param in self.params:
            BL, cfg = self.get_cfg(config=param, separateBL=True)
            data = self.getoneConfigData(config=param)
            itemData[param] = data[item]
            if not returnData:
                meanValue, stdValue, minValue, maxValue = self.getCHresp_info(oneChipData=data[item])
                chipData[BL][cfg] = {'mean': meanValue, 'std': stdValue, 'min': minValue, 'max': maxValue}
        if returnData:
            return itemData
        else:
            plt.figure(figsize=(8,7))
            for i, BL in enumerate(['200mV', '900mV']):
                # plt.figure(figsize=(8,7))
                configs = list(chipData[BL].keys())
                for cfg in configs:
                    # mean and std
                    plt.errorbar(x=cfg, y=chipData[BL][cfg]['mean'], yerr=chipData[BL][cfg]['std'], color=colors[i], fmt='.', capsize=4)
                    plt.scatter(x=cfg, y=chipData[BL][cfg]['mean'], color=colors[i], marker='.', s=100)
                    # if item=='negpeak' and BL=='900mV':
                    # min value
                    plt.scatter(x=cfg, y=chipData[BL][cfg]['min'], color=colors[i], marker='.', s=100)
                    # max value
                    plt.scatter(x=cfg, y=chipData[BL][cfg]['max'], color=colors[i], marker='.', s=100)
                meanvalues = [chipData[BL][cfg]['mean'] for cfg in configs]
                plt.plot(configs, meanvalues, color=colors[i], label=BL)
            plt.xlabel('Configurations', loc='right', fontdict={'weight': 'bold'})
            plt.ylabel('{} (ADC bit)'.format(item), loc='top', fontdict={'weight': 'bold'})
            plt.ylim(ylim)
            # plt.title('{} {}'.format(item, BL))
            plt.title('{}'.format(item))
            plt.legend()
            plt.grid(True)
            plt.savefig('/'.join([self.output_dir, 'PWR_{}.png'.format(item)]))
            plt.close()

    def Mean_ChResp_ana(self, BL: str):
        configs = []
        pedestals = []
        pospeaks = []
        negpeaks = []
        stdppeaks, stdnpeaks = [], []
        for param in self.params:
            _BL, cfg = self.get_cfg(config=param, separateBL=True)
            if _BL==BL:
                data = self.getoneConfigData(config=param)
                # items_in_data = ['pedestal', 'rms', 'pospeak', 'negpeak']
                items_in_data = ['pospeak', 'negpeak']
                meanppeak, stdppeak, minppeak, maxppeak = self.getCHresp_info(oneChipData=data['pospeak'])
                meannpeak, stdnpeak, minnpeak, maxnpeak = self.getCHresp_info(oneChipData=data['negpeak'])
                meanpedestal, stdpedestal, minpedestal, maxpedestal = self.getCHresp_info(oneChipData=data['pedestal'])
                configs.append('\n'.join([_BL, cfg]))
                pedestals.append(meanpedestal)
                pospeaks.append(meanppeak)
                negpeaks.append(-meannpeak)
                stdppeaks.append(stdppeak)
                stdnpeaks.append(stdnpeak)

        if BL=='200mV':
            plt.figure(figsize=(8,8))
            # plt.plot(configs, pedestals, 'b.-', label='Pedestal')
            plt.plot(configs, pospeaks, 'r.-', markersize=15, label="Positive peaks")
            plt.ylim([np.mean(pedestals)*2, np.max(pospeaks)+np.mean(pedestals)])
            plt.xlabel("Configurations", loc='right', fontdict={'weight':'bold'})
            plt.ylabel("Amplitude (ADC bit)", loc='top', fontdict={'weight': 'bold'})
            plt.legend()
            plt.title('Pulse Response: Baseline = {}'.format(BL))
            plt.grid(True)
            plt.savefig('/'.join([self.output_dir, '{}_{}_pulseResp.png'.format(self.item_to_ana, BL)]))
            plt.close()
            # sys.exit()
        elif BL=='900mV':
            plt.figure(figsize=(8,8))
            # plt.plot(configs, pedestals, 'b.-', label="Pedestal")
            plt.errorbar(x=configs, y=pospeaks, yerr=stdppeaks, color='r', fmt='.', markersize=5, label='Positive peaks', capsize=4)
            plt.plot(configs, pospeaks, color='black')
            plt.errorbar(x=configs, y=negpeaks, yerr=stdnpeaks, color='g', fmt='.', markersize=5, label='Negative peaks', capsize=4)
            plt.plot(configs, negpeaks)
            plt.axline((0,0), (1,1), color='black', linestyle='--')
            plt.xlabel("Configurations", loc='right', fontdict={'weight':'bold'})
            plt.ylabel("Amplitude (ADC bit)", loc='top', fontdict={'weight': 'bold'})
            plt.legend(loc='right')
            plt.title('Pulse Response : Baseline = {}'.format(BL))
            plt.grid(True)
            plt.savefig('/'.join([self.output_dir, '{}_{}_pulseResp.png'.format(self.item_to_ana, BL)]))
            plt.close()
            # sys.exit()

    def runAnalysis(self, path_to_statAna: str):
        if self.ERROR:
            return

        # peddata = self.ChResp_ana(item='pedestal')
        # print(peddata)
        # sys.exit()
        pwr_df, chresp_df = self.PWR_consumption_ana()
        pwr_stat_ana_df = pd.read_csv(path_to_statAna)

        pwr_item_cond = (pwr_stat_ana_df['testItem']=='I (mA/LArASIC)') | (pwr_stat_ana_df['testItem']=='V (V/LArASIC)') | (pwr_stat_ana_df['testItem']=='P (mW/LArASIC)')
        chresp_cond = pwr_stat_ana_df['testItem']=='ChResp'
        
        chresp_stat_df = pwr_stat_ana_df[chresp_cond].copy().reset_index()
        # print(chresp_stat_df)
        chresp_stat_modified = {'testItem': [], 'cfgs': [], 'cfg_item': [], 'chn' : [], 'mean': [], 'std': [], 'min': [], 'max': []}
        for index in chresp_stat_df.index:
            row = chresp_stat_df.iloc[index]
            for ichn in range(16):
                chresp_stat_modified['testItem'].append(row['testItem'])
                chresp_stat_modified['cfgs'].append(row['cfgs'])
                chresp_stat_modified['cfg_item'].append(row['cfg_item'])
                chresp_stat_modified['chn'].append(ichn)
                chresp_stat_modified['mean'].append(row['mean'])
                chresp_stat_modified['std'].append(row['std'])
                chresp_stat_modified['min'].append(row['min'])
                chresp_stat_modified['max'].append(row['max'])
        # sys.exit()
        # Power consumption
        # print(pwr_stat_ana_df)
        # print(pwr_df)
        pwr_out_df = pd.merge(pwr_stat_ana_df[pwr_item_cond], pwr_df, on=['testItem', 'cfgs', 'cfg_item'], how='outer')
        pwr_out_df['QC_result']= (pwr_out_df['value']> (pwr_out_df['mean']-3*pwr_out_df['std'])) & (pwr_out_df['value'] < (pwr_out_df['mean']+3*pwr_out_df['std']))
        pwr_qc_result = pwr_out_df[['testItem', 'cfgs', 'cfg_item','value', 'QC_result']]
        # Channel response
        chresp_out_df = pd.merge(pd.DataFrame(chresp_stat_modified), chresp_df, on=['testItem', 'cfgs', 'cfg_item', 'chn'], how='outer')
        # print(pd.DataFrame(chresp_stat_modified))
        # print(chresp_df)
        chresp_out_df['QC_result'] = (chresp_out_df['value']> (chresp_out_df['mean']-3*chresp_out_df['std'])) & (chresp_out_df['value'] < (chresp_out_df['mean']+3*chresp_out_df['std']))
        chresp_qc_result = chresp_out_df[['testItem', 'cfgs', 'cfg_item', 'chn', 'value', 'QC_result']]
        # print(chresp_qc_result)
        # sys.exit()
        # print(pwr_qc_result.sort_values(by='cfgs'))
        unique_cfgs = pwr_qc_result['cfgs'].unique()
        results_CFGs = []
        for cfg in unique_cfgs:
            # power
            tmp_pwr_df = pwr_qc_result[pwr_qc_result['cfgs']==cfg]
            tmp_pwr_df = tmp_pwr_df.reset_index().copy()
            # ch resp
            tmp_chresp_df = chresp_qc_result[chresp_qc_result['cfgs']==cfg].copy().reset_index()
            # print(tmp_chresp_df)
            # sys.exit()
            # power
            cfg_qc_pwr_result = ''
            if False in list(tmp_pwr_df['QC_result']):
                cfg_qc_pwr_result = 'FAILED'
            else:
                cfg_qc_pwr_result = 'PASSED'
            # ch resp
            cfg_qc_chresp_result = ''
            if False in list(tmp_chresp_df['QC_result']):
                cfg_qc_chresp_result = 'FAILED'
            else:
                cfg_qc_chresp_result = 'PASSED'

            # power
            pwr_params = []
            for i in range(len(tmp_pwr_df)):
                param = '_'.join([tmp_pwr_df.iloc[i]['cfg_item'], tmp_pwr_df.iloc[i]['testItem'].split(' ')[0] ])
                pwr_params.append('{} = {}'.format(param, tmp_pwr_df.iloc[i]['value']))
            # ch resp
            ch_results = [] # = [(posAmp=, negAmp=, rms=, ped=)]
            for ichn in range(16):
                CH = 'CH{}'.format(ichn)
                posAmp = tmp_chresp_df[(tmp_chresp_df['chn']==ichn) & (tmp_chresp_df['cfg_item']=='pospeak')]['value']
                negAmp = tmp_chresp_df[(tmp_chresp_df['chn']==ichn) & (tmp_chresp_df['cfg_item']=='negpeak')]['value']
                ped = tmp_chresp_df[(tmp_chresp_df['chn']==ichn) & (tmp_chresp_df['cfg_item']=='pedestal')]['value']
                rms = tmp_chresp_df[(tmp_chresp_df['chn']==ichn) & (tmp_chresp_df['cfg_item']=='rms')]['value']
                # print(float(posAmp), float(negAmp), float(ped), float(rms), CH)
                ch_results.append(("{}=(ped={};rms={};posAmp={};negAmp={})".format(CH, ped.iloc[0], rms.iloc[0], posAmp.iloc[0], negAmp.iloc[0])))
            # print(cfg_qc_chresp_result, ch_results)
            # sys.exit()
            # for i in range(len(tmp_chresp_df)):
            #     # param = '_'.join([tmp_chresp_df.iloc[i]['cfg_item'], 'CH{}'.format(tmp_chresp_df.iloc[i]['chn'])])
            #     # print(cfg, param, cfg_qc_chresp_result)
            #     print(tmp_chresp_df.iloc[i])
            #     sys.exit()
            # print(cfg, pwr_params, cfg_qc_pwr_result)
            overall_result = ''
            if 'FAILED' in [cfg_qc_pwr_result, cfg_qc_chresp_result]:
                overall_result = 'FAILED'
            else:
                overall_result = 'PASSED'
            results_CFGs.append(['Test_{}_Power_Consumption'.format(self.tms), cfg, overall_result] + pwr_params + ch_results)
        # print(results_CFGs)
        # print(unique_cfgs)
        with open('/'.join([self.output_dir, '{}_{}.csv'.format(self.item, self.chipID)]), 'w') as csvfile:
            csvwriter = csv.writer(csvfile, delimiter=',')
            csvwriter.writerows(results_CFGs)
        # print(pwr_qc_result)
        # print(self.chipID)
        # sys.exit()
        return results_CFGs, self.data['logs']




from scipy.stats import norm
import statistics
class QC_PWR_StatAna():
    """
        The purpose of this class to statistically analyze the decoded data of the LArASIC tested using the DUNE-DAT board.
        It calls the class QC_PWR_analysis in order to extract the current, voltage, and power for each ASIC from the json files 
        saved by the class QC_PWR.
        *** This analysis cannot tell us whether a chip pass or fail the test. Instead it will generate the acceptance range of
        pass/fail selection during the QC. ***

    """
    def __init__(self, root_path: str, output_path: str):
        self.root_path = root_path
        self.output_path = output_path
        self.output_path_fig = '/'.join([output_path, 'fig'])
        try:
            os.mkdir(self.output_path_fig)
        except:
            pass

    def getItem(self, item='I'):
        unit = ''
        if item=='I':
            unit = 'mA/LArASIC'
        elif item=='P':
            unit = 'mW/LArASIC'
        elif item=='V':
            unit = 'V/LArASIC'
        elif item in ['rms', 'pedestal', 'pospeak', 'negpeak']:
            unit = 'ADC bit'
        
        # unit = 'mA' # this unit may need to be manually changed if the unit the data source is not mA
        I_vdda, I_vddo, I_vddp = [], [], []
        chresp_data = []
        list_chipID = os.listdir(self.root_path)
        for chipID in list_chipID:
            pwr_ana = QC_PWR_analysis(root_path=self.root_path, chipID = chipID, output_path='')
            if pwr_ana.ERROR:
                continue
            tmpI_vdda, tmpI_vddo, tmpI_vddp = dict(), dict(), dict()
            tmp_chresp_data = dict()
            if item=='I':
                tmpI_vdda, tmpI_vddo, tmpI_vddp = pwr_ana.get_I()
            elif item=='V':
                tmpI_vdda, tmpI_vddo, tmpI_vddp = pwr_ana.get_V()
            elif item=='P':
                tmpI_vdda, tmpI_vddo, tmpI_vddp, _ = pwr_ana.get_P()
            elif item in ['rms','pedestal','pospeak','negpeak']:
                tmp_chresp_data = pwr_ana.ChResp_ana(item=item, returnData=True)
            if item in ['I', 'V', 'P']:
                I_vdda.append(tmpI_vdda['data'])
                I_vddo.append(tmpI_vddo['data'])
                I_vddp.append(tmpI_vddp['data'])
            elif item in ['rms', 'pedestal', 'pospeak', 'negpeak']:
                chresp_data.append(tmp_chresp_data)

        # print(I_vdda[0].keys())
        # print(len(list_chipID))
        outdf = pd.DataFrame({'testItem': [], 'cfgs': [], 'cfg_item': [], 'mean': [], 'std': [], 'min': [], 'max': []})
        if item in ['I', 'P', 'V']:
            vdda_allcfg = {k: [] for k in I_vdda[0].keys()}
            vddo_allcfg = {k: [] for k in I_vddo[0].keys()}
            vddp_allcfg = {k: [] for k in I_vddp[0].keys()}
            # print(vdda_allcfg)
            for I in I_vdda:
                for k, v in I.items():
                    vdda_allcfg[k].append(v)
            for I in I_vddo:
                for k, v in I.items():
                    vddo_allcfg[k].append(v)
            for I in I_vddp:
                for k, v in I.items():
                    vddp_allcfg[k].append(v)

            # Analysis of VDDA
            outdata_vdda = {'testItem': [], 'cfgs': [], 'cfg_item': [], 'mean': [], 'std': [], 'min': [], 'max': []}
            for k, v in vdda_allcfg.items():
                # print(k)
                mean, std = statistics.mean(v), statistics.stdev(v)
                # print("MEAN = {}, STD = {}".format(mean, std))
                xmin, xmax = np.min(v), np.max(v)
                # Get rid of values outside of the 3sigma range
                for i in range(50):
                    posMax = np.where(v==xmax)[0]
                    posMin = np.where(v==xmin)[0]
                    if xmax > mean+3*std:
                        del v[posMax[0]]
                        # for j in posMax:
                        #     del v[j]
                    if xmin < mean-3*std:
                        del v[posMin[0]]
                        # for j in posMin:
                        #     del v[j]
                    xmin, xmax = np.min(v), np.max(v)
                    mean, std = statistics.mean(v), statistics.stdev(v) 
                mean, std = np.round(mean, 4), np.round(std, 4)
                xmin, xmax = np.round(xmin, 4), np.round(xmax, 4)
                # print("MEAN = {}, STD = {}".format(mean, std))               
                x = np.linspace(xmin, xmax, len(v))
                p = norm.pdf(x, mean, std)
                plt.figure()
                plt.hist(v, bins=int(len(v)//32), density=True)
                plt.plot(x, p, 'r', label='mean = {}, std = {}'.format(mean, std))
                plt.xlabel('{}_VDDA ({})'.format(item, unit));plt.ylabel('#')
                # plt.show()
                plt.legend()
                plt.savefig('/'.join([self.output_path_fig, 'QC_PWR_{}_{}_vddp.png'.format(k, item)]))
                plt.close()
                # print("{} : Mean = {} mA, STD = {}".format(k, mean, std))
                outdata_vdda['testItem'].append(item + ' ({})'.format(unit))
                outdata_vdda['cfgs'].append(k)
                outdata_vdda['cfg_item'].append('vdda')
                outdata_vdda['mean'].append(mean)
                outdata_vdda['std'].append(std)
                outdata_vdda['min'].append(xmin)
                outdata_vdda['max'].append(xmax)

            # print(outdata_vdda)
            outdata_vdda_df = pd.DataFrame(outdata_vdda)
            # print(outdata_vdda_df)

            # Analysis of VDDO
            outdata_vddo = {'testItem': [], 'cfgs': [], 'cfg_item': [], 'mean': [], 'std': [], 'min': [], 'max': []}
            for k, v in vddo_allcfg.items():
                # print(k)
                mean, std = statistics.mean(v), statistics.stdev(v)
                # print("MEAN = {}, STD = {}".format(mean, std))
                xmin, xmax = np.min(v), np.max(v)
                # Get rid of values outside of the 3sigma range
                for i in range(50):
                    posMax = np.where(v==xmax)[0]
                    posMin = np.where(v==xmin)[0]
                    if xmax > mean+3*std:
                        del v[posMax[0]]
                        # for j in posMax:
                        #     del v[j]
                    if xmin < mean-3*std:
                        del v[posMin[0]]
                        # for j in posMin:
                        #     del v[j]
                    xmin, xmax = np.min(v), np.max(v)
                    mean, std = statistics.mean(v), statistics.stdev(v) 
                mean, std = np.round(mean, 4), np.round(std, 4)
                # print("MEAN = {}, STD = {}".format(mean, std))               
                x = np.linspace(xmin, xmax, len(v))
                p = norm.pdf(x, mean, std)
                plt.figure()
                plt.hist(v, bins=int(len(v)//32), density=True)
                plt.plot(x, p, 'r', label='mean = {}, std = {}'.format(mean, std))
                plt.xlabel('{}_VDDO ({})'.format(item, unit));plt.ylabel('#')
                # plt.show()
                plt.legend()
                plt.savefig('/'.join([self.output_path_fig, 'QC_PWR_{}_{}_vddp.png'.format(k, item)]))
                plt.close()
                # print("{} : Mean = {} mA, STD = {}".format(k, mean, std))
                outdata_vddo['testItem'].append(item + ' ({})'.format(unit))
                outdata_vddo['cfgs'].append(k)
                outdata_vddo['cfg_item'].append('vddo')
                outdata_vddo['mean'].append(mean)
                outdata_vddo['std'].append(std)
                outdata_vddo['min'].append(xmin)
                outdata_vddo['max'].append(xmax)

            # print(outdata_vddo)
            outdata_vddo_df = pd.DataFrame(outdata_vddo)
            # print(outdata_vddo_df)
            
            # Analysis of VDDP
            outdata_vddp = {'testItem': [], 'cfgs': [], 'cfg_item': [], 'mean': [], 'std': [], 'min': [], 'max': []}
            for k, v in vddp_allcfg.items():
                # print(k)
                mean, std = statistics.mean(v), statistics.stdev(v)
                # print("MEAN = {}, STD = {}".format(mean, std))
                xmin, xmax = np.min(v), np.max(v)
                # Get rid of values outside of the 3sigma range
                for i in range(50):
                    if xmax > mean+3*std:
                        posMax = np.where(v==xmax)[0]
                        del v[posMax[0]]
                        # for j in posMax:
                        #     del v[j]
                    if xmin < mean-3*std:
                        posMin = np.where(v==xmin)[0]
                        del v[posMin[0]]
                        # for j in posMin:
                        #     del v[j]
                    xmin, xmax = np.min(v), np.max(v)
                    mean, std = statistics.mean(v), statistics.stdev(v) 
                mean, std = np.round(mean, 4), np.round(std, 4)
                # print("MEAN = {}, STD = {}".format(mean, std))               
                x = np.linspace(xmin, xmax, len(v))
                p = norm.pdf(x, mean, std)
                plt.figure()
                plt.hist(v, bins=int(len(v)//32), density=True)
                plt.plot(x, p, 'r', label='mean = {}, std = {}'.format(mean, std))
                plt.xlabel('{}_VDDP ({})'.format(item, unit));plt.ylabel('#')
                # plt.show()
                plt.legend()
                plt.savefig('/'.join([self.output_path_fig, 'QC_PWR_{}_{}_vddp.png'.format(k, item)]))
                plt.close()
                # print("{} : Mean = {} mA, STD = {}".format(k, mean, std))
                outdata_vddp['testItem'].append(item + ' ({})'.format(unit))
                outdata_vddp['cfgs'].append(k)
                outdata_vddp['cfg_item'].append('vddp')
                outdata_vddp['mean'].append(mean)
                outdata_vddp['std'].append(std)
                outdata_vddp['min'].append(xmin)
                outdata_vddp['max'].append(xmax)

            # print(outdata_vddp)
            outdata_vddp_df = pd.DataFrame(outdata_vddp)
            # print(outdata_vddp_df)

            # CONCATENATE THE DATAFRAMES ALONG THE AXIS=0
            outdf = pd.concat([outdata_vdda_df, outdata_vddo_df, outdata_vddp_df], axis=0, ignore_index=True)
            # print(outdf)
            # SORT THE CONFIGURATION COLUMN SO THAT WE CAN SEE VDDA, VDDO, VDDP ON TOP OF EACH OTHER IN THE DATAFRAME
            # outdf.sort_values(by=['cfgs'], axis=0, inplace=True, ignore_index=True)
        elif item in ['rms', 'pedestal', 'pospeak', 'negpeak']:
            allcfg_itemdata = {k: np.array([]) for k in chresp_data[0].keys()}
            for data in chresp_data:
                for k, v in data.items():
                    allcfg_itemdata[k] = np.concatenate([allcfg_itemdata[k], np.array(v)])
            tmp_out_dict = {'testItem': [], 'cfgs': [], 'cfg_item': [], 'mean': [], 'std': [], 'min': [], 'max': []}
            for k, v in allcfg_itemdata.items():
                # print(k)
                mean, std = statistics.mean(v), statistics.stdev(v)
                # print("MEAN = {}, STD = {}".format(mean, std))
                xmin, xmax = np.min(v), np.max(v)
                v = list(v)
                # Get rid of values outside of the 3sigma range
                for i in range(50):
                    posMax = np.where(v==xmax)[0]
                    posMin = np.where(v==xmin)[0]
                    if xmax > mean+3*std:
                        # print(posMax, type(v))
                        del v[posMax[0]]
                        # for j in posMax:
                        #     del v[j]
                    if xmin < mean-3*std:
                        del v[posMin[0]]
                        # for j in posMin:
                        #     del v[j]
                    xmin, xmax = np.min(v), np.max(v)
                    mean, std = statistics.mean(v), statistics.stdev(v) 
                mean, std = np.round(mean, 4), np.round(std, 4)
                xmin, xmax = np.round(xmin, 4), np.round(xmax, 4)
                # print("MEAN = {}, STD = {}".format(mean, std))               
                x = np.linspace(xmin, xmax, len(v))
                p = norm.pdf(x, mean, std)
                plt.figure()
                plt.hist(v, bins=int(len(v)//32), density=True)
                plt.plot(x, p, 'r', label='mean = {}, std = {}'.format(mean, std))
                plt.xlabel('{} ({})'.format(item, unit));plt.ylabel('#')
                # plt.show()
                plt.legend()
                plt.savefig('/'.join([self.output_path_fig, 'QC_PWR_{}_{}.png'.format(k, item)]))
                plt.close()
                tmp_out_dict['testItem'].append('ChResp')
                tmp_out_dict['cfgs'].append(k)
                tmp_out_dict['cfg_item'].append(item)
                tmp_out_dict['mean'].append(mean)
                tmp_out_dict['std'].append(std)
                tmp_out_dict['min'].append(xmin)
                tmp_out_dict['max'].append(xmax)
            outdf = pd.DataFrame(tmp_out_dict)
        # print(outdf)
        outdf.sort_values(by=['cfg_item'], axis=0, inplace=True, ignore_index=True)
        return outdf

    def run_Ana(self):
        outdf = pd.DataFrame()
        SKIP = False
        # for item in ['I', 'V', 'P']:
        for item in ['I', 'V', 'P', 'rms', 'pedestal', 'pospeak', 'negpeak']:
            df = self.getItem(item=item)
            outdf = pd.concat([df, outdf], axis=0, ignore_index=True)
            # if outdf.shape == (0,0):
            #     SKIP = True
            #     break
            # break
        if not SKIP:
            outdf.to_csv('/'.join([self.output_path, 'StatAnaPWR.csv']), index=False)

if __name__ =='__main__':
    # root_path = '../../Data_BNL_CE_WIB_SW_QC'
    root_path = '../../B010T0004'
    output_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    # # list_data_dir = [dir for dir in os.listdir(root_path) if '.zip' not in dir]
    list_data_dir = [dir for dir in os.listdir(root_path) if (os.path.isdir('/'.join([root_path, dir]))) and (dir!='images')]
    # # qc_selection = json.load(open("qc_selection.json"))
    for data_dir in list_data_dir:
        print(data_dir)
        t0 = datetime.datetime.now()
        print('start time : {}'.format(t0))
        qc_pwr = QC_PWR(root_path=root_path, data_dir=data_dir, output_dir=output_path)
        qc_pwr.decode_FE_PWR()
        print(qc_pwr.logs_dict)
        tf = datetime.datetime.now()
        print('end time : {}'.format(tf))
        deltaT = (tf - t0).total_seconds()
        print("Decoding time : {} seconds".format(deltaT))
        sys.exit()
    # root_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    # output_path = '../../Analysis'
    # list_chipID = os.listdir(root_path)
    # for chipID in list_chipID:
    #     pwr_ana = QC_PWR_analysis(root_path=root_path, chipID=chipID, output_path=output_path)
    #     pwr_ana.runAnalysis(path_to_statAna='/'.join([output_path, 'StatAnaPWR.csv']))
    #     sys.exit()
        # pwr_ana.Mean_ChResp_ana(BL='900mV')
        # sys.exit()
    # pwr_ana_stat = QC_PWR_StatAna(root_path=root_path, output_path=output_path)
    # # pwr_ana_stat.getItem(item='I')
    # pwr_ana_stat.run_Ana()