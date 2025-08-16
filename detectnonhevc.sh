#!/usr/bin/env bash
# Version 1.0.0 - Detect non-HEVC video files (H.265)
# Works recursively through subdirectories

FFPROBE="/usr/bin/ffprobe"
LOCKFILE="/tmp/non_hevc_detect.lock"
EXTS="mkv|mp4|mov|avi|ts"

IFS=$'\n'

# 🔒 Acquire lock
exec 200>"$LOCKFILE"
flock -w 600 200 || {
    echo "⏳ Timeout waiting for lock. Another instance may be running. Exiting."
    exit 1
}

# 🔍 Check ffprobe
if ! command -v "$FFPROBE" &> /dev/null; then
    echo "❌ ffprobe not found. Install ffmpeg."
    exit 1
fi

# 📁 Directory check
if [ -z "$1" ]; then
    echo "⚠️ Please provide a directory path as an argument."
    exit 1
fi

dir="$1"
if [ ! -d "$dir" ]; then
    echo "❌ Directory doesn't exist: $dir"
    exit 1
fi

# Clear previous report
> /tmp/non_hevc_list.txt

# 🧹 Function to process a single file
process_file() {
    local file="$1"
    echo -e "\n📦 Checking: $file"

    local codec
    codec=$("$FFPROBE" -v error -select_streams v:0 \
            -show_entries stream=codec_name \
            -of default=noprint_wrappers=1:nokey=1 "$file")

    if [ -z "$codec" ]; then
        echo "⚠️ No video stream found."
        return
    fi

    if [[ "$codec" == "hevc" ]]; then
        echo "✅ HEVC"
    else
        echo "❌ Not HEVC → $codec"
        echo "$file" >> /tmp/non_hevc_list.txt
    fi
}

# 🔄 Process all files recursively, checking extensions
while IFS= read -r file; do
    ext="${file##*.}"
    shopt -s nocasematch
    if [[ "$ext" =~ ^($EXTS)$ ]]; then
        process_file "$file"
    fi
    shopt -u nocasematch
done < <(find "$dir" -type f)

# 📊 Summary
if [ -s /tmp/non_hevc_list.txt ]; then
    echo -e "\n📊 Files NOT HEVC:"
    cat /tmp/non_hevc_list.txt
else
    echo -e "\n🎉 All video files are HEVC!"
fi

unset IFS
