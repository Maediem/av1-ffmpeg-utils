#!/bin/bash

#############
# VARIABLES #
#############

# Colors
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
RESET_COLOR='\033[0m'  # Resets color back to default

# Default values
DEFAULT_SRC_LOCATION="/path/to/video/to/compress" # CHANGE ME
DEFAULT_DST_LOCATION="/path/to/video/output"      # CHANGE ME
DEFAULT_FILE_TYPE="mkv"
DEFAULT_CRF=23
DEFAULT_PRESET=3
DEFAULT_VERIFY_FIX_VIDEOS="y"

# Global AV1 encoding parameters
AV1_PARAMS_NON_ANIME="tune=0:enable-overlays=1:scd=1:scm=0:film-grain=5:enable-tpl-la=1:enable-dlf=1:enable-cdef=1:enable-restoration=1:aq-mode=2"
AV1_PARAMS_ANIME="tune=1:enable-overlays=1:scd=1:scm=1:film-grain=0:enable-tpl-la=1:enable-dlf=1:enable-cdef=1:enable-restoration=1:aq-mode=1"
AV1_PARAMS=""

unprocessed_files=()
#-----------------------------
# PROMPT USER TO SET VARIABLES
#-----------------------------

# Prompt for location
read -p "Enter the source location (default: \"$DEFAULT_SRC_LOCATION\"): " SRC_LOCATION
SRC_LOCATION="${SRC_LOCATION:-$DEFAULT_SRC_LOCATION}"

read -p "Enter the destination location (default: \"$DEFAULT_DST_LOCATION\"): " DST_LOCATION
DST_LOCATION="${DST_LOCATION:-$DEFAULT_DST_LOCATION}"

# Prompt user for content type
echo "Select content type:"
echo "1) Non-Anime"
echo "2) Anime"
read -p "Enter choice (1 or 2): " choice

# Set AV1 parameters based on selection
case "$choice" in
    1)
        AV1_PARAMS="$AV1_PARAMS_NON_ANIME"
        echo "Using Non-Anime AV1 parameters."
        ;;
    2)
        AV1_PARAMS="$AV1_PARAMS_ANIME"
        echo "Using Anime AV1 parameters."
        ;;
    *)
        echo "Invalid choice. Defaulting to Non-Anime settings."
        AV1_PARAMS="$AV1_PARAMS_NON_ANIME"
        ;;
esac

# Prompt for file type
read -p "Enter the file type to search (default: \"$DEFAULT_FILE_TYPE\"): " FILE_TYPE
FILE_TYPE="${FILE_TYPE:-$DEFAULT_FILE_TYPE}"

# Prompt for CRF value
read -p "Enter the CRF value (default: $DEFAULT_CRF): " CRF_VALUE
CRF_VALUE="${CRF_VALUE:-$DEFAULT_CRF}"

# Prompt for preset
read -p "Enter the FFmpeg preset (0-12) (default: $DEFAULT_PRESET): " PRESET_VALUE
PRESET_VALUE="${PRESET_VALUE:-$DEFAULT_PRESET}"

# Prompt for fixing videos before encoding them
echo -e "\nThis option will verify the video for potential issues. If needed, it will create a fixed copy to resolve problems such as incorrect timestamps, minor corruption, and container-related errors. However, severe corruption (e.g., damaged frames) requires full re-encoding and cannot be fixed with this method."
read -p "Would you like to verify and fix the video before encoding it? (default: $DEFAULT_VERIFY_FIX_VIDEOS) (y/n): " VALIDATE_FIX_VIDEOS
VALIDATE_FIX_VIDEOS="${VALIDATE_FIX_VIDEOS:-$DEFAULT_VERIFY_FIX_VIDEOS}"

# Always use AV1 codec for encoding
CODEC="libsvtav1"

# Ensure output directory exists
mkdir -p "$DST_LOCATION"

# Print the initial values
echo -e "${YELLOW}====================${RESET_COLOR}"
echo -e "${YELLOW}Data provided${RESET_COLOR}:"
echo -e "    ${YELLOW}File type${RESET_COLOR}: \"$FILE_TYPE\""
echo -e "    ${YELLOW}Source file location${RESET_COLOR}: \"$SRC_LOCATION\""
echo -e "    ${YELLOW}Destination file location${RESET_COLOR}: \"$DST_LOCATION\""
echo -e "    ${YELLOW}CRF value${RESET_COLOR}: $CRF_VALUE"
echo -e "    ${YELLOW}Codec${RESET_COLOR}: $CODEC"
echo -e "    ${YELLOW}Preset${RESET_COLOR}: $PRESET_VALUE"
echo -e "    ${YELLOW}Output directory${RESET_COLOR}: \"$DST_LOCATION\""
echo -e "    ${YELLOW}AV1 Parameters${RESET_COLOR}: \"$AV1_PARAMS\""
echo -e "    ${YELLOW}Performing verification of file before encoding it${RESET_COLOR}: \"$VALIDATE_FIX_VIDEOS\""
echo -e "${YELLOW}====================${RESET_COLOR}"

#############
# FUNCTIONS #
############

