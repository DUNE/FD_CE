############################################################################################
#   created on 6/11/2024 @ 18:49
#   email: radofanantenan.razakamiandra@stonybrook.edu
#   Analyze the data in QC_RMS.bin
############################################################################################

import os, sys, pickle, json, statistics, csv
from scipy.stats import norm
import numpy as np
from utils import dumpJson, createDirs, decodeRawData, printItem, LArASIC_ana, BaseClass, BaseClass_Ana
import matplotlib.pyplot as plt
import pandas as pd

class QC_CHKRES(BaseClass):
    def __init__(self, root_path: str, data_dir: str, output_path: str, env='RT'):
        printItem("FE Response measurement")
        super().__init__(root_path=root_path, data_dir=data_dir, output_path=output_path, QC_filename='QC_RMS.bin', tms=5, env=env)
        if self.ERROR:
            return
        self.CFG_datasheet = self.getCFGs()
        self.period = 500
    
    def decodeCFG(self, config: str):
        cfg_split = config.split('_')
        cfg_datasheet = dict()
        sdd, sdf, slkh, slk, snc, sts, st, sgp, sg = '', '', '', '', '', '', '', '', ''
        if len(cfg_split)==10:
            [chk, sdd, sdf, slkh, slk, snc, sts, st, sgp, sg] = cfg_split
        elif len(cfg_split)==11:
            [chk, k, sdd, sdf, slkh, slk, snc, sts, st, sgp, sg] = cfg_split
            cfg_datasheet['param_chk'] = k
        cfg_datasheet['SDD'] = sdd[-1]
        cfg_datasheet['SDF'] = sdf[-1]
        cfg_datasheet['SLKH'] = slkh[-1]
        cfg_datasheet['SLK'] = slk[-2:]
        cfg_datasheet['SNC'] = snc[-1]
        cfg_datasheet['STS'] = sts[-1]
        cfg_datasheet['ST'] = st[-2:]
        cfg_datasheet['SGP'] = sgp[-1]
        cfg_datasheet['SG'] = sg[-2:]
        return {config: cfg_datasheet}

    def getCFGs(self):
        cfg_dict = dict()
        for config in self.params:
            tmp_cfg = self.decodeCFG(config=config)
            cfg_dict[config]  = tmp_cfg[config]
        return cfg_dict

    def decode_oneRES(self, config: str):
        fembs = self.raw_data[config][0]
        raw_data = self.raw_data[config][1]
        cfg_info = self.raw_data[config][2]
        decodedRES = decodeRawData(fembs=fembs, rawdata=raw_data, period=self.period)
        out_dict = {self.logs_dict['FE{}'.format(ichip)]: dict() for ichip in range(8)}

        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            larasic = LArASIC_ana(dataASIC=decodedRES[ichip], output_dir=self.FE_outputDIRs[FE_ID], chipID=FE_ID, tms=self.tms, param=config, generatePlots=False, generateQCresult=False, period=self.period)
            pedchk = larasic.runAnalysis(getPulseResponse=True, isRMSNoise=True)
            out_dict[FE_ID][config] = {
                'pedestal': pedchk['pedrms']['pedestal']['data'],
                'rms': pedchk['pedrms']['rms']['data'],
                'pospeak': pedchk['pulseResponse']['pospeak']['data'],
                'negpeak': pedchk['pulseResponse']['negpeak']['data']
            }
        return out_dict

    def decode_CHKRES(self):
        if self.ERROR:
            return
        out_dict = {self.logs_dict['FE{}'.format(ichip)]: dict() for ichip in range(8)}
        for config in self.params:
            print("configuration : {}".format(config))
            tmp = self.decode_oneRES(config=config) 
            for ichip in range(8):
                FE_ID = self.logs_dict['FE{}'.format(ichip)]
                out_dict[FE_ID][config] = tmp[FE_ID][config]
        #logs = {
        #    "date": self.logs_dict['date'],
        #    "testsite": self.logs_dict['testsite'],
        #    "env": self.logs_dict['env'],
        #    "note": self.logs_dict['note'],
        #    "DAT_SN": self.logs_dict['DAT_SN'],
        #    "WIB_slot": self.logs_dict['DAT_on_WIB_slot']
        #}
        FE_IDs = []
        for ichip in range(8):
        #    pedrms_dict = {"logs": logs}
            pedrms_dict = {}
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            FE_IDs.append(FE_ID)
            for config in self.params:
                pedrms_dict[config] = dict()
                pedrms_dict[config]['CFG'] = self.CFG_datasheet[config]
                for key in out_dict[FE_ID][config].keys():
                    pedrms_dict[config][key] = out_dict[FE_ID][config][key]
            dumpJson(output_path=self.FE_outputDIRs[FE_ID], output_name='QC_RMS', data_to_dump=pedrms_dict)
        return FE_IDs

