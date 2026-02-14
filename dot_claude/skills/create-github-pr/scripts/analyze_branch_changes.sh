#!/usr/bin/env bash
# Analyze branch changes and output branch info, base branch, changed files, and commit log

set -euo pipefail

# Get current branch name
current_branch=$(git branch --show-current)

# Get default branch from remote
default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Determine base branch using decoration-based method
base_branch_line=$(git log HEAD --remotes --simplify-by-decoration --pretty=format:"%h %D" | grep "origin/" | grep -v "origin/$(git branch --show-current)" | head -n 1 || true)
if [[ -n "$base_branch_line" ]]; then
  # Extract branch name from decoration
  base_branch=$(echo "$base_branch_line" | grep -o "origin/[^,[:space:]]*" | head -n 1 | sed 's@origin/@@' || echo "")
fi

# If base_branch is still empty, fallback to default branch
if [[ -z "${base_branch:-}" ]]; then
  base_branch="$default_branch"
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
