#!/usr/bin/env bash
# Create empty temporary file for PR content

set -euo pipefail

# Create temporary directory
temp_dir=$(mktemp -d)
temp_file="$temp_dir/pr-content.md"

# Create empty file
touch "$temp_file"

# Output the file path
echo "$temp_file"
