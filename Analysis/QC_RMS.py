############################################################################################
#   created on 6/11/2024 @ 18:49
#   email: radofanantenan.razakamiandra@stonybrook.edu
#   Analyze the data in QC_RMS.bin
############################################################################################

import os, sys, pickle, json, statistics
from scipy.stats import norm
import numpy as np
from utils import dumpJson, createDirs, decodeRawData, printItem, LArASIC_ana, BaseClass
import matplotlib.pyplot as plt
import pandas as pd

class RMS(BaseClass):
    def __init__(self, root_path: str, data_dir: str, output_path: str):
        printItem("FE noise measurement")
        super().__init__(root_path=root_path, data_dir=data_dir, output_path=output_path, QC_filename='QC_RMS.bin', tms=5)
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

    def decode_oneRMS(self, config: str):
        fembs = self.raw_data[config][0]
        raw_data = self.raw_data[config][1]
        cfg_info = self.raw_data[config][2]
        decodedRMS = decodeRawData(fembs=fembs, rawdata=raw_data, period=self.period)
        out_dict = {self.logs_dict['FE{}'.format(ichip)]: dict() for ichip in range(8)}
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            larasic = LArASIC_ana(dataASIC=decodedRMS[ichip], output_dir=self.FE_outputDIRs[FE_ID], chipID=FE_ID, tms=self.tms, param=config, generatePlots=False, generateQCresult=False, period=self.period)
            pedrms = larasic.runAnalysis(getPulseResponse=True, isRMSNoise=True)
            out_dict[FE_ID][config] = {
                'pedestal': pedrms['pedrms']['pedestal']['data'],
                'rms': pedrms['pedrms']['rms']['data']
            }
        return out_dict

    def decodeRMS(self):
        if self.ERROR:
            return
        out_dict = {self.logs_dict['FE{}'.format(ichip)]: dict() for ichip in range(8)}
        for config in self.params:
            print("configuration : {}".format(config))
            tmp = self.decode_oneRMS(config=config) 
            for ichip in range(8):
                FE_ID = self.logs_dict['FE{}'.format(ichip)]
                out_dict[FE_ID][config] = tmp[FE_ID][config]
        logs = {
            "date": self.logs_dict['date'],
            "testsite": self.logs_dict['testsite'],
            "env": self.logs_dict['env'],
            "note": self.logs_dict['note'],
            "DAT_SN": self.logs_dict['DAT_SN'],
            "WIB_slot": self.logs_dict['DAT_on_WIB_slot']
        }
        for ichip in range(8):
            pedrms_dict = {"logs": logs}
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            for config in self.params:
                pedrms_dict[config] = dict()
                pedrms_dict[config]['CFG'] = self.CFG_datasheet[config]
                for key in out_dict[FE_ID][config].keys():
                    pedrms_dict[config][key] = out_dict[FE_ID][config][key]
            dumpJson(output_path=self.FE_outputDIRs[FE_ID], output_name='RMS_Noise', data_to_dump=pedrms_dict)

