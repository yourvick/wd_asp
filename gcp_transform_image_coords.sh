#!/bin/bash
input_file="$1"
output_file="$2"
factor="$3"
new_filepath="$4"

if [ -z "$input_file" ] || [ -z "$output_file" ] || [ -z "$factor" ] || [ -z "$new_filepath" ]; then
    echo "Error: Missing arguments."
    echo "Usage: ./gcp_transform_image_coords.sh <input.gcp> <output.gcp> <multiplication_factor> <new_image_filepath>"
    echo "Example: ./gcp_transform_image_coords.sh input.gcp output.gcp 0.5 /path/to/new/image.tif"
    exit 1
fi

if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found."
    exit 1
fi

if ! [[ "$factor" =~ ^[+-]?[0-9]+([.][0-9]+)?$ ]]; then
    echo "Error: Multiplication factor '$factor' is not a valid number."
    exit 1
fi

echo "Transforming image coordinates in '$input_file'..."
echo "Applying factor: $factor to img_x (col 9) and img_y (col 10)."
echo "Setting new image path (col 8): '$new_filepath'"

awk -F',' -v OFS=',' -v factor="$factor" -v new_filepath="$new_filepath" '
{
    if ($1 ~ /^#/) {
        print
    } else {
        $9 = $9 * factor
        $10 = $10 * factor
        $8 = new_filepath
        print
    }
}' "$input_file" > "$output_file"

if [ $? -eq 0 ]; then
    echo "Transformation complete. Output saved to '$output_file'"
else
    echo "Error: Transformation failed. Please check input file format and arguments."
    exit 1
fi
