#!/bin/bash

#############
# OBJECTIVE #
#############

# This script is designed to batch-process video files, converting them to the AV1 codec using FFmpeg.
# It features interactive configuration, logging with verbosity levels, and error handling for individual files.

#######################
# USER CONFIGURATIONS #
#######################

# --- Logging Configuration ---
# Set to "true" to enable writing logs to a file. Set to "false" to only print to the console.
LOGGING_ENABLED=true

# The full path to the log file. The script will attempt to create the directory if it doesn't exist.
# Command to read the errors: awk '/^\[.*\]\[ERROR\]/ {p=1} /^\[/ && !/\[ERROR\]/ {p=0} p' /var/log/ffmpeg-av1-encode.log
readonly LOG_FILE_PATH="/var/log/ffmpeg-av1-encode.log"

# Set the desired logging verbosity. Messages with a level equal to or higher than this will be logged.
# Available levels (from most to least verbose): DEBUG, INFO, WARN, ERROR
readonly CONFIG_LOG_LEVEL="INFO"

# --- Default Encoding Values ---
# These are the default settings presented to the user during the interactive setup.
readonly DEFAULT_SRC_LOCATION="/mnt/TeamGroupTC/VideoCompressing/todo"
readonly DEFAULT_DST_LOCATION="/mnt/TeamGroupTC/VideoCompressing/done"
readonly DEFAULT_FILE_TYPE="mkv"
readonly DEFAULT_CRF=23
readonly DEFAULT_PRESET=3
readonly DEFAULT_VERIFY_FIX_VIDEOS="y"
readonly DEFAULT_AUDIO_MODE="opus"


############################
# CORE SCRIPT DEPENDENCIES #
############################

# Enable extended command-line editing features (like history search) for the `read` command.
set -o emacs

# Configure key bindings for a better interactive experience.
bind 'set show-all-if-ambiguous on' # Show possible completions on the first Tab press.
bind '"\e[A": history-search-backward' # Up arrow searches history based on current input.
bind '"\e[B": history-search-forward'  # Down arrow does the same.

# This function provides path completion logic for commands that use it (like our `read` prompts).
_path_completion() {
    local current_word="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -f -- "$current_word"))
}

# Register the `_path_completion` function to be triggered for the `read` command with path prompting.
complete -o nospace -F _path_completion read


#############
# VARIABLES #
#############

# Color codes for terminal output, making it easier to read.
readonly RED=$(tput setaf 1; tput bold)
readonly GREEN=$(tput setaf 2; tput bold)
readonly YELLOW=$(tput setaf 3; tput bold)
readonly BLUE=$(tput setaf 4; tput bold)
readonly CYAN=$(tput setaf 6; tput bold)
readonly RESET_COLOR=$(tput sgr0)

# Pre-defined parameter sets for the SVT-AV1 encoder, optimized for different content types.
readonly CODEC="libsvtav1"
readonly AV1_PARAMS_LIVE_ACTION="tune=0:enable-overlays=1:scd=1:scm=0:film-grain=1:film-grain-denoise=0:enable-tf=0:enable-tpl-la=1:enable-dlf=1:enable-cdef=1:enable-restoration=1:aq-mode=2"
readonly AV1_PARAMS_ANIME="tune=1:enable-overlays=1:scd=1:scm=0:film-grain=0:film-grain-denoise=0:enable-tf=0:enable-tpl-la=1:enable-dlf=1:enable-cdef=1:enable-restoration=1:aq-mode=2"

# Maps log level names to numerical values for easy comparison.
declare -A LOG_LEVELS

# Assign values to the log levels
LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
)

# Set the variable as read only
readonly LOG_LEVELS

# Associative array mapping log levels to their colors.
declare -A LOG_LEVEL_COLORS

# Assign colors to the log levels
LOG_LEVEL_COLORS=(
    ["DEBUG"]="$CYAN"
    ["INFO"]="$BLUE"
    ["WARN"]="$YELLOW"
    ["ERROR"]="$RED"
)

