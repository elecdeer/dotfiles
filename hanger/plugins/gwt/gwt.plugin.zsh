#!/usr/bin/env zsh

function gwt() {
  # 引数が渡された場合は直接git wtを実行
  if [[ $# -gt 0 ]]; then
    print -s "git wt \"$@\""
    git wt "$@"
    return
  fi

  local selected_worktree
  selected_worktree=$(git-wt | tail -n +2 | sed 's/^[ *]*//' | awk '{
    path = $1
    branch = $2
    hash = $3

    # bareリポジトリやBRANCHが空の行はスキップ
    if (branch == "" || branch == "(bare)") next

    # Get push/pull status
    cmd = "git -C " path " rev-list --left-right --count @{upstream}...HEAD 2>/dev/null"
    cmd | getline result
    close(cmd)
    
    arrows = ""
    if (result != "") {
      split(result, counts, " ")
      behind = counts[1]
      ahead = counts[2]
      if (ahead > 0) arrows = arrows "\033[33m⇡\033[0m"
      if (behind > 0) arrows = arrows "\033[31m⇣\033[0m"
    }
    
    # 色分け: path=緑, branch=青, hash=グレー
    printf "\033[32m%s\033[0m\t\033[34m%s\033[0m\t\033[90m%s\033[0m\t%s\n", path, branch, hash, arrows
  }' | column -t -s $'\t' | fzf --with-nth 2,3,4 --header "Select Worktree" | awk '{print $2}')

  if [[ -n "$selected_worktree" ]]; then
    print -s "git wt \"$selected_worktree\""
    git wt "$selected_worktree"
  fi
}
