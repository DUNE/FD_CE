import os
import json
import re
from datetime import datetime

# Directory containing .txt files
ocr_results_dir = "Tested/B011T0001/ocr_results"

# Name of the person sending records to HWDB:
name = "Karla F."

# Dictionary to store unique serial numbers to avoid repetitions
unique_serials = set()

total_files_processed = 0
duplicate_count = 0

######################################################################

# Function to extract serial number from the OCR result
def extract_serial_number(text):

    match = re.search(r"\d{3}-\d{5}$", text)

    return match.group() if match else None

######################################################################



# Function to extract date from filename and format it:
def format_date_from_filename(filename):

    date_str = re.search(r"\d{8}", filename).group()
    date_obj = datetime.strptime(date_str, "%Y%m%d")

    return date_obj.strftime("%Y-%m-%d")


######################################################################


# Main function to process our files and create .json
def create_json_files():

    global total_files_processed, duplicate_count

    for txt_file in os.listdir(ocr_results_dir):
        if txt_file.endswith(".txt"):

            total_files_processed += 1
            txt_path = os.path.join(ocr_results_dir, txt_file)
            with open(txt_path, 'r', encoding='utf-8') as file:
                ocr_result = file.read()

            # Extracting serial number
            serial_number = extract_serial_number(ocr_result)
            if serial_number in unique_serials:
                duplicate_count += 1
                print(f"Skipping duplicate serial number: {serial_number}")
                continue
            unique_serials.add(serial_number)

            # Extract date from filename
            date = format_date_from_filename(txt_file)

            # Create JSON data:
            json_data = {
                "component_type": {
                    "part_type_id": "D08100100001"
                },
                "country_code": "US",
                "comments": f"Picture taken on {date} by RTS at BNL",
                "institution": {
                    "id": 128
                },
                "manufacturer": {
                    "id": 58
                },
                "specifications": {
                    "LArASIC SN": serial_number,
                    "RTS Operator": name,
                    "Test Results": "link_to_test_results"
                }
            }

            # Save JSON file with the same name as .txt file
            json_filename = os.path.splitext(txt_file)[0] + ".JSON"
            json_path = os.path.join(ocr_results_dir, json_filename)
            with open(json_path, 'w', encoding='utf-8') as json_file:
                json.dump(json_data, json_file, indent=4)

            print(f"JSON file '{json_filename}' created successfully!")

    print(f"\nTotal files processed: {total_files_processed}")
    print(f"\nDuplicated SN skipped: {duplicate_count}")

# Run the function
create_json_files()
