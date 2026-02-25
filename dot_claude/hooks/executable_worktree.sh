#!/bin/bash
# WorktreeCreate / WorktreeRemove フック
# git-wt (k1LoW/git-wt) に委譲する
# from: https://sushichan044.hateblo.jp/entry/2026/02/21/174922

set -euo pipefail

INPUT=$(cat)
HOOK_EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name')

case "$HOOK_EVENT" in
WorktreeCreate)
  WT_NAME=$(printf '%s' "$INPUT" | jq -r '.name')

  # git-wt の出力例:
  #   Preparing worktree (new branch 'branch-name')
  #   HEAD is now at abc1234 commit message
  #   /path/to/worktree
  # 最終行が作成されたworktreeの絶対パス
  WT_ABS_PATH=$(git-wt "$WT_NAME" --nocd | tail -n 1 | xargs)

  if [ -z "$WT_ABS_PATH" ]; then
    echo "Failed to create worktree: git-wt returned no path" >&2
    exit 1
  fi

  echo "$WT_ABS_PATH"
  ;;
WorktreeRemove)
  WT_PATH=$(printf '%s' "$INPUT" | jq -r '.worktree_path')
  git-wt -d "$WT_PATH" || true
  ;;
esac
