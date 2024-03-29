# .zshrc
# インタラクティブシェルでのみ読み込まれるファイル

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

export STARSHIP_CONFIG=${DOTFILES_DIR}/config/starship.toml
zi ice as"command" from"gh-r" \
    atclone"./starship init zsh > init.zsh; ./starship completions zsh > _starship" \
    atpull"%atclone" src"init.zsh"
zi light starship/starship

# ================================
# config
# ================================

# https://zsh.sourceforge.io/Doc/Release/Options.html

setopt auto_list # 補完候補を一覧で表示
setopt auto_menu # 補完キー連打で補完候補を順に表示する
setopt complete_in_word # 単語の途中でも補完を行う
# setopt LIST_ROWS_FIRST # 補完の並び順を列優先にする
bindkey "^[[Z" reverse-menu-complete  # Shift押しながらで逆順に

export HISTSIZE=10000 # ヒストリの保存行数
export SAVEHIST=10000 # ヒストリの保存行数
setopt share_history # ヒストリをセッション間で共有
setopt hist_ignore_all_dups # ヒストリに重複を保存しない
setopt hist_reduce_blanks # 記録時に余計な空白を除去する

zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} # 補完候補に色を付ける
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

zi from'gh-r' as'program' \
    pick'mise/bin/mise' mv"mise* -> mise" \
    atload'eval "$(mise activate zsh)"' \
    atclone'echo "\$mise completion zsh > _mise"; ./mise completion zsh > _mise' \
    atpull'%atclone' \
    for @jdx/mise
alias asdf='mise'
# asdfとの互換性を持たせる
export MISE_ASDF_COMPAT=1
# Node.jsのインストール後にcorepack enableを自動でやる
export MISE_NODE_COREPACK=1
# Node.jsのインストール後に自動でインストールするパッケージを指定するファイルのパスを指定
export MISE_NODE_DEFAULT_PACKAGES_FILE="${DOTFILES_DIR}/config/mise/.default-npm-packages"

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

zi wait lucid as"program" from"gh-r" mv"delta* -> delta" pick"delta/delta" light-mode \
    for dandavison/delta

zi wait lucid as"program" from"gh-r" mv"pastel* -> pastel" pick"pastel/pastel" light-mode \
    for @sharkdp/pastel

zi wait lucid as"program" from"gh-r" mv"hexyl* -> hexyl" pick"hexyl/hexyl" light-mode \
    for @sharkdp/hexyl

zi wait lucid as"program" from"gh-r" mv"jq* -> jq" light-mode \
    for @jqlang/jq

zi wait lucid as"program" from"gh-r" mv"yq* -> yq" light-mode \
    atclone'./yq shell-completion zsh > _yq' \
    atpull'%atclone' run-atpull'%atclone'\
    for @mikefarah/yq

zi wait lucid as"program" from"gh-r" mv"micro* -> micro" pick"micro/micro" light-mode \
    for zyedidia/micro

zi wait lucid as"program" from"gh-r" light-mode \
    atclone'./sg completions zsh > _sg' \
    atpull'%atclone' run-atpull'%atclone'\
    for @ast-grep/ast-grep
    
zi wait lucid light-mode \
    for rupa/z

zi wait lucid from'gh-r' as'program' light-mode \
    for junegunn/fzf

zi light-mode \
    for Aloxaf/fzf-tab

# git補完でのa-zソートを無効化
zstyle ':completion:*:git*:*' sort false
# 補完候補のgroupを有効にする
zstyle ':completion:*:descriptions' format '[%d]'
# force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
zstyle ':completion:*' menu no
# cdの補完でプレビュー
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd -1 --icon=always --color=always $realpath'
# switch group using `<` and `>`
zstyle ':fzf-tab:*' switch-group '<' '>'

zi pick'init.zsh' compile'*.zsh' \
    for laggardkernel/zsh-iterm2

# zinit wait lucid depth"1" blockf for \
#     yuki-yano/zeno.zsh

zi wait lucid as"program" from"gh-r" mv"gh* -> gh" pick"gh/bin/gh" light-mode \
    atclone'./gh/bin/gh completion --shell zsh > _gh' \
    atpull'%atclone' run-atpull'%atclone'\
    for cli/cli

# ================================
# completions
# ================================

zi wait lucid light-mode \
    for \
    atload'_zsh_autosuggest_start' zsh-users/zsh-autosuggestions \
    blockf zsh-users/zsh-completions \
    zsh-users/zsh-history-substring-search \

# deno（あれば）
zi wait lucid id-as"deno-completion" \
    has'deno' as'command' \
    atclone'echo "\$deno completions zsh > _deno"; deno completions zsh > _deno' \
    atpull'%atclone' run-atpull'%atclone' \
    for z-shell/null

# docker（あれば）
zi wait lucid as"completion" \
    has'docker' \
    for OMZP::docker/completions/_docker

# arduino-cli（あれば）
zi wait lucid id-as"arduino-cli-completion" for \
    has'arduino-cli' as'command' \
    atclone'echo "\$arduino-cli completion zsh > _arduino-cli"; arduino-cli completion zsh > _arduino-cli' \
    atpull'%atclone' run-atpull'%atclone'\
    z-shell/null


zi add-fpath "$(brew --prefix)/share/zsh/site-functions"


# ================================
# features
# ================================

# かつていたことのあるディレクトリに移動する
# https://qiita.com/kamykn/items/aa9920f07487559c0c7e
function fzf-z-search() {
    local res=$(z | sort -rn | cut -c 12- | fzf --reverse --prompt="cd > ")
    if [ -n "$res" ]; then
        BUFFER+="cd $res"
        zle accept-line
    else
        return 1
    fi
}

zle -N fzf-z-search
bindkey '^z' fzf-z-search


function select-history() {
    BUFFER=$(history -n -r 1 | fzf --exact --reverse --query="$LBUFFER" --prompt="History > ")
    CURSOR=${#BUFFER}
}

zle -N select-history
bindkey '^r' select-history


# ================================
function sync_mise_node_version_with_volta() {
    # echo "sync_mise_node_version_with_volta"

    if [[ ! -f "package.json" ]] || [[ "$MISE_VOLTA_SYNC_USER_CONFIRMED" == "true" ]]; then
        return
    fi

    volta_node_version=$(jq -r '.volta.node // empty' package.json)

    if [[ -z $volta_node_version ]]; then
        return
    fi

    current_node_version=$(mise current node)

    if [[ $volta_node_version == $current_node_version ]]; then
        return
    fi

    echo "package.jsonに記載されているnodeのバージョンとmiseで管理されているnodeのバージョンが一致しません。"
    printf "volta.node:\t\t%s\n" "$volta_node_version"
    printf "mise current node:\t%s\n" "$current_node_version"

    echo "mise local node $volta_node_version を実行しますか？ [y/N]"
    read answer

    if [[ "$answer" =~ ^[Yy]$ ]]; then
        mise local node $volta_node_version
        echo "実行しました。"
    fi

    export MISE_VOLTA_SYNC_USER_CONFIRMED=true
}

# cd後フック
# function chpwd() {
#     sync_mise_node_version_with_volta
# }

# # シェル開いた時にもチェック
# sync_mise_node_version_with_volta

# ================================

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
