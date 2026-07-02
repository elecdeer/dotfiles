#!/usr/bin/env zsh

_fzf_ghq_search_plugin_dir="${0:A:h}"

function fzf-ghq-search() {
  setopt local_options
  unsetopt xtrace

  local ghq_root
  ghq_root=$(gdn repo root) || return 1

  # herdrセッション内ではインライン選択 + herdrのタブ管理を使用
  # （herdrはfloating paneを持たないためインライン選択にフォールバック）
  if [[ -n "$HERDR_ENV" ]]; then
    local repo
    repo=$(
      export GDN_ROOT="$ghq_root"
      "$_fzf_ghq_search_plugin_dir/executable_fzf-ghq-list" \
        | fzf --prompt="repository > " --ansi \
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
    local tab_name="${repo:t}"
    # $root ディレクトリはbare構造のメインリポジトリなので、親ディレクトリ名（リポジトリ名）を使う
    [[ "$tab_name" == '$root' ]] && tab_name="${${repo:h}:t}"
    herdr tab create --cwd "$ghq_root/$repo" --label "$tab_name" --focus
    return
  fi

  # 非herdr: インラインでリポジトリを選択
  local repo
  repo=$(
    export GDN_ROOT="$ghq_root"
    "$_fzf_ghq_search_plugin_dir/executable_fzf-ghq-list" \
      | fzf --prompt="repository > " --ansi \
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
bindkey $'\e[113;6u' fzf-ghq-search
bindkey $'\C-x\C-q' fzf-ghq-search
