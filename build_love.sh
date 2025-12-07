#!/bin/bash

# Build script for creating a .love file
# This script creates a zip file with all game files at the root level

# Remove old .love file if it exists
if [ -f "Sunder.love" ]; then
    rm "Sunder.love"
    echo "Removed old Sunder.love file"
fi

# Create the .love file by zipping all necessary files
# The -r flag makes it recursive, -9 is maximum compression
# The -x flag excludes files we don't want in the distribution
zip -r -9 Sunder.love \
    main.lua \
    *.lua \
    assets/ \
    libraries/ \
    -x "*.git*" \
    -x "*Archive.love" \
    -x "*Sunder.love" \
    -x "*.sh" \
    -x "*.py" \
    -x "*.md" \
    -x "*.txt" \
    -x ".vscode/*" \
    -x ".cursor/*" \
    -x "bug_tracker.txt" \
    -x "userinput.py" \
    -x "build_love.sh"

echo "Created Sunder.love file successfully!"
echo "You can now run it with: love Sunder.love"
