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

class QC_Report():
    def __init__(self, root_path: str, output_path: str, chipID: str):
        self.chipID = chipID
        self.root_path = root_path
        self.output_path = output_path
        self.logs_dict = dict()
        self.qc_data = list()

    def get_QC_PWR(self):
        pwr_ana = QC_PWR_analysis(root_path=self.root_path, chipID=self.chipID, output_path=self.output_path)
        pwr_cons_data, self.logs_dict = pwr_ana.runAnalysis(path_to_statAna='/'.join([self.output_path, 'StatAnaPWR.csv']))
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

    def generate_summary_csv(self):
        pwr_data = self.get_QC_PWR()
        pwr_cycle_data = self.get_QC_PWR_CYCLE()

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
        for d in pwr_data:
            csv_data_rows.append(d)
        for d in pwr_cycle_data:
            csv_data_rows.append(d)
        print(csv_data_rows)
        with open('test.csv', 'w') as f:
            csvwriter = csv.writer(f, delimiter=',')
            csvwriter.writerows(csv_data_rows)
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
