import csv
import sys
import os

def process_coords_csv(input_filepath, output_filepath):
    try:
        with open(input_filepath, 'r', newline='', encoding='utf-8') as infile, \
             open(output_filepath, 'w', newline='', encoding='utf-8') as outfile:
            reader = csv.reader(infile)
            writer = csv.writer(outfile, quoting=csv.QUOTE_NONNUMERIC)
            header = next(reader, None)
            if header:
                writer.writerow(['img', 'coords'])
            else:
                print(f"Warning: Input file '{input_filepath}' is empty or has no header.")
                return
            for row in reader:
                if not row:
                    continue
                if len(row) > 0:
                    img_id = row[0]
                else:
                    print(f"Warning: Skipping empty row in '{input_filepath}'.")
                    continue
                if len(row) >= 17:
                    new_coords_list = row[9:17]
                else:
                    print(f"Warning: Row does not contain enough columns for new coordinates. Skipping row: {row}")
                    continue
                coords_string = ' '.join(new_coords_list)
                writer.writerow([img_id, coords_string])
        print(f"Transformation complete. Output saved to '{output_filepath}'")
    except FileNotFoundError:
        print(f"Error: Input file '{input_filepath}' not found. Please ensure it exists.")
        sys.exit(1)
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python script.py <input_csv_file> <output_csv_file>")
        print("Example: python script.py scaled_coords.csv transformed_coords.csv")
        sys.exit(1)
    input_csv_filename = sys.argv[1]
    output_csv_filename = sys.argv[2]
    process_coords_csv(input_csv_filename, output_csv_filename)
