#!/bin/bash

# Check if the directory 'name' exists, if not, create it
if [ ! -d "name" ]; then
    mkdir name
fi

# Read each line from inputfilelist
while IFS= read -r file; do
    # Check if the file exists
    if [ -f "$file" ]; then
        # Extract the author's name and store it in the 'name' directory
        grep 'Author:' "$file" | sed 's/Author: //' > "name/${file%.txt}.txt"
    else
        echo "File $file not found."
    fi
done < "inputfilelist"
