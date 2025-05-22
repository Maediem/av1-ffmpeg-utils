#!/bin/bash

#####################
# INSTALLATION TIPS #
#####################
# 1. Go to the following: https://github.com/BtbN/FFmpeg-Builds/releases
#
# 2. Download the following (latest): ffmpeg-master-latest-linux64-gpl-shared.tar.xz 
#
# 3. Unzip and move the directory:
#     cd /path/to/directory
#     tar -xf ffmpeg-master-latest-linux64-gpl-shared.tar.xz
#     mv ffmpeg-master-latest-linux64-gpl-shared /opt/ffmpeg
#
# 4. Create the proper profiles:
#     echo 'export PATH="/opt/ffmpeg/bin:$PATH"' | sudo tee /etc/profile.d/ffmpeg.sh 
#     echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/ffmpeg/lib' | sudo tee /etc/profile.d/ffmpeg_lib.sh
#
# 5. Add the profiles as source
#     source /etc/profile.d/ffmpeg.sh
#     source /etc/profile.d/ffmpeg_lib.sh
#
# 6. Open terminal and test the following: ffmpeg -version


#####################################################
################# BINDINGS/FEATURES #################
#####################################################

# Enable line editing
set -o emacs

# Function for path completion
_path_completion(){
    local path
    path=${READLINE_LINE:0:${READLINE_POINT}}
    completions=$(compgen -f -- "$path")

    # Check if there is only one completion
    if [ $(echo "$completions" | wc -l) -eq 1 ]; then
        READLINE_LINE=${completions}
        READLINE_POINT=${#READLINE_LINE}
    else
        COMPREPLY=($completions)
    fi
}

# Enable readline features
bind 'set show-all-if-ambiguous on'
#bind 'TAB:menu-complete'
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\e[C": forward-char'
bind '"\e[D": backward-char'
# Set the completion function for the read command
complete -o nospace -F _path_completion read


#############
# VARIABLES #
#############

# Colors
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
RESET_COLOR='\033[0m'  # Resets color back to default

# Default values
DEFAULT_SRC_LOCATION="/mnt/TeamGroupTC/VideoCompressing/todo"
DEFAULT_DST_LOCATION="/mnt/TeamGroupTC/VideoCompressing/done"
DEFAULT_FILE_TYPE="mkv"
DEFAULT_CRF=23
DEFAULT_PRESET=3
DEFAULT_VERIFY_FIX_VIDEOS="y"

FILE_FOUND=false

CODEC="libsvtav1"

# Global AV1 encoding parameters
AV1_PARAMS_LIVE_ACTION="tune=0:enable-overlays=1:scd=1:scm=0:film-grain=2:film-grain-denoise=0:enable-tf=0:enable-tpl-la=1:enable-dlf=1:enable-cdef=1:enable-restoration=1:aq-mode=2"
AV1_PARAMS_ANIME="tune=1:enable-overlays=1:scd=1:scm=0:film-grain=0:film-grain-denoise=0:enable-tf=0:enable-tpl-la=1:enable-dlf=1:enable-cdef=1:enable-restoration=1:aq-mode=2"
AV1_PARAMS=""

UNPROCESSED_FILES=()

#-----------------------------
# PROMPT USER TO SET VARIABLES
#-----------------------------

# Prompt for location
echo "Enter the source location (default: \"$DEFAULT_SRC_LOCATION\"): " 
read -e -p "" SRC_LOCATION
SRC_LOCATION="${SRC_LOCATION:-$DEFAULT_SRC_LOCATION}"

echo -e "\nEnter the destination location (default: \"$DEFAULT_DST_LOCATION\"):"
read -e -p "" DST_LOCATION
echo ""
DST_LOCATION="${DST_LOCATION:-$DEFAULT_DST_LOCATION}"

# Prompt user for content type
echo "Select content type:"
echo "1) Live Action (Non-Anime)"
echo "2) Anime"
read -p "Enter 1 or 2: " content_type

# Set AV1 parameters based on selection
case "$content_type" in
    1)
        AV1_PARAMS="$AV1_PARAMS_LIVE_ACTION"
        echo -e "\nUsing Live Action AV1 parameters."
        content_type="Live Action"
        ;;
    2)
        AV1_PARAMS="$AV1_PARAMS_ANIME"
        echo -e "\nUsing Anime AV1 parameters."
        content_type="Anime"
        ;;
    *)
        echo -e "\nInvalid choice. Defaulting to Live Action settings."
        AV1_PARAMS="$AV1_PARAMS_LIVE_ACTION"
        content_type="Live Action"
        ;;
