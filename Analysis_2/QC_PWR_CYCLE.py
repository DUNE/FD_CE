############################################################################################
#   created on 6/11/2024 @ 10:53
#   email: radofanantenan.razakamiandra@stonybrook.edu
#   Analyze the data in QC_PWR_CYCLE.bin
############################################################################################

import os, pickle, sys, statistics, pandas as pd, csv
import numpy as np
import matplotlib.pyplot as plt
from utils import createDirs, printItem, decodeRawData, dumpJson, LArASIC_ana, BaseClass
from utils import BaseClass_Ana

class PWR_CYCLE(BaseClass):
    def __init__(self, root_path: str, data_dir: str, output_path: str, env='RT'):
        printItem('FE power cycling')
        self.item = 'QC_PWR_CYCLE'
        super().__init__(root_path=root_path, data_dir=data_dir, output_path=output_path, QC_filename='QC_PWR_CYCLE.bin', tms=4, env=env)
        if self.ERROR:
            return
        self.period = 500

    def decode_pwrCons(self, pwrCons_data: dict):
        out_dict = {self.logs_dict['FE{}'.format(ichip)]: dict() for ichip in range(8)}
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            pwr_rails = ['VDDA', 'VDDO', 'VPPP']
            tmp_out = {'V': dict(), 'I': dict(), 'P': dict()}
            for pwr_rail in pwr_rails:
                key = 'FE{}_{}'.format(ichip, pwr_rail)
                V = np.round(pwrCons_data[key][0], 4)
                I = np.round(pwrCons_data[key][1], 4)
                P = np.round(pwrCons_data[key][2], 4)
                key = pwr_rail
                if pwr_rail=='VPPP':
                    key = 'VDDP'
                tmp_out['V'][key] = V
                tmp_out['I'][key] = I
                tmp_out['P'][key] = P
            out_dict[FE_ID] = tmp_out
        return out_dict

    def decodeWF(self, decoded_wf: list, pwr_cycle_N: str):
        out_dict = {self.logs_dict['FE{}'.format(ichip)]: dict() for ichip in range(8)}
        pwrcycleN = int(pwr_cycle_N.split('_')[1])
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            larasic = LArASIC_ana(dataASIC=decoded_wf[ichip], output_dir=self.FE_outputDIRs[FE_ID], chipID=FE_ID, tms=self.tms, param=pwr_cycle_N, generatePlots=False, generateQCresult=False, period=self.period)
            data_asic = larasic.runAnalysis(pwrcylceN=pwrcycleN)
            tmp_out = {
                'pedestal': data_asic['pedrms']['pedestal']['data'],
                'rms': data_asic['pedrms']['rms']['data'],
                'pospeak': data_asic['pulseResponse']['pospeak']['data'],
                'negpeak': data_asic['pulseResponse']['negpeak']['data']
            }
            out_dict[FE_ID] = tmp_out
        return out_dict
    
    def decode_OnePwrCycle(self, pwr_cycle_N: str):
        # OUTPUT DATA
        PwrCycle_data = {self.logs_dict['FE{}'.format(ichip)]: {pwr_cycle_N: dict()} for ichip in range(8)}
        raw_data = self.raw_data[pwr_cycle_N]
        #
        fembs = raw_data[0] # FEMB list : we use the first slot of WIB only
        rawdata_wf = raw_data[1] # raw data waveform
        config_data = raw_data[2] # configuration : HOW DO WE USE THIS INFORMATION ?
        pwrCons_data = raw_data[3] # power consumption
        #
        pwr = self.decode_pwrCons(pwrCons_data=pwrCons_data)
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            for key in pwr[FE_ID].keys():
                PwrCycle_data[FE_ID][pwr_cycle_N][key] = pwr[FE_ID][key]
        # decoding waveform
        decoded_wf = decodeRawData(fembs=fembs, rawdata=rawdata_wf, period=self.period)
        #
        chResp = self.decodeWF(decoded_wf=decoded_wf, pwr_cycle_N=pwr_cycle_N)
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            for key in chResp[FE_ID].keys():
                PwrCycle_data[FE_ID][pwr_cycle_N][key] = chResp[FE_ID][key]
        return PwrCycle_data
        
    def decode_PwrCycle(self):
        if self.ERROR:
            return
        N_pwrcycle = 8
        PwrCycle_data = {self.logs_dict['FE{}'.format(ichip)]: {} for ichip in range(8)}
        #for ichip in range(8):
        #    PwrCycle_data[self.logs_dict['FE{}'.format(ichip)]]['logs'] = {
        #            "item_name" : self.item,
        #            "RTS_timestamp" : self.logs_dict['FE{}'.format(ichip)],
        #            'Test Site' : self.logs_dict['testsite'],
        #            'RTS_Property_ID' : 'BNL001',
        #            'RTS chamber' : 1,
        #            'DAT_ID' : self.logs_dict['DAT_SN'],
        #            'DAT rev' : self.logs_dict['DAT_Revision'],
        #            'Tester' : self.logs_dict['tester'],
        #            'DUT' : self.logs_dict['DUT'],
        #            # 'Tray ID' : self.logs_dict['TrayID'],
        #            'Tray ID' : '0', #[d for d in self.input_dir.split('/') if 'B0' in d][0],
        #            'SN' : '',
        #            'DUT_location_on_tray' : '0', #self.logs_dict['position']['on Tray']['FE{}'.format(ichip)],
        #            'DUT_location_on_DAT' : '0', #self.logs_dict['position']['on DAT']['FE{}'.format(ichip)],
        #            'Chip_Mezzanine_1_in_use' : 'ADC_XXX_XXX',
        #            'Chip_Mezzanine_2_in_use' : 'CD_XXXX_XXXX',
        #            "date": self.logs_dict['date'],
        #            "env": self.logs_dict['env'],
        #            "note": self.logs_dict['note'],
        #            "DAT_SN": self.logs_dict['DAT_SN'],
        #            "WIB_slot": self.logs_dict['DAT_on_WIB_slot']
        #        }
            # tray_id = [d for d in self.input_dir.split('/') if 'B0' in d][0]
            # print(tray_id)
        # PwrCycle_data = {self.logs_dict['FE{}'.format(ichip)]: {"logs": logs} for ichip in range(8)}
        for ipcycle in range(N_pwrcycle):
            # if ipcycle==4:
            pwr_cycle_N = 'PwrCycle_{}'.format(ipcycle)
            print("Item : {}".format(pwr_cycle_N))
            one_pwrcyc = self.decode_OnePwrCycle(pwr_cycle_N=pwr_cycle_N)
            for FE_ID in one_pwrcyc.keys():
                PwrCycle_data[FE_ID][pwr_cycle_N] = one_pwrcyc[FE_ID][pwr_cycle_N]
        # save data to json file
        FE_IDs = []
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            FE_IDs.append(FE_ID)
            data = PwrCycle_data[FE_ID]
            dumpJson(output_path=self.FE_outputDIRs[FE_ID], output_name='QC_PWR_CYCLE', data_to_dump=data)
        return FE_IDs

