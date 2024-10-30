############################################################################################
#   created on 6/12/2024 @ 11:32
#   email: radofanantenan.razakamiandra@stonybrook.edu
#   Analyze the calibration data: QC_CALI_ASICDAC.bin, QC_CALI_DATDAC.bin, and QC_CALI_DIRECT.bin
############################################################################################

import os, sys, statistics
import numpy as np, pandas as pd
from utils import printItem, createDirs, dumpJson, linear_fit, LArASIC_ana, decodeRawData, BaseClass #, getPulse
import matplotlib.pyplot as plt
from scipy.signal import find_peaks
from utils import BaseClass_Ana
from scipy.stats import norm

class QC_CALI(BaseClass):
    '''
        Using the 6-bit DAC embedded on the chip to perform the calibration;
        LArASIC gain: 14mV/fC, peak time: 2$\mu$s
        INFO from QC_top:
            - cali_mode=2,
            - asicdac=0,
            - period = 512,
            - width = 384
            if snc==0: maxdac = 32
            else: maxdac = 64
            - num_samples = 5
            - filename: QC_CALI_ASICDAC.bin
    '''
    def __init__(self, root_path: str, data_dir: str, output_path: str, tms: int, QC_filename: str, generateWf=False):
        if tms in [61, 64]:
            printItem('ASICDAC Calibration')
            self.period = 500
        elif tms==62:
            printItem('DATDAC calibration')
            self.period = 1000
        elif tms==63:
            printItem('DIRECT calibration')
            self.period = 1000
        self.generateWf = generateWf
        super().__init__(root_path=root_path, data_dir=data_dir, output_path=output_path, tms=tms, QC_filename=QC_filename, generateWaveForm=self.generateWf)
        if self.ERROR:
            return
            

    def getCFG(self):
        '''
        return:
            {
                'SNC0': [(DAC, param), (DAC, param), ...., (DAC, param)],
                'SCN1': [(DAC, param), (DAC, param), ...., (DAC, param)]
            }
        '''
        cfg = {'SNC0': [], 'SNC1': []}
        if self.tms in [61, 64]:
            for param in self.params:
                splitted = param.split('_')
                BL = splitted[1]
                DAC = int(splitted[-1].split('ASICDAC')[-1])
                cfg[BL].append((DAC, param))
        elif self.tms in [62, 63]:
            cfg = {'SNC0': [], 'SNC1': []}
            for param in self.params:
                splitted = param.split('_')
                # if self.CALI_ITEM=='DATDAC':
                if self.tms==62:
                    BL = splitted[-1]
                    DAC = splitted[2]
                # elif self.CALI_ITEM=='DIRECT':
                if self.tms==63:
                    DAC = param.split('_')[-1]
                    BL = param.split('_')[1]
                cfg[BL].append((DAC, param))
        return cfg

    def avgWf(self, data: list, param='ASIC', getWaveforms=False):
        newdata = []
        for ichip in range(len(data)):
            ASIC_ID = self.logs_dict['FE{}'.format(ichip)]
            larasic = LArASIC_ana(dataASIC=data[ichip], output_dir=self.FE_outputDIRs[ASIC_ID], chipID=ASIC_ID, tms=self.tms, param=param, generateQCresult=False, generatePlots=False, period=self.period)
            data_asic = larasic.runAnalysis(getWaveforms=getWaveforms)
            chipdata = {'pedestal': data_asic['pedrms']['pedestal']['data'],
                        'rms': data_asic['pedrms']['rms']['data'],
                        'pospeak': data_asic['pulseResponse']['pospeak']['data'],
                        'negpeak': data_asic['pulseResponse']['negpeak']['data'],
                        }
            if getWaveforms:
                        chipdata['waveforms'] = data_asic['pulseResponse']['waveforms']
            newdata.append(chipdata)
        return newdata

    def decode(self, getWaveform_data=False):
        '''
            Decode the raw data and get timestamps and data
        '''
        cfg = self.getCFG()
        BLs = cfg.keys()
        decoded_data = {BL: dict() for BL in BLs}
        for BL in BLs:
            DAC_param = cfg[BL] # [(DAC, param), (DAC, param), ...., (DAC, param)]
            print('-- Start decoding BL {} --'.format(BL))
            for DAC, param in DAC_param:
                print('Decoding DAC {}...'.format(DAC))
                fembs = self.raw_data[param][0]
                rawdata = self.raw_data[param][1]
                data = decodeRawData(fembs=fembs, rawdata=rawdata, period=self.period)
                decoded_data[BL][DAC] = self.avgWf(data=data, param=param, getWaveforms=getWaveform_data) # already averaged
            print('-- End of decoding BL {} --'.format(BL))
        return decoded_data

    def organizeData(self, saveWaveformData=False):
        organized_data = dict()
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            organized_data[FE_ID] = dict()
            for BL in ['SNC0', 'SNC1']:
                organized_data[FE_ID][BL] = dict()
                for chn in range(16):
                    organized_data[FE_ID][BL]['CH{}'.format(chn)] = {'DAC': [], 'CH': [], 'pedestal': [], 'rms': [], 'pospeak': [], 'negpeak': []} # [DAC_list, [ch_list. ch_list, ....]]
        
        # organize the data
        decodedData = self.decode(getWaveform_data=self.generateWf)
        
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]            
            for BL in decodedData.keys():
                for chn in range(16):
                    for DAC in decodedData[BL].keys():
                        pedestal = decodedData[BL][DAC][ichip]['pedestal'][chn]
                        rms = decodedData[BL][DAC][ichip]['rms'][chn]
                        pospeak = decodedData[BL][DAC][ichip]['pospeak'][chn]
                        negpeak = decodedData[BL][DAC][ichip]['negpeak'][chn]
                        organized_data[FE_ID][BL]['CH{}'.format(chn)]['DAC'].append(DAC)
                        if self.generateWf:
                            dac_data = decodedData[BL][DAC][ichip]['waveforms'][chn]
                            organized_data[FE_ID][BL]['CH{}'.format(chn)]['CH'].append(list(dac_data))
                        organized_data[FE_ID][BL]['CH{}'.format(chn)]['pedestal'].append(pedestal)
                        organized_data[FE_ID][BL]['CH{}'.format(chn)]['rms'].append(rms)
                        organized_data[FE_ID][BL]['CH{}'.format(chn)]['pospeak'].append(pospeak)
                        organized_data[FE_ID][BL]['CH{}'.format(chn)]['negpeak'].append(negpeak)

        if saveWaveformData:
            #@ save the organized data to json files
            for ichip in range(8):
                FE_ID = self.logs_dict['FE{}'.format(ichip)]
                dumpJson(output_path=self.FE_outputDIRs[FE_ID], output_name='CALI_{}'.format(self.suffixName), data_to_dump=organized_data[FE_ID], indent=4)
        return organized_data

    def getAmplitudes(self, organizedData: dict):
        # logs
        logs = {
                "date": self.logs_dict['date'],
                "testsite": self.logs_dict['testsite'],
                "env": self.logs_dict['env'],
                "note": self.logs_dict['note'],
                "DAT_SN": self.logs_dict['DAT_SN'],
                "WIB_slot": self.logs_dict['DAT_on_WIB_slot']
            }
        
        # Pedestal
        pedestals = dict()
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            pedestals[FE_ID] = dict()
            for BL in ['SNC0', 'SNC1']:
                pedestals[FE_ID][BL] = dict()
                for chn in range(16):
                    DAC = 0 # pedestal without pulse
                    CH = 'CH{}'.format(chn)
                    ped = organizedData[FE_ID][BL][CH]['pedestal'][DAC]
                    std = organizedData[FE_ID][BL][CH]['rms'][DAC]
                    pedestals[FE_ID][BL][CH] = {'pedestal': ped, 'std': std}
        
        # Positive and negative Peaks
        amplitudes = dict()
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            amplitudes[FE_ID] = {'logs': logs}
            for BL in ['SNC0', 'SNC1']:
                amplitudes[FE_ID][BL] = dict()
                for chn in range(16):
                    amplitudes[FE_ID][BL]['CH{}'.format(chn)] = []
                    ped = pedestals[FE_ID][BL]['CH{}'.format(chn)]['pedestal']
                    std = pedestals[FE_ID][BL]['CH{}'.format(chn)]['std']
                    for idac, dac in enumerate(organizedData[FE_ID][BL]['CH{}'.format(chn)]['DAC']):
                        posAmp = organizedData[FE_ID][BL]['CH{}'.format(chn)]['pospeak'][idac]
                        negAmp = organizedData[FE_ID][BL]['CH{}'.format(chn)]['negpeak'][idac]
                        amplitudes[FE_ID][BL]['CH{}'.format(chn)].append({'DAC': dac, 'pedestal': ped, 'std': std,'posAmp': posAmp, 'negAmp': negAmp})
        
        # save data
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            print('Save amplitudes of {} ...'.format(FE_ID))
            dumpJson(output_path=self.FE_outputDIRs[FE_ID], output_name='CALI_{}_Amp'.format(self.suffixName), data_to_dump=amplitudes[FE_ID], indent=4)

    def plotWaveForms(self, organizedData: dict):
        for ichip in range(8):
            FE_ID = self.logs_dict['FE{}'.format(ichip)]
            onechipData = organizedData[FE_ID]
            print('Saving waveform for {}'.format(FE_ID))
            for BL in onechipData.keys():
                # print(FE_ID, BL)
                for chn in range(16):
                    plt.figure()
                    for idac, DAC in enumerate(onechipData[BL]['CH{}'.format(chn)]['DAC']):
                        dacdata = onechipData[BL]['CH{}'.format(chn)]['CH'][idac]
                        # plt.plot(dacdata, label='DAC {}'.format(DAC))
                        width = 20
                        # pospeak, h = find_peaks(x=dacdata, height=np.max(dacdata))
                        pospeak = np.argmax(dacdata)
                        if pospeak-10 < 0:
                            front = dacdata[-100 : ]
                            back = dacdata[ : -100]
                            dacdata = np.concatenate((front, back))
                            plt.plot(dacdata[pospeak-6 : pospeak+width], label='DAC {}'.format(DAC))
                        else:
                            plt.plot(dacdata[pospeak-6 :pospeak+width], label='DAC {}'.format(DAC))
                    plt.legend()
                    plt.savefig('/'.join([self.FE_outputPlots_DIRs[FE_ID], 'CALI_{}_wf_{}_chn{}.png'.format(self.suffixName, BL, chn)]))
                    plt.close()

    def runASICDAC_cali(self, saveWfData=False):
        if self.ERROR:
            return
        organizedData = self.organizeData(saveWaveformData=saveWfData)
        if self.generateWf:
            self.plotWaveForms(organizedData=organizedData)
        self.getAmplitudes(organizedData=organizedData)

