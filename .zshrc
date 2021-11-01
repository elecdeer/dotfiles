export ZPLUG_HOME=$(brew --prefix)/opt/zplug
source $ZPLUG_HOME/init.zsh

# ================================
# plugins
# ================================

# zplug from: https://qiita.com/Jung0/items/300f8b83520e56766f22
zplug 'zplug/zplug', hook-build:'zplug --self-manage'
# theme
zplug "mafredri/zsh-async"
zplug "sindresorhus/pure"
# 構文のハイライト(https://github.com/zsh-users/zsh-syntax-highlighting)
zplug "zsh-users/zsh-syntax-highlighting"
# history関係
zplug "zsh-users/zsh-history-substring-search"
# タイプ補完
zplug "zsh-users/zsh-autosuggestions"
zplug "zsh-users/zsh-completions"
zplug "chrissicool/zsh-256color"

DIRCOLORS_SOLARIZED_ZSH_THEME="ansi-dark"
zplug "pinelibg/dircolors-solarized-zsh"
zplug "felixr/docker-zsh-completion"

zplug "asdf-vm/asdf"

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



# Install plugins if there are plugins that have not been installed
if ! zplug check --verbose; then
  printf "Install? [y/N]: "
  if read -q; then
    echo; zplug install
  fi
fi
# Then, source plugins and add commands to $PATH
zplug load

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"


#asdf
fpath=($HOME/.asdf/completions $fpath)
autoload -Uz compinit && compinit
autoload -U bashcompinit && bashcompinit
                                                         
source $HOME/.asdf/asdf.sh                                                                                                                                     
source $HOME/.asdf/completions/asdf.bash 


#dockerCompletion
if [ -e ~/.zsh/completions ]; then
  fpath=(~/.zsh/completions $fpath)
fi

