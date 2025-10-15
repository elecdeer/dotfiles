# dotfiles

chezmoi で管理する dotfiles 設定

## インストール

```zsh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply elecdeer
```

## アーキテクチャ

### パッケージ管理層

1. **aqua** (`hanger/aqua/aqua.yaml`) - CLI ツール（bat, fd, ripgrep, fzf, starship 等）
2. **mise** (`dot_config/mise/config.toml`) - ランタイム（Node.js, Deno, claude-code）
3. **sheldon** (`dot_config/sheldon/plugins.toml.tmpl`) - zsh プラグイン（遅延ロード対応）

## 使用方法

### dotfiles 管理

```bash
# dotfiles変更の適用
chezmoi apply

# 適用される変更の確認
chezmoi diff

# 他の端末での変更を反映
chezmoi update
```

### パッケージ管理

#### aqua（CLI ツール）

```bash
# パッケージ検索してhanger/aqua/aqua.yamlに追加
aqua generate -g -i

# インストール済みパッケージ一覧
aqua list --installed

# アップデート
aqua update -c $AQUA_GLOBAL_CONFIG
```
