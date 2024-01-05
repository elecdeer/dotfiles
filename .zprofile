# ログインシェルで1度だけ読み込まれるファイル

eval "$(/opt/homebrew/bin/brew shellenv)"

if [ -d "/Users/elecdeer/Library/Application Support/JetBrains/Toolbox/scripts" ] ; then
    export PATH="$PATH:/Users/elecdeer/Library/Application Support/JetBrains/Toolbox/scripts"
fi

# VSCodeがインストールされていれば
if [ -d "/Applications/Visual Studio Code.app" ] ; then
    export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fi

# https://mise.jdx.dev/ide-integration.html#ide-integration
export PATH="$HOME/.local/share/mise/shims:$PATH"
