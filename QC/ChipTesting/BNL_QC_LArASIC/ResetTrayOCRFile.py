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

# Update each entry
for key, value in data.items():
    if not isinstance(value, (list, tuple)):
        raise TypeError(f"Entry for chip {key} is not a list or tuple")

    if len(value) < nFields:
        raise ValueError(f"Entry for chip {key} has fewer than 6 fields")

    if len(value) > nFields:
        print (f"Resetting entry for chip {key}")

    new_value = list(value[:nFields])
    new_value[0] = True

    # Preserve the original type
    data[key] = tuple(new_value) if isinstance(value, tuple) else new_value

# Overwrite the original file
with open(args.file, "wb") as f:
    pickle.dump(data, f, protocol=pickle.HIGHEST_PROTOCOL)

print(f"Processed {len(data)} entries in {args.file}.")