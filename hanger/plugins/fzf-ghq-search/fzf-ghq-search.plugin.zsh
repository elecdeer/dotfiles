#!/usr/bin/env zsh

_fzf_ghq_search_plugin_dir="${0:A:h}"

function _fzf_ghq_herdr_root_pane_id() {
  local workspace_id="$1"
  [[ -z "$workspace_id" ]] && return
  herdr pane list --workspace "$workspace_id" 2>/dev/null | jq -r '.result.panes[0].pane_id // empty' 2>/dev/null
}

function _fzf_ghq_herdr_split_workspace() {
  local workspace_id="$1"
  local cwd="$2"
  local pane_id
  pane_id=$(_fzf_ghq_herdr_root_pane_id "$workspace_id")
  [[ -z "$pane_id" ]] && return
  herdr pane split "$pane_id" --direction right --ratio 0.5 --cwd "$cwd" --no-focus >/dev/null 2>&1
}

function fzf-ghq-search() {
  setopt local_options
  unsetopt xtrace

  local ghq_root
  ghq_root=$(gdn repo root) || return 1

  # herdrセッション内ではインライン選択 + herdrのworkspace管理を使用
  # （herdrはfloating paneを持たないためインライン選択にフォールバック）
  if [[ -n "$HERDR_ENV" ]]; then
    local repo
    repo=$(
      export GDN_ROOT="$ghq_root"
      "$_fzf_ghq_search_plugin_dir/executable_fzf-ghq-list" \
        | fzf --prompt="repository > " --ansi \
            --height 50% \
            --reverse \
            --border \
            --delimiter $'\t' \
            --with-nth 3,4 \
            --nth 1 \
            --preview 'if [[ -f "$GDN_ROOT"/{2}/README.md ]]; then bat --color=always --style=numbers "$GDN_ROOT"/{2}/README.md; else lsd -1 --icon=always --color=always "$GDN_ROOT"/{2}; fi' \
            --preview-window=right:50% \
            | cut -f2
    )

    if [[ -z "$repo" ]]; then
      zle redisplay
      return 1
    fi
    local workspace_name="${repo:t}"
    # $root ディレクトリはbare構造のメインリポジトリなので、親ディレクトリ名（リポジトリ名）を使う
    [[ "$workspace_name" == '$root' ]] && workspace_name="${${repo:h}:t}"
    local existing_workspace_id
    existing_workspace_id=$(herdr workspace list 2>/dev/null | jq -r --arg label "$workspace_name" '.result.workspaces[] | select(.label == $label) | .workspace_id' 2>/dev/null | head -1)
    if [[ -n "$existing_workspace_id" ]]; then
      herdr workspace focus "$existing_workspace_id"
    else
      local new_workspace_id workspace_cwd
      workspace_cwd="$ghq_root/$repo"
      new_workspace_id=$(herdr workspace create --cwd "$workspace_cwd" --label "$workspace_name" --focus 2>/dev/null | jq -r '(.result.workspace.workspace_id // .result.workspace_id // .result.created_workspace.workspace_id // .workspace_id // .id // empty)' 2>/dev/null)
      _fzf_ghq_herdr_split_workspace "$new_workspace_id" "$workspace_cwd"
    fi
    return
  fi

  # 非herdr: インラインでリポジトリを選択
  local repo
  repo=$(
    export GDN_ROOT="$ghq_root"
    "$_fzf_ghq_search_plugin_dir/executable_fzf-ghq-list" \
      | fzf --prompt="repository > " --ansi \
          --height 50% \
          --reverse \
          --border \
          --delimiter $'\t' \
          --with-nth 3,4 \
          --nth 1 \
          --preview 'if [[ -f "$GDN_ROOT"/{2}/README.md ]]; then bat --color=always --style=numbers "$GDN_ROOT"/{2}/README.md; else lsd -1 --icon=always --color=always "$GDN_ROOT"/{2}; fi' \
          --preview-window=right:50% \
          | cut -f2
  )

  if [[ -n "$repo" ]]; then
    BUFFER+="cd $ghq_root/$repo"
    zle accept-line
  else
    zle redisplay
    return 1
  fi
}

zle -N fzf-ghq-search

if [[ -z "$HERDR_ENV" ]]; then
  bindkey $'\e[113;6u' fzf-ghq-search
  bindkey $'\C-x\C-q' fzf-ghq-search
fi
