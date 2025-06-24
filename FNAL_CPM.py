import os
import sys
import re
import time
import pandas as pd
from PIL import Image
import cv2
import numpy as np
import requests
import base64
import io
import json
import cv2
import csv

############ Global constants #################
w = 650
h = 450
x = 900
y = 720
crop_box = (x, y, x + w, y + h)
image_directory = '/Users/tcontrer/Downloads/' #"/Users/RTS/RTS_data/images/"
ocr_results_dir = "Tested/fnal_cpm_results/"
#################################################

def encode_image(image):
    """
    Encodes an image for OCR into base64 binary.

    Input:
        image [PIL Image]
    Returns:
        im_b64 [bas64 binary]
    """
    if not isinstance(image, Image.Image):
        image = Image.open(image).convert("RGB")

    max_size = 448 * 16
    if max(image.size) > max_size:
        w, h = image.size
        if w > h:
            new_w = max_size
            new_h = int(h * max_size / w)
        else:
            new_h = max_size
            new_w = int(w * max_size / h)
        image = image.resize((new_w, new_h), resample=Image.BICUBIC)

    # Convert image to base64
    buffered = io.BytesIO()
    image.save(buffered, format="PNG")
    im_b64 = base64.b64encode(buffered.getvalue()).decode()

    return im_b64

def preprocess_image(image_name, image_dir, ocr_results_dir):
    """
    Preprocesses images for OCR, by adjusting the contrast, 
    cropping based on the crop_box global variable, and rotates 
    180 degrees, saving the resulting image.
    
    Input:
        image_name [str]: Name of the image file
        image_dir [name]: Full directory of the image
    """

    # Extract image_number from the filename (assuming it's before the first '_')
    image_number = image_name.split('_')[0]

    try:
        # Open the image
        image = Image.open(image_dir + image_name)
    except IOError as e:
        print(f"Process ID #{image_number}: ERROR (cannot open image). {e}")
        return None

    # Rotate the image 180 degrees
    rotated_image = image.rotate(180)

    # Crop the image to the central chip
    cropped_chip = rotated_image.crop(crop_box)

    # Convert the cropped image to OpenCV format
    open_cv_image = cv2.cvtColor(np.array(cropped_chip), cv2.COLOR_RGB2BGR)

    # Resize the image to make the text more clear
    resized_image = cv2.resize(open_cv_image, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)

    # Save the resized image 
    temp_image_path = os.path.join(ocr_results_dir, f"{image_number}.png")
    cv2.imwrite(temp_image_path, resized_image)

    return temp_image_path


def perform_ocr_minicpm(image_path):
    """
    Performs the OCR on an image, returning a string of the results
    or prints errors and returns None.

    Inputs:
        image_path [str]: full path of the image to run over
    Returns:
        [str] of OCR results on succes or None
    """
    # Load and encode the image
    image = Image.open(image_path)
    encoded_image = encode_image(image)

    # API:
    url = "http://localhost:11434/api/generate"

    headers = {
        "Content-Type": "application/json",
    }

    # Set up:
    data = {
        "model": "aiden_lu/minicpm-v2.6:Q4_K_M",
        "prompt": "Please OCR this image with all output texts in one line with no space",
        "images": [encoded_image],
        "sampling": False,
        "stream": False,
        "num_beams": 3,
        "repetition_penalty": 1.2,
        "max_new_tokens": 2048,
        "max_inp_length": 4352,
        "decode_type": "beam_search",
        "options": {
            "seed": 42,
            "temperature": 0.0,
            "top_p": 0.1,
            "top_k": 10,
            "repeat_penalty": 1.0,
            "repeat_last_n": 0,
            "num_predict": 42,
        },
    }

    # Send the request to MiniCPM API
    response = requests.post(url, headers=headers, data=json.dumps(data))

    # Process the response
    if response.status_code == 200:
        try:
            responses = response.text.strip().split('\n')
            for line in responses:
                data = json.loads(line)
                actual_response = data.get("response", "")
                if actual_response:
                    return actual_response.strip()
        except json.JSONDecodeError as e:
            print(f"Error parsing JSON: {e}")
            print("Error: Unable to process OCR")
            return
    else:
        print(f"Error {response.status_code}: {response.text}")
        print("Error: API request failed")
        return

