# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a chezmoi-managed dotfiles repository that uses a two-tier package management system: mise for CLI tools and runtime environments, and sheldon for zsh plugins. The configuration emphasizes performance optimization and modular architecture.

## Common Commands

### Package Management
```bash
# Install all mise-managed tools
mise install

# Add new tool or runtime to mise
# Edit dot_config/mise/config.toml, then:
mise install

# Update all tools
mise upgrade

# List installed tools
mise list

# Regenerate sheldon plugin cache (if manual regeneration needed)
sheldon lock --update
```

### Dotfiles Management
```bash
# Apply dotfiles changes
chezmoi apply

# Check what would be applied
chezmoi diff

# Edit template files
chezmoi edit --watch

# Re-run templates after source changes
chezmoi apply --force
```

### Development Setup
```bash
# Full installation (macOS)
xcode-select --install
./install.sh
./deploy.sh
mise install

# Full installation (Linux)
# Install mise first, then:
mise install
./deploy.sh
```

## Architecture

### Template System
- Files with `.tmpl` extension use chezmoi templating
- `dot_zshrc.tmpl` - Main shell configuration with dynamic sourcing
- `dot_config/sheldon/plugins.toml.tmpl` - Plugin configuration with source directory references

### Package Management Layers
1. **mise** (`dot_config/mise/config.toml`) - CLI tools and runtimes (38 packages including bat, fd, ripgrep, fzf, gh, Node.js, Deno, Bun)
2. **sheldon** (`dot_config/sheldon/plugins.toml.tmpl`) - Zsh plugins with deferred loading

### Custom Plugins
Located in `hanger/plugins/`:
- `abbr-fast-syntax-highlighting` - Custom syntax highlighting for abbreviations
- `ohmyzsh-git-fn` - Git function integration  
- `on-demand-completion` - Lazy-loaded completion system

### Configuration Structure
- Shell layers: `dot_zshenv` → `dot_zprofile` → `dot_zshrc.tmpl`
- Git configuration with 1Password SSH signing
- 196 Git abbreviations in `dot_config/zsh-abbr/user-abbreviations`
- Performance optimizations: deferred plugin loading, intelligent completion caching

## File Naming Convention
- `dot_` prefix maps to `.` in home directory
- Template files use `.tmpl` extension for dynamic generation
- Configuration organized under `dot_config/` following XDG Base Directory specification