esac

# Prompt for file type
echo ""
read -p "Enter the file type to search (default: \"$DEFAULT_FILE_TYPE\"): " FILE_TYPE
FILE_TYPE="${FILE_TYPE:-$DEFAULT_FILE_TYPE}"

# Prompt for CRF value
echo -e "\nIn AV1 encoding, a lower CRF (Constant Rate Factor) means higher quality and a larger file size."
echo " - CRF 18–20 is generally considered visually lossless or nearly indistinguishable from the original."
echo " - CRF 21–24 typically offers high-quality results with better compression, suitable for streaming or storage where space matters."
read -p "Enter the CRF value (default: $DEFAULT_CRF): " CRF_VALUE
CRF_VALUE="${CRF_VALUE:-$DEFAULT_CRF}"

# Prompt for preset
echo -e "\nIn AV1 encoding, a lower preset are slower, but enable more more advance encoding tools, leading to better quality for a given bitrate (or smaller files for given CRF)."
echo " - Preset 0-2: Often used by professionals to maximize quality and compression efficiency. Time is not a primary concern."
echo " - Preset 3-5: Often used by high-quality enthusiasts to ensure excellent quality, good file sizes. Balances quality with reasonable encode times."
read -p "Enter the FFmpeg preset (0-12) (default: $DEFAULT_PRESET): " PRESET_VALUE
PRESET_VALUE="${PRESET_VALUE:-$DEFAULT_PRESET}"

# Prompt for fixing videos before encoding them
echo -e "\nThis option will verify the video for potential issues. If needed, it will create a fixed copy to resolve problems such as incorrect timestamps, minor corruption, and container-related errors. However, severe corruption (e.g., damaged frames) requires full re-encoding and cannot be fixed with this method."
read -p "Would you like to verify and fix the video before encoding it? (default: $DEFAULT_VERIFY_FIX_VIDEOS) (y/n): " VALIDATE_FIX_VIDEOS
VALIDATE_FIX_VIDEOS="${VALIDATE_FIX_VIDEOS:-$DEFAULT_VERIFY_FIX_VIDEOS}"
echo ""

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
echo -e "    ${YELLOW}AV1 Parameters ($content_type)${RESET_COLOR}: \"$AV1_PARAMS\""
echo -e "    ${YELLOW}Performing verification of file before encoding it${RESET_COLOR}: \"$VALIDATE_FIX_VIDEOS\""
echo -e "${YELLOW}====================${RESET_COLOR}"

#############
# FUNCTIONS #
#############

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


get_value(){
    local data="$1"
    local key_prefix="$2"
    local delimiter="$3"

    echo "$data" | grep "$key_prefix" | cut -d"$delimiter" -f2 | tr -d '"' | tr -d "'" # Remove quotes if any
}


set_color_value(){
    local metadata="$1"
    local color_type="$2"
    
    local value
    value=$(get_value "$metadata" "$color_type" "=")
    
    # If it's not unknown or N/A, return it as-is
    if [[ "$value" != "unknown" && "$value" != "N/A" && -n "$value" ]]; then
        echo "$value"
        return
    fi

    # Get height to determine fallback
    local height
    height=$(get_value "$metadata" "height" "=")
    
    if ! [[ "$height" =~ ^[0-9]+$ ]]; then
        echo "Error: Height '$height' is not a valid number." >&2
        exit 1
    fi

    # Provide smart defaults based on height
    case "$color_type" in
        color_range)
            echo "tv" ;;  # Typically tv (limited) for most content
        color_space)
            if (( height >= 2160 )); then
                echo "bt2020nc"
            elif (( height >= 720 )); then
                echo "bt709"
            else
                echo "smpte170m"
            fi
            ;;
        color_transfer)
            if (( height >= 2160 )); then
                echo "smpte2084"  # HDR10/PQ
            else
                echo "bt709"
            fi
            ;;
        color_primaries)
            if (( height >= 2160 )); then
                echo "bt2020"
            elif (( height >= 720 )); then
                echo "bt709"
            else
                echo "smpte170m"
            fi
            ;;
        *)
            echo "Error: Unknown color_type specified: $color_type" >&2
            exit 1
            ;;
    esac
}


