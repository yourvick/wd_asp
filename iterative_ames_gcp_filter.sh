#!/bin/bash
initial_input_file="$1"
final_output_file="$2"
threshold1="$3"
threshold2="$4"
threshold3="$5"

if [ -z "$initial_input_file" ] || [ -z "$final_output_file" ] || \
   [ -z "$threshold1" ] || [ -z "$threshold2" ] || [ -z "$threshold3" ]; then
    echo "Error: Missing arguments."
    echo "Usage: ./iterative_ames_gcp_filter.sh <input_ames_gcp_file> <output_filtered_ames_gcp_file> <threshold1> <threshold2> <threshold3>"
    echo "Example: ./iterative_ames_gcp_filter.sh original_ames.gcp final_filtered_ames.gcp 100 10 3"
    exit 1
fi

if [ ! -f "$initial_input_file" ]; then
    echo "Error: Initial input file '$initial_input_file' not found."
    exit 1
fi

PYTHON_SCRIPT_NAME="filter_ames_gcp_by_residual.py"
PYTHON_SCRIPT_PATH="$(dirname "$0")/$PYTHON_SCRIPT_NAME"

if [ ! -f "$PYTHON_SCRIPT_PATH" ]; then
    echo "Error: Python script '$PYTHON_SCRIPT_NAME' not found at '$PYTHON_SCRIPT_PATH'."
    echo "Please ensure 'filter_ames_gcp_by_residual.py' is in the same directory as this script."
    exit 1
fi

temp_file_1=$(mktemp --suffix=.gcp)
temp_file_2=$(mktemp --suffix=.gcp)

trap "rm -f \"$temp_file_1\" \"$temp_file_2\"" EXIT

python3 "$PYTHON_SCRIPT_PATH" "$initial_input_file" "$temp_file_1" "$threshold1"
step1_status=$?
if [ $step1_status -ne 0 ]; then
    echo "Error: Step 1 failed. Aborting."
    exit $step1_status
fi

python3 "$PYTHON_SCRIPT_PATH" "$temp_file_1" "$temp_file_2" "$threshold2"
step2_status=$?
if [ $step2_status -ne 0 ]; then
    echo "Error: Step 2 failed. Aborting."
    exit $step2_status
fi

python3 "$PYTHON_SCRIPT_PATH" "$temp_file_2" "$final_output_file" "$threshold3"
step3_status=$?
if [ $step3_status -ne 0 ]; then
    echo "Error: Step 3 failed. Aborting."
    exit $step3_status
fi
