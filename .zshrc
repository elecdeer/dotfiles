source <(curl -sL init.zshell.dev); zzinit

# ================================
# env
# ================================

get_os() {
	os="$(uname -s)"
	if [ "$os" = Darwin ]; then
		echo "macos"
	elif [ "$os" = Linux ]; then
		echo "linux"
	else
		error "unsupported OS: $os"
	fi
}

get_arch() {
	arch="$(uname -m)"
	if [ "$arch" = x86_64 ]; then
		echo "x64"
	elif [ "$arch" = aarch64 ] || [ "$arch" = arm64 ]; then
		echo "arm64"
	else
		error "unsupported architecture: $arch"
	fi
}

DOTFILES_DIR="${HOME}/dotfiles"
OS="$(get_os)"
ARCH="$(get_arch)"

# ================================
# theme
# ================================

DIRCOLORS_SOLARIZED_ZSH_THEME="ansi-dark"
zi light pinelibg/dircolors-solarized-zsh

zi ice as"command" from"gh-r" \
  atclone"./starship init zsh > init.zsh; ./starship completions zsh > _starship" \
  atpull"%atclone" src"init.zsh"
zi light starship/starship
export STARSHIP_CONFIG=${DOTFILES_DIR}/config/starship.toml

# ================================
# config
# ================================

# https://zsh.sourceforge.io/Doc/Release/Options.html

setopt auto_list # 補完候補を一覧で表示
setopt auto_menu # 補完キー連打で補完候補を順に表示する
setopt complete_in_word # 単語の途中でも補完を行う
setopt hist_ignore_dups # 直前と同じコマンドラインはヒストリに追加しない
# setopt LIST_ROWS_FIRST # 補完の並び順を列優先にする
bindkey "^[[Z" reverse-menu-complete  # Shift押しながらで逆順に
setopt share_history # ヒストリをセッション間で共有

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

# zi wait lucid light-mode \
#     for @asdf-vm/asdf

# この辺要らないかも
# https://rtx.pub/install.sh を参考に
RTX_BPICK="*${OS}-${ARCH}.tar.gz"
# GitHub ReleaseのLatestを取得
zi from'gh-r' as'program' bpick"$RTX_BPICK" \
    pick'rtx/bin/rtx' \
    atload'eval "$(rtx activate zsh)"' \
    atclone'echo "\$rtx completion zsh > _rtx"; ./rtx/bin/rtx completion zsh > _rtx' \
    atpull'%atclone' \
    for @jdxcode/rtx
alias asdf='rtx'
# asdfとの互換性を持たせる
export RTX_ASDF_COMPAT=1

zi wait lucid light-mode \
    for azu/ni.zsh

zi wait lucid as"program" from"gh-r" mv"bat* -> bat" pick"bat/bat" light-mode \
    atclone'cp -vf bat/autocomplete/bat.zsh bat/autocomplete/_bat' \
    atpull'%atclone' \
    for @sharkdp/bat
alias cat='bat'

zi wait lucid as"program" from"gh-r" mv"lsd* -> lsd" pick"lsd/lsd" light-mode \
    for @lsd-rs/lsd
alias ls='lsd'

zi wait lucid as"program" from"gh-r" mv"fd* -> fd" pick"fd/fd" light-mode \
    for @sharkdp/fd
alias find='fd'

zi wait lucid as"program" from"gh-r" mv"ripgrep* -> rg" pick"rg/rg" light-mode \
    for BurntSushi/ripgrep
alias grep='rg'

zi pick'init.zsh' compile'*.zsh' \
    for laggardkernel/zsh-iterm2

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

zi add-fpath "$(brew --prefix)/share/zsh/site-functions"

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