# Set the variable as read only
readonly LOG_LEVEL_COLORS

# Global variables that will be populated by user input.
SRC_LOCATION=""
DST_LOCATION=""
FILE_TYPE=""
CRF_VALUE=""
PRESET_VALUE=""
VALIDATE_FIX_VIDEOS=""
AV1_PARAMS=""
CONTENT_TYPE=""
UNPROCESSED_FILES=()
AUDIO_MODE=""


#############
# FUNCTIONS #
#############

# Central logging function. Handles console output, file logging, and verbosity levels.
log() {
    local level_name=${1^^}
    local message="$2"

    local message_level=${LOG_LEVELS[$level_name]}
    local config_level=${LOG_LEVELS[$CONFIG_LOG_LEVEL]}

    # If the message's level is lower than the configured level, do nothing.
    if [[ -z "$message_level" || $message_level -lt $config_level ]]; then
        return
    fi

    local timestamp; timestamp=$(date '+%F %T')

    # Define the uncolored prefix. This is used for indentation calculation and for the log file.
    local uncolored_prefix="[${timestamp}] [${level_name}]"

    # Get the appropriate color for the level name. Default to RESET_COLOR if not found.
    local level_color=${LOG_LEVEL_COLORS[$level_name]:-${RESET_COLOR}}

    # The indentation for continued lines is calculated from the uncolored prefix length.
    local indent; indent=$(printf "%${#uncolored_prefix}s" " ")

    # Use a flag to track if we're on the first line of a multi-line message.
    local first_line=true

    # Process each line of the message separately to handle multi-line input correctly.
    while IFS= read -r line; do
        # Skip processing any empty lines that might be in the source message.
        [[ -n "$line" ]] || continue

        if [[ "$first_line" == "true" ]]; then
            # Construct the colored output for the console.
            echo -e "[${timestamp}] [${level_color}${level_name}${RESET_COLOR}] ${line}${RESET_COLOR}"

            if [[ "$LOGGING_ENABLED" == "true" ]]; then
                # Strip any potential colors from the message line for the log file.
                local clean_line; clean_line=$(echo "$line" | sed 's/\x1B\[[0-9;]*[mG]//g')

                # Use the uncolored_prefix for the file log.
                echo "${uncolored_prefix} ${clean_line}" >> "$LOG_FILE_PATH"
            fi

            first_line=false
        else
            # All subsequent lines of the same message are indented for readability.
            echo -e "${indent}   ${line}${RESET_COLOR}"

            if [[ "$LOGGING_ENABLED" == "true" ]]; then
                local clean_line; clean_line=$(echo "$line" | sed 's/\x1B\[[0-9;]*[mG]//g')
                # The indentation is also written to the log file.
                echo "${indent}   ${clean_line}" >> "$LOG_FILE_PATH"
            fi
        fi
    done <<< "$message"
}

# Safely run and display a command, returning its exit status for error handling.
run_command() {
    log "INFO" "Executing command: $(printf "'%q' " "$@")"
    "$@"
}

