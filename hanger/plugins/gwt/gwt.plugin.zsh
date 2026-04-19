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

  # zellijセッション内ではfloating paneでUIを表示する
  # named pipeで同期し、floatingが閉じてからnew-tabを開く
  if [[ -n "$ZELLIJ" ]]; then
    local _tmpfifo
    _tmpfifo=$(mktemp -u /tmp/gwt-XXXXXX)
    mkfifo "$_tmpfifo"
    # zellij run --floating は non-blocking なので、cat "$_tmpfifo" でブロックして結果を待つ
    zellij run --floating --close-on-exit --name "gwt" --width 80% --height 50% --x 10% --y 25% \
      -- "$_gwt_plugin_dir/executable_gwt-floating" "$PWD" "$_tmpfifo"
    local _result _wt_name _wt_path
    _result=$(cat "$_tmpfifo")
    rm -f "$_tmpfifo"
    [[ -z "$_result" ]] && return
    _wt_name=$(printf '%s' "$_result" | head -1 | cut -f1)
    _wt_path=$(printf '%s' "$_result" | head -1 | cut -f2)
    [[ -z "$_wt_path" ]] && return
    # 既に同名タブが開いていれば移動する（exit code は常に 0 なので切り替え後の tab 名で判定）
    zellij action go-to-tab-name "${_wt_name}" 2>/dev/null
    local _current_tab_name
    _current_tab_name=$(zellij action current-tab-info --json 2>/dev/null | jq -r '.name // empty' 2>/dev/null)
    if [[ "$_current_tab_name" != "${_wt_name}" ]]; then
      zellij action new-tab --cwd "$_wt_path" --name "${_wt_name}"
    fi
    return
  fi

  # 非zellij: インラインでworktreeを選択
  local selected_worktree selected_path selected_line
  selected_line=$("$_gwt_plugin_dir/executable_gwt-select" "$PWD") || return
  selected_worktree=$(echo "$selected_line" | cut -f1)
  selected_path=$(echo "$selected_line" | cut -f2)

  # historyに記録してからworktree作成/解決
  if [[ "$selected_path" == __BASE__:* ]]; then
    local _base="${selected_path#__BASE__:}"
    if [[ "$_base" == origin/* ]]; then
      print -s "(cd <${_base#origin/} worktree> && git pull) && git wt \"$selected_worktree\""
    elif [[ -n "$_base" ]]; then
      print -s "git wt \"$_base\" && git wt \"$selected_worktree\""
    else
      print -s "git wt \"$selected_worktree\""
    fi
  else
    print -s "git wt \"$selected_worktree\""
  fi

  local _resolved_path
  _resolved_path=$("$_gwt_plugin_dir/executable_gwt-create" "$selected_worktree" "$selected_path") || return

  # cmuxが使える場合、1ペインのときのみ左右に分割してcdする
  cmux-splits "$_resolved_path"
  cmux ping &>/dev/null && cmux rename-workspace "$selected_worktree" &>/dev/null

}
