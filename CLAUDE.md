# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for macOS and Linux development environments. It manages shell configuration, development tools, and application installations using a combination of Homebrew, aqua (CLI version manager), and custom shell plugins.

## Key Commands

### Initial Setup
```bash
# Fresh installation on macOS
xcode-select --install
./install.sh
./deploy.sh
aqua install --all

# Fresh installation on Linux
curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v3.0.0/aqua-installer | bash
aqua install --all
./deploy.sh
```

### Package Management
```bash
# Update all aqua-managed tools
aqua update-aqua
aqua update

# Install/update Homebrew packages
brew bundle --file "./Brewfile-base"    # Core development tools
brew bundle --file "./Brewfile-app"     # GUI applications

# Regenerate shell plugin cache
sheldon source > ~/.config/sheldon/sheldon.zsh
```

### Configuration Files
- **Shell plugins**: `config/sheldon/plugins.toml` (managed by sheldon)
- **CLI tools**: `config/aqua.yaml` (managed by aqua)
- **Git config**: `config/git/config`
- **Terminal config**: `config/wezterm/wezterm.lua`

## Architecture

### Tool Management Strategy
- **aqua**: Primary CLI tool version manager (defined in `config/aqua.yaml`)
- **Homebrew**: System dependencies and GUI applications (Brewfile-base, Brewfile-app)
- **sheldon**: Zsh plugin manager with deferred loading for performance
- **mise**: Node.js version management with Volta compatibility checking

### Shell Configuration
- **Modular plugin system**: Uses sheldon for zsh plugin management with performance optimizations
- **Completion system**: On-demand completion loading to reduce shell startup time
- **Custom features**: 
  - `^z`: fzf-powered directory navigation using zsh-z
  - `^r`: fzf-powered history search
  - Automatic Node.js version sync between mise and package.json volta settings

### Deployment System
- **install.sh**: Sets up Homebrew and installs packages
- **deploy.sh**: Creates symbolic links for configuration files
- **util.sh**: Provides utility functions for scripts (section formatting)

## Development Notes

### Plugin System
The repository includes custom plugins in `plugins/`:
- `abbr-fast-syntax-highlighting`: Enhanced syntax highlighting for abbreviations
- `ohmyzsh-git-fn`: Git function aliases
- `on-demand-completion`: Lazy-loading completion system

### Performance Optimizations
- Sheldon plugins use deferred loading (`zsh-defer`) where possible
- Completion system loads on-demand to reduce startup time
- Custom compinit logic checks timestamps to avoid unnecessary reinitialization

### Version Management
- Node.js managed by mise with automatic Volta compatibility checking
- CLI tools pinned to specific versions in aqua.yaml for reproducibility
- Homebrew formulas updated through Brewfile bundle management