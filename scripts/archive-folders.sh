#!/bin/zsh

# Icons: ✔ ✅ ❎ ✖ ⛔ ☕ ● 🛈 ⚠

# Note: Starting from block 38210031 (2022-09-27T16_04_30.648154915Z.rcd.gz) compressing saves only ~50Mb per day max
# because record files are already gzipped. It is still ~16Gb per year, so I continue archiving in a compressed
# format but I do only in gz, because xz starts resulting in a bigger files with a lot of additional time to
# compress/decompress, so it makes no sense anymore to use it


# Signatures: xz
# Records:
    # Until 2022-09-27:         xz
    # Starting from 2022-09-28: gz

set -euo pipefail

pattern=$1      # For example 2019, 2019-09, 2019-09-13, etc.
GZIPPED_FILES_START_DATE="2022-09-27"

# Outputs the UTC time + the current process ID. Example: 2024-01-28T18:49:10.335Z-1234
function print_timestamp()
{
    echo -n $(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")-$$
    return 0
}

# Expect a filename as parameter
function file_size()
{
    echo $(stat -c %s "$1" | numfmt --to=iec)
}

# Stop the script gracefully
function graceful_stop_check()
{
    if [[ -f graceful-stop ]]; then
        echo "$(print_timestamp) 🛈  Graceful stop requested." | tee -a logs/graceful-stop-executed.log
        rm ./wip/archiving
        exit 0
    fi
}

if [[ -f wip/archiving ]]; then
    echo "\n$(print_timestamp) 🛈  New archiving request detected, but another one is already in progress. Skipping that request."
    exit 0
fi

touch ./wip/archiving

echo "$(print_timestamp) 🛈  Searching for ready-to-archive folders."
stream_folders=($(ls ./streams));
if (( ${#stream_folders[@]} > 1 )); then
    # Remove the last element of the list, that is always the current live sync folder
    unset stream_folders\[-1\]
    for folder in $stream_folders; do
        echo -n "$(print_timestamp) ☕ Moving ./streams/$folder to ./read/$folder ..."
        mv ./streams/$folder ./read
        echo "done."
        graceful_stop_check
    done
fi

for folder in ./read/*; do
    if [[ $folder == ./read/$pattern* ]]; then
        local foldername=$(echo $folder | cut -c 8-)
        
        # Exceptions
        if grep -q $foldername ./skip; then
            echo "$(print_timestamp) ⛔ $foldername: Found it in the exception list. Skipping."
            continue
        fi

        # Move from read to wip
        mv $folder ./wip

        local output_signatures_fullpath="./write/$foldername.signatures.tar.xz"
        local output_records_tar_path="./write/$foldername.records.tar"
        local output_records_compressed_path="$output_records_tar_path.xz"
        if [[ "$foldername" > "$GZIPPED_FILES_START_DATE" ]]; then
            output_records_compressed_path="$output_records_tar_path.gz"
            fi

            if [[ -s "$output_signatures_fullpath" && -s "$output_records_compressed_path" ]]; then
                echo "$(print_timestamp) ⛔ $foldername: All archives already exist. Skipping ($output_signatures_fullpath, $output_records_compressed_path)"
                continue
        fi

        # Search and delete duplicated files
        echo -n "$(print_timestamp) ☕ $foldername: Searching and cleaning duplicates in ./wip/$foldername ..."
        find ./wip/$foldername -type f -print0 | xargs -0P $(nproc --all) md5sum | awk '++seen[$1]>1{print $2}' | xargs --no-run-if-empty rm
        echo "done."
        graceful_stop_check

        # Check all files are there
        echo "$(print_timestamp) ☕ $foldername: Checking folder contains all files for that day ..."
        ./check-files.zsh $foldername wip
        if [ $? -ne 0 ]; then
            echo "✖ Error while checking source files"
            continue
        fi
        # If something went wrong with check-files the date is now marked to be skipped
        if grep -q $foldername ./skip; then
            echo "$(print_timestamp) ⛔ $foldername: Problems with the content for the day. Moving ./wip/$foldername back to ./read/$foldername folder and skipping."
            mv ./wip/$foldername ./read
            continue
        fi
        graceful_stop_check

        # Compress signatures
        if [[ ! -s "$output_signatures_fullpath" ]]; then
            # Create a temp tar file for signatures
            temp_signature_tar="./wip/$foldername.signatures.tar"
            echo -n "$(print_timestamp) ☕ $foldername: Creating temporary tar $temp_signature_tar ..."
            find ./wip/$foldername -type f -name "*.rcd_sig" | cut -c 7- | tar -cf $temp_signature_tar -C ./wip -T -
            echo "done (size: $(file_size $temp_signature_tar))"
            echo -n "$(print_timestamp) ☕ $foldername: Creating signatures archive $output_signatures_fullpath ..."
            xz -6 -T0 -c "$temp_signature_tar" > "$output_signatures_fullpath"
            if [ $? -eq 0 ]; then
                echo "done (size: $(file_size $output_signatures_fullpath))"
                echo -n "$(print_timestamp) ☕ $foldername: Removing temporary tar $temp_signature_tar ..."
                rm -rf "$temp_signature_tar"
                echo "done."
            fi
        else
            echo "$(print_timestamp) 🛈  $foldername: Signatures archive $output_signatures_fullpath already exists (size: $(file_size $output_signatures_fullpath))"
        fi
        graceful_stop_check
        
        # Create a tar file for all data but signatures directly to the destination folder
        if [[ ! -s "$output_records_tar_path" ]]; then
            echo -n "$(print_timestamp) ☕ $foldername: Creating records tar $output_records_tar_path ..."
            find ./wip/$foldername -type f ! -name "*.rcd_sig" | cut -c 7- | tar -cf $output_records_tar_path -C ./wip -T -
            echo -n "done"
        else
            echo -n "$(print_timestamp) 🛈  $foldername: Records tar $output_records_tar_path already exists"
        fi
        echo " (size: $(file_size $output_records_tar_path))"
        graceful_stop_check

        # Compress the records
        if [[ ! -s "$output_records_compressed_path" ]]; then
            echo -n "$(print_timestamp) ☕ $foldername: Creating records archive $output_records_compressed_path ..."
            if [[ "$foldername" > "$GZIPPED_FILES_START_DATE" ]]; then
                pigz -k -c "$output_records_tar_path" > "$output_records_compressed_path"
            else                    
                xz -k -6 -T0 -c "$output_records_tar_path" > "$output_records_compressed_path"
            fi
            # Remove temp folder and file
            if [ $? -eq 0 ]; then
                echo "done (size: $(file_size $output_records_compressed_path))"
                echo -n "$(print_timestamp) ☕ $foldername: Removing temporary folder ./wip/$foldername ..."
                rm -rf "./wip/$foldername"
                echo "done."
                echo -n "$(print_timestamp) ☕ $foldername: Removing temporary tar $output_records_tar_path ..."
                rm -f "$output_records_tar_path"
                echo "done."
            fi                    
        else
            echo "$(print_timestamp) ⛔ $foldername: Compressed archive $output_records_compressed_path already exist. Skipping."
            continue
        fi
        graceful_stop_check
    fi
done

echo "$(print_timestamp) 🛈  Archive process completed."

rm ./wip/archiving
