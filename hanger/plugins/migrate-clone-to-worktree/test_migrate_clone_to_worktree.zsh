#!/usr/bin/env zsh
set -euo pipefail

plugin_dir="${0:A:h}"
source "${plugin_dir}/migrate-clone-to-worktree.plugin.zsh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

assert_file_exists() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    print -u2 "expected file to exist: $path"
    exit 1
  fi
}

assert_dir_exists() {
  local path="$1"
  if [[ ! -d "$path" ]]; then
    print -u2 "expected directory to exist: $path"
    exit 1
  fi
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  if [[ "$expected" != "$actual" ]]; then
    print -u2 "expected: $expected"
    print -u2 "actual  : $actual"
    exit 1
  fi
}

repo="${tmp_dir}/myrepo"
git init --initial-branch=main "$repo" >/dev/null
git -C "$repo" config user.name "Test User"
git -C "$repo" config user.email "test@example.com"

print "main file" > "${repo}/README.md"
mkdir -p "${repo}/src"
print "console.log('main')" > "${repo}/src/index.js"
mkdir -p "${repo}/node_modules/example"
print "ignored" > "${repo}/node_modules/example/index.js"
git -C "$repo" add README.md src/index.js
git -C "$repo" commit -m "Initial commit" >/dev/null

git -C "$repo" switch -c feature >/dev/null 2>&1
print "feature file" > "${repo}/feature.txt"
git -C "$repo" add feature.txt
git -C "$repo" commit -m "Add feature" >/dev/null
git -C "$repo" switch - >/dev/null 2>&1
git -C "$repo" worktree add "${repo}/.wt/feature" feature >/dev/null 2>&1

print "uncommitted" > "${repo}/local.txt"

printf 'y\n' | migrate_clone_to_worktree "$repo" >/dev/null 2>&1

output="${tmp_dir}/myrepo.wt-layout"
root="${output}/\$root"
feature_wt="${output}/feature"

assert_dir_exists "$root"
assert_dir_exists "${root}/.git"
assert_file_exists "${root}/README.md"
assert_file_exists "${root}/src/index.js"
assert_file_exists "${root}/local.txt"
assert_file_exists "${feature_wt}/feature.txt"

if [[ -e "${root}/node_modules" ]]; then
  print -u2 "node_modules should not be copied"
  exit 1
fi

assert_equals "false" "$(git -C "$root" rev-parse --is-bare-repository)"
assert_equals ".." "$(git -C "$root" config wt.basedir)"
assert_equals "feature" "$(git -C "$feature_wt" branch --show-current)"

git -C "$root" status --porcelain >/dev/null
git -C "$feature_wt" status --porcelain >/dev/null

print "ok"