def validate_COLDATA_OCR(ocr_result, process_id):
    """
    Validates the OCR result, assuming it processed a COLDATA chip
    which, upon perfect success, should look like:

        COLDATA  NBMY62.00 XXXXX YYYY
    
    with the second word being the wafer identification number, the third
    and fourth words containing the serial number. 

    Inputs:
        ocr_result [str]: string of OCR result
        process_id [int]: process id used to keep track of different
                          OCR tests.
    Returns:
        serial_number [str]: Returns a string of the serial number in
                             the format YYYY-XXXXX, or None if failed
        wafer_id [str]: Returns a string of the wafer lot id, in the
                        format AAAAXX.XX, or None if failed
        warnings [list of str]: A list of all warnings from validation
    """

    print(f"    Raw OCR result: {ocr_result}")

    warnings = []
    serial_number = None
    wafer_id = None

    # Remove all characters except letters and numbers using regex
    ocr_result = re.sub(r'[^a-zA-Z0-9]', '', ocr_result)

    print(f"    Stripped OCR results: {ocr_result}")

    if len(ocr_result) != 24:
        warnings.append(f"ERROR: Incorrect number of characters found on chip. Needed 24, found {len(ocr_result)}")
        return serial_number, wafer_id, warnings

    if not ocr_result[0:7] == "COLDATA":
        warnings.append(f"WARNING: Could not read 'COLDATA' on chip. OCR found '{ocr_result[0:7]}'")
    
    # Checking wafer lot id
    lot = ocr_result[7:15]
    if (lot[0:4].isalpha() and lot[4:].isnumeric()): 
        wafer_id = lot[0:6] + "." + lot[6:]
    else:
        warnings.append(f"WARNING: Wafer ID does not have correct character types. OCR found '{lot}'")
        print(f"lot = {lot}")

    # Checking serial number
    sn = ocr_result[15:]
    if not len(sn) == 9:
        warnings.append(f"WARNING: Incorrection length of serial number. Needed 9, found {len(sn)}")
    elif sn.isnumeric():
        serial_number = sn[5:] + "-" + sn[0:5]
    else:
        warnings.append(f"ERROR: serial number could not be found. OCR found '{sn}'")
        return None, wafer_id, warnings
    

    if serial_number or wafer_id:
        print(f"-----> Process ID #{process_id}")
        if serial_number:
            print(f"-------->Serial Number (SN): {serial_number}")
        if wafer_id:
            print(f"-------->Wafer Lot: {wafer_id}")
    
    return serial_number, wafer_id, warnings

def SaveChipInfo(image_id, serial_number, wafer_id, output_dir):
    """
    Saves the serial number, wafer id, and image id of a given chip
    to a csv file.

    Inputs:
        image_id [str]: name of the image of the chip (without the extension)
        serial_number [str]: serial number of the chip, in the form XXXX-YYYYY
        wafer_id [str]: wafer lot number, in the form AAAAXX.YY
        output_dir [str]: Directory to save the chip info to
    Returns:
        chipinfo_file [str]: full path to file that the SN was saved to.
    """

    chipinfo_file = output_dir + "ChipInfo_" + image_id + ".csv"

    chipinfo = {"SN":serial_number,
                "Wafer":wafer_id,
                "image":image_id}

    print(f'Saving chip info to {chipinfo_file}.')

    with open(chipinfo_file, 'w') as f:
        writer = csv.DictWriter(f, chipinfo.keys())
        writer.writeheader()
        writer.writerow(chipinfo)

    return chipinfo_file

def ShowOCRResult(image_id, ocr_results_dir, chipinfo_dir):
    """
    Prints the chip information and open the corresponding
    image for comparison. 

    Inputs:
        image_id [str]: Name of png image that had the OCR run
                        over and the name of the text file
                        with the results.
        ocr_result_dir [str]: Directory of OCR results
        chipinfo_dir [str]: directory of the csv file containing
                            the chip information
    """

    image_file = image_id.split("_")[0] + ".png"
    chipinfo_file = "ChipInfo_" + image_id.split("_")[0] + ".csv"

    print(f"Opening files {image_file} and {chipinfo_file}")

    try:
        f = open(chipinfo_dir + chipinfo_file, 'r')
    except OSError:
        print(f"ERROR!! Could not open/read file: {chipinfo_dir + chipinfo_file}")
        return

    with f:
        csvFile = csv.DictReader(f)
        print("     Chip Info:")
        for lines in csvFile:
            print(lines)

    try:
        image = cv2.imread(ocr_results_dir + image_file)
    except cv2.error as e:
        print(f"ERROR!! Couldn't open image file: {ocr_results_dir + image_file}")
        return

    cv2.imshow("chip", image)
    cv2.waitKey(0)
    
    return

