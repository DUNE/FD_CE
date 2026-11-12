import os
import re
import pandas as pd
from PIL import Image
import cv2
import numpy as np
import requests
import base64
import io
import json


def image_preprocess(image_fp, image_fn, proc_image_dir):
    # Just does the image cropping/rotation for the move comparisons

    image_path ="/".join([ image_fp , image_fn])
#    if "_SN" not in image_fn:
#        print (f"{image_fn} is wrong")
    if os.path.isfile(image_path): 
        pass
    else:
        print ("File not found")
        return None

    # Constants
    # crop_box = (x, y, x+w, y+h)  # (x, y, x+w, y+h)
    ### MSU crop box size
    w = 326 *1.4 #  680
    h = 326 *1.4 #  680 
    x = 1279 # 1120 # 890 12
    y = 959 # 792 #  600 
    crop_box = (x - w/2, y-h/2, x + w/2, y + h/2)
    
    # Extract image_number from the filename (assuming it's before the first '_')
    # image of name Alignment_{timestamp}_DAT{DAT_nr}_skt{skt_nr}.bmp
    image_number = image_fn.split('_')[0]
    
    # Create a directory with the name of image_number
    #os.makedirs(image_number, exist_ok=True)
    
    try:
        # Open the image
        #print (image_path)
        image = Image.open(image_path)
    except IOError as e:
        #print(f"Process ID #{image_number}: ERROR (cannot open image). {e}")
        return None
    
    # Crop the image to the central chip
    cropped_chip = image.crop(crop_box)
    
    # Convert the cropped image to OpenCV format
    open_cv_image = cv2.cvtColor(np.array(cropped_chip), cv2.COLOR_RGB2BGR)
    
    # Resize the image to make the text more clear
    resized_image = cv2.resize(open_cv_image, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    
    #cv2.imwrite(ocr_image_dir, resized_image)
    cv2.imwrite(proc_image_dir, resized_image)

def DisplayChips(op_ts,DAT_nr):
    # Display all of the chips from the alignment check

    # op_ts is the timestamp of the operation,
    # Check in file in AlignCheck_DAT{DAT_nr}.csv
    # Find all the images, process them, store the results
    # 