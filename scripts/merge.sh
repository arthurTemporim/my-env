#!/bin/bash

# Usage: ./merge_videos_gpu.sh input_folder [output_file]

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 input_folder [output_file]"
    exit 1
fi

input_folder=$1

# Generate a default output file name if not provided
if [ -z "$2" ]; then
    output_file="merged_video_$(date +"%Y%m%d_%H%M%S").mp4"
else
    output_file=$2
fi

# Create the file list in the input folder
file_list="$input_folder/file_list.txt"

# Populate the file list with all .mp4 files in the input folder
> "$file_list" # Empty the file list if it already exists
for f in "$input_folder"/*.*4; do
    # Ensure each file path is correctly quoted
    echo "file '$(realpath "$f")'" >> "$file_list"
done

# Merge the files using ffmpeg without re-encoding
ffmpeg -f concat -safe 0 -i "$file_list" -c copy "$output_file"

# Clean up the temporary file list
rm "$file_list"

echo "All videos from $input_folder have been merged into $output_file"

