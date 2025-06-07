source "/Users/elecdeer/.local/share/sheldon/repos/github.com/romkatv/zsh-defer/zsh-defer.plugin.zsh"
source "/Users/elecdeer/dotfiles/plugins/on-demand-completion/on-demand-completion.plugin.zsh"
_compinit() {
  local re_initialize=0
  for match in .zcompdump*(.Nmh+24); do
    re_initialize=1
    break
  done

  autoload -Uz compinit
  if [ "$re_initialize" -eq "1" ]; then
    compinit
    # update the timestamp on compdump file
    compdump
  else
    # omit the check for new functions since we updated today
    compinit -C
  fi
}
_compinit
zsh-defer source "/Users/elecdeer/.local/share/sheldon/repos/github.com/pinelibg/dircolors-solarized-zsh/dircolors-solarized-zsh.plugin.zsh"
export DIRCOLORS_SOLARIZED_ZSH_THEME="ansi-dark"
zsh-defer source "/Users/elecdeer/.local/share/sheldon/repos/github.com/zdharma-continuum/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
zsh-defer source "/Users/elecdeer/.local/share/sheldon/repos/github.com/azu/ni.zsh/ni.plugin.zsh"
zsh-defer source "/Users/elecdeer/.local/share/sheldon/repos/github.com/Aloxaf/fzf-tab/fzf-tab.plugin.zsh"
source "/Users/elecdeer/.local/share/sheldon/repos/github.com/zsh-users/zsh-history-substring-search/zsh-history-substring-search.plugin.zsh"
source "/Users/elecdeer/.local/share/sheldon/repos/github.com/zsh-users/zsh-completions/zsh-completions.plugin.zsh"
source "/Users/elecdeer/.local/share/sheldon/repos/github.com/zsh-users/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"
source "/Users/elecdeer/.local/share/sheldon/repos/github.com/olets/zsh-abbr/zsh-abbr.plugin.zsh"
ABBR_USER_ABBREVIATIONS_FILE="${DOTFILES_DIR}/config/zsh-abbr/user-abbreviations"
ABBR_GET_AVAILABLE_ABBREVIATION=1
ABBR_LOG_AVAILABLE_ABBREVIATION=1
ABBR_AUTOLOAD=0

abbr load
zsh-defer source "/Users/elecdeer/dotfiles/plugins/abbr-fast-syntax-highlighting/abbr-fast-syntax-highlighting.plugin.zsh"
source "/Users/elecdeer/.local/share/sheldon/repos/github.com/agkozak/zsh-z/zsh-z.plugin.zsh"
zsh-defer source "/Users/elecdeer/dotfiles/plugins/ohmyzsh-git-fn/ohmyzsh-git-fn.plugin.zsh"
# Node.jsのインストール後にcorepack enableを自動でやる
export MISE_NODE_COREPACK=1
# Node.jsのインストール後に自動でインストールするパッケージを指定するファイルのパスを指定
export MISE_NODE_DEFAULT_PACKAGES_FILE="${DOTFILES_DIR}/config/mise/.default-npm-packages"

eval "$(~/.local/bin/mise activate zsh)"
on_demand_completion "mise"
export AQUA_GLOBAL_CONFIG="${DOTFILES_DIR}/config/aqua.yaml"
export AQUA_POLICY_CONFIG="${DOTFILES_DIR}/config/aqua/aqua-policy.yaml"
export PATH="$(aqua root-dir)/bin:$PATH"
on_demand_completion "aqua"
source "/Users/elecdeer/.local/share/sheldon/repos/github.com/sindresorhus/pure/async.zsh"
source "/Users/elecdeer/.local/share/sheldon/repos/github.com/sindresorhus/pure/pure.zsh"
on_demand_completion "arduino-cli"
on_demand_completion "docker"
on_demand_completion "deno" "deno completions zsh"
on_demand_completion "sg" "sg completions zsh"
on_demand_completion "yq" "yq shell-completion zsh"
on_demand_completion "gh" "gh completion -s zsh"
on_demand_completion "pnpm" "pnpm completion zsh"
# インストール自体はaquaで行う
local plugin_path_dir=$(dirname $(aqua which pnpm-shell-completion))
local plugin_path="${plugin_path_dir}/pnpm-shell-completion.plugin.zsh"
source $plugin_path
source "/Users/elecdeer/.local/share/sheldon/repos/github.com/lukechilds/zsh-better-npm-completion/zsh-better-npm-completion.plugin.zsh"
# required:  zsh-better-npm-completion
# original: https://github.com/lukechilds/zsh-better-npm-completion/blob/master/zsh-better-npm-completion.plugin.zsh

_zbnc_zsh_better_ni_completion() {
  # Store custom completion status
  local custom_completion=false

  # Load custom completion commands
  case "$(_zbnc_npm_command)" in
    add)
      _zbnc_npm_install_completion
      ;;
    remove)
      _zbnc_npm_uninstall_completion
      ;;
    run)
      _zbnc_npm_run_completion
      ;;
  esac

  # Fall back to default completion if we haven't done a custom one
  [[ $custom_completion = false ]] && _zbnc_default_npm_completion
}

zsh-defer compdef _zbnc_zsh_better_ni_completion ni
source ${DOTFILES_DIR}/.zshrc.local
