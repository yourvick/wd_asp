#!/bin/bash

# ---- VARIABLES ----
img1="DZB1214-500055L004001"
img2="DZB1214-500055L005001"
img3="DZB1214-500055L006001"
img4="DZB1214-500055L007001"
dem="CG_NASADEM_30m.tif"
dem_lr="CG_NASADEM_600m.tif"
tsp=32
tmp=8
proc=4

# ---- STEP 1: build pyramids ----
stereo_gui ${img1}.tif ${img2}.tif ${img3}.tif ${img4}.tif \
    --create-image-pyramids-only

# ---- STEP 2: manually georeference and generate GCPs ----
# ---- ---- 2.1: convert sub2 images to jpg for manual georeferencing ---- ----
convert_to_jpg() {
    local img=$1
    gdal_translate -of JPEG -co QUALITY=75 -b 1 \
        -co WORLDFILE=YES ${img}_sub2.tif ${img}_sub2_q75.jpg
}

convert_to_jpg ${img1}
convert_to_jpg ${img2}
convert_to_jpg ${img3}
convert_to_jpg ${img4}

#### manually georeference with around 20 GCPs,
#### share the gcps between images when possible,
#### and upload GR'ed images as ${img}_sub2_q75_GR.tif

# ---- ---- 2.2: extract gcps from manually GR'ed images ---- ----
generate_and_filter_gcp() {
    local img=$1
    gcp_gen --threads $tsp \
        --camera-image ${img}_sub2.tif \
        --ortho-image ${img}_sub2_q75_GR.tif \
        --dem $dem \
        --gcp-sigma 1.0 \
        --output-prefix s2_gcp/s2 \
        -o ${img}_sub2.gcp
    iterative_ames_gcp_filter.sh ${img}_sub2.gcp ${img}_sub2_filt.gcp 100 10 4
    gcp_transform_image_coords.sh ${img}_sub2_filt.gcp ${img}.gcp 2 ${img}.tif
}

generate_and_filter_gcp ${img1}
generate_and_filter_gcp ${img2}
generate_and_filter_gcp ${img3}
generate_and_filter_gcp ${img4}

# ---- STEP 3: generate cameras ----
miss="${img1:2:7}"
rev="${img1:9:4}"
filt="camera=L&MISSION_NBR=${miss}&REVOLUTION=${rev}"
usgs_user="yourvick"
usgs_token="jE6QVBTgT@bV_W@f_ZSK4jrNNj3uNQItvMGTvme6urggreB6DIdmTz84rrR9k26i"
aoi="cg_aoi.geojson"

usgsxplore search declassii \
    --filter "${filt}" \
    --output imgs.gpkg \
    -vf ${aoi} \
    -u ${usgs_user} -t ${usgs_token}
ogr2ogr -f CSV temp_coords.csv imgs.gpkg \
    -sql "SELECT \"Entity ID\" AS img, \"NW Corner Long dec\" AS tl_x,\"NW Corner Lat dec\" AS tl_y, \"NE Corner Long dec\" AS tr_x,\"NE Corner Lat dec\" AS tr_y, \"SE Corner Long dec\" AS br_x,\"SE Corner Lat dec\" AS br_y, \"SW Corner Long dec\" AS bl_x,\"SW Corner Lat dec\" AS bl_y FROM imgs"
python scale_coords.py temp_coords.csv scale_coords.csv 0.999965 0.998
python ames_coords.py scale_coords.csv transformed_coords.csv
lkup="transformed_coords.csv"

generate_camera_and_footprint() {
    local img=$1
    cam_gen --pixel-pitch 0.007 \
        --threads $tsp \
        --focal-length 305 \
        --lon-lat-values "$(awk -v lookup_value="${img}" -F, 'NR==1 {next} {gsub(/"/, "", $1); gsub(/"/, "", $2); if ($1 == lookup_value) {print $2}}' "transformed_coords.csv")" ${img}.tif \
        --reference-dem $dem \
        --refine-camera \
        -o s0_cam/${img}_null.tsai
    camera_footprint ${img}.tif s0_cam/${img}_null.tsai \
        --threads $tsp \
        --output-kml s0_cam/${img}_null_fp.kml \
        -t nadirpinhole \
        --dem-file $dem_lr
}

generate_camera_and_footprint ${img1}
generate_camera_and_footprint ${img2}
generate_camera_and_footprint ${img3}
generate_camera_and_footprint ${img4}

cat << EOF > s0_cam/tsai_foot.tsai
TSAI
k1 = -0.001
k2 = 0.005
p1 = 0.0002
p2 = -2.0e-05
k3 = -0.005
EOF

