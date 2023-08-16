source <(curl -sL init.zshell.dev); zzinit

DOTFILES_DIR="${HOME}/dotfiles"

# ================================
# theme
# ================================
zi ice compile'(pure|async).zsh' pick'async.zsh' src'pure.zsh'
zi light sindresorhus/pure

DIRCOLORS_SOLARIZED_ZSH_THEME="ansi-dark"
zi light pinelibg/dircolors-solarized-zsh

# ================================
# config
# ================================

setopt auto_list # 補完候補を一覧で表示
setopt auto_menu # 補完キー連打で補完候補を順に表示する
setopt complete_in_word # 単語の途中でも補完を行う
setopt hist_ignore_dups # 直前と同じコマンドラインはヒストリに追加しない

zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS} # 補完候補に色を付ける
zstyle ':completion:*' matcher-list "m:{a-z}={A-Z}" # 補完時に大文字小文字を区別しない
zstyle ':completion:*:default' menu select=1 # 補完候補をカーソル的にハイライト
zstyle ':completion::complete:*' use-cache true # 補完候補をキャッシュする

# ================================
# highlight
# ================================

# 構文ハイライト https://github.com/zdharma-continuum/fast-syntax-highlighting


zi wait lucid atinit"ZI[COMPINIT_OPTS]=-C;" for \
    zdharma-continuum/fast-syntax-highlighting


# ================================
# tools
# ================================

zi wait lucid light-mode for \
    asdf-vm/asdf \
    azu/ni.zsh

# exaがインストールされている場合にlsを置き換え
zi wait lucid \
  has'exa' \
  atinit'AUTOCD=1' \
  atload='exa_params=('--git' '--classify' '--group' '--group-directories-first' '--time-style=long-iso' '--color-scale')' \
  for zplugin/zsh-exa

zi pick'init.zsh' compile'*.zsh' for \
    laggardkernel/zsh-iterm2

export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# zinit wait lucid depth"1" blockf for \
#     yuki-yano/zeno.zsh


# ================================
# completions
# ================================

zi wait lucid light-mode \
    for \
    atload'_zsh_autosuggest_start' zsh-users/zsh-autosuggestions \
    blockf zsh-users/zsh-completions \
    zsh-users/zsh-history-substring-search \

# deno
zi wait lucid id-as"deno-completion" \
    has'deno' as'command' \
    atclone'echo "\$deno completions zsh > _deno"; deno completions zsh > _deno' \
    atpull'%atclone' run-atpull'%atclone' \
    for z-shell/null

# docker
zi wait lucid as"completion" \
    for OMZP::docker/completions/_docker

# arduino-cli
zi wait lucid id-as"arduino-cli-completion" for \
    has'arduino-cli' as'command' \
    atclone'echo "\$arduino-cli completion zsh > _arduino-cli"; arduino-cli completion zsh > _arduino-cli' \
    atpull'%atclone' run-atpull'%atclone'\
    z-shell/null

# ================================

# .zshrc.localがあれば読み込み
zi light-mode as'null' \
    atinit'if [ -f ${DOTFILES_DIR}/.zshrc.local ]; then source ${DOTFILES_DIR}/.zshrc.local; fi' \
    for z-shell/null


# ================================
# 最後に遅延ロード
zi id-as"load-completion" wait lucid light-mode as'null' \
    atload"zicompinit; zicdreplay" \
    for z-shell/null

#
# if type zprof > /dev/null 2>&1; then
#    zprof | cat
# fi
