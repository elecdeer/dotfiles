### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk


# ================================
# plugins
# ================================

# テーマ https://github.com/sindresorhus/pure#zinit
zinit ice compile'(pure|async).zsh' pick'async.zsh' src'pure.zsh'
zinit light sindresorhus/pure

# 構文ハイライト https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md#zplugin
zinit light zsh-users/zsh-syntax-highlighting

# history
zinit load zsh-users/zsh-history-substring-search

# 補完
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions
zinit light chrissicool/zsh-256color

# color
DIRCOLORS_SOLARIZED_ZSH_THEME="ansi-dark"
zinit load pinelibg/dircolors-solarized-zsh

zinit light asdf-vm/asdf



# ================================
# alias
# ================================

alias ls="gls -N --color"
alias ll="gls -Nl --color"
alias la="gls -Nla --color"

# ================================
# config
# ================================
#補完にも色付

setopt auto_list
setopt auto_menu
zstyle ':completion:*:default' menu select=1
# if [ -n "$LS_COLORS" ]; then
#     zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# fi
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# 大文字小文字を区別しない
zstyle ":completion:*" matcher-list "m:{a-z}={A-Z}"


test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"



# ================================
# Completion
# ================================

COMPLETIONS_DIR=~/.zsh/completions

if [ ! -d $COMPLETIONS_DIR ]; then
  mkdir -p $COMPLETIONS_DIR
fi

# docker-compose
if [ ! -e $COMPLETIONS_DIR/_docker-compose ]; then
  ln -s /Applications/Docker.app/Contents/Resources/etc/docker-compose.zsh-completion $COMPLETIONS_DIR/_docker-compose
fi

# deno
if [ ! -e $COMPLETIONS_DIR/_deno ]; then
  deno completions zsh > $COMPLETIONS_DIR/_deno
fi

fpath=($(brew --prefix)/share/zsh-completions $fpath)
fpath=(~/.zsh/completions $fpath)


autoload -Uz compinit && compinit
autoload -U bashcompinit && bashcompinit

