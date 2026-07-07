#!/usr/bin/env zsh

_fzf_ghq_search_plugin_dir="${0:A:h}"

function fzf-ghq-search() {
  setopt local_options
  unsetopt xtrace

  local ghq_root
  ghq_root=$(gdn repo root) || return 1

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

if [[ -z "$HERDR_ENV" ]]; then
  zle -N fzf-ghq-search
  bindkey $'\e[113;7u' fzf-ghq-search
fi
