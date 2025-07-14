################################################################
#   Author : Rado           Date: Nov 24,2024
#   Script generating the QC report: summary with data in a csv
#   file and summary with plots in a pdf file
################################################################

import os, sys, csv
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from datetime import datetime

# Import analysis classes
#from QC_PWR import QC_PWR_analysis
#from QC_PWR_CYCLE import PWR_CYCLE_Ana
#from QC_CALIBRATION import QC_CALI_Ana
#from QC_RMS import RMS_Ana
#from QC_Cap_Meas import QC_Cap_Meas_Ana
#from QC_CHKRES import QC_CHKRES_Ana
#from QC_FE_MON import QC_FE_MON_Ana
#from Init_checkout import QC_INIT_CHK_Ana

class QC_Report():
    def __init__(self, root_path: str, input_path: str, chipID: str):
        self.chipID = chipID
        self.root_path = root_path
        self.input_path = input_path

    def generate_summary_csv(self):
        csv_fp = "/".join(self.input_path, chipID, "QC_INIT_CHK.csv"
        inin_chk_data = pd.read_csv(csv_fp)
        ##init_chk_data = self.get_INIT_CHK()
        #input ("aaa")
        #pwr_data = self.get_QC_PWR()
        #pwr_cycle_data = self.get_QC_PWR_CYCLE()
        #rms_data = self.get_QC_RMS()
        #capacitance_data = self.get_QC_Cap_Meas()
        #chkres_data = self.get_QC_CHKRES()
        #fe_mon_data = self.get_FE_MON()

        #cali_data = []
        #for cali_item in ['QC_CALI_ASICDAC', 'QC_CALI_ASICDAC_47', 'QC_CALI_DATDAC', 'QC_CALI_DIRECT']:
        ## for cali_item in ['QC_CALI_ASICDAC', 'QC_CALI_DATDAC']:
        ## for cali_item in ['QC_CALI_ASICDAC']:
        #    cali_data += self.get_QC_CALI(cali_item=cali_item)

        month_day_year = '_'.join(self.logs_dict['date'].split('_')[:3])
        header = [#[self.logs_dict['item_name'], self.logs_dict['env']],
                  ['RTS_Timestamp', self.logs_dict['RTS_timestamp'], 'Environment : {}'.format(self.logs_dict['env'])],
                  ['Test site', self.logs_dict['Test Site']],
                  ['RTS_Property_ID', self.logs_dict['RTS_Property_ID']],
                  ['RTS_Chamber', self.logs_dict['RTS chamber']],
                  ['DAT_ID', self.logs_dict['DAT_ID']],
                  ['DAT_Rev', self.logs_dict['DAT rev']],
                  ['DAT_on_WIB_slot', self.logs_dict['WIB_slot']],
                  ['Date', month_day_year],
                  ['Tester', self.logs_dict['Tester']],
                  ['DUT', self.logs_dict['DUT']],
                  ['Tray_ID', self.logs_dict['Tray ID']],
                  ['SN', self.logs_dict['SN']],
                  ['DUT_location_on_tray', self.logs_dict['DUT_location_on_tray']],
                  ['DUT_location_on_DAT', self.logs_dict['DUT_location_on_DAT']],
                  ['Chip_Mezzanine_1_in_use', self.logs_dict['Chip_Mezzanine_1_in_use']],
                  ['Chip_Mezzanine_2_in_use', self.logs_dict['Chip_Mezzanine_2_in_use']],
                 ]
        csv_data_rows = []
        for h in header:
            csv_data_rows.append(h)
        
        for d in init_chk_data:
            csv_data_rows.append(d)
        for d in pwr_data:
            csv_data_rows.append(d)
        for d in chkres_data:
            csv_data_rows.append(d)
        for d in fe_mon_data:
            csv_data_rows.append(d)
        for d in pwr_cycle_data:
            csv_data_rows.append(d)
        for d in cali_data:
            csv_data_rows.append(d)
        for d in rms_data:
            csv_data_rows.append(d)
        csv_data_rows.append(capacitance_data)
        # print(csv_data_rows)
        with open('/'.join([self.output_path, self.chipID,'{}.csv'.format(self.chipID)]), 'w') as f:
            csvwriter = csv.writer(f, delimiter=',')
            csvwriter.writerows(csv_data_rows)
        # print(self.chipID)

if __name__ == "__main__":

    # try:
    #     # Generate the PDF
    #     create_simple_pdf()
    #     print("PDF has been generated successfully!")
    # except Exception as e:
    #     print(f"An error occurred: {str(e)}")
    # root_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    # output_path = '../../Analysis'
    env = 'RT'
    root_path = f'../../out_B010T0004__{env}'
    output_path = f'../../analyzed_B010T0004_{env}'
    list_chipID = os.listdir(root_path)
    for chipID in list_chipID:
        report = QC_Report(root_path=root_path, chipID=chipID, output_path=output_path)
        report.generate_summary_csv()
        # sys.exit()
