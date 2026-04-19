#!/usr/bin/env zsh

_fzf_ghq_search_plugin_dir="${0:A:h}"

function fzf-ghq-search() {
  setopt local_options
  unsetopt xtrace

  local ghq_root
  ghq_root=$(ghq root) || return 1

  # zellijセッション内ではfloating paneでUIを表示する
  # named pipeで同期し、floatingが閉じてからcdする
  if [[ -n "$ZELLIJ" ]]; then
    local _tmpfifo
    _tmpfifo=$(mktemp -u /tmp/fzf-ghq-XXXXXX)
    mkfifo "$_tmpfifo"
    # zellij run --floating は non-blocking なので、cat "$_tmpfifo" でブロックして結果を待つ
    zellij run --floating --close-on-exit --name "ghq" --width 80% --height 50% --x 10% --y 25% \
      -- "$_fzf_ghq_search_plugin_dir/executable_fzf-ghq-floating" "$ghq_root" "$_tmpfifo"
    local repo
    repo=$(cat "$_tmpfifo")
    rm -f "$_tmpfifo"
    if [[ -z "$repo" ]]; then
      zle redisplay
      return 1
    fi
    local tab_name="${repo:t}"
    # $root ディレクトリはbare構造のメインリポジトリなので、親ディレクトリ名（リポジトリ名）を使う
    [[ "$tab_name" == '$root' ]] && tab_name="${${repo:h}:t}"
    zellij action new-tab --cwd "$ghq_root/$repo" --name "$tab_name"
    return
  fi

  # 非zellij: インラインでリポジトリを選択
  local repo
  repo=$(
    export GHQ_ROOT="$ghq_root"
    "$_fzf_ghq_search_plugin_dir/executable_fzf-ghq-list" "$ghq_root" \
      | fzf --prompt="repository > " --ansi \
          --delimiter $'\t' \
          --with-nth 3,4 \
          --nth 1 \
          --preview 'if [[ -f "$GHQ_ROOT"/{2}/README.md ]]; then bat --color=always --style=numbers "$GHQ_ROOT"/{2}/README.md; else lsd -1 --icon=always --color=always "$GHQ_ROOT"/{2}; fi' \
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