run_command() {
    echo -e "${YELLOW}====================${RESET_COLOR}"
    
    if [[ $# -eq 1 ]]; then
        # If a single string argument is passed, execute it with eval
        echo -e "${YELLOW}Running command${RESET_COLOR}: \"$1\""
        eval "$1"
    elif [[ $# -gt 1 ]]; then
        # If multiple arguments are passed, treat them as an array command
        echo -e "${YELLOW}Running command${RESET_COLOR}: $*"
        "$@"
    else
        echo -e "${RED}Error: No command provided!${RESET_COLOR}"
        return 1
    fi

    echo -e "${YELLOW}====================${RESET_COLOR}"
}


###############
# MAIN SCRIPT #
###############

echo -e "Scanning directory: ${YELLOW}\"$SRC_LOCATION\"${RESET_COLOR} for files of type: ${YELLOW}\"$FILE_TYPE\"${RESET_COLOR}"
file_found=0 # False

find "$SRC_LOCATION" -type f -name "*.$FILE_TYPE" | sort | while IFS= read -r file; do
    file_found=1 # True
    echo "Found file: \"$file\""
    
    # Initializing the variables
    # Extract filename and modify it
    filename="$(basename -- "$file")"
    filename_no_ext="${filename%.*}"
    output_filename=""
    output_path=""

    # For debugging
    #echo "Filename extracted: \"$filename\""
    #echo "Filename without extension: \"$filename_no_ext\""
    
    
    # Get the output_filename
    codec_in_filename=$(echo "$filename" | grep -Po "[xXhH][\.-_]?26[45]|HEVC|hevc")
    if [ -n "$codec_in_filename" ]; then
        output_filename=$(echo "$filename_no_ext" | sed "s/$codec_in_filename/AV1/I").mkv
    else
        # Extract the part containing the resolution (e.g., ".1080p." or "[1080p]")
        tmp=$(echo "$filename_no_ext" | grep -Po ".\d+p.")
        
        # Get the first and last characters surrounding the resolution
        if [[ -n "$tmp" ]]; then
            tmp_first_char="${tmp:0:1}"  # First character
            tmp_last_char="${tmp: -1}"   # Last character
        
            if [ "$tmp_first_char" == "." ] || [ "$tmp_first_char" == " " ]; then
                output_filename="${filename_no_ext}${tmp_first_char}AV1.mkv"
            else
                output_filename="${filename_no_ext}${tmp_first_char}AV1${tmp_last_char}.mkv"
            fi
        else
            output_filename="${filename_no_ext}_AV1.mkv"
        fi
    fi
    
    # Get the full output path and make sure the directory exists
    output_path="$DST_LOCATION/$output_filename"
    mkdir -p "$DST_LOCATION"
    
    # Skipping file if the output already exists, otherwise, compress it accordingly
    if [[ -f "$output_path" ]]; then
        echo -e "${YELLOW}$output_path${RESET_COLOR} already exists. Skipping this file."
        unprocessed_files+=("$output_path")
    else
        # Fixing the video to correct issues and replacing the original with fixed one
        if echo "$VALIDATE_FIX_VIDEOS" | grep -Piq "^y"; then
            # Check if any errors are detected in the video
            echo "Verifying the file..."
            CMD=(ffmpeg -nostdin -v error -i "$file" -f null -)
            echo -e "${YELLOW}Executing command${RESET_COLOR}: ${CMD[@]} 2>&1"
            error_output=$("${CMD[@]}" 2>&1)
            
            if [[ -n "$error_output" ]]; then
                echo -e "${YELLOW}Performing fix${RESET_COLOR} on '$filename' to ensure proper timestamps and format..."
                
                # Showing the error(s) detected
                echo -e "${RED}====================${RESET_COLOR}"
                echo -e "${RED}Error(s) found in file${RESET_COLOR}: ${YELLOW}$file${RESET_COLOR}\n$error_output"
                echo -e "${RED}====================${RESET_COLOR}"
                
                # Define the new filename (keeping it in the same directory)
                fixed_file="$(dirname -- "$file")/${filename_no_ext}.fixed.mkv"
                
                # Command to process the file
                CMD=(ffmpeg -nostdin -i "$file" -c copy -map 0 -fflags +genpts "$fixed_file")
                run_command "${CMD[@]}"
                
                # Check if ffmpeg succeeded
                if [[ $? -eq 0 ]]; then
                    mv -f "$fixed_file" "$file"
                    echo -e "Fix ${GREEN}successful${RESET_COLOR}! The original file was replaced with the fixed file."
                else
                    echo -e "${RED}Error${RESET_COLOR}: Fix ${RED}failed${RESET_COLOR}. Keeping the original file."
		                # Deleting fixed file in case it is present
		                rm -f "$fixed_file"
                fi
            else
                echo -e "No ${RED}error${RESET_COLOR} detected. Proceeding with encoding."
            fi
        fi

	# Command to process the file
        CMD=(ffmpeg -nostdin -i "$file" -map 0:v -map 0:a -c:v $CODEC -pix_fmt yuv420p10le -crf $CRF_VALUE -preset $PRESET_VALUE -g 240 -svtav1-params "$AV1_PARAMS" -c:a copy -map 0:s? -c:s copy -movflags +faststart "$output_path")
        run_command "${CMD[@]}"
    fi
done

if [ "$file_found" -eq 0 ]; then
    echo -e "No files of type '${YELLOW}$FILE_TYPE${RESET_COLOR}' found in directory: \"${YELLOW}$SRC_LOCATION${RESET_COLOR}\"."
    exit 1
fi

# Check if the array is not empty and loop through the files
if [ ${#unprocessed_files[@]} -ne 0 ]; then
    
    if [ ${#unprocessed_files[@]} -eq 1 ]; then
        echo -e "\nThe following file was not processed:"
    else
        echo -e "\nThe following files were not processed:"
    fi

    for unprocessed_file in "${unprocessed_files[@]}"; do
        echo -e "- ${YELLOW}$unprocessed_file${RESET_COLOR}"
    done
fi

echo "Processing complete."