#@ Analysis of the decoded data
class QC_CALI_Ana(BaseClass_Ana):
    def __init__(self, root_path: str, output_path: str, chipID: str, CALI_item: str):
        self.item = CALI_item + '_Amp'
        super().__init__(root_path=root_path, chipID=chipID, output_path=output_path, item=CALI_item)
        self.output_dir = '/'.join([self.output_dir, CALI_item])
        try:
            os.mkdir(self.output_dir)
        except OSError:
            pass
        print(self.output_dir)

    def getItem_forStatAna(self):
        '''
            Idea I want to implement in this function:
            - concatenate the data for the 16-channels corresponding to each DAC value
        '''
        BLs = ['SNC0', 'SNC1']
        outdata = {BL: dict() for BL in BLs}
        for BL in BLs:
            data = self.data[BL]
            DAClist = self.getDAClist(BL=BL)
            tmp_out = {'DAC': DAClist, 
                        'pedestal': [np.array([]) for _ in range(len(DAClist))],
                        'posAmp': [np.array([]) for _ in range(len(DAClist))],
                        'negAmp': [np.array([]) for _ in range(len(DAClist))]
                      }
            for ich in range(16):
                # for i, d in enumerate(data['CH{}'.format(ich)]):
                chdata = data['CH{}'.format(ich)]
                for idac, dac in enumerate(DAClist):
                    tmpdata = chdata[idac] 
                    tmp_out['pedestal'][idac] = np.append(tmp_out['pedestal'][idac], tmpdata['pedestal'])
                    tmp_out['posAmp'][idac] = np.append(tmp_out['posAmp'][idac], tmpdata['posAmp'])
                    tmp_out['negAmp'][idac] = np.append(tmp_out['negAmp'][idac], tmpdata['negAmp'])
            
            outdata[BL] = tmp_out
        return outdata

    def getDAClist(self, BL: str):
        data = self.data[BL]
        DAClist = []
        ch = 'CH0'
        for d in data[ch]:
            DAClist.append(d['DAC'])
        return DAClist

    def getDataperDAC(self, BL: str, item: str, DAC: int):
        data = self.data[BL]
        allchDACdata = []
        chns = list(range(16))
        for ich in range(16):
            CH = "CH{}".format(ich)
            # get dict with the corresponding DAC value
            dacdata = dict()
            for d in data[CH]:
                if d["DAC"] == DAC:
                    dacdata = d
            allchDACdata.append(dacdata[item])
        return DAC, chns, allchDACdata
    
    def getmeanData(self, BL: str, item: str):
        '''
            Get the average of the 16 channels value of "item" for each DAC. 
        '''
        data = self.data[BL]
        DAC_list = self.getDAClist(BL=BL)
        # for d in data["CH0"]:
        #     DAC_list.append(d["DAC"])
        DAC_list = sorted(DAC_list)

        meandata = []
        stddata = []
        for idac, dac in enumerate(DAC_list):
            onedac_data = []
            for ich in range(16):
                chn = "CH{}".format(ich)
                d = data[chn][idac]
                onedac_data.append(d[item])
            mean = np.round(np.mean(onedac_data), 4)
            std = np.round(np.std(onedac_data), 4)
            meandata.append(mean)
            stddata.append(std)
        
        # # plot example -- linearity
        # fig, ax = plt.subplots()
        # ax.plot(DAC_list, meandata, 'b-', marker='.', markersize=12)
        # ax.set_xticklabels(DAC_list)
        # plt.show()
        # sys.exit()
        return DAC_list, meandata, stddata
    
    def getINL(self, BL: str, item: str):
        '''
            - For each channel number, get the DAC and item values.
            - Get the INL for each channel.
            - Return the INL for the 16 channels.
            We use the positive amplitude to get the linearity.
        '''
        data = self.data[BL]
        INLs = {}

        for chn in range(16):
            # chn = 0
            chdata = data["CH{}".format(chn)]
            item_data = []
            DAC_list = []
            for d in chdata:
                DAC_list.append(d["DAC"])
                item_data.append(d[item])
            # print(DAC_list)
            # print(item_data)
            # # plot example -- linearity / channel
            # fig, ax = plt.subplots()
            # ax.plot(DAC_list, item_data, marker='.', markersize=12)
            # ax.set_xticklabels(DAC_list)
            # ax.set_ylabel("Amplitude (ADC bin)")
            # ax.set_xlabel("DAC bin")
            # plt.show()
            #
            # check linearity and get INL
            slope, yintercept, inl = linear_fit(x=DAC_list, y=item_data)
            # print(inl)
            INLs[chn] = inl
        return INLs
    
    def Amp_vs_CH(self):
        items = ['posAmp', 'negAmp']
        BLs = ['SNC0', 'SNC1']
        BL_dict = {'SNC0': '900mV', 'SNC1' : '200mV'}
        for BL in BLs:
            for item in items:
                DAClist = self.getDAClist(BL=BL)
                fig, ax = plt.subplots()
                for dac in DAClist:
                    DAC, chns, allchdacdata = self.getDataperDAC(BL=BL, item=item, DAC=dac)
                    ax.plot(chns, allchdacdata, label='{}'.format(DAC))
                ax.set_xlabel('CH');ax.set_ylabel('ADC bit')
                ax.set_title('{} : {}'.format(BL_dict[BL], item))
                ax.legend()
                fig.savefig('/'.join([self.output_dir, '{}_ampch_{}_{}.png'.format(self.item, BL_dict[BL], item)]))
                plt.close()
    
    def Amp_vs_DAC(self):
        items = ['posAmp', 'negAmp']
        BLs = ['SNC0', 'SNC1']
        BL_dict = {'SNC0': '900mV', 'SNC1' : '200mV'}
        for item in items:
            for BL in BLs:
                daclist, meandata, stddata = self.getmeanData(BL=BL, item=item)
                fig, ax = plt.subplots()
                ax.errorbar(x=daclist, y=meandata, yerr=stddata)
                ax.set_xlabel('DAC');ax.set_ylabel('ADC bit')
                ax.set_title('{} : {}'.format(BL_dict[BL], item))
                plt.grid(True)
                fig.savefig('/'.join([self.output_dir, '{}_ampdac_{}_{}.png'.format(self.item, BL_dict[BL], item)]))
                plt.close()
    
    def INL_vs_CH(self):
        items = ['posAmp', 'negAmp']
        BLs = ['SNC0', 'SNC1']
        BL_dict = {'SNC0': '900mV', 'SNC1' : '200mV'}
        for item in items:
            for BL in BLs:
                inls = self.getINL(BL=BL, item=item)
                fig, ax = plt.subplots()
                ax.plot(inls.keys(), inls.values())
                ax.set_xlabel('CH');ax.set_ylabel('INL')
                ax.set_title('{} : {}'.format(BL_dict[BL], item))
                fig.savefig('/'.join([self.output_dir, '{}_inlCH_{}_{}.png'.format(self.item, BL_dict[BL], item)]))
                plt.close()

    def makeplots(self):
        if self.ERROR:
            return
        # self.Amp_vs_CH()
        # self.Amp_vs_DAC()
        # self.INL_vs_CH()
        self.getItem_forStatAna()

