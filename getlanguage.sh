#!/bin/bash

# Check if the directory 'name' exists, if not, create it
if [ ! -d "language" ]; then
    mkdir language
fi

# Read each line from inputfilelist
while IFS= read -r file; do
    # Check if the file exists
    if [ -f "$file" ]; then
        # Extract the author's name and store it in the 'name' directory
        grep 'Language:' "$file" | sed 's/Language: //' > "language/${file%.txt}.txt"
    else
        echo "File $file not found."
    fi
done < "inputfilelist"
