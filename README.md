# dotfiles

chezmoi で管理する dotfiles 設定

## インストール

```zsh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply elecdeer
```

## アーキテクチャ

### パッケージ管理層

1. **mise** (`dot_config/mise/config.toml`) - CLI ツールとランタイム（bat, fd, ripgrep, fzf, gh, Node.js, Deno, Bun 等 38 パッケージ）
2. **sheldon** (`dot_config/sheldon/plugins.toml.tmpl`) - zsh プラグイン（遅延ロード対応）

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

#### mise（CLI ツール・ランタイム）

```bash
# 全ツールのインストール
mise install

# 新しいツールやランタイムの追加
# dot_config/mise/config.tomlを編集してから：
mise use -g <tool-name>

# インストール済みツール一覧
mise list
```

##### ツールのアップデート手順

```bash
# 1. 全ツールを最新バージョンにアップデート
mise upgrade

# 2. 更新された設定ファイルをchezmoiに反映
chezmoi add ~/.config/mise/config.toml ~/.config/mise/mise.lock

# 3. 変更をコミット
git commit
```
