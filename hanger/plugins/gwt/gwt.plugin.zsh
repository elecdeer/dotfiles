#!/usr/bin/env zsh

# プラグインディレクトリのパスをsource時に記録する
# （関数内では$0がfunction名になるため、source時に取得する必要がある）
_gwt_plugin_dir="${0:A:h}"

function gwa() {
  "$_gwt_plugin_dir/gwa" "$@"
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

function _gwt_herdr_send_command_to_workspace() {
  local command="$1"
  local workspace_id="$2"
  [[ -z "$command" ]] && return
  [[ -z "$workspace_id" ]] && return
  local pane_id
  pane_id=$(herdr pane list --workspace "$workspace_id" 2>/dev/null | jq -r '.result.panes[0].pane_id // empty' 2>/dev/null)
  [[ -z "$pane_id" ]] && return
  herdr pane run "$pane_id" "$command"
}

function _gwt_herdr_split_workspace() {
  local workspace_id="$1"
  local cwd="$2"
  [[ -z "$workspace_id" ]] && return
  local pane_id
  pane_id=$(herdr pane list --workspace "$workspace_id" 2>/dev/null | jq -r '.result.panes[0].pane_id // empty' 2>/dev/null)
  [[ -z "$pane_id" ]] && return
  herdr pane split "$pane_id" --direction right --ratio 0.5 --cwd "$cwd" --no-focus >/dev/null 2>&1
}

function _gwt_enter_command() {
  local worktree_name="$1"
  local selected_path="$2"
  print -r -- "GWT_PLUGIN_DIR=${(q)_gwt_plugin_dir} source ${(q)_gwt_plugin_dir}/gwt-enter ${(q)worktree_name} ${(q)selected_path}"
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

  # herdrセッション内ではインライン選択 + herdrのworkspace管理を使用
  # （herdrはfloating paneを持たないためインライン選択にフォールバック）
  if [[ -n "$HERDR_ENV" ]]; then
    local _selected_line _wt_name _selected_path
    _selected_line=$("$_gwt_plugin_dir/gwt-select" "$PWD") || return
    [[ -z "$_selected_line" ]] && return
    _wt_name=$(printf '%s' "$_selected_line" | head -1 | cut -f1)
    _selected_path=$(printf '%s' "$_selected_line" | head -1 | cut -f2)
    [[ -z "$_wt_name" ]] && return

    # 既に同名workspaceが開いていれば移動する
    local _existing_workspace_id
    _existing_workspace_id=$(herdr workspace list 2>/dev/null | jq -r --arg label "$_wt_name" '.result.workspaces[] | select(.label == $label) | .workspace_id' 2>/dev/null | head -1)
    if [[ -n "$_existing_workspace_id" ]]; then
      herdr workspace focus "$_existing_workspace_id"
    else
      local _new_workspace_cwd="$PWD"
      if [[ -n "$_selected_path" && "$_selected_path" != __BASE__:* ]]; then
        _new_workspace_cwd="$_selected_path"
      fi
      local _new_workspace_id
      _new_workspace_id=$(herdr workspace create --cwd "$_new_workspace_cwd" --label "${_wt_name}" --focus 2>/dev/null | jq -r '(.result.workspace.workspace_id // .result.workspace_id // .result.created_workspace.workspace_id // .workspace_id // .id // empty)' 2>/dev/null)
      if [[ -z "$_selected_path" || "$_selected_path" == __BASE__:* ]]; then
        _gwt_herdr_send_command_to_workspace "$(_gwt_enter_command "$_wt_name" "$_selected_path")" "$_new_workspace_id"
      else
        _gwt_herdr_split_workspace "$_new_workspace_id" "$_new_workspace_cwd"
      fi
    fi
    return
  fi

  # 非herdr: インラインでworktreeを選択
  local selected_worktree selected_path selected_line
  selected_line=$("$_gwt_plugin_dir/gwt-select" "$PWD") || return
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
  _resolved_details=$("$_gwt_plugin_dir/gwt-create" --details "$selected_worktree" "$selected_path") || return
  _resolved_path=$(printf '%s' "$_resolved_details" | cut -f1)
  _status=$(printf '%s' "$_resolved_details" | cut -f2)
  _root_branch=$(printf '%s' "$_resolved_details" | cut -f3)
  [[ -z "$_resolved_path" ]] && return

  if [[ "$_status" == "mise-diff-needed" ]]; then
    print "mise config differs from the root worktree. Review before running mise trust:"
    print "  cd ${(q)_resolved_path} && $(_gwt_mise_diff_command "$_root_branch")"
  elif [[ "$_status" == "mise-trust-failed" ]]; then
    print "mise trust failed. Review the mise config before continuing:"
    print "  cd ${(q)_resolved_path} && $(_gwt_mise_diff_command "$_root_branch")"
  fi

}