class QC_CHKRES_Ana(BaseClass_Ana):
    def __init__(self, root_path: str, output_path: str, chipID: str):
        self.item = 'QC_CHKRES'
        print (self.item)
        self.tms = '02'
        super().__init__(root_path=root_path, chipID=chipID, output_path=output_path, item=self.item)
        self.root_path = root_path
        self.output_path = output_path
        #self.output_dir = '/'.join([self.output_dir, self.item])
        #try:
        #    os.mkdir(self.output_dir)
        #except OSError:
        #    pass
        #print(self.output_dir)
        ## sys.exit()
    
    def _FileExist(self):
        chipDir = '/'.join([self.output_path, self.chipID])
        chipDirExist = os.path.isdir(chipDir)
        #qcMondirExist = os.path.isdir('/'.join([chipDir, 'QC_RMS']))
        feMonFileExist = os.path.isfile('/'.join([chipDir, 'QC_RMS.json']))
        return  feMonFileExist

    def getItem(self,config=''):
        data = self.data[config]
        return data, config

    def plot_rms_data(self, dict_data, config):
        decodedConfig = dict_data['CFG']
        ped = dict_data['pedestal']
        rms = dict_data['rms']
        # plot of pedestal vs CH
        fig, ax = plt.subplots(1,2,figsize=(5*2,5))
        ax[0].plot(np.arange(16), ped, '.-')
        ax[0].set_xlabel('CH')
        ax[0].set_ylabel('Pedestal')
        # plot of RMS vs CH
        ax[1].plot(np.arange(16), rms, '.-')
        ax[1].set_xlabel('CH')
        ax[1].set_ylabel('RMS')
        plt.savefig('/'.join([self.output_path, config + '.png']))
        plt.close()

    def run_Ana(self, path_to_statAna=None, generatePlots=False):
        """
        Analyze RMS test data and optionally compare with statistical thresholds.
        
        Args:
            path_to_statAna (str, optional): Path to CSV file with statistical thresholds.
                                            If None, only raw data analysis is performed.
            generatePlots (bool): Whether to generate plots for each configuration.
        
        Returns:
            list: List of result rows containing test data and analysis results
        """
        if not self._FileExist():
            return None

        data_df = pd.DataFrame({'cfg': []})
        result_table = []

        # Load statistical data if provided
        stat_df = None
        if path_to_statAna:
            stat_df = pd.read_csv(path_to_statAna)

        for config in self.params:
            data, cfg = self.getItem(config=config)
            
            if generatePlots:
                self.plot_rms_data(dict_data=data, config=cfg)

            # Create basic dataframe with measurements
            df = pd.DataFrame({
                'cfg': [cfg for _ in range(len(data['pedestal']))],
                'CH': [chn for chn in range(16)],
                'pedestal': data['pedestal'],
                'rms': data['rms']
            })

            # Apply statistical analysis if data available
            qc_result = None
            if stat_df is not None:
                stat_config_row = stat_df[stat_df['cfg']==config].copy().reset_index().drop('index', axis=1)
                
                # Add statistical data
                stat_dict = {
                    'mean_pedestal': [stat_config_row['mean_pedestal'][0] for _ in range(16)],
                    'mean_rms': [stat_config_row['mean_rms'][0] for _ in range(16)],
                    'std_pedestal': [stat_config_row['std_pedestal'][0] for _ in range(16)],
                    'std_rms': [stat_config_row['std_rms'][0] for _ in range(16)]
                }
                
                for key, val in stat_dict.items():
                    df[key] = val

                # Perform QC checks
                df['QC_result_pedestal'] = (
                    (df['pedestal'] >= (df['mean_pedestal']-3*df['std_pedestal'])) & 
                    (df['pedestal'] <= (df['mean_pedestal']+3*df['std_pedestal']))
                )
                df['QC_result_rms'] = (
                    (df['rms'] >= (df['mean_rms']-3*df['std_rms'])) & 
                    (df['rms'] <= (df['mean_rms']+3*df['std_rms']))
                )

                # Determine overall result
                qc_res_ped = 'FAILED' if False in df['QC_result_pedestal'] else 'PASSED'
                qc_res_rms = 'FAILED' if False in df['QC_result_rms'] else 'PASSED'
                qc_result = 'FAILED' if 'FAILED' in [qc_res_ped, qc_res_rms] else 'PASSED'

                # Clean up statistical columns
                for key in stat_dict.keys():
                    df.drop(key, axis=1, inplace=True)

            # Build result row
            row_table = []
            if qc_result is not None:
                row_table = [f'Test_0{self.tms}_RMS', config, qc_result]
            else:
                row_table = [f'Test_0{self.tms}_RMS', config]
            for chn in range(len(df['CH'])):
                ped = df.iloc[chn]['pedestal']
                rms = df.iloc[chn]['rms']
                row_table.append(f"CH{chn}=(pedestal={ped};rms={rms})")
            result_table.append(row_table)

            # Concatenate to main dataframe
            data_df = df if data_df.empty else pd.concat([data_df, df], axis=0).reset_index().drop('index', axis=1)

        # Save results
        #if not data_df.empty:
        #    data_df.to_csv(f'{self.output_path}/{self.chipID}/{self.item}.csv', index=False)
        #with open('/'.join([self.output_path, self.chipID, '{}.csv'.format(self.item)]), 'w') as csvfile:
        #    csv.writer(csvfile, delimiter=',').writerows(result_table)    

        return result_table


