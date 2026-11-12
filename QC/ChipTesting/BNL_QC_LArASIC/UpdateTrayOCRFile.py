import argparse
import pickle

parser = argparse.ArgumentParser(
    description="Reset the OCR file"
)
parser.add_argument("file", help="Path to the ocr file")
args = parser.parse_args()

# Load the dictionary
with open(args.file, "rb") as f:
    data = pickle.load(f)

nFields=8

set_untested={1,2,3,4,5,6,7,9}
set_good={}
# {1,3,4,5,6,7,8,9}
set_bad={}
# {2,26,27,28,29,30,31,32,33}
set_bad_moved={}

# Uncomment to reset all other chips 
# Comment out if keeping values from real tests
# # '''
# for chip in range(1,91+1):
#     if chip not in set_good and chip not in set_bad:
#         set_untested[-1]=chip
# # '''
#
for chip in range(1,91+1):
    if chip not in set_untested:
        set_good[-1]=chip


# Update each entry
for key, value in data.items():

    if not isinstance(value, (list, tuple)):
        raise TypeError(f"Entry for chip {key} is not a list or tuple")

    if len(value) < nFields:
        raise ValueError(f"Entry for chip {key} has fewer than 6 fields")

    new_value = list(value)
    
    if (key in set_untested) or (key in set_good) or (key in set_bad):

        if len(value) > nFields:
            print (f"Resetting entry for chip {key}")

        new_value = list(value[:nFields])
        new_value[0] = True
    
    if key in set_good:
        print (f"Setting entry for chip {key} to QC PASS")
        new_value.append("PASS_QC")

    if key in set_bad:
        print (f"Setting entry for chip {key} to QC FAIL")
        new_value.append("Failed_in_QC")
        new_value[0] = False

    if key in set_bad_moved:
        print (f"Setting entry for chip {key} to Moved_to_bad_tray_slot")
        new_value.append("Moved_to_bad_tray_slot")

    # Preserve the original type
    data[key] = tuple(new_value) if isinstance(value, tuple) else new_value

# Overwrite the original file
with open(args.file, "wb") as f:
    pickle.dump(data, f, protocol=pickle.HIGHEST_PROTOCOL)

print(f"Processed {len(data)} entries in {args.file}.")