# Gathers all user settings in an interactive session.
get_user_settings() {
    echo -e "\nPlease provide the encoding settings. Press TAB for path completion.\n"

    # Using `read -erp` is the robust way to create a user prompt.
    # Source directory
    read -erp "Enter the source location (default: \"${YELLOW}${DEFAULT_SRC_LOCATION}${RESET_COLOR}\"): " SRC_LOCATION
    SRC_LOCATION="${SRC_LOCATION:-$DEFAULT_SRC_LOCATION}"

    if [[ ! -d "$SRC_LOCATION" || ! -r "$SRC_LOCATION" ]]; then
        log "ERROR" "Source location \"${YELLOW}${SRC_LOCATION}${RESET_COLOR}\" is not a readable directory."
        exit 1
    fi

    echo ""

    # Destination/output directory
    read -erp "Enter the destination location (default: \"${YELLOW}${DEFAULT_DST_LOCATION}${RESET_COLOR}\"): " DST_LOCATION
    DST_LOCATION="${DST_LOCATION:-$DEFAULT_DST_LOCATION}"

    if [[ -d "$DST_LOCATION" && ! -w "$DST_LOCATION" ]] || \
       [[ ! -d "$DST_LOCATION" && ! -w "$(dirname "$DST_LOCATION")" ]]; then
        log "ERROR" "Destination location \"${YELLOW}${DST_LOCATION}${RESET_COLOR}\" is not writable."
        exit 1
    fi

    # Parameters for libsvtav1
    echo -e "\nSelect content type:\n${YELLOW}1${RESET_COLOR}) Live-Action (Non-Anime)\n${YELLOW}2${RESET_COLOR}) Anime"
    read -p "Enter ${YELLOW}1${RESET_COLOR} or ${YELLOW}2${RESET_COLOR} (default: ${YELLOW}1${RESET_COLOR}): " ctype_choice

    case "${ctype_choice:-1}" in
        1) AV1_PARAMS="$AV1_PARAMS_LIVE_ACTION"; CONTENT_TYPE="Live-Action" ;;
        2) AV1_PARAMS="$AV1_PARAMS_ANIME"; CONTENT_TYPE="Anime" ;;
        *) AV1_PARAMS="$AV1_PARAMS_LIVE_ACTION"; CONTENT_TYPE="Live-Action"; log "WARN" "Invalid choice. Defaulting to Live-Action." ;;
    esac

    echo ""

    # File type
    read -erp "Enter the file type to search (default: \"${YELLOW}${DEFAULT_FILE_TYPE}${RESET_COLOR}\"): " FILE_TYPE
    FILE_TYPE="${FILE_TYPE:-$DEFAULT_FILE_TYPE}"

    # CRF
    echo -e "\nIn AV1 encoding, a lower CRF (Constant Rate Factor) means higher quality and a larger file size."
    echo -e " - CRF ${YELLOW}20–23${RESET_COLOR} is generally considered visually lossless."
    echo -e " - CRF ${YELLOW}24–28${RESET_COLOR} typically offers high-quality results with better compression."
    read -erp "Enter the CRF value (${YELLOW}0-63${RESET_COLOR}) (default: ${YELLOW}${DEFAULT_CRF}${RESET_COLOR}): " CRF_VALUE
    CRF_VALUE="${CRF_VALUE:-$DEFAULT_CRF}"

    if ! [[ "$CRF_VALUE" =~ ^[0-9]+$ ]] || (( CRF_VALUE < 0 || CRF_VALUE > 63 )); then
        log "ERROR" "Invalid CRF value. Must be an integer (0-63)."; exit 1;
    fi

    echo -e "\nIn AV1 encoding, a lower preset is slower but provides better quality/compression."
    echo -e " - Preset ${YELLOW}0-2${RESET_COLOR}: Highest quality/compression, very slow."
    echo -e " - Preset ${YELLOW}3-5${RESET_COLOR}: Excellent quality, balances speed and size."
    read -erp "Enter the FFmpeg preset (${YELLOW}0-12${RESET_COLOR}) (default: ${YELLOW}${DEFAULT_PRESET}${RESET_COLOR}): " PRESET_VALUE
    PRESET_VALUE="${PRESET_VALUE:-$DEFAULT_PRESET}"

    if ! [[ "$PRESET_VALUE" =~ ^[0-9]+$ ]] || (( PRESET_VALUE < 0 || PRESET_VALUE > 12 )); then
        log "ERROR" "Invalid preset value. Must be an integer (0-12)."; exit 1;
    fi
    
    # Audio handling
    echo -e "\nSelect how to handle the audio stream:"
    echo -e " ${YELLOW}1${RESET_COLOR}) ${CYAN}Convert to Opus${RESET_COLOR}: (Recommended) Finds the best audio track and converts it to high-quality Opus to save space."
    echo -e " ${YELLOW}2${RESET_COLOR}) ${CYAN}Copy (Remux)${RESET_COLOR}:   Copies all existing audio tracks without re-encoding. Fastest, but keeps original (often larger) audio."
    read -erp "Enter ${YELLOW}1${RESET_COLOR} or ${YELLOW}2${RESET_COLOR} (default: $DEFAULT_AUDIO_MODE): " audio_choice

    case "${audio_choice:-1}" in
        1) AUDIO_MODE="$DEFAULT_AUDIO_MODE" ;;
        2) AUDIO_MODE="copy" ;;
        *) AUDIO_MODE="$DEFAULT_AUDIO_MODE"; log "WARN" "Invalid choice. Defaulting to '$DEFAULT_AUDIO_MODE'." ;;
    esac

    echo ""

    # Fixing (remux) the video file if any error is detected in the verification
    read -erp "Verify and fix videos before encoding? (${YELLOW}y${RESET_COLOR}/${YELLOW}n${RESET_COLOR}) (default: ${YELLOW}${DEFAULT_VERIFY_FIX_VIDEOS}${RESET_COLOR}): " VALIDATE_FIX_VIDEOS
    VALIDATE_FIX_VIDEOS="${VALIDATE_FIX_VIDEOS:-$DEFAULT_VERIFY_FIX_VIDEOS}"
}

