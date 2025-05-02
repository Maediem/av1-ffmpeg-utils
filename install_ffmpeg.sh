#!/bin/bash

#############
# Variables #
#############

AUTH_USER=$(whoami)
FFMPEG_URL="https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-linux64-gpl-shared.tar.xz"
DOWNLOAD_DIR="$HOME/Downloads"
EXTRACTED_DIR="ffmpeg-master-latest-linux64-gpl-shared"
INSTALL_DIR="/opt/ffmpeg"
PROFILE_SCRIPT="/etc/profile.d/ffmpeg.sh"
PROFILE_LIB_SCRIPT="/etc/profile.d/ffmpeg_lib.sh"

###############
# MAIN SCRIPT #
###############

if sudo -l >/dev/null 2>&1; then
    echo "User has sudo privilege and thus, this script can proceed."
else
    echo "User does not have sudo privilege. Cannot proceed."
    exit 1
fi

if [ "$AUTH_USER" == 'root' ] && [ -n "$SUDO_USER" ]; then
    DOWNLOAD_DIR="/home/${SUDO_USER}/Downloads"
fi

# Ensure that the Downloads directory exists
mkdir -p "$DOWNLOAD_DIR"

# Go to Downloads directory
cd "$DOWNLOAD_DIR" || { echo "Failed to access $DOWNLOAD_DIR"; exit 1; }

# Download the latest FFmpeg build
wget -O ffmpeg.tar.xz "$FFMPEG_URL" || { echo "Failed to download ffmpeg with wget via '$FFMPEG_URL'"; exit 1; }

# Extract the archive
tar -xvf ffmpeg.tar.xz || { echo "Failed to extract ffmpeg via 'tar -xvf' commnd"; exit 1; }

# Rename extracted directory to "ffmpeg"
mv "$EXTRACTED_DIR" "ffmpeg" || { echo "Failed to rename the extracted directory '$EXTRACTED_DIR' to 'ffmpeg'"; exit 1; }

# Move FFmpeg to /opt/ffmpeg
sudo rm -rf "$INSTALL_DIR" # Deleting current directory if it exists
sudo mv ffmpeg "$INSTALL_DIR" || { echo "Failed to move 'ffmpeg' to '$INSTALL_DIR'"; exit 1; }

# Ensure the PATH variable is set
if [ ! -f "$PROFILE_SCRIPT" ]; then
    echo 'export PATH="/opt/ffmpeg/bin:$PATH"' | sudo tee "$PROFILE_SCRIPT"
fi

# Ensure the LD_LIBRARY_PATH variable is set
if [ ! -f "$PROFILE_LIB_SCRIPT" ]; then
    echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/ffmpeg/lib' | sudo tee "$PROFILE_LIB_SCRIPT"
fi

# Source the new profiles
source "$PROFILE_SCRIPT"
source "$PROFILE_LIB_SCRIPT"

# Verify FFmpeg installation
ffmpeg -version && echo -e "\nffmpeg installed successfully!"
