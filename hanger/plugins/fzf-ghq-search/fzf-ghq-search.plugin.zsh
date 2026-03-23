#!/usr/bin/env zsh

_fzf_ghq_search_plugin_dir="${0:A:h}"

function fzf-ghq-search() {
  setopt local_options
  unsetopt xtrace

  local ghq_root repo
  ghq_root=$(ghq root) || return 1

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