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
# from filelock import FileLock
############ Global constants #################
w = 326 #  680
h = 326 #  680 
x = 1120 # 890 
y = 792 #  600 
crop_box = (x, y, x + w, y + h)
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

def preprocess_image(image_name, image_dir, ocr_results_dir, angle=0):
    """
    Preprocesses images for OCR, by adjusting the contrast, 
    cropping based on the crop_box global variable, and rotates 
    180 degrees, saving the resulting image.
    
    Input:
        image_name [str]: Name of the image file
        image_dir [name]: Full directory of the image
    """
    print(f'preprocessing image:')
    print(f'image_name = {image_name}')
    print(f'image_dir  = {image_dir}')
    print(f'ocr_results_dr = {ocr_results_dir}')
    print(f'angle = {angle}')
    # Extract image_number from the filename (assuming it's before the first '_')
    image_number = image_name.split('_')[0]
    print(f'image_number = {image_number}')
    print(f'Will open file at {image_dir}{image_name}')

    try:
        # Open the image
        image = Image.open(image_dir + image_name)
    except IOError as e:
        print(f"Process ID #{image_number}: ERROR (cannot open image). {e}")
        return None


    print('Cropping to chip')
    # Crop the image to the central chip
    cropped_image = image.crop(crop_box)

    print(f'Rotating by {angle}')
    # Rotate the image 180 degrees
    rotated_image = cropped_image.rotate(angle)

    # Convert the rotated and cropped image to OpenCV format
    open_cv_image = cv2.cvtColor(np.array(rotated_image), cv2.COLOR_RGB2BGR)

    # Resize the image to make the text more clear
    resized_image = cv2.resize(open_cv_image, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)

    # Save the resized image 
    print(f'Saving image to {ocr_results_dir}{image_number}.png')
    temp_image_path = os.path.join(ocr_results_dir, f"{image_number}.png")
    cv2.imwrite(temp_image_path, resized_image)
    print(f'returning temp path at : {temp_image_path}')
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
        "model": "aiden_lu/minicpm-v2.6:Q4_K_M", # "gemma3:4b"
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
    response = requests.post(url, headers=headers, data=json.dumps(data), timeout=240)

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
        except requests.exceptions.Timeout:
            print('The request timed out')
        except requests.exceptions.RequestException as e:
            print(e)
        except Exception as e:
            print(e)
    else:
        print(f"Error {response.status_code}: {response.text}")
        print("Error: API request failed")
        return