get_value(){
    local data="$1"
    local key_prefix="$2"
    local delimiter="$3"

    echo "$data" | grep "$key_prefix" | cut -d "$delimiter" -f2 | tr -d '"' | tr -d "'" # Remove quotes if any
}

set_color_value(){
    local metadata="$1"
    local color_type="$2"
    local value
    value=$(get_value "$metadata" "$color_type" "=")

    # If it's not unknown or N/A, return it as-is
    if [[ "$value" != "unknown" && "$value" != "N/A" && -n "$value" ]]; then
        echo "$value"
        return 0
    fi

    # Get height to determine fallback
    local height

    height=$(get_value "$metadata" "height" "=")
    if ! [[ "$height" =~ ^[0-9]+$ ]]; then
        log "ERROR" "Could not determine a valid video height from metadata. Height reported as: '$height'"
        return 1
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
            log "ERROR" "Unknown color_type specified in script logic: $color_type"
            return 1
            ;;
    esac
}

set_gop_value(){
    local metadata="$1"
    local gop="240" # A safe default for ~24fps video if detection fails
    local fps_raw
    local fps_calculated

    # First, try to get the real frame rate (r_frame_rate)
    fps_raw=$(get_value "$metadata" "r_frame_rate" "=")

    # If r_frame_rate is invalid or missing, fall back to average frame rate (avg_frame_rate)
    if [[ -z "$fps_raw" || "$fps_raw" == "0/0" || "$fps_raw" == "N/A" || "$fps_raw" == "unknown" ]]; then
        fps_raw=$(get_value "$metadata" "avg_frame_rate" "=")
    fi

    # Try to parse FPS like "24000/1001" or "25/1"
    if [[ "$fps_raw" =~ ^([0-9]+)/([1-9][0-9]*)$ ]]; then
        local fps_numerator="${BASH_REMATCH[1]}"
        local fps_denominator="${BASH_REMATCH[2]}"
        fps_calculated=$(echo "scale=4; $fps_numerator / $fps_denominator" | bc -l)
    # Handles integer or decimal FPS like "30" or "29.97"
    elif [[ "$fps_raw" =~ ^[0-9]+(\.[0-9]+)?$ && "$fps_raw" != "0" ]]; then
        fps_calculated="$fps_raw"
    else
        log "WARN" "Could not determine a valid FPS from metadata. Using default GOP of ${gop}."
        fps_calculated="" # Explicitly clear
    fi

    if [[ -n "$fps_calculated" ]]; then
        # Ensure fps_calculated is a positive number before using in bc
        if (( $(echo "$fps_calculated > 0" | bc -l) )); then
            # Calculate GOP as 10 seconds worth of frames
            gop=$(printf "%.0f" "$(echo "$fps_calculated * 10" | bc -l)")
        fi
    fi
    echo "$gop"
}