class RMS_StatAna():
    def __init__(self, root_path: str, output_path: str):
        self.root_path = root_path
        self.output_path = output_path
        self.output_fig = '/'.join([output_path, 'fig'])
        try:
            os.mkdir(self.output_fig)
        except:
            pass
        
    def _FileExist(self, chipDir:str):
        chipDirExist = os.path.isdir(chipDir)
        qcMondirExist = os.path.isdir('/'.join([chipDir, 'QC_RMS']))
        feMonFileExist = os.path.isfile('/'.join([chipDir, 'QC_RMS/RMS_Noise.json']))
        return chipDirExist and qcMondirExist and feMonFileExist
    
    def getItems(self):
        list_chipID = os.listdir(self.root_path)
        cfg_map = dict()
        i = 0
        out_dict = dict()
        keys = []
        for chipID in list_chipID:
            path_to_chip = '/'.join([self.root_path, chipID])
            if not self._FileExist(chipDir=path_to_chip):
                continue
            path_to_file = '/'.join([path_to_chip, 'QC_RMS/RMS_Noise.json'])
            data = json.load(open(path_to_file))
            if i==0:
                keys = [k for k in data.keys() if k!='logs']
                # get configurations
                for key in keys:
                    cfg_map[key] = data[key]['CFG']
                    out_dict[key] = {'pedestal': np.array([]), 'rms': np.array([])}
            for key in keys:
                out_dict[key]['pedestal'] = np.append(out_dict[key]['pedestal'], data[key]['pedestal'])
                out_dict[key]['rms'] = np.append(out_dict[key]['rms'], data[key]['rms'])
            i += 1
        return out_dict, cfg_map

    def run_Ana(self):
        ######################################
        print("QC RMS statistical analysis....")
        ######################################
        data, configurations = self.getItems()
        cfg_list = []
        mean_ped, std_ped = [], []
        mean_rms, std_rms = [], []
        for cfg in configurations.keys():
            print('CFG = {}...'.format(cfg))
            # Pedestal
            tmpdata = data[cfg]['pedestal']
            median, std = statistics.median(tmpdata), statistics.stdev(tmpdata)
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

            # cfg_list.append(cfg)
            mean_ped.append(median)
            std_ped.append(std)
            # print(median, std)

            x = np.linspace(xmin, xmax, len(tmpdata))
            p = norm.pdf(x, median, std)
            plt.figure()
            plt.hist(tmpdata, bins=len(tmpdata)//128, density=True)
            plt.plot(x, p, 'r', label='mean = {}, std = {}'.format(median, std))
            plt.xlabel('-'.join(['Pedestal', cfg]));plt.ylabel('#')
            plt.legend()
            plt.savefig('/'.join([self.output_fig, 'QC_RMS_Pedestal_{}.png'.format(cfg)]))
            plt.close()
            # sys.exit()
            #
            # RMS
            tmpdata = data[cfg]['rms']
            median, std = statistics.median(tmpdata), statistics.stdev(tmpdata)
            xmin, xmax = np.min(tmpdata), np.max(tmpdata)
            for _ in range(350):
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

            cfg_list.append(cfg)
            mean_rms.append(median)
            std_rms.append(std)
            
            x = np.linspace(xmin, xmax, len(tmpdata))
            p = norm.pdf(x, median, std)
            plt.figure()
            plt.hist(tmpdata, bins=len(tmpdata)//128, density=True)
            plt.plot(x, p, 'r', label='mean = {}, std = {}'.format(median, std))
            plt.xlabel('-'.join(['RMS', cfg]));plt.ylabel('#')
            plt.legend()
            plt.savefig('/'.join([self.output_fig, 'QC_RMS_RMS_{}.png'.format(cfg)]))
            plt.close()

        OUTPUT_DF = pd.DataFrame({'cfg': cfg_list, 'mean_pedestal': mean_ped, 'std_pedestal': std_ped, 'mean_rms': mean_rms, 'std_rms': std_rms})
        OUTPUT_DF.to_csv('/'.join([self.output_path, 'StatAna_RMS.csv']), index=False)
        pd.DataFrame(configurations).to_csv('/'.join([self.output_path, 'QC_RMS_CONFIG_MAP.csv']))

if __name__ == '__main__':
    # root_path = '../../Data_BNL_CE_WIB_SW_QC'
    # output_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    # # list_data_dir = [dir for dir in os.listdir(root_path) if '.zip' not in dir]
    # root_path = '../../B010T0004'
    # list_data_dir = [dir for dir in os.listdir(root_path) if (os.path.isdir('/'.join([root_path, dir]))) and (dir!='images')]
    # for i, data_dir in enumerate(list_data_dir):
    #     rms = RMS(root_path=root_path, data_dir=data_dir, output_path=output_path)
    #     rms.decodeRMS()
    root_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    output_path = '../../Analysis'
    rms_stat = RMS_StatAna(root_path=root_path, output_path=output_path)
    rms_stat.run_Ana()