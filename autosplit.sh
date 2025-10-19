#!/bin/bash

# 1.95GiB max size to avoid hitting GitHub ceilings
SIZE_LIMIT=2093790080
CURRENT_SIZE=0
LIST_FILE_COUNT=1

# Check for the required folder argument
if [ -z "$1" ]; then
    echo "Usage: $0 <folder_path>"
    exit 1
fi

FOLDER_PATH="$1"

next_list() {
    LIST_FILENAME="file_list_${LIST_FILE_COUNT}.txt"
    LIST_FILE_COUNT=$((LIST_FILE_COUNT + 1))
    CURRENT_SIZE=0
}

next_list

find "$FOLDER_PATH" -type f -print0 | while IFS= read -r -d $'\0' file; do
    FILE_SIZE=$(stat -c%s "$file" 2>/dev/null)

    if [ -z "$FILE_SIZE" ]; then
        echo "Warning: Could not get size for file: $file. Skipping." >> "file_list_errors.log"
        continue
    fi

    if (( CURRENT_SIZE + FILE_SIZE > SIZE_LIMIT )); then
        next_list
    fi
    
    echo "$FILE_SIZE $file" >> "$LIST_FILENAME"
    
    # Update the current size
    CURRENT_SIZE=$((CURRENT_SIZE + FILE_SIZE))

done

exit $LIST_FILE_COUNT
