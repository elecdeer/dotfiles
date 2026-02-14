#!/usr/bin/env bash
# Verify remote branch status and output readable text

set -euo pipefail

branch_name="${1:-$(git branch --show-current)}"

echo "=== Remote Branch Status for '$branch_name' ==="
echo ""

# Check if branch exists on remote
if git ls-remote --heads origin "$branch_name" | grep -q "$branch_name"; then
  echo "Remote Exists: Yes"
  
  # Compare local and remote commits
  local_commit=$(git rev-parse HEAD)
  remote_commit=$(git rev-parse "origin/$branch_name")
  
  if [[ "$local_commit" == "$remote_commit" ]]; then
    echo "Status: Up to date"
    echo ""
    echo "✓ Local and remote branches are synchronized."
  else
    # Count commits ahead and behind
    commits_ahead=$(git rev-list --count "origin/$branch_name"..HEAD 2>/dev/null || echo "0")
    commits_behind=$(git rev-list --count HEAD.."origin/$branch_name" 2>/dev/null || echo "0")
    
    echo "Commits Ahead: $commits_ahead"
    echo "Commits Behind: $commits_behind"
    echo ""
    
    if [[ "$commits_ahead" -gt 0 ]] && [[ "$commits_behind" -eq 0 ]]; then
      echo "Status: Ahead of remote"
      echo "⚠ Local branch has $commits_ahead commit(s) not pushed to remote."
      echo "  Action: Run 'git push origin $branch_name' to sync."
    elif [[ "$commits_ahead" -eq 0 ]] && [[ "$commits_behind" -gt 0 ]]; then
      echo "Status: Behind remote"
      echo "⚠ Remote branch has $commits_behind commit(s) not in local."
      echo "  Action: Run 'git pull origin $branch_name' to sync."
    else
      echo "Status: Diverged"
      echo "⚠ Local and remote branches have diverged."
      echo "  Action: Review changes and consider rebase or merge."
    fi
  fi
else
  echo "Remote Exists: No"
  echo "Status: Not pushed"
  echo ""
  echo "⚠ Branch '$branch_name' does not exist on remote."
  echo "  Action: Run 'git push -u origin $branch_name' to push."
fi
