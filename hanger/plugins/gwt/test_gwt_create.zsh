#!/usr/bin/env zsh

set -eu
set -o pipefail

SCRIPT_DIR=${0:A:h}
GWT_CREATE_SCRIPT="$SCRIPT_DIR/executable_gwt-create"

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/gwt-create-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT

remote_repo="$tmpdir/remote.git"
repo_root="$tmpdir/repo"

git init --bare "$remote_repo" >/dev/null
git init "$repo_root" >/dev/null
git -C "$repo_root" config user.name "Codex Test"
git -C "$repo_root" config user.email "codex@example.com"

printf 'base\n' > "$repo_root/file.txt"
git -C "$repo_root" add file.txt
git -C "$repo_root" commit -m "initial commit" >/dev/null
git -C "$repo_root" branch -M main
git -C "$repo_root" remote add origin "$remote_repo"
git -C "$repo_root" push -u origin main >/dev/null

origin_main_hash=$(git -C "$repo_root" rev-parse origin/main)

printf 'local only\n' >> "$repo_root/file.txt"
git -C "$repo_root" commit -am "local main ahead" >/dev/null
local_main_hash=$(git -C "$repo_root" rev-parse HEAD)

origin_feature_path=$(
  cd "$repo_root" &&
    "$GWT_CREATE_SCRIPT" origin-feature "__BASE__:origin/main"
)
origin_feature_hash=$(git -C "$repo_root" rev-parse origin-feature)

[[ -d "$origin_feature_path" ]]
[[ "$origin_feature_hash" == "$origin_main_hash" ]]
[[ "$origin_feature_hash" != "$local_main_hash" ]]

git -C "$repo_root" checkout -b feature-base >/dev/null
printf 'feature base\n' >> "$repo_root/file.txt"
git -C "$repo_root" commit -am "feature base" >/dev/null
feature_base_hash=$(git -C "$repo_root" rev-parse HEAD)
git -C "$repo_root" checkout main >/dev/null

local_feature_path=$(
  cd "$repo_root" &&
    "$GWT_CREATE_SCRIPT" local-feature "__BASE__:feature-base"
)
local_feature_hash=$(git -C "$repo_root" rev-parse local-feature)

[[ -d "$local_feature_path" ]]
[[ "$local_feature_hash" == "$feature_base_hash" ]]
[[ "$local_feature_hash" != "$local_main_hash" ]]

print "test_gwt_create: ok"