if __name__ == '__main__':
    root_path = "E:/B009T0008/"
    output_path = root_path + "Ana"
    data_dir = "Time_20250527114445_DUT_0000_1001_2002_3003_4004_5005_6006_7007"
    env = 'RT'
    qc_checkres = QC_CHKRES(root_path=root_path, data_dir=data_dir, output_path=output_path, env=env)
    qc_checkres.decode_CHKRES()
    # root_path = '../../Data_BNL_CE_WIB_SW_QC'
    # output_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    # # list_data_dir = [dir for dir in os.listdir(root_path) if '.zip' not in dir]
    # root_path = '../../B010T0004'
    # list_data_dir = [dir for dir in os.listdir(root_path) if (os.path.isdir('/'.join([root_path, dir]))) and (dir!='images')]
    # for i, data_dir in enumerate(list_data_dir):
    #     rms = RMS(root_path=root_path, data_dir=data_dir, output_path=output_path)
    #     rms.decodeRMS()
    # root_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    # output_path = '../../Analysis'
    #root_path = '../../out_B010T0004_'
    #output_path = '../../analyzed_B010T0004_'
    #rms_stat = RMS_StatAna(root_path=root_path, output_path=output_path)
    #rms_stat.run_Ana()
    ##
    ##
    # root_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    # output_path = '../../Analysis'
    # list_chipID = os.listdir(root_path)
    # for chipID in list_chipID:
    #     rms_ana = RMS_Ana(root_path=root_path, output_path=output_path, chipID=chipID)
    #     rms_ana.run_Ana(path_to_statAna='/'.join([output_path, 'StatAna_RMS.csv']), generatePlots=False)
