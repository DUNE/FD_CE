"""
This program crops a chip from the input picture
based on chip coordinates. The it reads the text on the
chip using easyocr. This script has been adapted from
SN_tesserocr.py in order to work with the FNAL RTS,
on the local computer for FNAL.

Written by: Taylor Contreras 
(based on scripts by Karla Tellez Giron Flores)
"""
import os
import glob
import re
import cv2
import numpy as np
from PIL import Image
from tesserocr import PyTessBaseAPI, PSM

# Explicitly set the tessdata directory
tessdata_dir = "/Users/RTS/tessdata/"

# Define the coordinates and sizes for the chip (x, y, width, height)
# x, y are the coordinates of the top left corner of the chip.
# To add more chips, just add their corresponding set of coordinates
# separated by commas (), ()
chip_coordinates = [
   (1030, 800, 600, 360) #(1170, 710, 250, 530)
]

def adjust_contrast(image, clip_limit=0.5, tile_grid_size=(8, 8)):
    clahe = cv2.createCLAHE(clipLimit=clip_limit, tileGridSize=tile_grid_size)
    return clahe.apply(image)

def process_and_save_chips(image_path, id):
    """
    Processes an image, by rotating and adjusting the contrast, based on the 
    global variable chip_coordinate, then runs the OCR software to get the 
    text in the image. An image of the processed file used for OCR is saved,
    and the results of the OCR are returned.
    Input
        image_path [string]
    Returns
        ocr_results [array of strings]
    """
    # Read the image
    image = cv2.imread(image_path)

    # Convert to gray scale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    ocr_results = []

    for i, (x, y, w, h) in enumerate(chip_coordinates):
        chip_image = gray[y:y+h, x:x+w]

        #Rotate the chip
        rotated_chip = cv2.rotate(chip_image, cv2.ROTATE_180)

        # Adjust contrast
        contrast_enhanced_chip = adjust_contrast(rotated_chip)
        #cv2.imshow("chip", contrast_enhanced_chip)
        cv2.waitKey(0)
        out_file = f'/Users/RTS/DUNE-rts-sn-rec/Tested/fnal_results/chip_{id}.png'
        cv2.imwrite(out_file, contrast_enhanced_chip)

        pil_image = Image.fromarray(contrast_enhanced_chip)

        # Use Tesserocr to do OCR on the processed chip image
        with PyTessBaseAPI(path=tessdata_dir, psm=PSM.SPARSE_TEXT) as api:
            api.SetImage(pil_image)
            text = api.GetUTF8Text()
            ocr_results.append(text.strip())

    return ocr_results, out_file

# Function to validate OCR results
def validate_ocr_result(ocr_result, process_id, debug=False):
    """
    Validates the OCR result, assuming it processed a COLDATA chip
    which, upon success, should look like:

        COLDATA
        AAAAAAAA
        XXXXXXXX
        YYYY
    
    with the second line being the wafer identification number, the third
    and fourth line containing the serial number. 
    """

    print(f"Raw OCR result: {ocr_result}")

    warnings = []
    serial_number = None

    # Breakup results by lines and remove empty lines
    words = ocr_result.split("\n")
    words = list(filter(None, words))

    print(f"First format of OCR result: {words}")

    exp_num_lines = 4
    if len(words) < exp_num_lines:
        warnings.append(f"ERROR: Less than 4 lines ({len(words)}) were found.")
        return -99, warnings
    elif len(words) > exp_num_lines:
        warnings.append(f"WARNING: More than 4 ({len(words)}) lines were found.")
    else:
        # Remove all non-numeric parts of last two words which should be the SN
        words[-1] = re.sub(r"\D", "", words[-1])
        words[-2] = re.sub(r"\D", "", words[-2])

        print(f"Final format of OCR result: {words}")

        # Extract the Serial Number as last two lines
        serial_number = f"{words[-2]}-{words[-1]}"

        try:
            int(words[-2])
            int(words[-1])
        except:
            warnings.append("ERROR: Integer serial number not found. Please check the serial number.")

        # Define the expected first four words
        expected_first_two = ["COLDATA", "NBMY62.00"]

        # Check if there are at least 4 words to compare
        for i, expected_word in enumerate(expected_first_two):
            if words[i] != expected_word:
                warnings.append(f"(!) Warning: character mismatch in words: {words[i]} rather than {expected_first_two[i]}.")
                continue

        print(f"-----> Process ID #{process_id}. Serial Number (SN): {serial_number}")

    return serial_number, warnings

def SaveSerialNumber(serial_number, outdir="", outfile="test.txt"):

    with open(outdir + outfile, 'w') as output:
        output.write(serial_number)

if __name__ == "__main__":

    path = "/Users/RTS/RTS_data/images/"
    dir_list = os.listdir(path)
    dir_list = [file for file in dir_list if "SN" in file]

    for image_name in dir_list:
        if "_SN" in image_name:
            print("--------Processing OCR for ", image_name, "------------")
            process_id = image_name.split("_")[0]

            ocr_results, outfile = process_and_save_chips(path+image_name, process_id) #"/Users/RTS/RTS_data_FNAL/images/DF_tray_chip_p2_col1_row1.bmp")

            serial_number, warnings = validate_ocr_result(ocr_results[0], process_id, debug=True)

            # Print all warnings
            for warning in warnings:
                print(warning)

            image = cv2.imread(outfile)
            cv2.imshow("chip", image)
            cv2.waitKey(0)

            #if serial_number:
            #    SaveSerialNumber(serial_number, "/Users/RTS/RTS_data/", "serial_number.txt")
    