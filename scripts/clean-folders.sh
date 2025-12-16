#!/bin/bash

if [ ! -f ./pid.clean-folders ]
then
    echo "Cleaning in progress..." > pid.clean-folders

    # Outputs the UTC time + the current process ID. Example: 2024-01-28T18:49:10.335Z-1234
    function print_timestamp()
    {
        echo -n $(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")-$$
        return 0
    }

    for folder in ./read/*/; do

        # Remove trailing slash from path+filename
        folder_name="${folder%/}"

        # Search and delete duplicated files
        echo -n "$(print_timestamp) ☕ Folder $folder_name: Searching and cleaning duplicates ..."
        TIMEFORMAT='%R'
        execution_time=$({ time( find $folder -type f -print0 | xargs -0P $(nproc --all) md5sum | awk '++seen[$1]>1{print $2}' | xargs --no-run-if-empty rm )} 2>&1 )
        echo "done in $execution_time seconds"

    done

    rm pid.clean-folders

else
    echo "Cleaning in progress; not starting"
fi
