#!/bin/bash

# Usage: ./rotate_videos_gpu.sh input_folder [output_folder]

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 input_folder [output_folder]"
    exit 1
fi

input_folder=$1
output_folder=${2:-"$input_folder"} # Default to an "output" folder within the input folder

# Loop through all video files in the input folder
for input_file in "$input_folder"/*.mp4; do
    # Get the base name of the file
    base_name=$(basename "$input_file")
    # Create the output file name
    output_file="${base_name%.*}_rotated.mp4"

    # Rotate the video by 180 degrees using NVIDIA GPU acceleration
    ffmpeg -hwaccel nvdec -i "$input_file" -vf "transpose=2,transpose=2" -c:v h264_nvenc -c:a copy "$output_file"

    echo "Video $input_file has been rotated and saved as $output_file"
done

