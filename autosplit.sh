#!/bin/bash

# Prevent globbing patterns from being expanded
set -f
# 1.95GiB max size to avoid hitting GitHub and Tribes 2 ceilings
# Might be too high if GitHub uses GB instead of GiB, let me know
#SIZE_LIMIT=2093790080
# test partitioning
SIZE_LIMIT=52428800

EXCLUSIONS="$1"
ARTIFACT_PREFIX="$2"

PATH_SIZE=$(du -b . | tail -n1 | cut -f1)

direct_zip() {
    # Convert comma-separated string to 'zip -x "pattern"' arguments
    EXCLUDE_ARGS=""
    IFS=',' read -ra PATTERNS <<< "$EXCLUSIONS"
    for P in "${PATTERNS[@]}"; do
        P_TRIMMED=$(echo "$P" | xargs)
        if [ -n "$P_TRIMMED" ]; then
        EXCLUDE_ARGS="$EXCLUDE_ARGS -x \"$P_TRIMMED\""
        fi
    done
    
    # Execute the zip command using 'eval' to properly handle multiple exclusion arguments
    eval "zip -0 -r ${ARTIFACT_PREFIX}.vl2 . $EXCLUDE_ARGS"
}

if [[ $PATH_SIZE -lt $SIZE_LIMIT ]]; then
    # short circuit to faster mechanism that doesn't involve stat (slow when the repo has thousands of small files)
    direct_zip
    exit 0
fi

CURRENT_SIZE=0
LIST_FILE_COUNT=1

FIND_EXCLUDES=()
IFS=', ' read -r -a PATTERNS_ARRAY <<< "$EXCLUSIONS"
for pattern in "${PATTERNS_ARRAY[@]}"; do
    FIND_EXCLUDES+=( -not -path "./$pattern" )
done

echo "exclusions: ${FIND_EXCLUDES[@]}"

next_list() {
    if [[ $LIST_FILE_COUNT -ne 1 ]]; then
        LAST_COUNT=$(($LIST_FILE_COUNT-1))
        echo "Zipping archive part ${LAST_COUNT}"
        zip -0 -@ ${ARTIFACT_PREFIX}-part${LAST_COUNT}.vl2 < $LIST_FILENAME > /dev/null
        rm $LIST_FILENAME
    fi
    LIST_FILENAME="file_list_${LIST_FILE_COUNT}.txt"
    LIST_FILE_COUNT=$((LIST_FILE_COUNT + 1))
    CURRENT_SIZE=0
}

next_list

while IFS= read -r -d $'\0' file; do
    FILE_SIZE=$(stat -c%s "$file" 2>/dev/null)
    if [ -z "$FILE_SIZE" ]; then
        echo "Warning: Could not get size for file: $file. Skipping."
        continue
    fi
    if (( CURRENT_SIZE + FILE_SIZE > SIZE_LIMIT )); then
        next_list
        echo "Collecting files for vl2 part $LIST_FILENAME"
    fi
    echo "$file" >> "$LIST_FILENAME"
    # Update the current size
    CURRENT_SIZE=$((CURRENT_SIZE + FILE_SIZE))
done < <(find . "${FIND_EXCLUDES[@]}" -type f -print0)

next_list
