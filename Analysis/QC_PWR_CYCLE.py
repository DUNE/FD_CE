############################################################################################
#   created on 6/11/2024 @ 10:53
#   email: radofanantenan.razakamiandra@stonybrook.edu
#   Analyze the data in QC_PWR_CYCLE.bin
############################################################################################

import os, pickle, sys, statistics, pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from utils import createDirs, printItem, decodeRawData, dumpJson, LArASIC_ana, BaseClass
from utils import BaseClass_Ana

class PWR_CYCLE(BaseClass):
    def __init__(self, root_path: str, data_dir: str, output_path: str):
        printItem('FE power cycling')
        super().__init__(root_path=root_path, data_dir=data_dir, output_path=output_path, QC_filename='QC_PWR_CYCLE.bin', tms=4)
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
        logs = {
            "date": self.logs_dict['date'],
            "testsite": self.logs_dict['testsite'],
            "env": self.logs_dict['env'],
            "note": self.logs_dict['note'],
            "WIB_slot": self.logs_dict['DAT_on_WIB_slot']
        }
        PwrCycle_data = {self.logs_dict['FE{}'.format(ichip)]: {"logs": logs} for ichip in range(8)}
        for ipcycle in range(N_pwrcycle):
            # if ipcycle==4:
            pwr_cycle_N = 'PwrCycle_{}'.format(ipcycle)
            print("Item : {}".format(pwr_cycle_N))
            one_pwrcyc = self.decode_OnePwrCycle(pwr_cycle_N=pwr_cycle_N)
            for FE_ID in one_pwrcyc.keys():
                PwrCycle_data[FE_ID][pwr_cycle_N] = one_pwrcyc[FE_ID][pwr_cycle_N]
        # save data to json file
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            data = PwrCycle_data[FE_ID]
            dumpJson(output_path=self.FE_outputDIRs[FE_ID], output_name='PWR_CYCLE', data_to_dump=data)

class PWR_CYCLE_Ana(BaseClass_Ana):
    '''
        This class is written to analyze the decoded data for each ASIC.
        The name of the function get_IVP(...) means get Current, Voltage, or Power.
    '''
    def __init__(self, root_path: str, chipID: str, output_path: str):
        self.item = 'QC_PWR_CYCLE'
        super().__init__(root_path=root_path, chipID=chipID, output_path=output_path, item=self.item)
        self.output_dir = '/'.join([output_path, self.item])
        try:
            os.makedirs(self.output_dir)
        except OSError:
            pass
    
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
            pass

    def run_Ana(self):
        if self.ERROR:
            return
        vdda, vddp, vddo = self.get_IVP(param='V', forStat=True)
        print(vdda.shape)
        sys.exit()
        # plt.figure()
        # plt.plot(vdda['cycle'], vdda['P'], label='VDDA')
        # plt.plot(vddp['cycle'], vddp['P'], label='VDDP')
        # plt.plot(vddo['cycle'], vddo['P'], label='VDDO')
        # plt.legend()
        # plt.show()
        # sys.exit()
        # self.get_wfdata(forStat=True, item='rms')

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
                allP_vddp[i].append(p_vdda[i])
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
            tmpdata = allV_vddp[icycle]
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
    # root_path = '../../Data_BNL_CE_WIB_SW_QC'
    # output_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    # # list_data_dir = [dir for dir in os.listdir(root_path) if '.zip' not in dir]
    # root_path = '../../B010T0004'
    # list_data_dir = [dir for dir in os.listdir(root_path) if (os.path.isdir('/'.join([root_path, dir]))) and (dir!='images')]
    # for i, data_dir in enumerate(list_data_dir):
    #     # if i==0:
    #         pwr_c = PWR_CYCLE(root_path=root_path, data_dir=data_dir, output_path=output_path)
    #         pwr_c.decode_PwrCycle()
    root_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    output_path = '../../Analysis'
    # list_chipID = os.listdir(root_path)
    # for chipID in list_chipID:
    #     print(chipID)
    #     pwrcyclea_ana = PWR_CYCLE_Ana(root_path=root_path, chipID=chipID, output_path=output_path)
    #     pwrcyclea_ana.run_Ana()
    #     # pwr_ana.Mean_ChResp_ana(BL='900mV')
    #     # sys.exit()
    stat = PWR_CYCLE_statAna(root_path=root_path, output_path=output_path)
    stat.run_Ana()