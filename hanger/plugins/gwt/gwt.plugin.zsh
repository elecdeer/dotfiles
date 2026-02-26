#!/usr/bin/env zsh

function gwt() {
  # 引数が渡された場合は直接git wtを実行
  if [[ $# -gt 0 ]]; then
    print -s "git wt \"$@\""
    git wt "$@"
    return
  fi

  local selected_worktree
  selected_worktree=$(git-wt | tail -n +2 | sed 's/^[ *]*//' | awk -v now="$(date +%s)" '
    {
      path = $1
      branch = $2
      hash = $3

      if (branch == "" || branch == "(bare)") next

      mtime = 0
      cmd = "stat -f \"%m\" \"" path "\" 2>/dev/null"
      if ((cmd | getline result) > 0) mtime = result + 0
      close(cmd)

      diff = now - mtime
      if (diff < 60) {
        relative_time = diff "s"
      } else if (diff < 3600) {
        relative_time = int(diff / 60) "m"
      } else if (diff < 86400) {
        relative_time = int(diff / 3600) "h"
      } else if (diff < 2592000) {
        relative_time = int(diff / 86400) "d"
      } else {
        relative_time = int(diff / 2592000) "mo"
      }

      arrows = ""
      cmd = "git -C \"" path "\" rev-list --left-right --count @{upstream}...HEAD 2>/dev/null"
      if ((cmd | getline result) > 0) {
        split(result, counts, " ")
        behind = counts[1] + 0
        ahead = counts[2] + 0
        if (ahead > 0) arrows = arrows "\033[33m⇡\033[0m"
        if (behind > 0) arrows = arrows "\033[31m⇣\033[0m"
      }
      close(cmd)

      printf "%s\t%s\t\033[34m%-45s\033[0m\t\033[90m%-8s\033[0m\t\033[2m%6s ago\033[0m\t%s\n",
        mtime, branch, branch, hash, relative_time, arrows
    }
  ' | sort -t $'\t' -k1 -rn | cut -f2- \
    | fzf --ansi \
        --delimiter $'\t' \
        --with-nth 2,3,4,5 \
        --nth 1,2 \
        --header "Select Worktree" \
    | cut -f1)

  if [[ -n "$selected_worktree" ]]; then
    print -s "git wt \"$selected_worktree\""
    git wt "$selected_worktree"
  fi
}