set_audio_value(){
    local metadata="$1"
    local codec channels bit_rate target_bitrate

    # If meta data is empty, copy the audio
    if [[ -z "$metadata" ]]; then
        echo "copy"
        return 0
    fi
    
    # Get the codec name (e.g. opus, eac3)
    codec=$(get_value "$metadata" "codec_name" "=")

    # If audio is empty or is the same as the default, copy
    if [[ "$codec" == "$DEFAULT_AUDIO_MODE" ]] || [[ -z "$codec" ]]; then
        echo "copy"
        return 0
    fi
    
    # Get the channel data and default to 2 (stereo) if missing
    channels=$(get_value "$metadata" "channels" "=")
    channels=${channels:-2}    

    if (( channels > 2)); then
        target_bitrate=$(( channels * 80)) # High quality target: 80kbps per channel
    else
        target_bitrate=256 # Excellent/transparent target for stereo
    fi

    # Sanity check: Don't exceed source bitrate if source is lossy/low
    bit_rate=$(get_value "$metadata" "bit_rate" "=")
    if [[ -n "$bit_rate" ]]; then
        bit_rate=$(( bit_rate / 1000))
        if (( bit_rate > 0 && target_bitrate > bit_rate )); then
            target_bitrate=$bit_rate
        fi
    fi

    echo "libopus"
    echo "-b:a"
    echo "${target_bitrate}k"

    # If we have 6 channels (5.1), add the required channel layout flag.
    if (( channels == 6 )); then
        echo "-channel_layout"
        echo "5.1"
    # Also handle 8 channels (7.1) proactively
    elif (( channels == 8 )); then
        echo "-channel_layout"
        echo "7.1"
    fi
}