# def StatAna_cali(root_path: str, list_chipID: list):
#     BLs = ['SNC0', 'SNC1']
#     items_to_ana = ['posAmp', 'negAmp']
#     allINLs = np.array([])
#     for chipID in list_chipID:
#         ana_cali = QC_CALI_Ana(root_path=root_path, output_path='', chipID=chipID, CALI_item='QC_CALI_ASICDAC')
#         if ana_cali.ERROR:
#             continue
#         INLs = ana_cali.getINL(BL=BLs[0], item=items_to_ana[1])
#         val = list(INLs.values())
#         allINLs = np.concatenate((allINLs, np.array(val)))
#     plt.figure()
#     mean = np.round(np.mean(allINLs), 4)
#     std = np.round(np.std(allINLs), 4)
#     plt.hist(allINLs, bins=100, label='mean = {}, std = {}'.format(mean, std))
#     plt.legend()
#     plt.show()
#     # print(alldata)

def StatAna_cali(root_path: str, output_path: str, cali_item='QC_CALI_ASICDAC', saveDist=False):
    def plot_distribution(array, xtitle, output_path_fig, figname):
        xmin, xmax = np.min(array), np.max(array)
        mean, std = np.round(statistics.median(array), 4), np.round(statistics.stdev(array), 4)
        x = np.linspace(xmin, xmax, len(array))
        p = norm.pdf(x, mean, std)
        Nbins = len(array)//32
        plt.figure()
        plt.hist(array, bins=Nbins, density=True)
        plt.plot(x, p, 'r', label='mean = {}, std = {}'.format(mean, std))
        plt.xlabel(xtitle);plt.ylabel('#')
        plt.legend()
        plt.savefig('/'.join([output_path_fig, figname + '.png']))
        plt.close()

    outdata = dict()
    output_path_fig = '/'.join([output_path, 'fig'])
    list_chipID = os.listdir(root_path)
    firstData = True
    BLs = []
    DACs = [[], []]
    for chipID in list_chipID:
        ana_cali = QC_CALI_Ana(root_path=root_path, output_path=output_path, chipID=chipID, CALI_item=cali_item)
        if ana_cali.ERROR:
            continue
        chipdata = ana_cali.getItem_forStatAna()
        if firstData:
            outdata = chipdata
            BLs = list(outdata.keys())
            DACs = [list(outdata[bl]['DAC']) for bl in BLs]
        else:
            for ibl, bl in enumerate(BLs):
                for idac, dac in enumerate(DACs[ibl]):
                    outdata[bl]['pedestal'][idac] = np.concatenate((outdata[bl]['pedestal'][idac], chipdata[bl]['pedestal'][idac]))
                    outdata[bl]['posAmp'][idac] = np.concatenate((outdata[bl]['posAmp'][idac], chipdata[bl]['posAmp'][idac]))
                    outdata[bl]['negAmp'][idac] = np.concatenate((outdata[bl]['negAmp'][idac], chipdata[bl]['negAmp'][idac]))
        firstData = False
    # all the data are stored in one dictionary now
    # testItems = [] # pedestal, posAmp, negAmp
    # BLs = [] # SNC0, SNC1
    # DACs = [] # 0, 4, 8, ....
    # means = []
    # stdevs = []
    out_dict = {'testItem': [], 'BL': [], 'DAC': [], 'mean': [], 'std': []}
    for ibl, bl in enumerate(outdata.keys()):
        bldata = outdata[bl]
        # print(bldata.keys())
        # print(len(bldata['pedestal'][0]))
        # print(bldata['DAC'])
        for idac, dac in enumerate(bldata['DAC']):
            pedestal = bldata['pedestal'][idac]
            posAmp = bldata['posAmp'][idac]
            negAmp = bldata['negAmp'][idac]
            # pedestal
            pedmean = statistics.median(pedestal)
            pedstd = statistics.stdev(pedestal)
            pedmin, pedmax = pedmean-3*pedstd, pedmean+3*pedstd
            # posAmp
            posAmpmean = statistics.median(posAmp)
            posAmpstd = statistics.stdev(posAmp)
            posAmpmin, posAmpmax = posAmpmean-3*posAmpstd, posAmpmean+3*posAmpstd
            # negAmp
            negAmpmean = statistics.median(negAmp)
            negAmpstd = statistics.stdev(negAmp)
            negAmpmin, negAmpmax = negAmpmean-3*negAmpstd, negAmpmean+3*negAmpstd
            for _ in range(10):
                # pedestal
                posmin = np.where(pedestal < pedmin)[0]
                posmax = np.where(pedestal > pedmax)[0]
                pos = np.concatenate((posmin, posmax))
                pedestal = np.delete(pedestal, pos)
                pedmean = statistics.median(pedestal)
                pedstd = statistics.stdev(pedestal)
                pedmin, pedmax = pedmean-3*pedstd, pedmean+3*pedstd
                # posAmp
                posmin = np.where(posAmp < posAmpmin)[0]
                posmax = np.where(posAmp > posAmpmax)[0]
                pos = np.concatenate((posmin, posmax))
                posAmp = np.delete(posAmp, pos)
                posAmpmean = statistics.median(posAmp)
                posAmpstd = statistics.stdev(posAmp)
                posAmpmin, posAmpmax = posAmpmean-3*posAmpstd, posAmpmean+3*posAmpstd
                # negAmp
                posmin = np.where(negAmp < negAmpmin)[0]
                posmax = np.where(negAmp > negAmpmax)[0]
                pos = np.concatenate((posmin, posmax))
                negAmp = np.delete(negAmp, pos)
                negAmpmean = statistics.median(negAmp)
                negAmpstd = statistics.stdev(negAmp)
                negAmpmin, negAmpmax = negAmpmean-3*negAmpstd, negAmpmean+3*negAmpstd
            if saveDist:
                plot_distribution(array=pedestal, xtitle='pedestal', output_path_fig=output_path_fig, figname='_'.join([cali_item, 'pedestal', bl, str(dac)]))
                plot_distribution(array=posAmp, xtitle='posAmp', output_path_fig=output_path_fig, figname='_'.join([cali_item, 'posAmp', bl, str(dac)]))
                plot_distribution(array=negAmp, xtitle='negAmp', output_path_fig=output_path_fig, figname='_'.join([cali_item, 'negAmp', bl, str(dac)]))
            
            # pedestal
            out_dict['testItem'].append('pedestal')
            out_dict['BL'].append(bl)
            out_dict['DAC'].append(dac)
            out_dict['mean'].append(pedmean)
            out_dict['std'].append(pedstd)
            # posAmp
            out_dict['testItem'].append('posAmp')
            out_dict['BL'].append(bl)
            out_dict['DAC'].append(dac)
            out_dict['mean'].append(posAmpmean)
            out_dict['std'].append(posAmpstd)
            # negAmp
            out_dict['testItem'].append('negAmp')
            out_dict['BL'].append(bl)
            out_dict['DAC'].append(dac)
            out_dict['mean'].append(negAmpmean)
            out_dict['std'].append(negAmpstd)

    for key in out_dict.keys():
        print(len(out_dict[key]))
    out_df = pd.DataFrame(out_dict).sort_values(by=['testItem', 'BL'])
    # print(out_df.head())
    out_df.to_csv('/'.join([output_path, cali_item + '.csv']))


    # plt.figure()
    # for idac, dac in enumerate(DACs[1]):
    #     plt.hist(outdata['SNC1']['posAmp'][idac], bins=50, alpha=0.5, label='DAC = {}'.format(dac))
    #     # break
    # plt.legend()
    # plt.show()
    # sys.exit()