def validate_LArASIC_OCR(ocr_result, process_id, ocr_image_dir, allow_input=True):
    """
    Validates the OCR result, assuming it processed a LArASIC chip
    which, upon perfect success, should look like:

        BNL LArASIC Version PVV AA/BB AAA-BBBBB

    with the second word being the wafer identification number, the third
    and fourth words containing the serial number. 

    Inputs:
        ocr_result [str]: string of OCR result
        process_id [int]: process id used to keep track of different
                          OCR tests.
        allow_input [bool]: If true, then if the OCR fails, the user will
                            be prompted to input the serial number. 
    Returns:
        serial_number [str]: Returns a string of the serial number in
                             the format AAA-BBBBB, or None if failed
        wafer_id [str]: Returns a string of the wafer lot id, in the
                        format AA/BB, or None if failed
        warnings [list of str]: A list of all warnings from validation
    """

    print(f"    Raw OCR result: {ocr_result}")

    warnings = []
    version_id = None
    serial_number = None
    wafer_id = None
    passed = True

   # Check for 5 spaces (6 words)
    space_count = ocr_result.count(' ')
    print(f'Found {space_count+1} words')
    if space_count != 5:
        warnings.append(f"(!) Warning: incorrect number of spaces.")

    # Split the OCR result into words
    words = ocr_result.split()

    ocr_stripped = re.sub(r'[^a-zA-Z0-9]', '', ocr_result)

    # Define the expected first three words
    expected_first_three = ["BNL", "LArASIC", "Version"] # "P5B"]

    # Check if there are at least 4 words to compare
    if len(words) >= 3:
        for i, expected_word in enumerate(expected_first_three):
            if words[i] != expected_word:
                warnings.append(f"(!) Warning: character mismatch in the first three words.")
                break
    else:
        warnings.append(f"(!) Warning: insufficient number of words.")

    # Check the format of the 4th word PXY where X is version number and Y is revision i.e. P5 or P5B
    if len(words) >=4:
        if not re.fullmatch(r"P\d[A-Za-z]?",words[3]):
            warnings.append(f"(!) Warning: character mismatch in the 4th word.")
        else:
            version_id = words[3]
    else:
        warnings.append(f"(!) Warning: Potential Error (missing 4th word).")


    # Check the format of the 5th word: "AB/CD" where A, B, C, D are digits
    if len(words) >= 5:
        if not re.fullmatch(r"\d{2}/\d{2}", words[4]):
            warnings.append(f"(!) Warning: character mismatch in the 5th word.")
        else:
            wafer_id = words[4]
    else:
        warnings.append(f"(!) Warning: Potential Error (missing 5th word).")

    # Check the format of the 6th word: "AAA-BBBBB"
    if len(words) >= 6:
        if not re.fullmatch(r"\d{3}-\d{5}", words[5]):
            warnings.append(f"(!) Warning: character mismatch in the 6th word.")         
        else:
            serial_number = words[5]
    else:
        warnings.append(f"(!) Warning: Potential Error (missing 6th word).")

    # Allow wafer and SN to be found even if not in correct order
    if not version_id:
        version_id_match = re.search(r'(P[A-Za-z0-9]*?)(?=\d{2}/)', ocr_stripped)
        if not version_id_match:
            print ('No match found in ocr_result for version')
            passed = False
            warnings.append(f"\n\n(!) ERROR (problem reading wafer ID). Please check the output .txt file and correct.")
        else:
            version_id = version_id_match

    if not wafer_id:
        wafer_id_match = re.search(r"\d{2}/\d{2}$", ocr_stripped)
        if not wafer_id_match:
            print ('No match found in ocr_result for wafer number')
            passed = False
            warnings.append(f"\n\n(!) ERROR (problem reading wafer ID). Please check the output .txt file and correct.")
        else:
            wafer_id = wafer_id_match

    if not serial_number:
        serial_number_match = re.search(r"\d{3}-\d{5}$", ocr_stripped)
        if not serial_number_match:
            print ('No match found in ocr_result for serial number')
            passed = False
            warnings.append(f"\n\n(!) ERROR (problem reading Serial Number). Please check the output .txt file and correct.")
        else:
            serial_number = serial_number_match

    if not passed:
        warnings.append(f"ERROR: serial number could not be found")

        if allow_input:
            print(f"Warnings: {warnings}")
            warnings = [] # clear warnings since we now are using user input

            print("User must not input the chip information manually. The chips are labeled:")
            print("        BNL")  
            print("        LArASIC")
            print("        Version PXA (something like P5 or P5B)")                                  
            print("        AA/BB (somehting like 22/45)")
            print("        XXX-YYYYY (part of serial number)") 

            while True:
                wafer_id = input("Enter the wafer number (line 4):")
                try:
                    wafer_id_match = re.fullmatch(r"\d{2}/\d{2}$", wafer_id)
                    if len(wafer_id) != 5:
                        raise ValueError("Incorrect number of characters. The wafer/batch number must have 5 characters of form XX/YY.")
                    elif not wafer_id_match:
                        print ('Wrong format of wafer ID, please enter wafer ID in format XX/YY')
                    else:
                        break
                except Exception as error:
                    print(f"ERROR: {error}. Please try again.")

            while True:
                serial_number = input("Enter the serial number (line):")
                try:
                    serial_number_match = re.fullmatch(r"\d{3}-\d{5}$", serial_number)
                    if len(serial_number) != 10:
                        raise ValueError("Incorrect number of characters. The serial number must have 9 characters.")
                    elif not serial_number_match:
                        raise ValueError("Serial number must be of format XXX-YYYYY")
                    else:
                        break
                except Exception as error:
                    print(f"ERROR: {error}. Please try again.")
        else:
            #return serial_number, wafer_id, warnings
            return ([False, serial_number, wafer_id, "BNL", "LArASIC", "Version", version_id, ocr_image_dir], warnings)
    
    if serial_number or wafer_id:
        print(f"-----> Process ID #{process_id}")
        if serial_number:
            print(f"-------->Serial Number (SN): {serial_number}")
        if wafer_id:
            print(f"-------->Wafer Lot: {wafer_id}")
    
    #return serial_number, wafer_id, warnings
    return ([True, serial_number, wafer_id, "BNL", "LArASIC", "Version", version_id, ocr_image_dir], warnings)
    
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

