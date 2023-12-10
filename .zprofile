eval "$(/opt/homebrew/bin/brew shellenv)"

if [ -d "/Users/elecdeer/Library/Application Support/JetBrains/Toolbox/scripts" ] ; then
    export PATH="$PATH:/Users/elecdeer/Library/Application Support/JetBrains/Toolbox/scripts"
fi

# https://github.com/jdx/rtx?tab=readme-ov-file#ide-integration
export PATH="$HOME/.local/share/rtx/shims:$PATH"
