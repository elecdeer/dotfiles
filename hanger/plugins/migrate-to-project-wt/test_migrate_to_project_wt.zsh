#!/usr/bin/env zsh
set -euo pipefail

plugin_dir="${0:A:h}"
source "${plugin_dir}/migrate-to-project-wt.plugin.zsh"

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

assert_branch_path() {
  local repo="$1"
  local branch="$2"
  local expected_path="$3"
  local actual_path
  actual_path="$(git -C "$repo" worktree list --porcelain | awk -v branch="$branch" '
    /^worktree / { path = substr($0, 10) }
    /^branch refs\/heads\// {
      current = substr($0, 19)
      if (current == branch) {
        print path
      }
    }
  ')"
  assert_equals "$(realpath "$expected_path")" "$(realpath "$actual_path")"
}

create_repo() {
  local repo="$1"
  git init --initial-branch=main "$repo" >/dev/null
  git -C "$repo" config user.name "Test User"
  git -C "$repo" config user.email "test@example.com"
  print "main" > "${repo}/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -m "Initial commit" >/dev/null
}

create_branch() {
  local repo="$1"
  local branch="$2"
  local file_path="$3"
  git -C "$repo" switch -c "$branch" >/dev/null 2>&1
  mkdir -p "$(dirname "${repo}/${file_path}")"
  print "$branch" > "${repo}/${file_path}"
  git -C "$repo" add "$file_path"
  git -C "$repo" commit -m "Add ${branch}" >/dev/null
  git -C "$repo" switch main >/dev/null 2>&1
}

assert_migrated_repo() {
  local repo="$1"
  local wt_dir="$2"
  assert_dir_exists "$repo"
  assert_dir_exists "${repo}/.git"
  assert_dir_exists "$wt_dir"
  assert_equals "../{gitroot}.wt" "$(git -C "$repo" config wt.basedir)"
  git -C "$repo" status --porcelain >/dev/null
}

test_normal_repo_with_nested_wt() {
  local root="${tmp_dir}/normal"
  local repo="${root}/project"
  create_repo "$repo"
  create_branch "$repo" "feat/nested" "feature.txt"
  git -C "$repo" worktree add "${repo}/.wt/feat/nested" "feat/nested" >/dev/null 2>&1

  migrate-to-project-wt --yes "$repo" >/dev/null

  assert_migrated_repo "$repo" "${root}/project.wt"
  assert_file_exists "${repo}/README.md"
  assert_file_exists "${root}/project.wt/feat/nested/feature.txt"
  assert_branch_path "$repo" "feat/nested" "${root}/project.wt/feat/nested"
  assert_dir_exists "${root}"/_project.project-wt-backup-*(N[1])
}

test_normal_repo_without_linked_wt() {
  local root="${tmp_dir}/normal-single"
  local repo="${root}/project"
  create_repo "$repo"

  migrate-to-project-wt --yes "$repo" >/dev/null

  assert_migrated_repo "$repo" "${root}/project.wt"
  assert_file_exists "${repo}/README.md"
  assert_dir_exists "${root}"/_project.project-wt-backup-*(N[1])
}

test_root_layout() {
  local root="${tmp_dir}/root-layout"
  local wrapper="${root}/project"
  local main_repo="${wrapper}/\$root"
  mkdir -p "$main_repo"
  create_repo "$main_repo"
  git -C "$main_repo" config wt.basedir ".."
  create_branch "$main_repo" "feature-a" "feature.txt"
  git -C "$main_repo" worktree add "${wrapper}/feature-a" "feature-a" >/dev/null 2>&1

  migrate-to-project-wt --yes "$wrapper" >/dev/null

  assert_migrated_repo "$wrapper" "${root}/project.wt"
  assert_file_exists "${wrapper}/README.md"
  assert_file_exists "${root}/project.wt/feature-a/feature.txt"
  assert_branch_path "$wrapper" "feature-a" "${root}/project.wt/feature-a"
  assert_dir_exists "${root}"/_project.project-wt-backup-*(N[1])
}

test_bare_layout() {
  local root="${tmp_dir}/bare-layout"
  local source_repo="${root}/source"
  local bare_repo="${root}/project.git"
  mkdir -p "$root"
  create_repo "$source_repo"
  create_branch "$source_repo" "feature-a" "feature.txt"
  git clone --bare "$source_repo" "$bare_repo" >/dev/null 2>&1
  git -C "$bare_repo" symbolic-ref HEAD refs/heads/main
  git -C "$bare_repo" worktree add "${bare_repo}/.wt/main" main >/dev/null 2>&1
  git -C "$bare_repo" worktree add "${bare_repo}/.wt/feature-a" feature-a >/dev/null 2>&1

  migrate-to-project-wt --yes "$bare_repo" >/dev/null

  assert_dir_exists "$bare_repo"
  assert_migrated_repo "${root}/project" "${root}/project.wt"
  assert_file_exists "${root}/project/README.md"
  assert_file_exists "${root}/project.wt/feature-a/feature.txt"
  assert_branch_path "${root}/project" "feature-a" "${root}/project.wt/feature-a"
  assert_dir_exists "${root}"/_project.git.project-wt-backup-*(N[1])
}

test_normal_repo_with_nested_wt
test_normal_repo_without_linked_wt
test_root_layout
test_bare_layout

print "test_migrate_to_project_wt: ok"