class PWR_CYCLE_Ana(BaseClass_Ana):
    '''
        This class is written to analyze the decoded data for each ASIC.
        The name of the function get_IVP(...) means get Current, Voltage, or Power.
    '''
    def __init__(self, root_path: str, chipID: str, output_path: str):
        self.item = 'QC_PWR_CYCLE'
        print (self.item)
        self.tms = '04'
        super().__init__(root_path=root_path, chipID=chipID, output_path=output_path, item=self.item)
        self.root_path = root_path
        self.output_path = output_path
        #self.output_dir = '/'.join([output_path, chipID, self.item])
        #try:
        #    os.makedirs(self.output_dir)
        #except OSError:
        #    pass
        self.units = {'V': 'V', 'I': 'mA', 'P': 'mW'}
    
    def get_IVP(self, param='V', forStat=False):
        if forStat:
            vdda_cycles = np.zeros(len(self.params))
            vddp_cycles = np.zeros(len(self.params))
            vddo_cycles = np.zeros(len(self.params))
            for cycle in self.params:
                Ncycle = int(cycle.split('_')[1])
                vdda_cycles[Ncycle] = self.data[cycle][param]['VDDA']
                vddp_cycles[Ncycle] = self.data[cycle][param]['VDDP']
                vddo_cycles[Ncycle] = self.data[cycle][param]['VDDO']
            return vdda_cycles, vddp_cycles, vddo_cycles
        else:
            # cycles = [[], [], []] for [[VDDA], [VDDP], [VDDO]]
            cycles = [[], [], []]
            Voltages = [[], [], []] # for [[VDDA], [VDDP], [VDDO]]
            for cycle in self.params:
                Ncycle = int(cycle.split('_')[1])
                data = self.data[cycle][param]
                # VDDA
                cycles[0].append(Ncycle)
                Voltages[0].append(data['VDDA'])
                # VDDP
                cycles[1].append(Ncycle)
                Voltages[1].append(data['VDDP'])
                # VDDO
                cycles[2].append(Ncycle)
                Voltages[2].append(data['VDDO'])
            VDDA = {'cycle': cycles[0], param: Voltages[0]}
            VDDP = {'cycle': cycles[1], param: Voltages[1]}
            VDDO = {'cycle': cycles[2], param: Voltages[2]}
            return VDDA, VDDP, VDDO
    
    def get_wfdata(self, item='pedestal', forStat=False):
        if forStat:
            # concatenate the 16-channels data for each cycle and return all of them, grouped by cycle.
            # The distribution will be drawn for each cycle.
            # cycleData = np.zeros(len(self.params))
            # cycleData = np.array([np.array([]) for _ in range(len(self.params))])
            cycleData = [[] for _ in range(8)]
            for cycle in self.params:
                Ncycle = int(cycle.split('_')[1])
                data = np.array(self.data[cycle][item])
                # cycleData[Ncycle] = np.concatenate((cycleData[Ncycle], data))
                cycleData[Ncycle] = data
            return cycleData
        else:
            # Get mean values for each cycle
            # Plot mean values vs. cycle number
            cycle_data = {}
            for cycle in self.params:
                Ncycle = int(cycle.split('_')[1])
                # print(self.data[cycle][item])
                # print(self.data)
                # sys.exit()
                data = np.array(self.data[cycle][item])
                # mean = np.round(np.mean(data), 4)
                # std = np.round(np.std(data), 4)
                # cycle_data[cycle] = {'{}_mean'.format(item): mean, '{}_std'.format(item): std}
                cycle_data[cycle] = {'CH{}'.format(ichn) : data[ichn] for ichn in range(len(data))}
            return cycle_data

    def plot_cycle_vs_item(self, data_dict, item='', vdd_cfg=''):
        plt.figure()
        plt.plot(data_dict['cycle'], data_dict[item], '--.', markersize=10)
        plt.xlabel('Cycle')
        plt.ylabel(item + ' ({})'.format(self.units[item]))
        plt.savefig('/'.join([self.output_path, self.item + '_' + item +'_{}.png'.format(vdd_cfg)]))
        plt.close()

    def create_dfItem_PWR(self, param='V', generatePlots=False):
        vdda, vddp, vddo = self.get_IVP(param=param, forStat=False)
        if generatePlots:
            self.plot_cycle_vs_item(data_dict=vdda, item=param, vdd_cfg='VDDA')
            self.plot_cycle_vs_item(data_dict=vddo, item=param, vdd_cfg='VDDO')
            self.plot_cycle_vs_item(data_dict=vddp, item=param, vdd_cfg='VDDP')
        out_dict = {'testItem': [], 'Cycle': [], 'vdd_cfgs': [], 'value': []}
        key_val = {'VDDA': vdda, 'VDDO': vddo, 'VDDP': vddp}
        for key, val in key_val.items():
            data = val
            for icycle in data['cycle']:
                out_dict['testItem'].append(param)# +' ({})'.format(self.units[param]))
                out_dict['Cycle'].append(icycle)
                out_dict['vdd_cfgs'].append(key)
                out_dict['value'].append(data[param][icycle])
        out_df = pd.DataFrame(out_dict)
        return out_df
    
    def create_dfItem_wf(self, param='pedestal'):
        data_wf = self.get_wfdata(item=param, forStat=False)
        out_dict = {'testItem': [], 'Cycle': [], 'vdd_cfgs' : [], 'CH' : [], 'value' : []}
        for cycle, data in data_wf.items():
            icycle = int(cycle.split('_')[1])
            for ichn in range(len(data)):
                out_dict['testItem'].append(param)
                out_dict['Cycle'].append(icycle)
                out_dict['vdd_cfgs'].append('n/a')
                out_dict['CH'].append(ichn)
                out_dict['value'].append(data['CH{}'.format(ichn)])
        out_df = pd.DataFrame(out_dict)
        return out_df

    def run_Ana(self, path_to_statAna=None):
        """
        Analyze test data and optionally compare with statistical thresholds.
        
        Args:
            path_to_statAna (str, optional): Path to CSV file with statistical thresholds.
                                        If None, only raw data analysis is performed.
        """
        if self.ERROR:
            return

        #print('0============0', self.chipID)
        # Load statistical data if provided
        pwr_stat_ana_df = None
        chresp_stat_ana_df = None
        
        if path_to_statAna is not None:
            pwrcycle_stat_ana_df = pd.read_csv(path_to_statAna)
            pwr_stat_ana_df = pwrcycle_stat_ana_df[pwrcycle_stat_ana_df['vdd_cfgs'].isna()==False].copy().reset_index()
            pwr_stat_ana_df.drop('index', axis=1, inplace=True)
            tmpchresp_stat_ana_df = pwrcycle_stat_ana_df[pwrcycle_stat_ana_df['vdd_cfgs'].isna()==True].copy().reset_index()
            tmpchresp_stat_ana_df.drop('index', axis=1, inplace=True)
            
            # Create channel response statistics
            chresp_stat_ana = {'testItem': [], 'Cycle': [], 'CH': [], 'mean': [], 'std': []}
            for iitem in range(len(tmpchresp_stat_ana_df['testItem'])):
                tmpdata = tmpchresp_stat_ana_df.iloc[iitem]
                for ichn in range(16):
                    chresp_stat_ana['testItem'].append(tmpdata['testItem'])
                    chresp_stat_ana['Cycle'].append(tmpdata['Cycle'])
                    chresp_stat_ana['CH'].append(ichn)
                    chresp_stat_ana['mean'].append(tmpdata['mean'])
                    chresp_stat_ana['std'].append(tmpdata['std'])
            chresp_stat_ana_df = pd.DataFrame(chresp_stat_ana)

        # Get power measurement data
        pwr_out_df = pd.DataFrame({'testItem': [], 'Cycle': [], 'vdd_cfgs': [], 'value': []})
        for param in ['V', 'I', 'P']:
            param_df = self.create_dfItem_PWR(param=param, generatePlots=False)
            pwr_out_df = pd.concat([pwr_out_df, param_df], axis=0)
        pwr_out_df.reset_index().drop('index',axis=1, inplace=True)

        # Analyze power data with statistics if available
        if pwr_stat_ana_df is not None:
            comp_pwrSat_pwrChip_df = pd.merge(pwr_out_df, pwr_stat_ana_df, on=['testItem', 'Cycle', 'vdd_cfgs'], how='outer')
            comp_pwrSat_pwrChip_df['QC_result'] = (
                (comp_pwrSat_pwrChip_df['value'] >= (comp_pwrSat_pwrChip_df['mean']-3*comp_pwrSat_pwrChip_df['std'])) & 
                (comp_pwrSat_pwrChip_df['value'] <= (comp_pwrSat_pwrChip_df['mean']+3*comp_pwrSat_pwrChip_df['std']))
            )
            pwr_qc_results = comp_pwrSat_pwrChip_df[['testItem', 'Cycle', 'vdd_cfgs', 'value', 'QC_result']].copy()
        else:
            pwr_qc_results = pwr_out_df.copy()
            pwr_qc_results['QC_result'] = True  # Default pass without statistics

        pwr_qc_results = pwr_qc_results.reset_index().drop('index', axis=1)
        pwr_qc_results['Cycle'] = pwr_qc_results['Cycle'].astype(int)

        # Get channel response data
        chresp_out_df = pd.DataFrame({'testItem': [], 'Cycle': [], 'CH': [], 'value': []})
        for param in ['pedestal', 'rms', 'negpeak', 'pospeak']:
            param_df = self.create_dfItem_wf(param=param).drop('vdd_cfgs', axis=1).copy()
            chresp_out_df = pd.concat([chresp_out_df, param_df], axis=0)

        # Analyze channel response with statistics if available
        if chresp_stat_ana_df is not None:
            comp_chrespStat_chrespChip_df = pd.merge(chresp_stat_ana_df, chresp_out_df, on=['testItem', 'Cycle', 'CH'], how='outer')
            comp_chrespStat_chrespChip_df['QC_result'] = (
                (comp_chrespStat_chrespChip_df['value'] >= (comp_chrespStat_chrespChip_df['mean']-3*comp_chrespStat_chrespChip_df['std'])) & 
                (comp_chrespStat_chrespChip_df['value'] <= (comp_chrespStat_chrespChip_df['mean']+3*comp_chrespStat_chrespChip_df['std']))
            )
            chresp_qc_results = comp_chrespStat_chrespChip_df[['testItem', 'Cycle', 'CH', 'value', 'QC_result']]
        else:
            chresp_qc_results = chresp_out_df.copy()
            chresp_qc_results['QC_result'] = True  # Default pass without statistics

        # Process results cycle by cycle
        cycles = chresp_qc_results['Cycle'].unique()
        results_cycles = []
        for icycle in cycles:
            tmpdata_pwr = pwr_qc_results[pwr_qc_results['Cycle']==icycle].copy().reset_index().drop('index',axis=1)
            tmpdata_chresp = chresp_qc_results[chresp_qc_results['Cycle']==icycle].copy().reset_index().drop('index',axis=1)

            # The rest of the code remains the same as original
            # ...existing code for processing cycle results...
            cycle_pwr_qc_result = ''
            cycle_chresp_qc_result = ''
            if False in list(tmpdata_pwr['QC_result']):
                cycle_pwr_qc_result = 'FAILED'
            else:
                cycle_pwr_qc_result = 'PASSED'
            if False in list(tmpdata_chresp['QC_result']):
                cycle_chresp_qc_result = 'FAILED'
            else:
                cycle_chresp_qc_result = 'PASSED'
            
            # Format power parameters
            pwr_params = []
            for i in range(len(tmpdata_pwr)):
                param = '_'.join([tmpdata_pwr.iloc[i]['vdd_cfgs'], tmpdata_pwr.iloc[i]['testItem']])
                pwr_params.append('{} = {}'.format(param, tmpdata_pwr.iloc[i]['value']))

            # Format channel results
            ch_results = []
            for ichn in range(16):
                CH = 'CH{}'.format(ichn)
                posAmp = tmpdata_chresp[(tmpdata_chresp['CH']==ichn) & (tmpdata_chresp['testItem']=='pospeak')]['value']
                negAmp = tmpdata_chresp[(tmpdata_chresp['CH']==ichn) & (tmpdata_chresp['testItem']=='negpeak')]['value']
                ped = tmpdata_chresp[(tmpdata_chresp['CH']==ichn) & (tmpdata_chresp['testItem']=='pedestal')]['value']
                rms = tmpdata_chresp[(tmpdata_chresp['CH']==ichn) & (tmpdata_chresp['testItem']=='rms')]['value']
                ch_results.append(("{}=(ped={};rms={};posAmp={};negAmp={})".format(CH, ped.iloc[0], rms.iloc[0], posAmp.iloc[0], negAmp.iloc[0])))

            # Determine overall result based on whether we have statistics
            if path_to_statAna is not None:
                overall_result = 'PASSED' if cycle_pwr_qc_result == 'PASSED' and cycle_chresp_qc_result == 'PASSED' else 'FAILED'
                results_cycles.append(['Test_{}_Power_cycle'.format(self.tms), 'Cycle_{}'.format(icycle), overall_result] + pwr_params + ch_results)
            else:
                # Without statistics, just record measurements without pass/fail
                results_cycles.append(['Test_{}_Power_cycle'.format(self.tms), 'Cycle_{}'.format(icycle)] + pwr_params + ch_results)

        # Save results
        #with open('/'.join([self.output_path, self.chipID, '{}.csv'.format(self.item)]), 'w') as csvfile:
        #    csv.writer(csvfile, delimiter=',').writerows(results_cycles)

        return results_cycles

    def run_Ana_withStat(self, path_to_statAna=''):
        if self.ERROR:
            return
        
        #print('0============0', self.chipID)
        pwrcycle_stat_ana_df = pd.read_csv(path_to_statAna)
        pwr_stat_ana_df = pwrcycle_stat_ana_df[pwrcycle_stat_ana_df['vdd_cfgs'].isna()==False].copy().reset_index()
        pwr_stat_ana_df.drop('index', axis=1, inplace=True)
        tmpchresp_stat_ana_df = pwrcycle_stat_ana_df[pwrcycle_stat_ana_df['vdd_cfgs'].isna()==True].copy().reset_index()
        tmpchresp_stat_ana_df.drop('index', axis=1, inplace=True)
        
        # include channel number in chresp_stat_ana_df
        # each item in the statistical analysis corresponds to the reference value for 16 channels
        chresp_stat_ana = {'testItem' : [], 'Cycle': [], 'CH': [], 'mean': [], 'std': []}
        for iitem in range(len(tmpchresp_stat_ana_df['testItem'])):
            tmpdata = tmpchresp_stat_ana_df.iloc[iitem]
            for ichn in range(16):
                chresp_stat_ana['testItem'].append(tmpdata['testItem'])
                chresp_stat_ana['Cycle'].append(tmpdata['Cycle'])
                # chresp_stat_ana['vdd_cfgs'].append(tmpdata['vdd_cfgs'])
                chresp_stat_ana['CH'].append(ichn)
                chresp_stat_ana['mean'].append(tmpdata['mean'])
                chresp_stat_ana['std'].append(tmpdata['std'])
        chresp_stat_ana_df = pd.DataFrame(chresp_stat_ana)
        # print(chresp_stat_ana_df)
        # sys.exit()

        pwr_out_df = pd.DataFrame({'testItem': [], 'Cycle': [], 'vdd_cfgs': [], 'value': []})
        for param in ['V', 'I', 'P']:
            param_df = self.create_dfItem_PWR(param=param, generatePlots=True)
            pwr_out_df = pd.concat([pwr_out_df, param_df], axis=0)
        pwr_out_df.reset_index().drop('index',axis=1, inplace=True)
        comp_pwrSat_pwrChip_df = pd.merge(pwr_out_df, pwr_stat_ana_df, on=['testItem', 'Cycle', 'vdd_cfgs'], how='outer')
        comp_pwrSat_pwrChip_df['QC_result']= (comp_pwrSat_pwrChip_df['value']>= (comp_pwrSat_pwrChip_df['mean']-3*comp_pwrSat_pwrChip_df['std'])) & (comp_pwrSat_pwrChip_df['value'] <= (comp_pwrSat_pwrChip_df['mean']+3*comp_pwrSat_pwrChip_df['std']))
        pwr_qc_results = comp_pwrSat_pwrChip_df[['testItem', 'Cycle', 'vdd_cfgs', 'value', 'QC_result']].copy().reset_index().drop('index', axis=1)
        pwr_qc_results['Cycle'] = pwr_qc_results['Cycle'].astype(int)
        # print(comp_pwrSat_pwrChip_df[comp_pwrSat_pwrChip_df['QC_result']==False])
        # sys.exit()
        chresp_out_df = pd.DataFrame({'testItem' : [], 'Cycle': [], 'CH': [], 'value': []})
        for param in ['pedestal', 'rms', 'negpeak', 'pospeak']:
            param_df = self.create_dfItem_wf(param=param).drop('vdd_cfgs', axis=1).copy()
            chresp_out_df = pd.concat([chresp_out_df, param_df], axis=0)
        # chresp_out_df.reset_index().drop('index', axis=1, inplace=True)
        comp_chrespStat_chrespChip_df = pd.merge(chresp_stat_ana_df, chresp_out_df, on=['testItem', 'Cycle', 'CH'], how='outer')
        comp_chrespStat_chrespChip_df['QC_result']= (comp_chrespStat_chrespChip_df['value']>= (comp_chrespStat_chrespChip_df['mean']-3*comp_chrespStat_chrespChip_df['std'])) & (comp_chrespStat_chrespChip_df['value'] <= (comp_chrespStat_chrespChip_df['mean']+3*comp_chrespStat_chrespChip_df['std']))
        # print(comp_chrespStat_chrespChip_df)
        # sys.exit()
        chresp_qc_results = comp_chrespStat_chrespChip_df[['testItem', 'Cycle','CH', 'value', 'QC_result']]
        

        cycles = chresp_qc_results['Cycle'].unique()
        results_cycles = []
        for icycle in cycles:
            tmpdata_pwr = pwr_qc_results[pwr_qc_results['Cycle']==icycle].copy().reset_index().drop('index',axis=1)
            tmpdata_chresp = chresp_qc_results[chresp_qc_results['Cycle']==icycle].copy().reset_index().drop('index', axis=1)
            cycle_pwr_qc_result = ''
            cycle_chresp_qc_result = ''
            # print(tmpdata_pwr['QC_result'])
            if False in list(tmpdata_pwr['QC_result']):
                cycle_pwr_qc_result = 'FAILED'
            else:
                cycle_pwr_qc_result = 'PASSED'
            if False in list(tmpdata_chresp['QC_result']):
                cycle_chresp_qc_result = 'FAILED'
            else:
                cycle_chresp_qc_result = 'PASSED'
            
            # power
            pwr_params = []
            for i in range(len(tmpdata_pwr)):
                param = '_'.join([tmpdata_pwr.iloc[i]['vdd_cfgs'], tmpdata_pwr.iloc[i]['testItem']]) #, tmpdata_pwr.iloc[i]['testItem'].split(' ')[0] ])
                pwr_params.append('{} = {}'.format(param, tmpdata_pwr.iloc[i]['value']))
            # ch resp
            ch_results = [] # = [(posAmp=, negAmp=, rms=, ped=)]
            for ichn in range(16):
                CH = 'CH{}'.format(ichn)
                posAmp = tmpdata_chresp[(tmpdata_chresp['CH']==ichn) & (tmpdata_chresp['testItem']=='pospeak')]['value']
                negAmp = tmpdata_chresp[(tmpdata_chresp['CH']==ichn) & (tmpdata_chresp['testItem']=='negpeak')]['value']
                ped = tmpdata_chresp[(tmpdata_chresp['CH']==ichn) & (tmpdata_chresp['testItem']=='pedestal')]['value']
                rms = tmpdata_chresp[(tmpdata_chresp['CH']==ichn) & (tmpdata_chresp['testItem']=='rms')]['value']
                # print(float(posAmp), float(negAmp), float(ped), float(rms), CH)
                ch_results.append(("{}=(ped={};rms={};posAmp={};negAmp={})".format(CH, ped.iloc[0], rms.iloc[0], posAmp.iloc[0], negAmp.iloc[0])))  
            # print(cycle_pwr_qc_result, pwr_params)      
            # print(cycle_chresp_qc_result, ch_results)

            overall_result = ''
            if 'FAILED' in [cycle_pwr_qc_result, cycle_chresp_qc_result]:
                overall_result = 'FAILED'
            else:
                overall_result = 'PASSED'
            results_cycles.append(['Test_{}_Power_cycle'.format(self.tms), 'Cycle_{}'.format(icycle), overall_result] + pwr_params + ch_results)
        # sys.exit()
        with open('/'.join([self.output_path, self.chipID, '{}_.csv'.format(self.item)]), 'w') as csvfile:
            csvwriter = csv.writer(csvfile, delimiter=',')
            csvwriter.writerows(results_cycles)
        # print(self.data['logs'])
        # sys.exit()
        # print(pwr_qc_result)
        # print(self.chipID)
        # sys.exit()
        return results_cycles, self.data['logs']