def RunOCR(image_directory, image_file, ocr_results_dir, to_rts_config=False, socket_label='CD0', config_file='asic_info.csv', to_tray_file=False, tray_file="", user_input=True):
    """
    Preprocess a given image, perform the ocr, and write
    the result to a file upon success.

    Inputs:
        ocr_queue [Queue]: multiprocessing queue for threading
        image_directory [str]: directory of image
        image_file [str]: file name of image
        ocr_results_dir [str]: directory to save results
        to_rts_config [bool]: If true, write the SN to the rts config file
        socke_label [str]: Label for the socket (either CD0 or CD1)
        config_file [str]: name of rts config file to write to if 
                           to_rts_config is true
        user_input [bool]: If true and the OCR fails, ask the 
                           user to manually input the SN.
    """
    print("Running OCR...")
    success = False
    # Extract image_number from the filename (assuming it's before the first '_')
    image_number = image_file.split('_')[0]
    tray_nr = image_file.split('_')[1].removeprefix('tr')
    col_nr = image_file.split('_')[2].removeprefix('col')
    row_nr = image_file.split('_')[3].removeprefix('row')

    nTrayRows = 6    
    chip_nr = (col_nr -1 )*nTrayRows + row_nr

    print(f'processing image at {image_file}')

    # No longer using rotations as the image will come prerotated from the robot vision system

    print('Preprocessing image')
    temp_image_path = preprocess_image(image_file + ".bmp", image_directory, ocr_results_dir)

    warnings=[]
    if temp_image_path:
        # Perform OCR using MiniCPM
        print(f'Preprocessed image at {temp_image_path}')
        ocr_result = perform_ocr_minicpm(temp_image_path)

        words = ocr_result.split()

        print(f"OCR: {ocr_result}")
        if ocr_result:
            ocr_validated = validate_LArASIC_OCR(ocr_result, image_number, allow_input=False)                
            if not ocr_validated:
                # Do something here 
                ocr_validated = ([False,'000-0000', '00/00', 'BNL','LArASIC', 'Version', 'BAD', temp_image_path],["Invalid OCR"])
            
            ocr_info = ocr_validated[0]

            serial_number=ocr_info[1]
            wafer_id=ocr_info[2]
            warnings = ocr_validated[1]
            # serial_number, wafer_id, warnings = validate_LArASIC_OCR(ocr_result, image_number, allow_input=False)                
            [print(w) for w in warnings]
            
            chipinfo_file = SaveChipInfo(image_number, serial_number, wafer_id, ocr_results_dir)
            success = True
    
    if to_rts_config:
        WriteToRTSConfig(chipinfo_file, config_file, socket_label)
    if to_tray_file:
        WriteToTrayCatalog(chipinfo_file, temp_image_path, len(warnings),tray_file, tray_nr, col_nr, row_nr)
    
    return (success, ocr_info, warnings) # temp_image_path, len(warnings), serial_number

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
    print(f'Writing new SN ({sn}) for {socket_label} to {config_file}...')

    config_df = pd.read_csv(config_file)

    # Find corresponding socket label and overwrite with new SN
    row_num = 0
    for i in config_df['Item']:
        if i == socket_label: 
            config_df.loc[row_num, 'Value'] = sn
            break
        row_num += 1

    # Overwrite existing csv
    config_df.to_csv(config_file, index=False)

    return
   
def WriteToTrayCatalog(chipinfo_file, proc_image, n_warnings, tray_file, tray, col, row):
    """
    Write the serial number, processed image path and number of warnings to the 
    tray catalog for quick SN retrieval
    """
    print(f'Writing info for chip at {tray}, {col}, {row} to {tray_file}')
    chip_df = pd.read_csv(chipinfo_file)
    sn = str(chip_df['SN'][0])
    print(f'Writing new SN ({sn}) for tr{tray} col{col} row{row} to {tray_file}...')

    tray_df = pd.read_csv(tray_file)

    mask=(tray_df['tray']==int(tray)) & (tray_df['col']==int(col)) & (tray_df['row']==int(row))
    tray_df.loc[mask, 'processed']=proc_image
    tray_df.loc[mask, 'serial']=sn
    tray_df.loc[mask, 'warnings']=(n_warnings)

    tray_df.to_csv(tray_file, index=False)
    # os.replace(tray_file+".tmp", tray_file)
    print('Wrote to tray catalog')
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

        serial_number, wafer_id, warnings = validate_LArASIC_OCR(results, image_id)

        SaveChipInfo(image_id, serial_number, wafer_id, ocr_results_dir)

        [print(w) for w in warnings]

        ShowOCRResult(image_id, ocr_results_dir, ocr_results_dir)

###################################################################################
if __name__=="__main__":

    start_time = time.time()

    image_directory = '/Users/neutrino/Desktop/RTS/images/' #"/Users/RTS/RTS_data/images/"
    ocr_results_dir = "/Users/neutrino/Desktop/RTS/ocr_results/"

    image_id = "20250402142447_SN"
    RunOCR(image_directory, image_id, ocr_results_dir)
    #image_id = "20250402170946"
    ShowOCRResult(image_id, ocr_results_dir, ocr_results_dir)
    #CheckAllOCRResults(ocr_results_dir)

    print("### %s seconds ###" % (time.time() - start_time))
