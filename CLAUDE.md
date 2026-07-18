# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a [mise dotfiles](https://mise.jdx.dev/dotfiles.html)-managed dotfiles repository that uses a two-tier package management system: mise for CLI tools and runtime environments, and sheldon for zsh plugins. The configuration emphasizes performance optimization and modular architecture.

`home/` 以下の実体ファイルを `~/` 配下へ symlink（テンプレート要のものは `template` モードでレンダリング）配置する。配置マッピングは repo 直下の `mise.toml` の `[dotfiles]` にある。

> [!IMPORTANT]
> symlink は `home/` 以下の実体を指すため、リポジトリは安定したパスに置くこと（移動すると全リンクが壊れる）。

## Common Commands

### Package Management
```bash
# Install all mise-managed tools
mise install

# Add new tool or runtime to mise
# Edit home/config/mise/config.toml (= ~/.config/mise/config.toml), then:
mise install

# Update all tools
mise upgrade

# List installed tools
mise list

# Regenerate sheldon plugin cache (if manual regeneration needed)
sheldon lock --update
```

### Dotfiles Management
`mise dotfiles` はリポジトリ直下（`mise.toml` のある場所）で実行する。
```bash
# Check what would be applied (templates are rendered for comparison)
mise dotfiles status

# Apply dotfiles changes (--force to replace existing non-symlink files)
mise dotfiles apply
```

### Development Setup
```bash
# Full installation (macOS)
xcode-select --install
curl https://mise.run | sh          # install mise
git clone <repo> ~/.dotfiles && cd ~/.dotfiles
mise dotfiles apply                 # place dotfiles (creates ~/.config/mise/config.toml symlink)
mise install                        # install tools
mise run skills-install              # apm.yml から ~/.claude/skills へ Claude Code skills をデプロイ
mise run setup-agents-skills        # ~/.agents/skills -> ~/.claude/skills
mise bootstrap packages apply       # (optional) system packages

# Full installation (Linux)
# Same as above without xcode-select
```

## Architecture

### Template System
- テンプレートは mise の [Tera エンジン](https://mise.jdx.dev/templates.html)。`template` モードのファイルのみ対象。
- `templates/sheldon-plugins.toml.tera` - Plugin configuration。OS 分岐は `{% if os() == "macos" %}`（値は `macos`/`linux`）、リポジトリパス参照は `{{ vars.repo_root }}`（`mise.toml` の `[vars]` で `config_root` から渡す）。
- `home/zshrc` はテンプレート構文を含まない素のファイル。

### Package Management Layers
1. **mise** (`home/config/mise/config.toml`) - CLI tools and runtimes (bat, fd, ripgrep, fzf, gh, Node.js, Deno, Bun 等)
2. **sheldon** (`templates/sheldon-plugins.toml.tera`) - Zsh plugins with deferred loading
3. **apm** (`apm.yml` / `skills/`) - Claude Code skills。外部 skill は GitHub リポジトリを直接参照し、自作 skill は `skills/` 配下でこのリポジトリ自身（`elecdeer/dotfiles`）を配布元として自己参照する。`apm install --global --target claude` で `~/.claude/skills/` へ直接デプロイされ、`home/` の symlink 機構は経由しない。

### Custom Plugins
Located in `hanger/plugins/`（`[dotfiles]` に載せず、テンプレートから `{{ vars.repo_root }}/hanger/plugins/...` として絶対パス参照する）:
- `abbr-fast-syntax-highlighting` - Custom syntax highlighting for abbreviations
- `ohmyzsh-git-fn` - Git function integration
- `on-demand-completion` - Lazy-loaded completion system

### Configuration Structure
- Shell layers: `home/zshenv` → `home/zprofile` → `home/zshrc`
- Git configuration with 1Password SSH signing
- Git abbreviations in `home/config/zsh-abbr/user-abbreviations`
- Performance optimizations: deferred plugin loading, intelligent completion caching

## File Layout Convention
- `home/` 以下の相対パスが `~/` 配下へマップされる（`home/zshrc` → `~/.zshrc`、`home/config/**` → `~/.config/**`）。
- ディレクトリは `symlink-each` で個別 symlink 化し、他ツールが生成するファイルを壊さない。
- 実行権限は symlink 先（リポジトリ内ファイル）の +x がそのまま使われる。
- Configuration は `home/config/` 以下に XDG Base Directory 準拠で整理。
