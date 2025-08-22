import sys
import numpy as np

def filter_ames_gcp_by_residual(input_filepath, output_filepath, threshold=None):
    gcp_data = []
    header_line = ""
    with open(input_filepath, 'r') as f:
        for line in f:
            if line.startswith('#'):
                header_line = line.strip()
            else:
                try:
                    parts = line.strip().split(',')
                    if len(parts) < 12:
                        continue
                    lat = float(parts[1])
                    lon = float(parts[2])
                    img_x = float(parts[8])
                    img_y = float(parts[9])
                    gcp_data.append({
                        'lat': lat, 'lon': lon,
                        'img_x': img_x, 'img_y': img_y,
                        'original_line_parts': parts
                    })
                except ValueError:
                    continue
    if not gcp_data:
        print("Error: No valid GCP data found in the input file. Ensure it's an AMES .gcp file.", file=sys.stderr)
        return 0, 0
    map_lat = np.array([g['lat'] for g in gcp_data])
    map_lon = np.array([g['lon'] for g in gcp_data])
    img_x = np.array([g['img_x'] for g in gcp_data])
    img_y = np.array([g['img_y'] for g in gcp_data])
    A = np.column_stack([
        np.ones_like(map_lat),
        map_lat,
        map_lon,
        map_lat**2,
        map_lat * map_lon,
        map_lon**2,
        map_lat**3,
        (map_lat**2) * map_lon,
        map_lat * (map_lon**2),
        map_lon**3
    ])
    if len(gcp_data) < 10:
        print(f"Error: A third-order polynomial transformation requires at least 10 GCPs. Found {len(gcp_data)}.", file=sys.stderr)
        return 0, 0
    try:
        coeffs_img_x, residuals_info_x, rank_x, s_x = np.linalg.lstsq(A, img_x, rcond=None)
        coeffs_img_y, residuals_info_y, rank_y, s_y = np.linalg.lstsq(A, img_y, rcond=None)
    except np.linalg.LinAlgError as e:
        print(f"Error during least squares calculation: {e}", file=sys.stderr)
        print("Hint: Ensure you have enough GCPs (at least 10 for third-order polynomial) and they are not collinear/coplanar.", file=sys.stderr)
        return 0, 0
    predicted_img_x = A @ coeffs_img_x
    predicted_img_y = A @ coeffs_img_y
    output_lines = []
    if header_line:
        output_lines.append(header_line)
    filtered_gcp_count = 0
    for i, gcp in enumerate(gcp_data):
        res_x_pixels = gcp['img_x'] - predicted_img_x[i]
        res_y_pixels = gcp['img_y'] - predicted_img_y[i]
        total_residual_pixels = np.sqrt(res_x_pixels**2 + res_y_pixels**2)
        updated_line = ",".join(gcp['original_line_parts'])
        if threshold is None or total_residual_pixels <= threshold:
            output_lines.append(updated_line)
            filtered_gcp_count += 1
    with open(output_filepath, 'w') as f:
        for line in output_lines:
            f.write(line + '\n')
    return len(gcp_data), filtered_gcp_count

if __name__ == "__main__":
    if len(sys.argv) < 3 or len(sys.argv) > 4:
        print("Usage: python filter_ames_gcp_by_residual.py <input_ames_gcp_file> <output_ames_gcp_file> [pixel_residual_threshold]", file=sys.stderr)
        sys.exit(1)
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    pixel_residual_threshold = float(sys.argv[3]) if len(sys.argv) == 4 else None
    total_gcps, kept_gcps = filter_ames_gcp_by_residual(input_file, output_file, pixel_residual_threshold)
    if total_gcps > 0 and kept_gcps == 0 and pixel_residual_threshold is not None:
        print(f"Warning: All {total_gcps} GCPs were filtered out with the given pixel residual threshold of {pixel_residual_threshold}.", file=sys.stderr)
    elif total_gcps > 0:
        print(f"Processed {total_gcps} GCPs using a third-order polynomial (predicting pixels from map coords). {kept_gcps} GCPs kept after filtering (if threshold applied).")
    else:
        sys.exit(1)
