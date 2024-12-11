import sys 
import os

def rootdir_cs (duttype = "FE"):
    if "FE" in duttype:
        rootdir = "D:/DAT_LArASIC_QC/Tested/"
    elif "ADC" in duttype:
        rootdir = "D:/DAT_ColdADC_QC/Tested/"
    elif "CD" in duttype:
        rootdir = "D:/DAT_CD_QC/Tested/"
    else:
        print ("Wrong ASIC type, exit anyway")
        exit()
    return rootdir
