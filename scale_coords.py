import pandas as pd
import numpy as np
import sys

def calculate_new_rectangle_coordinates(row, width_scale_factor, height_scale_factor):
    P1 = np.array([row['tl_x'], row['tl_y']])
    P2 = np.array([row['tr_x'], row['tr_y']])
    P3 = np.array([row['br_x'], row['br_y']])
    P4 = np.array([row['bl_x'], row['bl_y']])
    center = (P1 + P2 + P3 + P4) / 4.0
    V_width = P2 - P1
    V_height = P4 - P1
    V_width_scaled = V_width * width_scale_factor
    V_height_scaled = V_height * height_scale_factor
    half_V_width_scaled = V_width_scaled / 2.0
    half_V_height_scaled = V_height_scaled / 2.0
    new_P1 = center - half_V_width_scaled - half_V_height_scaled
    new_P2 = center + half_V_width_scaled - half_V_height_scaled
    new_P3 = center + half_V_width_scaled + half_V_height_scaled
    new_P4 = center - half_V_width_scaled + half_V_height_scaled
    return pd.Series({
        'new_tl_x': new_P1[0], 'new_tl_y': new_P1[1],
        'new_tr_x': new_P2[0], 'new_tr_y': new_P2[1],
        'new_br_x': new_P3[0], 'new_br_y': new_P3[1],
        'new_bl_x': new_P4[0], 'new_bl_y': new_P4[1]
    })

# Check if all required command-line arguments are provided
if len(sys.argv) < 5:
    print("Usage: python script.py <input_csv_file> <output_csv_file> <horizontal_scale_factor> <vertical_scale_factor>")
    print("Example: python script.py input.csv output.csv 0.999965 0.998")
    sys.exit(1)

input_csv_file = sys.argv[1]
output_csv_file = sys.argv[2]
try:
    horizontal_scale_factor = float(sys.argv[3])
    vertical_scale_factor = float(sys.argv[4])
except ValueError:
    print("Error: Scale factors must be valid numbers.")
    sys.exit(1)

try:
    df_rectangles = pd.read_csv(input_csv_file)
except FileNotFoundError:
    print(f"Error: Input file '{input_csv_file}' not found. Please make sure the file is in the correct directory.")
    sys.exit(1)
except Exception as e:
    print(f"An error occurred while reading the input CSV file: {e}")
    sys.exit(1)

print(f"Applying horizontal scale factor: {horizontal_scale_factor} ({(1-horizontal_scale_factor)*100:.2f}% change in width)")
print(f"Applying vertical scale factor: {vertical_scale_factor} ({(1-vertical_scale_factor)*100:.2f}% change in height)")

df_new_coordinates = df_rectangles.apply(
    lambda row: calculate_new_rectangle_coordinates(row, horizontal_scale_factor, vertical_scale_factor), axis=1
)

df_result = pd.concat([df_rectangles, df_new_coordinates], axis=1)

print("\nOriginal and New Rectangle Coordinates:")
print(df_result)

try:
    df_result.to_csv(output_csv_file, index=False)
    print(f"\nNew scaled coordinates saved to '{output_csv_file}'")
except Exception as e:
    print(f"An error occurred while saving the output CSV file: {e}")
    sys.exit(1)