class PWR_CYCLE_statAna():
    def __init__(self, root_path: str, output_path: str):
        self.root_path = root_path
        self.output_path = output_path
        self.output_path_fig = '/'.join([output_path, 'fig'])
        try:
            os.mkdir(self.output_path_fig)
        except:
            pass

    def cleanDistribution(self, array):
        data = np.array(array)
        std = statistics.stdev(data)
        median = statistics.median(data)
        xmin = median - 3*std
        xmax = median + 3*std
        for _ in range(10):
            posmin = np.where(data < xmin)[0]
            posmax = np.where(data > xmax)[0]
            # data = np.delete(data, posmin)
            # data = np.delete(data, posmax)
            pos = np.concatenate((posmin, posmax))
            data = np.delete(data, pos)
            std = statistics.stdev(data)
            median = statistics.median(data)
            xmin = median - 3*std
            xmax = median + 3*std
        std = np.round(std, 4)
        median = np.round(median, 4)
        return data, median, std

    def savePlotDistribution(self, array, filename, mean, std, xtitle, saveFig=True):
        if saveFig:
            plt.figure()
            plt.hist(array, bins=len(array)//16, label='mean = {}, std = {}'.format(mean, std))
            plt.xlabel(xtitle)
            plt.ylabel('#')
            plt.legend()
            plt.savefig('/'.join([self.output_path_fig, filename + '.png']))
            plt.close()

    def run_Ana(self):
        list_chipID = os.listdir(self.root_path)
        allV_vdda = [[] for _ in range(8)]
        allV_vddp = [[] for _ in range(8)]
        allV_vddo = [[] for _ in range(8)]
        allI_vdda = [[] for _ in range(8)]
        allI_vddp = [[] for _ in range(8)]
        allI_vddo = [[] for _ in range(8)]
        allP_vdda = [[] for _ in range(8)]
        allP_vddp = [[] for _ in range(8)]
        allP_vddo = [[] for _ in range(8)]
        all_pedestals = [np.array([]) for _ in range(8)]
        all_rms = [np.array([]) for _ in range(8)]
        all_pospeaks = [np.array([]) for _ in range(8)]
        all_negpeaks = [np.array([]) for _ in range(8)]
        
        for chipID in list_chipID:
            onechipData = PWR_CYCLE_Ana(root_path=self.root_path, chipID=chipID, output_path=self.output_path)
            if onechipData.ERROR:
                continue
            # voltage
            v_vdda, v_vddp, v_vddo = onechipData.get_IVP(param='V', forStat=True)
            for i in range(len(v_vdda)):
                allV_vdda[i].append(v_vdda[i])
                allV_vddp[i].append(v_vddp[i])
                allV_vddo[i].append(v_vddo[i])
            # current
            i_vdda, i_vddp, i_vddo = onechipData.get_IVP(param='I', forStat=True)
            for i in range(len(i_vdda)):
                allI_vdda[i].append(i_vdda[i])
                allI_vddp[i].append(i_vddp[i])
                allI_vddo[i].append(i_vddo[i])
            # power
            p_vdda, p_vddp, p_vddo = onechipData.get_IVP(param='P', forStat=True)
            for i in range(len(p_vdda)):
                allP_vdda[i].append(p_vdda[i])
                allP_vddp[i].append(p_vddp[i])
                allP_vddo[i].append(p_vddo[i])
            # pedestal
            pedestals = onechipData.get_wfdata(item='pedestal', forStat=True)
            # rms
            rmss = onechipData.get_wfdata(item='rms', forStat=True)
            # positive peak
            pospeaks = onechipData.get_wfdata(item='pospeak', forStat=True)
            # negative peak
            negpeaks = onechipData.get_wfdata(item='negpeak', forStat=True)
            for i in range(len(pedestals)):
                all_pedestals[i] = np.concatenate((all_pedestals[i], pedestals[i]))
                all_rms[i] = np.concatenate((all_rms[i], rmss[i]))
                all_pospeaks[i] = np.concatenate((all_pospeaks[i], pospeaks[i]))
                all_negpeaks[i] = np.concatenate((all_negpeaks[i], negpeaks[i]))
        #
        output_ana = {'testItem': [], 'Cycle': [], 'vdd_cfgs': [], 'mean': [], 'std': []}
        for icycle in range(8):
            # voltage
            ## VDDA
            tmpdata = allV_vdda[icycle]
            outdata, median, std = self.cleanDistribution(array=tmpdata)
            self.savePlotDistribution(array=outdata, filename='QC_PWR_CYCLE_voltage_vdda_cycle{}'.format(icycle), mean=median, std=std, xtitle='V_VDDA_cycle{}'.format(icycle))
            output_ana['testItem'].append('V')
            output_ana['Cycle'].append(icycle)
            output_ana['vdd_cfgs'].append('VDDA')
            output_ana['mean'].append(median)
            output_ana['std'].append(std)
            ## VDDO
            tmpdata = allV_vddo[icycle]
            outdata, median, std = self.cleanDistribution(array=tmpdata)
            self.savePlotDistribution(array=outdata, filename='QC_PWR_CYCLE_voltage_vddo_cycle{}'.format(icycle), mean=median, std=std, xtitle='V_VDDA_cycle{}'.format(icycle))
            output_ana['testItem'].append('V')
            output_ana['Cycle'].append(icycle)
            output_ana['vdd_cfgs'].append('VDDO')
            output_ana['mean'].append(median)
            output_ana['std'].append(std)
            ## VDDP
            tmpdata = allV_vddp[icycle]
            outdata, median, std = self.cleanDistribution(array=tmpdata)
            self.savePlotDistribution(array=outdata, filename='QC_PWR_CYCLE_voltage_vddp_cycle{}'.format(icycle), mean=median, std=std, xtitle='V_VDDA_cycle{}'.format(icycle))
            output_ana['testItem'].append('V')
            output_ana['Cycle'].append(icycle)
            output_ana['vdd_cfgs'].append('VDDP')
            output_ana['mean'].append(median)
            output_ana['std'].append(std)
            # Current
            ## VDDA
            tmpdata = allI_vdda[icycle]
            outdata, median, std = self.cleanDistribution(array=tmpdata)
            self.savePlotDistribution(array=outdata, filename='QC_PWR_CYCLE_current_vdda_cycle{}'.format(icycle), mean=median, std=std, xtitle='I_VDDA_cycle{}'.format(icycle))
            output_ana['testItem'].append('I')
            output_ana['Cycle'].append(icycle)
            output_ana['vdd_cfgs'].append('VDDA')
            output_ana['mean'].append(median)
            output_ana['std'].append(std)
            ## VDDO
            tmpdata = allI_vddo[icycle]
            outdata, median, std = self.cleanDistribution(array=tmpdata)
            self.savePlotDistribution(array=outdata, filename='QC_PWR_CYCLE_current_vddo_cycle{}'.format(icycle), mean=median, std=std, xtitle='I_VDDA_cycle{}'.format(icycle))
            output_ana['testItem'].append('I')
            output_ana['Cycle'].append(icycle)
            output_ana['vdd_cfgs'].append('VDDO')
            output_ana['mean'].append(median)
            output_ana['std'].append(std)
            ## VDDP
            tmpdata = allI_vddp[icycle]
            outdata, median, std = self.cleanDistribution(array=tmpdata)
            self.savePlotDistribution(array=outdata, filename='QC_PWR_CYCLE_current_vddp_cycle{}'.format(icycle), mean=median, std=std, xtitle='I_VDDA_cycle{}'.format(icycle))
            output_ana['testItem'].append('I')
            output_ana['Cycle'].append(icycle)
            output_ana['vdd_cfgs'].append('VDDP')
            output_ana['mean'].append(median)
            output_ana['std'].append(std)
            # Power
            ## VDDA
            tmpdata = allP_vdda[icycle]
            outdata, median, std = self.cleanDistribution(array=tmpdata)
            self.savePlotDistribution(array=outdata, filename='QC_PWR_CYCLE_power_vdda_cycle{}'.format(icycle), mean=median, std=std, xtitle='P_VDDA_cycle{}'.format(icycle))
            output_ana['testItem'].append('P')
            output_ana['Cycle'].append(icycle)
            output_ana['vdd_cfgs'].append('VDDA')
            output_ana['mean'].append(median)
            output_ana['std'].append(std)
            ## VDDO
            tmpdata = allP_vddo[icycle]
            outdata, median, std = self.cleanDistribution(array=tmpdata)
            self.savePlotDistribution(array=outdata, filename='QC_PWR_CYCLE_power_vddo_cycle{}'.format(icycle), mean=median, std=std, xtitle='P_VDDA_cycle{}'.format(icycle))
            output_ana['testItem'].append('P')
            output_ana['Cycle'].append(icycle)
            output_ana['vdd_cfgs'].append('VDDO')
            output_ana['mean'].append(median)
            output_ana['std'].append(std)
            ## VDDP
            tmpdata = np.array([])
            tmpdata = allP_vddp[icycle]
            outdata, median, std = self.cleanDistribution(array=tmpdata)
            self.savePlotDistribution(array=outdata, filename='QC_PWR_CYCLE_power_vddp_cycle{}'.format(icycle), mean=median, std=std, xtitle='V_VDDA_cycle{}'.format(icycle))
            output_ana['testItem'].append('P')
            output_ana['Cycle'].append(icycle)
            output_ana['vdd_cfgs'].append('VDDP')
            output_ana['mean'].append(median)
            output_ana['std'].append(std)
            #
            # Pedestals
            tmpdata = all_pedestals[icycle]
            outdata, median, std = self.cleanDistribution(array=tmpdata)
            self.savePlotDistribution(array=outdata, filename='QC_PWR_CYCLE_pedestal_cycle{}'.format(icycle), mean=median, std=std, xtitle='pedestal_cycle{}'.format(icycle))
            output_ana['testItem'].append('pedestal')
            output_ana['Cycle'].append(icycle)
            output_ana['vdd_cfgs'].append('n/a')
            output_ana['mean'].append(median)
            output_ana['std'].append(std)
            # rms
            tmpdata = all_rms[icycle]
            outdata, median, std = self.cleanDistribution(array=tmpdata)
            self.savePlotDistribution(array=outdata, filename='QC_PWR_CYCLE_rms_cycle{}'.format(icycle), mean=median, std=std, xtitle='rms_cycle{}'.format(icycle))
            output_ana['testItem'].append('rms')
            output_ana['Cycle'].append(icycle)
            output_ana['vdd_cfgs'].append('n/a')
            output_ana['mean'].append(median)
            output_ana['std'].append(std)
            # positive peak
            tmpdata = all_pospeaks[icycle]
            outdata, median, std = self.cleanDistribution(array=tmpdata)
            self.savePlotDistribution(array=outdata, filename='QC_PWR_CYCLE_pospeak_cycle{}'.format(icycle), mean=median, std=std, xtitle='posPeak_cycle{}'.format(icycle))
            output_ana['testItem'].append('pospeak')
            output_ana['Cycle'].append(icycle)
            output_ana['vdd_cfgs'].append('n/a')
            output_ana['mean'].append(median)
            output_ana['std'].append(std)
            # negative peak
            tmpdata = all_negpeaks[icycle]
            outdata, median, std = self.cleanDistribution(array=tmpdata)
            self.savePlotDistribution(array=outdata, filename='QC_PWR_CYCLE_negpeak_cycle{}'.format(icycle), mean=median, std=std, xtitle='negPeak_cycle{}'.format(icycle))
            output_ana['testItem'].append('negpeak')
            output_ana['Cycle'].append(icycle)
            output_ana['vdd_cfgs'].append('n/a')
            output_ana['mean'].append(median)
            output_ana['std'].append(std)
            # tmpdata = all_rms[icycle]
            # data, median, std = self.cleanDistribution(array=tmpdata)
            # plt.figure()
            # plt.hist(data, bins=30, label='median = {}, std = {}'.format(median, std))
            # plt.legend()
            # plt.show()
            # sys.exit()
        out_df = pd.DataFrame(output_ana).sort_values(by=['testItem', 'Cycle'])
        out_df.to_csv('/'.join([self.output_path, 'StatAnaPWR_CYCLE.csv']), index=False)

if __name__ == '__main__':
    root_path = "E:/B009T0008/"
    output_path = root_path + "Ana"
    data_dir = "Time_20250527114445_DUT_0000_1001_2002_3003_4004_5005_6006_7007"
    env = 'RT'
    pwr_cycle = PWR_CYCLE(root_path=root_path, data_dir=data_dir, output_path=output_path, env=env)
    pwr_cycle.decode_PwrCycle()
    # root_path = '../../Data_BNL_CE_WIB_SW_QC'
    # output_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    # # # list_data_dir = [dir for dir in os.listdir(root_path) if '.zip' not in dir]
    # root_path = '../../B010T0004'
    # list_data_dir = [dir for dir in os.listdir(root_path) if (os.path.isdir('/'.join([root_path, dir]))) and (dir!='images')]
    # for i, data_dir in enumerate(list_data_dir):
    # #     # if i==0:
    #         pwr_c = PWR_CYCLE(root_path=root_path, data_dir=data_dir, output_path=output_path)
    #         pwr_c.decode_PwrCycle()
    #         print(pwr_c.logs_dict)
    #         sys.exit()
    # root_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    # output_path = '../../Analysis'
    #root_path = '../../out_B010T0004_'
    #output_path = '../../analyzed_B010T0004_'
    ## list_chipID = os.listdir(root_path)
    ## for chipID in list_chipID:
    ##     print(chipID)
    ##     pwrcyclea_ana = PWR_CYCLE_Ana(root_path=root_path, chipID=chipID, output_path=output_path)
    ##     pwrcyclea_ana.run_Ana(path_to_statAna='/'.join([output_path, 'StatAnaPWR_CYCLE.csv']))
    ##     sys.exit()
    ##     # pwr_ana.Mean_ChResp_ana(BL='900mV')
    ##     # sys.exit()
    #stat = PWR_CYCLE_statAna(root_path=root_path, output_path=output_path)
    #stat.run_Ana()