add_intrinsics() {
    local img=$1
    head -n 12 s0_cam/${img}_null.tsai > s0_cam/${img}.tsai
    cat s0_cam/tsai_foot.tsai >> s0_cam/${img}.tsai
}

add_intrinsics ${img1}
add_intrinsics ${img2}
add_intrinsics ${img3}
add_intrinsics ${img4}

# ---- STEP 4: singly bundle adjust with GCPs ----
singly_bundle_adjust() {
    local img=$1
    bundle_adjust ${img}.tif s0_cam/${img}.tsai ${img}.gcp \
        -t nadirpinhole \
        --threads $tsp \
        --inline-adjustments \
        --num-passes 2 \
        --camera-weight 0 \
        --tri-weight 0.1 \
        --tri-robust-threshold 0.1 \
        -o s1_ba/s1
}

singly_bundle_adjust ${img1}
singly_bundle_adjust ${img2}
singly_bundle_adjust ${img3}
singly_bundle_adjust ${img4}

# ---- STEP 5: create first mapprojected images and matchfiles with bundle adjust ----
mapproject_image() {
    local img=$1
    local camera_path=$2
    mapproject --threads $tsp \
        --tr 6 \
        $dem_lr ${img}.tif \
        ${camera_path} \
        s1_ba/s1-${img}_mp.tif
}

mapproject_image ${img1} s1_ba/s1-${img1}.tsai
mapproject_image ${img2} s1_ba/s1-${img2}.tsai
mapproject_image ${img3} s1_ba/s1-${img3}.tsai
mapproject_image ${img4} s1_ba/s1-${img4}.tsai

bundle_adjust ${img1}.tif s1_ba/s1-${img1}.tsai \
    ${img2}.tif s1_ba/s1-${img2}.tsai \
    ${img3}.tif s1_ba/s1-${img3}.tsai \
    ${img4}.tif s1_ba/s1-${img4}.tsai \
    --ip-per-tile 200 \
    --matches-per-tile 200 \
    --max-pairwise-matches 100000000 \
    --individually-normalize \
    --mapprojected-data "s1_ba/s1-${img1}_mp.tif s1_ba/s1-${img2}_mp.tif s1_ba/s1-${img3}_mp.tif s1_ba/s1-${img4}_mp.tif $dem_lr" \
    -t nadirpinhole \
    --threads $tsp \
    --overlap-limit 4 \
    --num-iterations 100 \
    --num-passes 2 \
    --inline-adjustments \
    -o s2_ba/s2

# ---- STEP 6: float intrinsics ----
bundle_adjust ${img1}.tif s1_ba/s1-${img1}.tsai \
    ${img2}.tif s1_ba/s1-${img2}.tsai \
    ${img3}.tif s1_ba/s1-${img3}.tsai \
    ${img4}.tif s1_ba/s1-${img4}.tsai \
    -t nadirpinhole \
    --clean-match-files-prefix s2_ba/s2 \
    --threads $tsp \
    --solve-intrinsics \
    --intrinsics-to-float all \
    --intrinsics-to-share all \
    --max-pairwise-matches 100000000 \
    --num-iterations 2000 \
    --num-passes 1 \
    --parameter-tolerance 1e-15 \
    --overlap-limit 4 \
    --inline-adjustments \
    --heights-from-dem $dem \
    --heights-from-dem-uncertainty 10 \
    -o s3_ba/s3

# ---- STEP 7: repeat mapprojection ----
mapproject_image ${img1} s3_ba/s3-s1-${img1}.tsai
mapproject_image ${img2} s3_ba/s3-s1-${img2}.tsai
mapproject_image ${img3} s3_ba/s3-s1-${img3}.tsai
mapproject_image ${img4} s3_ba/s3-s1-${img4}.tsai

# ---- STEP 8: full mgm parallel stereo ----
run_parallel_stereo() {
    local img1=$1
    local img2=$2
    local output_dir=$3
    parallel_stereo --threads-singleprocess $tsp \
        --threads-multiprocess $tmp \
        --processes $proc \
        --session-type nadirpinhole \
        --stereo-algorithm asp_mgm \
        s3_ba/s3-s1-${img1}_mp.tif s3_ba/s3-s1-${img1}.tsai \
        s3_ba/s3-s1-${img2}_mp.tif s3_ba/s3-s1-${img2}.tsai \
        ${output_dir} \
        $dem_lr \
        --accept-provided-mapproj-dem
}

run_parallel_stereo ${img1} ${img2} s4/p1/mgm/s4p1mgm
run_parallel_stereo ${img3} ${img4} s4/p3/mgm/s4p3mgm
run_parallel_stereo ${img2} ${img3} s4/p2/mgm/s4p2mgm
