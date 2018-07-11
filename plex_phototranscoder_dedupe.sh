#!/bin/bash
#
# Workaround for duplicate files in PhotoTranscoder.
# Symlinks each duplicate file to the oldest (original) file
#
# https://www.reddit.com/r/PleX/comments/8vuhan/think_ive_found_a_cache_bug_large_cache_directory
# https://forums.plex.tv/t/plex-server-cache-over-310gb/274438/10
#
# Authors:
# Shawn Bruce                   - https://github.com/kantlivelong
# SB Tech Services  (www.sbts.com.au)   - https://github.com/sbts
#
#


dry_run=0
skip_warn=0
use_relative=0
cur_hash=""
cur_file=""
first_hash=""
first_file=""

CleanupTempFiles() {
    rm $tmpfilelistp1
    rm $tmpfilelistp2
}

show_help() {
    echo -e "Usage: ${0##*/} [OPTION]... /path/to/PhotoTranscoder"
    echo -e "\t-h\t\t Help"
    echo -e "\t-n\t\t Dry-run"
    echo -e "\t-Y\t\t Skip warning message."
    echo -e "\t-r\t\t Use relative symlinks."
}

if [ $# -lt 1 ]
then
    show_help
    exit 1
fi

while getopts "hnYr" opt; do
    case "$opt" in
    h)
        show_help
        exit 0
        ;;
    n)
        dry_run=1
        ;;
    Y)
        skip_warn=1
        ;;
    r)
        use_relative=1
        ;;
    esac
done


read -rst5 phototranscoder_path < <( readlink -f "${@: -1}"; )

if (( EUID != 0 )); then
   echo "This script must be run as root!" 
   exit 1
fi

if [[ ! -d $phototranscoder_path ]]; then
    echo "PhotoTranscoder path does not exist! - ${phototranscoder_path}"
    exit 1
fi

if [ $skip_warn -eq 0 ]
then
    echo "Please ensure Plex is stopped and you have a backup before continuing."
    echo "This process can take hours to complete."
    echo ""
    echo "Press ENTER to continue."
    read
fi

#CreateTempfiles
trap CleanupTempFiles EXIT
tmpfilelistp1=$(mktemp)
tmpfilelistp2=$(mktemp)

#GenerateFileList
echo "Generating list of files (part 1)..."
while read -rst240 Ts Sum Name ; do
    printf '%s %s %s\n' "$Sum" "$Ts" "$Name" >> $tmpfilelistp1
done < <( find "${phototranscoder_path}" -type f -printf "%C@\t" -exec md5sum "{}" \; )

echo "Generating list of files (part 2)..."
sort -o $tmpfilelistp2 $tmpfilelistp1

#DeDuplicate
echo "Symlinking duplicates to originals..."

while read -rst5 cur_hash cur_ts cur_file
do
    if [[ "${cur_hash}" == "${first_hash}" ]]
    then
        echo -e "     \tDUPE : ${cur_hash} - ${cur_file}"
        if [ $dry_run -eq 0 ]
        then
            if [ $use_relative -eq 1 ]
            then
                ln -sfr "${first_file}" "${cur_file}"
            else
                ln -sf "${first_file}" "${cur_file}"
            fi
            chown --reference="${first_file}" "${cur_file}"
        fi
    else
        first_hash=$cur_hash
        first_file=$cur_file
        echo -e "=====\tORIG : ${first_hash} - ${first_file}"
    fi

done < $tmpfilelistp2

exit
