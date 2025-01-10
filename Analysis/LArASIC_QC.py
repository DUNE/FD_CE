import os
from datetime import datetime
from Init_checkout import QC_INIT_CHECK, QC_INIT_CHK_Ana
from QC_PWR import QC_PWR, QC_PWR_analysis
from QC_PWR_CYCLE import PWR_CYCLE, PWR_CYCLE_Ana
from QC_CHKRES import QC_CHKRES, QC_CHKRES_Ana
from QC_FE_MON import FE_MON, QC_FE_MON_Ana
from QC_RMS import RMS, RMS_Ana
from QC_CALIBRATION import QC_CALI, QC_CALI_Ana
from QC_Cap_Meas import QC_Cap_Meas, QC_Cap_Meas_Ana
#
from QC_Report import QC_Report

if __name__ =="__main__":
    ## decoding part
    root_path = '../../B010T0004'
    output_path = '../../out_B010T0004'
    list_data_dir = [dir for dir in os.listdir(root_path) if (os.path.isdir('/'.join([root_path, dir]))) and (dir!='images')]
    for data_dir in list_data_dir:
        print(data_dir)
        t0 = datetime.now()
        print('start time : {}'.format(t0))
        # # Initialization checkout
        init_chk = QC_INIT_CHECK(root_path=root_path, data_dir=data_dir, output_dir=output_path)
        init_chk.decode_INIT_CHK(generateQCresult=False, generatePlots=False)
        # # Power consumption measurement
        qc_pwr = QC_PWR(root_path=root_path, data_dir=data_dir, output_dir=output_path)
        qc_pwr.decode_FE_PWR()
        # # Channel response checkout
        qc_checkres = QC_CHKRES(root_path=root_path, data_dir=data_dir, output_dir=output_path)
        qc_checkres.decode_CHKRES()
        # FE monitoring
        fe_mon = FE_MON(root_path=root_path, data_dir=data_dir, output_path=output_path)
        fe_mon.decodeFE_MON()
        # Power cycling
        pwr_cycle = PWR_CYCLE(root_path=root_path, data_dir=data_dir, output_path=output_path)
        pwr_cycle.decode_PwrCycle()
        # # RMS noise
        rms = RMS(root_path=root_path, data_dir=data_dir, output_path=output_path)
        rms.decodeRMS()
        # # ASICDAC Calibration
        asicdac = QC_CALI(root_path=root_path, data_dir=data_dir, output_path=output_path, tms=61, QC_filename='QC_CALI_ASICDAC.bin', generateWf=False)
        asicdac.runASICDAC_cali(saveWfData=False)
        tmpdir = os.listdir('/'.join([root_path, data_dir]))[0]
        if 'QC_CALI_ASICDAC_47.bin' in os.listdir('/'.join([root_path, data_dir, tmpdir])):
            asic47dac = QC_CALI(root_path=root_path, data_dir=data_dir, output_path=output_path, tms=64, QC_filename='QC_CALI_ASICDAC_47.bin', generateWf=False)
            asic47dac.runASICDAC_cali(saveWfData=False)
        datdac = QC_CALI(root_path=root_path, data_dir=data_dir, output_path=output_path, tms=62, QC_filename='QC_CALI_DATDAC.bin', generateWf=False)
        datdac.runASICDAC_cali(saveWfData=False)
        direct_cali = QC_CALI(root_path=root_path, data_dir=data_dir, output_path=output_path, tms=63, QC_filename='QC_CALI_DIRECT.bin', generateWf=False)
        direct_cali.runASICDAC_cali(saveWfData=False)
        ## Calibration capacitor measurement
        cap = QC_Cap_Meas(root_path=root_path, data_dir=data_dir, output_path=output_path, generateWf=True)
        cap.decode_CapMeas()
        tf = datetime.now()
        print('end time : {}'.format(tf))
        deltaT = (tf - t0).total_seconds()
        print("Decoding time : {} seconds".format(deltaT))
        print("=xx="*20)

    ## analysis part
    decoded_path = '../../out_B010T0004'
    analyzed_path = '../../analyzed_B010T0004'
    list_chipID = os.listdir(decoded_path)
    for chipID in list_chipID:
        report = QC_Report(root_path=decoded_path, chipID=chipID, output_path=analyzed_path)
        report.generate_summary_csv()