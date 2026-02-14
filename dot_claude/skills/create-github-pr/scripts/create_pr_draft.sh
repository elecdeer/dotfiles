#!/usr/bin/env bash
# Create temporary file with PR content template in YAML frontmatter format

set -euo pipefail

title="${1:-}"
base="${2:-main}"
head="${3:-$(git branch --show-current)}"
body="${4:-}"

# Create temporary directory
temp_dir=$(mktemp -d)
temp_file="$temp_dir/pr-content.md"

# Write content with YAML frontmatter
cat > "$temp_file" <<EOF
---
title: $title
base: $base
head: $head
---

$body
EOF

# Output the file path
echo "$temp_file"
