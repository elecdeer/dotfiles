#!/usr/bin/env bash
# Analyze branch changes and output branch info, base branch, changed files, and commit log
#
# Usage: analyze_branch_changes.sh [--base <base-branch>]
#   --base, -b <base-branch>  Explicitly specify the base branch (skips auto-detection)

set -euo pipefail

# Parse arguments
explicit_base_branch=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base | -b)
      explicit_base_branch="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--base <base-branch>]" >&2
      exit 1
      ;;
  esac
done

# Get current branch name
current_branch=$(git branch --show-current)

# Get default branch from remote
default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Try to update the default branch before determining base branch
echo "=== Updating Default Branch ($default_branch) ===" >&2
# Find the worktree that has the default branch checked out
default_branch_worktree=$(git worktree list --porcelain | awk '
  /^worktree / { wt = substr($0, 10) }
  $0 == "branch refs/heads/'"$default_branch"'" { print wt }
' | head -n 1)

if [[ -n "$default_branch_worktree" ]]; then
  echo "Pulling $default_branch in worktree: $default_branch_worktree" >&2
  if git -C "$default_branch_worktree" pull --ff-only 2>&1 >&2; then
    echo "Successfully updated $default_branch." >&2
  else
    echo "" >&2
    echo "⚠ WARNING: Failed to update $default_branch." >&2
    echo "  Worktree: $default_branch_worktree" >&2
    echo "  The base branch may be outdated. Please take one of the following actions:" >&2
    echo "    1. Run: git -C \"$default_branch_worktree\" pull" >&2
    echo "    2. Verify there are no local changes or merge conflicts on $default_branch." >&2
    echo "  Then re-run this script to ensure the PR is created against the correct base." >&2
    echo "" >&2
    echo "  ‼ Action required: Manually confirm $default_branch is up to date before proceeding." >&2
  fi
else
  # No worktree has the default branch checked out; update via fetch
  echo "No worktree found with $default_branch checked out. Fetching via git fetch..." >&2
  if git fetch origin "$default_branch:$default_branch" 2>&1 >&2; then
    echo "Successfully updated $default_branch." >&2
  else
    echo "" >&2
    echo "⚠ WARNING: Failed to fetch $default_branch from origin." >&2
    echo "  The base branch may be outdated. Please take one of the following actions:" >&2
    echo "    1. Run: git fetch origin $default_branch:$default_branch" >&2
    echo "    2. Verify network connectivity and remote access." >&2
    echo "  Then re-run this script to ensure the PR is created against the correct base." >&2
    echo "" >&2
    echo "  ‼ Action required: Manually confirm $default_branch is up to date before proceeding." >&2
  fi
fi
echo "" >&2

# Determine base branch
if [[ -n "$explicit_base_branch" ]]; then
  # Use explicitly specified base branch (skip auto-detection)
  base_branch="$explicit_base_branch"
  echo "Using explicitly specified base branch: $base_branch" >&2
else
  # Auto-detect base branch using decoration-based method
  base_branch_line=$(git log HEAD --remotes --simplify-by-decoration --pretty=format:"%h %D" | grep "origin/" | grep -v "origin/$(git branch --show-current)" | head -n 1 || true)
  if [[ -n "$base_branch_line" ]]; then
    # Extract branch name from decoration
    base_branch=$(echo "$base_branch_line" | grep -o "origin/[^,[:space:]]*" | head -n 1 | sed 's@origin/@@' || echo "")
  fi

  # If base_branch is still empty, fallback to default branch
  if [[ -z "${base_branch:-}" ]]; then
    base_branch="$default_branch"
  fi
fi

# Check if branch exists on remote
if git ls-remote --heads origin "$current_branch" | grep -q "$current_branch"; then
  remote_exists="true"
  # Count commits ahead of remote
  commits_ahead=$(git rev-list --count "origin/$current_branch"..HEAD 2>/dev/null || echo "0")
else
  remote_exists="false"
  commits_ahead="0"
fi

# Output results
echo "=== Branch Information ==="
echo "Current Branch: $current_branch"
echo "Base Branch: $base_branch"
echo "Default Branch: $default_branch"
echo "Remote Exists: $remote_exists"
echo "Commits Ahead of Remote: $commits_ahead"
echo ""

# Check for stacked PRs (if base branch is not default branch)
if [[ "$base_branch" != "$default_branch" ]]; then
  echo "=== Stacked PR Check ==="
  
  # Search for PRs with the base branch as head
  pr_list=$(gh pr list --head "$base_branch" --state open --json number,title 2>/dev/null || echo "[]")
  
  if [[ "$pr_list" != "[]" ]]; then
    echo "Found PR(s) for base branch ($base_branch):"
    echo "$pr_list" | jq -r '.[] | "  #\(.number): \(.title)\n"'
    echo ""
    echo "⚠ This PR will be stacked on top of the above PR(s)."
    echo "  Consider including 'Built on top of #<number>' in the PR description."
  else
    echo "No open PR found for base branch ($base_branch)."
    echo "This will be a regular PR targeting $base_branch."
  fi
  echo ""
fi

echo "=== Changed Files (vs origin/$base_branch) ==="
git diff --stat "origin/$base_branch"...HEAD
echo ""

echo "=== Commit Log ==="
# Try full commit messages first (without Author/Date, only description)
full_log=$(git log "origin/$base_branch"..HEAD --graph --pretty=format:"%h%d%n%B" 2>/dev/null || echo "")
log_length=${#full_log}

# If log is too long (>5000 chars), fallback to oneline summary
if [[ $log_length -gt 5000 ]]; then
  echo "(Commit log is too long, showing summary only)"
  echo ""
  git log "origin/$base_branch"..HEAD --graph --oneline --decorate
else
  echo "$full_log"
fi
