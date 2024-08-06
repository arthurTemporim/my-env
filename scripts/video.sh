#!/bin/bash

# Usage: ./shrink_videos_gpu.sh input_folder [resolution_scale] [bitrate] [crf] [preset]

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 input_folder [output_folder] [resolution_scale] [bitrate] [crf] [preset]"
    echo "Example: $0 input_folder output_folder 0.5 2000k 23 slow"
    exit 1
fi

input_folder=$1
output_folder=${2:-"$input_folder"} # Default to an "output" folder within the input folder
resolution_scale=${3:-0.5}  # Default to scaling to 50%
bitrate=${4:-2048k}         # Default bitrate
#bitrate=${4:-1024k}         # Default bitrate
crf=${5:-23}                # Default CRF
preset=${6:-slow}           # Default preset

# Loop through all video files in the input folder
for input_file in "$input_folder"/*.*4; do
    # Get the base name of the file
    base_name=$(basename "$input_file")
    # Create the output file name
    output_file="${base_name%.*}_shrinked.mp4"

    # Lower resolution and bitrate to reduce file size with NVIDIA GPU acceleration
    ffmpeg -hwaccel nvdec -i "$input_file" -vf "scale=iw*$resolution_scale:ih*$resolution_scale" -c:v h264_nvenc -b:v "$bitrate" -crf "$crf" -preset "$preset" -c:a copy "$output_file"

    echo "Video $input_file has been resized and saved as $output_file"
done