# This function encapsulates all the logic for processing a single video file.
process_file() {
    local file="$1"
    local filename
    filename=$(basename -- "$file")
    # A blank line on the console helps separate processing blocks for different files.
    echo
    log "INFO" "${GREEN}Processing file${RESET_COLOR}: \"${YELLOW}${file}${RESET_COLOR}\""

    # Determine Output Filename
    local filename_no_ext="${filename%.*}"
    local output_filename_no_ext

    # turns on case-insensitive matching for the shell
    shopt -s nocasematch

    # Replacing encoding values by AV1
    if [[ "$filename_no_ext" =~ (x264|h264|x265|h265|hevc) ]]; then
        output_filename_no_ext="${filename_no_ext/${BASH_REMATCH[0]}/AV1}"
    else
        output_filename_no_ext="${filename_no_ext}_AV1"
    fi

    # Turn off case-insensitive matching to restore normal shell behavior
    shopt -u nocasematch

    local output_path="$DST_LOCATION/${output_filename_no_ext}.mkv"

    # Check if the destination file already exists
    if [[ -f "$output_path" ]]; then
        log "WARN" "${YELLOW}$output_path${RESET_COLOR} already exists. Skipping."
        UNPROCESSED_FILES+=("$output_path")
        return 0
    fi

    # Verify and Fix Video (replace the source file if the fix was successful)
    if [[ "$VALIDATE_FIX_VIDEOS" =~ ^[yY]$ ]]; then
        log "INFO" "Verifying video \"${YELLOW}${file}${RESET_COLOR}\" for errors..."
        local error_output
        error_output=$(ffmpeg -nostdin -v error -i "$file" -f null - 2>&1)

        if [[ -n "$error_output" ]]; then
            log "WARN" "${RED}Errors${RESET_COLOR} detected. Attempting to remux \"${YELLOW}${file}${RESET_COLOR}\"..."

            # Log the primary event, then loop through the detailed error lines.
            log "ERROR" "FFmpeg validation failed with the following output:\n${error_output}"

            local fixed_file
            fixed_file="$(dirname -- "$file")/${filename_no_ext}.fixed.mkv"

            if run_command ffmpeg -nostdin -i "$file" -c copy -map 0 -fflags +genpts "$fixed_file"; then
                log "INFO" "Fix ${GREEN}successful${RESET_COLOR}. Replacing original source file with the fixed version."
                mv -f "$fixed_file" "$file"
            else
                log "ERROR" "Fix failed. The original file will be used for encoding, but it may fail."
                rm -f "$fixed_file"
            fi
        else
            log "INFO" "No errors detected in the container."
        fi
    fi

    #---------------------------------
    # Setting some encoding parameters
    #---------------------------------
    local ffprobe_video_metadata
    ffprobe_video_metadata=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_space,color_primaries,color_transfer,color_range,height,r_frame_rate,avg_frame_rate -of default=noprint_wrappers=1 "$file")

    if [[ -z "$ffprobe_video_metadata" ]]; then
        log "ERROR" "Failed to read video stream metadata from \"${YELLOW}${file}${RESET_COLOR}\". Skipping file."
        return 1
    fi

    local color_primaries_value color_range_value color_space_value color_trc_value gop_value

    color_primaries_value=$(set_color_value "$ffprobe_video_metadata" "color_primaries") || {
        log "ERROR" "Failed to set color primaries for \"${YELLOW}${file}${RESET_COLOR}\". Skipping file."
        return 1
    }

    color_range_value=$(set_color_value "$ffprobe_video_metadata" "color_range") || {
        log "ERROR" "Failed to set color range for \"${YELLOW}${file}${RESET_COLOR}\". Skipping file."
        return 1
    }

    color_space_value=$(set_color_value "$ffprobe_video_metadata" "color_space") || {
        log "ERROR" "Failed to set color space for \"${YELLOW}${file}${RESET_COLOR}\". Skipping file."
        return 1
    }

    color_trc_value=$(set_color_value "$ffprobe_video_metadata" "color_transfer") || {
        log "ERROR" "Failed to set color transfer (trc) for \"${YELLOW}${file}${RESET_COLOR}\". Skipping file."
        return 1
    }

    gop_value=$(set_gop_value "$ffprobe_video_metadata") || {
        log "ERROR" "Failed to set GOP value for \"${YELLOW}${file}${RESET_COLOR}\". Skipping file."
        return 1
    }

    local ffprobe_audio_metadata audio_params
    
    # If not copy, get audio metadata for compressing
    if [[ "$AUDIO_MODE" == "$DEFAULT_AUDIO_MODE" ]]; then
        ffprobe_audio_metadata=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,channels,bit_rate -of default=noprint_wrappers=1 "$file")
        
        mapfile -t audio_params < <(set_audio_value "$ffprobe_audio_metadata") || {
            log "ERROR" "Failed to set the audio parameters for \"${YELLOW}${file}${RESET_COLOR}\". Skipping file."
            return 1
        }
    fi

    # Defaulting the audio parameters to copy if something went wrong
    if [ -z "$audio_params" ]; then
        audio_params=("copy")
    fi

    # Run Encoding Command
    local cmd=(
        ffmpeg -nostdin -i "$file"
        -map 0:v -map 0:a -map 0:s?
        -c:v "$CODEC" -pix_fmt yuv420p10le
        -colorspace "$color_space_value"
        -color_primaries "$color_primaries_value"
        -color_trc "$color_trc_value"
        -color_range "$color_range_value"
        -crf "$CRF_VALUE" -preset "$PRESET_VALUE"
        -g "$gop_value"
        -svtav1-params "$AV1_PARAMS"
        -c:a "${audio_params[@]}" -c:s copy
        -movflags +faststart "$output_path"
    )

    if ! run_command "${cmd[@]}"; then
        log "ERROR" "FFmpeg encoding FAILED for \"${YELLOW}${file}${RESET_COLOR}\". Deleting incomplete output file."
        rm -f "$output_path"
        return 1
    fi

    log "INFO" "${GREEN}Successfully${RESET_COLOR} encoded: \"${YELLOW}${output_path}${RESET_COLOR}\""
    return 0
}


