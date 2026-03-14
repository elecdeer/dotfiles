#!/usr/bin/env zsh

# プラグインディレクトリのパスをsource時に記録する
# （関数内では$0がfunction名になるため、source時に取得する必要がある）
_gwt_plugin_dir="${0:A:h}"

function gwt() {
  # 引数が渡された場合は直接git wtを実行
  if [[ $# -gt 0 ]]; then
    print -s "git wt \"$@\""
    git wt "$@"
    return
  fi

  local _gwt_list_script="$_gwt_plugin_dir/executable_gwt-list"

  local fzf_output
  # GWT_LIST_SCRIPTをexportしてchange:reloadのsh環境に渡す
  fzf_output=$(
    export GWT_LIST_SCRIPT="$_gwt_list_script"
    "$_gwt_list_script" \
    | fzf --ansi \
        --delimiter $'\t' \
        --with-nth 3,4,5,6 \
        --nth 1,2 \
        --print-query \
        --bind 'change:reload("$GWT_LIST_SCRIPT" {q})' \
        --header "Select Worktree"
  )

  # --print-queryにより1行目がクエリ、2行目以降が選択項目
  local query selected_line
  query=$(echo "$fzf_output" | head -1)
  selected_line=$(echo "$fzf_output" | sed -n '2p')

  if [[ -z "$query" && -z "$selected_line" ]]; then
    return
  fi

  local selected_worktree selected_path
  if [[ -n "$selected_line" ]]; then
    # リストから選択した場合（"⊕ create" エントリもこちら）
    selected_worktree=$(echo "$selected_line" | cut -f1)
    selected_path=$(echo "$selected_line" | cut -f2)
  else
    # クエリのみで確定した場合
    selected_worktree="$query"
    selected_path=""
  fi

  # selected_pathが "__BASE__:{base_branch}" 形式の場合は新規作成
  if [[ "$selected_path" == __BASE__:* ]]; then
    local base_branch="${selected_path#__BASE__:}"
    selected_path=""

    if [[ -n "$base_branch" ]]; then
      print -s "git wt \"$base_branch\" && git wt \"$selected_worktree\""
      git wt "$base_branch" && git wt "$selected_worktree"
    else
      print -s "git wt \"$selected_worktree\""
      git wt "$selected_worktree"
    fi
  else
    print -s "git wt \"$selected_worktree\""
    git wt "$selected_worktree"
  fi

  # pathが不明の場合はworktreeリストから取得する
  if [[ -z "$selected_path" ]]; then
    selected_path=$(git worktree list --porcelain | awk -v branch="$selected_worktree" '
      /^worktree / { path = substr($0, 10) }
      /^branch / { if ($0 ~ "refs/heads/" branch "$") print path }
    ')
  fi

  # cmuxが使える場合、1ペインのときのみ左右に分割してcdする
  cmux-splits "$selected_path"
  cmux ping &>/dev/null && cmux rename-workspace "$selected_worktree" &>/dev/null

}
