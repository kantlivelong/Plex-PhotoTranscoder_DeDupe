#!/bin/bash
#
# Workaround for duplicate files in PhotoTranscoder.
# Symlinks each duplicate file to the oldest (original) file
#
# https://www.reddit.com/r/PleX/comments/8vuhan/think_ive_found_a_cache_bug_large_cache_directory
# https://forums.plex.tv/t/plex-server-cache-over-310gb/274438/10
#

read -rst5 phototranscoder_path < <( readlink -f "$1"; )

cur_hash=""
cur_file=""
first_hash=""
first_file=""


if (( EUID != 0 )); then
   echo "This script must be run as root!" 
   exit 1
fi


if (( ${#} != 1 )); then
    echo "Usage:"
    echo "  ${0##*/} /path/to/PhotoTranscoder"
    exit 1
fi


if [[ ! -d $phototranscoder_path ]]; then
    echo "PhotoTranscoder path does not exist! - ${phototranscoder_path}"
    exit 1
fi


echo "Please ensure Plex is stopped and you have a backup before continuing."
echo "This process can take hours to complete."
echo ""
echo "Press ENTER when ready."
read

CleanupTempFiles() {
    rm $tmpfilelistp1
    rm $tmpfilelistp2
}

CreateTempfiles() {
    trap CleanupTempFiles EXIT
    tmpfilelistp1=$(mktemp)
    tmpfilelistp2=$(mktemp)
}


GenerateFileList() {
    echo "Generating list of files (part 1)...  (Unsorted)"
    while read -rst240 Ts Sum Name ; do
        printf '%s %s %s\n' "$Sum" "$Ts" "$Name" >> $tmpfilelistp1
    done < <( find "${phototranscoder_path}" -type f -printf "%C@\t" -exec md5sum "{}" \; )

    echo "Generating list of files (part 2)...  (Sorted)"
    sort -o $tmpfilelistp2 $tmpfilelistp1
}

DeDuplicate() {
    echo "Symlinking duplicates to originals...  (Sorted)"

    while read -rst5 cur_hash cur_ts cur_file; do

        if [[ "${cur_hash}" == "${first_hash}" ]]; then
            echo "      DUPE : ${cur_hash} - ${cur_file}"
            rm "${cur_file}"
            ln -s "${first_file}" "${cur_file}"
            chown --reference="${first_file}" "${cur_file}"
        else
            first_hash=$cur_hash
            first_file=$cur_file
            echo -e "\n===== ORIG : ${first_hash} - ${first_file}"
        fi

    done < $tmpfilelistp2
}

CreateTempfiles
GenerateFileList
DeDuplicate

exit
