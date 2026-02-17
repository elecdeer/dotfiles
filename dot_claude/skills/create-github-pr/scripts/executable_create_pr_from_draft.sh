#!/usr/bin/env bash
# Create PR from draft file with YAML frontmatter

set -euo pipefail

draft_file="${1:-}"

if [[ -z "$draft_file" ]]; then
  echo "Error: Draft file path is required" >&2
  echo "Usage: $0 <draft-file-path>" >&2
  exit 1
fi

if [[ ! -f "$draft_file" ]]; then
  echo "Error: Draft file not found: $draft_file" >&2
  exit 1
fi

# Parse YAML frontmatter
in_frontmatter=false
title=""
base=""
head=""
body_lines=()

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" == "---" ]]; then
    if [[ "$in_frontmatter" == "false" ]]; then
      in_frontmatter=true
      continue
    else
      in_frontmatter=false
      continue
    fi
  fi
  
  if [[ "$in_frontmatter" == "true" ]]; then
    # Parse frontmatter fields
    if [[ "$line" =~ ^title:\ *(.+)$ ]]; then
      title="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^base:\ *(.+)$ ]]; then
      base="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^head:\ *(.+)$ ]]; then
      head="${BASH_REMATCH[1]}"
    fi
  else
    # Collect body lines
    body_lines+=("$line")
  fi
done < "$draft_file"

# Validate required fields
if [[ -z "$title" ]]; then
  echo "Error: 'title' field is missing in frontmatter" >&2
  exit 1
fi

if [[ -z "$base" ]]; then
  echo "Error: 'base' field is missing in frontmatter" >&2
  exit 1
fi

if [[ -z "$head" ]]; then
  echo "Error: 'head' field is missing in frontmatter" >&2
  exit 1
fi

# Join body lines
body=$(printf "%s\n" "${body_lines[@]}")

# Create temporary file for body content
temp_body=$(mktemp)
trap "rm -f $temp_body" EXIT
echo "$body" > "$temp_body"

echo "=== Creating PR ==="
echo "Title: $title"
echo "Base: $base"
echo "Head: $head"
echo ""

# Create PR using gh CLI
gh pr create \
  --base "$base" \
  --head "$head" \
  --title "$title" \
  --body-file "$temp_body"
