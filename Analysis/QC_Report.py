################################################################
#   Author : Rado           Date: Nov 24,2024
#   Script generating the QC report: summary with data in a csv
#   file and summary with plots in a pdf file
################################################################

import os, sys, csv
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from fpdf import FPDF
from datetime import datetime

# Import analysis classes
from QC_PWR import QC_PWR_analysis
from QC_PWR_CYCLE import PWR_CYCLE_Ana
from QC_CALIBRATION import QC_CALI_Ana
from QC_RMS import RMS_Ana
from QC_Cap_Meas import QC_Cap_Meas_Ana
from QC_CHKRES import QC_CHKRES_Ana
from QC_FE_MON import QC_FE_MON_Ana
from Init_checkout import QC_INIT_CHK_Ana

class QC_Report():
    def __init__(self, root_path: str, output_path: str, chipID: str):
        self.chipID = chipID
        self.root_path = root_path
        self.output_path = output_path
        self.logs_dict = dict()
        self.qc_data = list()

    def get_INIT_CHK(self):
        init_chk = QC_INIT_CHK_Ana(root_path=self.root_path, output_path=self.output_path, chipID=self.chipID)
        # init_chk_data = init_chk.run_Ana(path_to_stat='/'.join([self.output_path, 'StatAna_INIT_CHK.csv']))
        init_chk_data = init_chk.run_Ana()
        return init_chk_data
    
    def get_QC_PWR(self):
        pwr_ana = QC_PWR_analysis(root_path=self.root_path, chipID=self.chipID, output_path=self.output_path)
        # pwr_cons_data, self.logs_dict = pwr_ana.runAnalysis(path_to_statAna='/'.join([self.output_path, 'StatAnaPWR.csv']))
        pwr_cons_data, self.logs_dict = pwr_ana.runAnalysis(path_to_statAna=None)
        # print(logs)
        # print(pwr_cons_data)
        # sys.exit()
        return pwr_cons_data
    
    def get_QC_PWR_CYCLE(self):
        pwrcycle_ana = PWR_CYCLE_Ana(root_path=self.root_path, chipID=self.chipID, output_path=self.output_path)
        pwrcycle_data, logs = pwrcycle_ana.run_Ana(path_to_statAna='/'.join([self.output_path, 'StatAnaPWR_CYCLE.csv']))
        print(self.logs_dict==logs)
        print(self.logs_dict)
        # print(logs)
        # sys.exit()
        # print(logs)
        # print(pwrcycle_data)
        # sys.exit()
        return pwrcycle_data #, logs
    
    def get_FE_MON(self):
        ana_femon = QC_FE_MON_Ana(root_path=self.root_path, output_path=self.output_path, chipID=self.chipID)
        fe_mon_data = ana_femon.run_Ana(path_to_statAna='/'.join([self.output_path, 'StatAna_FE_MON.csv']))
        return fe_mon_data
    
    def get_QC_CHKRES(self):
        chk_res = QC_CHKRES_Ana(root_path=self.root_path, chipID=self.chipID, output_path=self.output_path)
        # chkres_data = chk_res.run_Ana(path_to_stat='/'.join([self.output_path, 'StatAna_CHKRES.csv']))
        chkres_data = chk_res.run_Ana()
        return chkres_data

    def get_QC_CALI(self, cali_item='QC_CALI_ASICDAC'):
        ana_cali = QC_CALI_Ana(root_path=self.root_path, output_path=self.output_path, chipID=self.chipID, CALI_item=cali_item)
        cali_data = ana_cali.run_Ana(generatePlots=False, path_to_statAna='/'.join([self.output_path, '{}_GAIN_INL.csv'.format(cali_item)]))
        return cali_data # re-run the decoding so that the logs can be updated

    def get_QC_RMS(self):
        rms_ana = RMS_Ana(root_path=self.root_path, chipID=self.chipID, output_path=self.output_path)
        # rms_data = rms_ana.run_Ana(path_to_statAna='/'.join([self.output_path, 'StatAna_RMS.csv']), generatePlots=False)
        rms_data = rms_ana.run_Ana(path_to_statAna=None, generatePlots=False)
        return rms_data

    def get_QC_Cap_Meas(self):
        cap_meas = QC_Cap_Meas_Ana(root_path=self.root_path, output_path=self.output_path, chipID=self.chipID)
        data = cap_meas.run_Ana(path_to_stat='/'.join([self.output_path, 'QC_Cap_Meas.csv']), generatePlots=False)
        return data
    
    def generate_summary_csv(self):
        pwr_data = self.get_QC_PWR()
        # pwr_cycle_data = self.get_QC_PWR_CYCLE()
        rms_data = self.get_QC_RMS()
        # capacitance_data = self.get_QC_Cap_Meas()
        chkres_data = self.get_QC_CHKRES()
        # fe_mon_data = self.get_FE_MON()
        init_chk_data = self.get_INIT_CHK()

        cali_data = []
        # for cali_item in ['QC_CALI_ASICDAC', 'QC_CALI_ASICDAC_47', 'QC_CALI_DATDAC', 'QC_CALI_DIRECT']:
        # # for cali_item in ['QC_CALI_ASICDAC', 'QC_CALI_DATDAC']:
        # # for cali_item in ['QC_CALI_ASICDAC']:
        #     cali_data += self.get_QC_CALI(cali_item=cali_item)

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
        # for d in fe_mon_data:
        #     csv_data_rows.append(d)
        # for d in pwr_cycle_data:
        #     csv_data_rows.append(d)
        # for d in cali_data:
        #     csv_data_rows.append(d)
        for d in rms_data:
            csv_data_rows.append(d)
        # csv_data_rows.append(capacitance_data)
        # print(csv_data_rows)
        with open('/'.join([self.output_path, self.chipID,'{}.csv'.format(self.chipID)]), 'w') as f:
            csvwriter = csv.writer(f, delimiter=',')
            csvwriter.writerows(csv_data_rows)
        print(self.chipID)
# def create_simple_pdf(filename="sample.pdf"):
#     """
#     Creates a simple PDF file using FPDF
    
#     Parameters:
#     filename (str): Name of the output PDF file
#     """
#     # Create PDF object
#     pdf = FPDF()
    
#     # Add a page
#     pdf.add_page()
    
#     # Set font
#     pdf.set_font("Arial", size=16)
    
#     # Add title
#     pdf.cell(200, 10, txt="Sample PDF Document", ln=1, align="C")
    
#     # Set font for body text
#     pdf.set_font("Arial", size=12)
    
#     # Add timestamp
#     timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
#     pdf.cell(200, 10, txt=f"Generated on: {timestamp}", ln=1, align="L")
    
#     # Add some content
#     pdf.cell(200, 10, txt="This is a simple PDF document created using Python.", ln=1, align="L")
#     pdf.cell(200, 10, txt="You can add more content here.", ln=1, align="L")
    
#     # Save the PDF
#     pdf.output(filename)

if __name__ == "__main__":
    # try:
    #     # Generate the PDF
    #     create_simple_pdf()
    #     print("PDF has been generated successfully!")
    # except Exception as e:
    #     print(f"An error occurred: {str(e)}")
    root_path = '../../Analyzed_BNL_CE_WIB_SW_QC'
    output_path = '../../Analysis'
    list_chipID = os.listdir(root_path)
    for chipID in list_chipID:
        report = QC_Report(root_path=root_path, chipID=chipID, output_path=output_path)
        report.generate_summary_csv()
        sys.exit()