#################################
# SCRIPT INITIALIZATION AND MAIN
#################################

# This is the main execution block of the script.
main() {
    # Verify Log File
    if [[ "$LOGGING_ENABLED" == "true" ]]; then
        mkdir -p "$(dirname "$LOG_FILE_PATH")" && touch "$LOG_FILE_PATH"

        if [[ ! -w "$LOG_FILE_PATH" ]]; then
            echo -e "${RED}ERROR${RESET_COLOR}: Log file at \"${YELLOW}${LOG_FILE_PATH}${RESET_COLOR}\" is not writable."
            local choice
            read -p "Write \"q\" to quit, or press [Enter] to continue without file logging: " choice

            if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
                echo "Quitting script."
                exit 0
            fi

            LOGGING_ENABLED=false
            echo -e "${YELLOW}File logging has been disabled for this session.${RESET_COLOR}"
        fi
    fi

    log "INFO" "FFmpeg AV1 Encoding Script started."

    # Get User Settings
    get_user_settings

    echo -e "\n${YELLOW}==================================================${RESET_COLOR}"
    echo -e "Batch starting with the following configuration:"
    echo -e "  Source Location: ${YELLOW}$SRC_LOCATION${RESET_COLOR}"
    echo -e "  Destination Location: ${YELLOW}$DST_LOCATION${RESET_COLOR}"
    echo -e "  File Type: ${YELLOW}$FILE_TYPE${RESET_COLOR}"
    echo -e "  Content Type: ${YELLOW}$CONTENT_TYPE${RESET_COLOR}"
    echo -e "  CRF: ${YELLOW}$CRF_VALUE${RESET_COLOR}"
    echo -e "  Preset: ${YELLOW}$PRESET_VALUE${RESET_COLOR}"
    echo -e "  Audio Mode: ${YELLOW}$AUDIO_MODE${RESET_COLOR}"
    echo -e "  AV1 Parameters: ${YELLOW}$AV1_PARAMS${RESET_COLOR}"
    echo -e "  Verify/Fix Videos: ${YELLOW}$VALIDATE_FIX_VIDEOS${RESET_COLOR}"
    echo -e "${YELLOW}==================================================${RESET_COLOR}"

    # Ensure the destination directory exists before we start processing.
    mkdir -p "$DST_LOCATION"

    # Find and Process Files
    local files=()
    # Safely read file paths into an array, even those with special characters
    mapfile -d '' files < <(find "$SRC_LOCATION" -type f -name "*.$FILE_TYPE" -print0 | sort -z)

    if (( ${#files[@]} == 0 )); then
        log "WARN" "No files of type \"${YELLOW}${FILE_TYPE}${RESET_COLOR}\" found in directory: \"${YELLOW}${SRC_LOCATION}${RESET_COLOR}\"."
        exit 0
    fi

    log "INFO" "Found ${#files[@]} file(s) to process."
    local success_count=0
    local failure_count=0

    for file in "${files[@]}"; do
        if process_file "$file"; then
            ((success_count++))
        else
            ((failure_count++))
            log "ERROR" "A critical error occurred while processing \"${YELLOW}${file}${RESET_COLOR}\". The script will continue with the next file."
        fi
    done

    # Final Report
    echo -e "\n${YELLOW}==================================================${RESET_COLOR}"
    log "INFO" "FFmpeg AV1 Encoding Script completed."
    echo -e "${YELLOW}==================================================${RESET_COLOR}"

    log "INFO" "Successfully processed: ${GREEN}$success_count${RESET_COLOR} file(s)."
    log "INFO" "Failed to process: ${RED}$failure_count${RESET_COLOR} file(s)."

    if (( ${#UNPROCESSED_FILES[@]} > 0 )); then
        local skipped_message="The following files were skipped (destination already existed):\n"
        skipped_message+=$(printf -- ' - %s\n' "${UNPROCESSED_FILES[@]}")
        log "WARN" "$skipped_message"
    fi
}

# This construct ensures that the script's execution begins at the `main` function.
main "$@"
