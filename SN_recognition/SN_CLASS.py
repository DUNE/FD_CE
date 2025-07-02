import sys
import os
import numpy as np
from SN_chip_CPM_scan import ocr_chip

class SN_CLASS():
    def __init__(self):
        self.chip_ds = {}
        pass
    #    self.imagedir =  "/images/"
        
    def Chips_on_Tray(self, rootdir):
        fn = rootdir  + "/chips_on_tray.txt"
        try:
            with open(fn, "r") as fp:
                rmsg = fp.read() 
        except:
            print (f"can not open{fn}" )
            exit()
        tmps = rmsg.split(",")
        #chips = []
        for tmp in tmps:
            try:
                t = int(tmp)
                #chips.append(t)
                #self.chip_ds[t] = {}
            except:
                pass

    def chip_ocr(self, rootdir):
        imagedir = rootdir + "/images/"
        ocrdirs = [d for d in os.listdir(imagedir) if "_OCR" in d[-4:]]
        ocrdirs.sort()
        if len(ocrdirs) > 0:
            nocrdir =ocrdirs[-1]
        ocr_imgdir = "/".join([imagedir, nocrdir])
        post_ocr_imgdir = ocr_imgdir  + "_POST"
        if not os.path.exists(post_ocr_imgdir):  # Check if the folder already exists
            os.mkdir(post_ocr_imgdir)

        image_fns = [d for d in os.listdir(ocr_imgdir) ]
        for ifn in image_fns:
            if "tray_label" in ifn:
                pass
            else:
                if "NAN" not in ifn:
                    tmps = ifn[0:-4].split("_")
                    self.chip_ds[int(tmps[1])] = {"Degree":int(tmps[2]), "fn":ifn}
        chips = list(self.chip_ds.keys())
        chips.sort()
        for key in chips:
            fn = "/".join([ocr_imgdir , self.chip_ds[key]["fn"]])
            print (fn)
            ocr_chip(image_fp = ocr_imgdir, image_fn = self.chip_ds[key]["fn"], ocr_image_dir = "/".join([post_ocr_imgdir, self.chip_ds[key]["fn"]]))
            

        #print ( self.chip_ds)

if __name__ == '__main__':
    rootdir = "C:/SGAO/ColdTest/Tested/DAT_LArASIC_QC/Tested/B099T0097/"
    sn = SN_CLASS()
    chips = sn.Chips_on_Tray(rootdir)
    sn.chip_ocr(rootdir)