set_gop_value(){
    local metadata="$1"
    local gop="240"
    local fps_raw=""
    local fps=""

    fps_raw=$(get_value "$metadata" "r_frame_rate" "=")
    
    if [[ -z "$fps_raw" || "$fps_raw" == "0/0" || "$fps_raw" == "N/A" ]]; then
        fps_raw=$(get_value "$metadata" "avg_frame_rate" "=")
    fi

    if [[ -n "$fps_raw" && "$fps_raw" != "0/0" && "$fps_raw" != "N/A" ]]; then
        # Calculate fps for the GOP
        fps=$(echo "scale=4; $fps_raw" | bc -l)
        gop=$(printf "%.0f" "$(echo "$fps * 10" | bc -l)")
    fi
    
    echo "$gop"
}


###############
# MAIN SCRIPT #
###############

echo -e "Scanning directory: ${YELLOW}\"$SRC_LOCATION\"${RESET_COLOR} for files of type: ${YELLOW}\"$FILE_TYPE\"${RESET_COLOR}"

find "$SRC_LOCATION" -type f -name "*.$FILE_TYPE" | sort | while IFS= read -r file; do
    file_found=true 
    echo "Found file: \"$file\""
    
    # Initializing the variables
    # Extract filename and modify it
    filename="$(basename -- "$file")"
    filename_no_ext="${filename%.*}"
    output_filename=""
    output_path=""
    color_primaries_value=""
    color_range_value=""
    color_space_value=""
    color_trc_value=""
    gop_value=""

    # For debugging
    #echo "Filename extracted: \"$filename\""
    #echo "Filename without extension: \"$filename_no_ext\""
    
    #------------------------
    # Get the output_filename
    #------------------------
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
    
    #---------------------------------------
    # Verifying the video for potential fixes
    #---------------------------------------
    # Skipping file if the output already exists, otherwise, compress it accordingly
    if [[ -f "$output_path" ]]; then
        echo -e "${YELLOW}$output_path${RESET_COLOR} already exists. Skipping this file."
        UNPROCESSED_FILES+=("$output_path")
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
    
        #---------------------------------
        # Setting some encoding parameters
        #---------------------------------
        ffprobe_metadata=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_space,color_primaries,color_transfer,color_range,height,r_frame_rate,avg_frame_rate -of default=noprint_wrappers=1 "$file")
        color_primaries_value=$(set_color_value "$ffprobe_metadata" "color_primaries") || {
            echo -e "${RED}ERROR${RESET_COLOR}: Main script failed at setting color primaries." >&2
            exit 1
        }
        color_range_value=$(set_color_value "$ffprobe_metadata" "color_range") || {
            echo -e "${RED}ERROR${RESET_COLOR}: Main script failed at setting color range." >&2
            exit 1
        }
        color_space_value=$(set_color_value "$ffprobe_metadata" "color_space") || {
            echo -e "${RED}ERROR${RESET_COLOR}: Main script failed at setting color space." >&2
            exit 1
        }
        color_trc_value=$(set_color_value "$ffprobe_metadata" "color_transfer") || {
            echo -e "${RED}ERROR${RESET_COLOR}: Main script failed at setting color transfer (trc)." >&2
            exit 1 
        }
        gop_value=$(set_gop_value "$ffprobe_metadata") || {
            echo -e "${RED}ERROR${RESET_COLOR}: Main script failed at setting GOP value." >&2
            exit 1
        }
        
        #----------------------------
	# Command to process the file
        #----------------------------
        CMD=(ffmpeg -nostdin -i "$file" -map 0:v -map 0:a -c:v $CODEC -pix_fmt yuv420p10le -colorspace "$color_space_value" -color_primaries "$color_primaries_value" -color_trc "$color_trc_value" -color_range "$color_range_value" -crf $CRF_VALUE -preset $PRESET_VALUE -g "$gop_value" -svtav1-params "$AV1_PARAMS" -c:a copy -map 0:s? -c:s copy -movflags +faststart "$output_path")
        run_command "${CMD[@]}"
    fi
done

if [[ $file_found == false ]]; then
    echo -e "No files of type '${YELLOW}$FILE_TYPE${RESET_COLOR}' found in directory: \"${YELLOW}$SRC_LOCATION${RESET_COLOR}\"."
    exit 1
fi

#---------------------------------------
# Printing files that were not processed
#---------------------------------------
# Check if the array is not empty and loop through the files
if [ ${#UNPROCESSED_FILES[@]} -ne 0 ]; then
    
    if [ ${#UNPROCESSED_FILES[@]} -eq 1 ]; then
        echo -e "\nThe following file was not processed:"
    else
        echo -e "\nThe following files were not processed:"
    fi

    for unprocessed_file in "${UNPROCESSED_FILES[@]}"; do
        echo -e "- ${YELLOW}${UNPROCESSED_FILE}S${RESET_COLOR}"
    done
fi
