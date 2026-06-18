#!/usr/bin/env zsh

# プラグインディレクトリのパスをsource時に記録する
# （関数内では$0がfunction名になるため、source時に取得する必要がある）
_gwt_plugin_dir="${0:A:h}"

function gwa() {
  "$_gwt_plugin_dir/executable_gwa" "$@"
}

_gwt_mise_config_paths="mise.toml .mise.toml .config/mise/config.toml mise.lock .config/mise/mise.lock"

function _gwt_mise_diff_command() {
  local root_branch="$1"
  if [[ -n "$root_branch" ]]; then
    print -r -- "git --no-pager diff ${(q)root_branch}...HEAD -- $_gwt_mise_config_paths"
  else
    print -r -- "git --no-pager diff -- $_gwt_mise_config_paths"
  fi
}

function _gwt_zellij_send_command() {
  local command="$1"
  [[ -z "$command" ]] && return
  zellij action write-chars "$command"
  zellij action write 13
}

function _gwt_enter_command() {
  local worktree_name="$1"
  local selected_path="$2"
  print -r -- "GWT_PLUGIN_DIR=${(q)_gwt_plugin_dir} source ${(q)_gwt_plugin_dir}/executable_gwt-enter ${(q)worktree_name} ${(q)selected_path}"
}

function gwt() {
  # 引数が渡された場合は直接gdn wt switchを実行
  if [[ $# -gt 0 ]]; then
    local _path
    if [[ $# -ge 2 ]]; then
      print -s "gdn wt switch ${(q)1} --base ${(q)2}"
      _path=$(gdn wt switch "$1" --base "$2") || return
    else
      print -s "gdn wt switch ${(q)1}"
      _path=$(gdn wt switch "$1") || return
    fi
    [[ -n "$_path" ]] && cd "$_path"
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
    local _result _wt_name _selected_path
    _result=$(cat "$_tmpfifo")
    rm -f "$_tmpfifo"
    [[ -z "$_result" ]] && return
    _wt_name=$(printf '%s' "$_result" | head -1 | cut -f1)
    _selected_path=$(printf '%s' "$_result" | head -1 | cut -f2)
    [[ -z "$_wt_name" ]] && return
    # 既に同名タブが開いていれば移動する（exit code は常に 0 なので切り替え後の tab 名で判定）
    zellij action go-to-tab-name "${_wt_name}" 2>/dev/null
    local _current_tab_name
    _current_tab_name=$(zellij action current-tab-info --json 2>/dev/null | jq -r '.name // empty' 2>/dev/null)
    if [[ "$_current_tab_name" != "${_wt_name}" ]]; then
      local _new_tab_cwd="$PWD"
      if [[ -n "$_selected_path" && "$_selected_path" != __BASE__:* ]]; then
        _new_tab_cwd="$_selected_path"
      fi
      zellij action new-tab --cwd "$_new_tab_cwd" --name "${_wt_name}"
      if [[ -z "$_selected_path" || "$_selected_path" == __BASE__:* ]]; then
        _gwt_zellij_send_command "$(_gwt_enter_command "$_wt_name" "$_selected_path")"
      fi
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
    if [[ -n "$_base" ]]; then
      print -s "gdn wt switch ${(q)selected_worktree} --base ${(q)_base}"
    else
      print -s "gdn wt switch ${(q)selected_worktree}"
    fi
  else
    print -s "gdn wt switch ${(q)selected_worktree}"
  fi

  local _resolved_details _resolved_path _status _root_branch
  _resolved_details=$("$_gwt_plugin_dir/executable_gwt-create" --details "$selected_worktree" "$selected_path") || return
  _resolved_path=$(printf '%s' "$_resolved_details" | cut -f1)
  _status=$(printf '%s' "$_resolved_details" | cut -f2)
  _root_branch=$(printf '%s' "$_resolved_details" | cut -f3)
  [[ -z "$_resolved_path" ]] && return

  # cmuxが使える場合、1ペインのときのみ左右に分割してcdする
  cmux-splits "$_resolved_path"
  cmux ping &>/dev/null && cmux rename-workspace "$selected_worktree" &>/dev/null

  local _has_lock=false _lf
  for _lf in pnpm-lock.yaml package-lock.json yarn.lock bun.lockb; do
    [[ -f "$_resolved_path/$_lf" ]] && _has_lock=true && break
  done

  if [[ "$_status" == "mise-diff-needed" ]]; then
    print "mise config differs from the root worktree. Review before running mise trust:"
    print "  cd ${(q)_resolved_path} && $(_gwt_mise_diff_command "$_root_branch")"
  elif [[ "$_status" == "mise-trust-failed" ]]; then
    print "mise trust failed. Review the mise config before continuing:"
    print "  cd ${(q)_resolved_path} && $(_gwt_mise_diff_command "$_root_branch")"
  elif [[ "$_has_lock" == "true" ]]; then
    print "Run in the new worktree:"
    print "  cd ${(q)_resolved_path} && ni"
  fi

}
