# This program crops a chip from the input picture
# based on chip coordinates. The it reads the text on the
# chip using easyocr.


import os
import cv2
import numpy as np
from PIL import Image
from tesserocr import PyTessBaseAPI, PSM

# Explicitly set the tessdata directory
tessdata_dir = '/usr/share/tesseract-ocr/4.00/tessdata/'


# Define the coordinates and sizes for the chip (x, y, width, height)
# x, y are the coordinates of the top left corner of the chip.
# To add more chips, just add their corresponding set of coordinates
# separated by commas (), ()

chip_coordinates = [
    (1197, 790, 204, 223)
]

def adjust_contrast(image, clip_limit=2.0, tile_grid_size=(8, 8)):
    clahe = cv2.createCLAHE(clipLimit=clip_limit, tileGridSize=tile_grid_size)
    return clahe.apply(image)

def process_and_save_chips(image_path):
    # Read the image
    image = cv2.imread(image_path)
    # Convert to gray scale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    ocr_results = []

    for i, (x, y, w, h) in enumerate(chip_coordinates):
        chip_image = gray[y:y+h, x:x+w]

        #Rotate the chip
        rotated_chip = cv2.rotate(chip_image, cv2.ROTATE_90_CLOCKWISE)

        # Adjust contrast
        contrast_enhanced_chip = adjust_contrast(rotated_chip)

        pil_image = Image.fromarray(contrast_enhanced_chip)

        # Use Tesserocr to do OCR on the processed chip image
        with PyTessBaseAPI(path=tessdata_dir, psm=PSM.SPARSE_TEXT) as api:
            api.SetImage(pil_image)
            text = api.GetUTF8Text()
            ocr_results.append(text.strip())

        cv2.imwrite(f'processed_chips/chip_{i}.png', contrast_enhanced_chip)

    return ocr_results

ocr_results = process_and_save_chips('/home/karla/Documents/CE-QC/QC_camera/text_recognition/RTS/SN.bmp')

for idx, text in enumerate(ocr_results):
    print(f"OCR result for chip {idx}:\n\n{text}\n")