if __name__ == '__main__':
    # root_path = '../../Data_BNL_CE_WIB_SW_QC'
    # output_path = '../../Analyzed_BNL_CE_WIB_SW_QC'

    # # list_data_dir = [dir for dir in os.listdir(root_path) if '.zip' not in dir]
    # root_path = '../../B010T0004'
    # list_data_dir = [dir for dir in os.listdir(root_path) if (os.path.isdir('/'.join([root_path, dir]))) and (dir!='images')]
    # for i, data_dir in enumerate(list_data_dir):
    #     # if '20240703163752' in data_dir:
    #         asicdac = QC_CALI(root_path=root_path, data_dir=data_dir, output_path=output_path, tms=61, QC_filename='QC_CALI_ASICDAC.bin', generateWf=True)
    #         asicdac.runASICDAC_cali(saveWfData=False)
    #         subdir = os.listdir('/'.join([root_path, data_dir]))[0]
    #         if 'QC_CALI_ASICDAC_47.bin' in os.listdir('/'.join([root_path, data_dir, subdir])):
    #             asic47dac = QC_CALI(root_path=root_path, data_dir=data_dir, output_path=output_path, tms=64, QC_filename='QC_CALI_ASICDAC_47.bin', generateWf=True)
    #             asic47dac.runASICDAC_cali(saveWfData=False)
    #         datdac = QC_CALI(root_path=root_path, data_dir=data_dir, output_path=output_path, tms=62, QC_filename='QC_CALI_DATDAC.bin', generateWf=True)
    #         datdac.runASICDAC_cali(saveWfData=False)
    #         direct_cali = QC_CALI(root_path=root_path, data_dir=data_dir, output_path=output_path, tms=63, QC_filename='QC_CALI_DIRECT.bin', generateWf=True)
    #         direct_cali.runASICDAC_cali(saveWfData=False)
    root_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    output_path = '../../Analysis'
    list_chipID = os.listdir(root_path)
    # for chipID in list_chipID:
    #     ana_cali = QC_CALI_Ana(root_path=root_path, output_path=output_path, chipID=chipID, CALI_item='QC_CALI_ASICDAC_47')
    #     ana_cali.makeplots()
    StatAna_cali(root_path=root_path, output_path=output_path, cali_item='QC_CALI_DIRECT', saveDist=True)