def RunOCR(image_directory, image_file, ocr_results_dir, to_rts_config=False, socket_label='CD0', config_file='asic_info.csv'):
    """
    Preprocess a given image, perform the ocr, and write
    the result to a file upon success.

    Inputs:
        ocr_queue [Queue]: multiprocessing queue for threading
        image_directory [str]: directory of image
        image_file [str]: file name of image
        ocr_results_dir [str]: directory to save results
    """
    print("Running OCR...")
    success = False
    # Extract image_number from the filename (assuming it's before the first '_')
    image_number = image_file.split('_')[0]
    
    # Preprocess image for best OCR results
    temp_image_path = preprocess_image(image_file + ".bmp", image_directory, ocr_results_dir)
    
    if temp_image_path:
        # Perform OCR using MiniCPM
        ocr_result = perform_ocr_minicpm(temp_image_path)

        if ocr_result:
            serial_number, wafer_id, warnings = validate_COLDATA_OCR(ocr_result, image_number)
            [print(w) for w in warnings]
            
            chipinfo_file = SaveChipInfo(image_number, serial_number, wafer_id, ocr_results_dir)
            success = True

    if to_rts_config:
        WriteToRTSConfig(chipinfo_file, config_file, socket_label)

    return success

def WriteToRTSConfig(chipinfo_file, config_file, socket_label):
    """
    Write the serial number of a given chip to the RTS config file.
    Inputs:
        chipinfo_file [str]: file with chip information
        config_file [str]: RTS config file
        socket_label [str]: label of chip socket (ex. CD0 or CD1)
    """

    chip_df = pd.read_csv(chipinfo_file)
    sn = str(chip_df['SN'][0])

    config_df = pd.read_csv(config_file)

    # Find corresponding socket label and overwrite with new SN
    row_num = 0
    for i in config_df['Item']:
        if i == socket_label: 
            config_df.loc[row_num, 'Value'] = sn
            break
        row_num += 1

    # Overwrite existing csv
    config_df.to_csv(config_file)

    return
   
def RunOverDir(ocr_results_dir, image_directory):
    """
    Run OCR over all bmp images with '_SN' in the name in a given directory.
    Makes the ocr_results_dir if it does not already exist. 

    Inputs:
        ocr_results_dir [str]: String containing directory of ocr results
        image_directory [str]: String containing directory of images to
                               perform OCR on. 
    """

    # Ensure the directory exists
    os.makedirs(ocr_results_dir, exist_ok=True)
    if not os.path.isdir(image_directory):
        print(f"The directory {image_directory} does not exist. Please check the path.")
        exit(1)

    # List all files in the directory that contain "_SN.bmp"
    all_files = os.listdir(image_directory)
    image_files = [f for f in all_files if "_SN.bmp" in f]

    if not image_files:
        print(f"No files with '_SN.bmp' found in the directory {image_directory}.")
        exit(1)

    # Iterate through each image file
    for image_file in image_files:
        RunOCR(image_directory, image_file, ocr_results_dir)
    
    return

def CheckAllOCRResults(ocr_results_dir):
    """
    Prints each ocr result and opens the corresponding 
    image file for comparison one at a time for all
    pairs in the ocr_results_dir directory.

    Inputs:
        ocr_results_dir [str]: directory of ocr results
    """
    all_files = os.listdir(ocr_results_dir)
    image_files = [f for f in all_files if ".png" in f]
    text_files = [f for f in all_files if ".txt" in f]

    image_files.sort()
    text_files.sort()

    print(f"Checking {len(image_files)} results...")

    for i in range(len(image_files)):
        image_id = image_files[i].split(".")[0]

        if image_id != text_files[i].split(".")[0]:
            print("WARNING!! Image and text file do not match.")
            continue

        print(f"\n--- Opening files {image_files[i]} and {text_files[i]} ---")

        with open(ocr_results_dir + text_files[i]) as f:
            # Read the contents of the file into a variable
            results = f.read()

        serial_number, wafer_id, warnings = validate_COLDATA_OCR(results, image_id)

        SaveChipInfo(image_id, serial_number, wafer_id, ocr_results_dir)

        [print(w) for w in warnings]

        ShowOCRResult(image_id, ocr_results_dir, ocr_results_dir)

###################################################################################
if __name__=="__main__":

    start_time = time.time()

    image_id = "20250402142447_SN"
    RunOCR(image_directory, image_id, ocr_results_dir)
    #image_id = "20250402170946"
    ShowOCRResult(image_id, ocr_results_dir, ocr_results_dir)
    #CheckAllOCRResults(ocr_results_dir)

    print("### %s seconds ###" % (time.time() - start_time))
