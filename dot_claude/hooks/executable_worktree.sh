#!/bin/bash
# WorktreeCreate / WorktreeRemove フック
# git-gardener (gdn) に委譲する

set -euo pipefail

INPUT=$(cat)
HOOK_EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name')

case "$HOOK_EVENT" in
WorktreeCreate)
  WT_NAME=$(printf '%s' "$INPUT" | jq -r '.name')

  # gdn wt switch はworktreeの絶対パスのみをstdoutに出力する
  WT_ABS_PATH=$(gdn wt switch "$WT_NAME")

  if [ -z "$WT_ABS_PATH" ]; then
    echo "Failed to create worktree: gdn returned no path" >&2
    exit 1
  fi

  echo "$WT_ABS_PATH"
  ;;
WorktreeRemove)
  WT_PATH=$(printf '%s' "$INPUT" | jq -r '.worktree_path')
  # gdn wt delete はブランチ名を受け取るため、パスからブランチ名を逆引きする
  WT_BRANCH=$(git -C "$WT_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null) || true
  if [ -n "$WT_BRANCH" ] && [ "$WT_BRANCH" != "HEAD" ]; then
    gdn wt delete "$WT_BRANCH" || true
  else
    # detached HEAD の場合は git worktree remove で直接削除
    git -C "$(dirname "$WT_PATH")" worktree remove --force "$WT_PATH" || true
  fi
  ;;
esac
