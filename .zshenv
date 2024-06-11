# zshを起動したときに必ず読み込まれるファイル
# 非インタラクティブシェル（シェルスクリプト実行など）でも読み込まれる
# 基本的に環境変数以外はここに書かない

export XDG_CONFIG_HOME="$HOME"/.config
export XDG_CACHE_HOME="$HOME"/.cache
export XDG_DATA_HOME="$HOME"/.local/share
export XDG_STATE_HOME="$HOME"/.local/state
export DOTFILES_DIR="$HOME"/dotfiles