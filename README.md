# dotfiles

[mise](https://mise.jdx.dev/) の [dotfiles 機能](https://mise.jdx.dev/dotfiles.html) で管理する dotfiles 設定。

- `home/` 以下の実体ファイルを `~/` 配下へ **symlink** で配置する（テンプレートが必要なものだけ `template` モード）。
- 配置マッピングとブートストラップ設定はリポジトリ直下の `mise.toml`（`[dotfiles]` / `[bootstrap.packages]`）に定義。
- CLI ツール・ランタイムの一覧は `home/config/mise/config.toml`（= `~/.config/mise/config.toml`）の `[tools]`。

> [!NOTE]
> symlink は `home/` 以下の実体を指すため、**リポジトリを安定したパスへ置くこと**（移動すると全リンクが壊れる）。

## インストール

```zsh
# 1. (macOS) Xcode Command Line Tools
xcode-select --install

# 2. mise を導入（https://mise.jdx.dev/getting-started.html）
curl https://mise.run | sh

# 3. リポジトリを取得（安定パス。gdn 標準構造 ~/dev/github.com/elecdeer/dotfiles へ）
gdn repo clone elecdeer/dotfiles          # gdn 未導入なら git clone <url> <安定パス>
cd "$(gdn repo root)/github.com/elecdeer/dotfiles"

# 4. dotfiles を配置（~/.config/mise/config.toml の symlink もここで作られる）
#    既存の実ファイルを置き換える場合は --force を付ける
mise dotfiles apply

# 5. CLI ツール・ランタイムを導入（tools 設定が配置された後に実行）
mise install

# 6. Claude Code skills を apm.yml から ~/.claude/skills へデプロイ
mise run skills-install

# 7. ~/.agents/skills -> ~/.claude/skills の symlink を作成
mise run setup-agents-skills

# 8. （必要時）system パッケージを導入
mise bootstrap packages apply
```

## 使用方法

### dotfiles 管理

`mise dotfiles` はリポジトリ直下（`mise.toml` のある場所）で実行する。

```bash
# 差分の確認（テンプレートはレンダリングされて比較される）
mise dotfiles status

# 配置の適用（既存の実ファイルを置き換える場合は --force）
mise dotfiles apply
```

- 新しいファイルを管理下に置くときは `home/` 以下に実体を追加し、`mise.toml` の `[dotfiles]` にマッピングを追記する。
- `~/.config/sheldon/plugins.toml` はテンプレート（`templates/sheldon-plugins.toml.tera`）。OS 分岐は `os()`、リポジトリパス参照は `{{ vars.repo_root }}` を使う。

### パッケージ管理

#### mise（CLI ツール・ランタイム）

```bash
# 全ツールのインストール
mise install

# 新しいツールやランタイムの追加（~/.config/mise/config.toml に追記される）
mise use -g <tool-name>

# インストール済みツール一覧
mise list
```

##### ツールのアップデート手順

```bash
# 1. 全ツールを最新バージョンにアップデート
mise upgrade

# 2. 更新された設定は home/config/mise/config.toml の symlink 経由でリポジトリに反映済み
# 3. 変更をコミット
git commit
```

#### mise bootstrap packages（system パッケージ）

system ライブラリ等が必要な場合は `mise.toml` の `[bootstrap.packages]` に
`"brew:xxx"` / `"apt:xxx"` 形式で追記し、`mise bootstrap packages apply` で導入する。

## Claude Code skills について

[APM (Agent Package Manager)](https://microsoft.github.io/apm/) で管理する。

- 依存関係の定義: リポジトリルートの `apm.yml`
- 外部 skill は GitHub リポジトリを直接参照し、自作 skill は `skills/` 配下に置いた上でこのリポジトリ自身
  （`elecdeer/dotfiles`）を配布元として自己参照する
- `apm install --global --target claude` で `~/.claude/skills/` へ直接デプロイされる
  （`home/` の symlink 機構は経由しない）

### skills の更新

```zsh
mise run skills-update   # apm.yml の #main 参照先を最新化し ~/.claude/skills へ再デプロイ
```

### 新しい外部 skill を追加する

`apm.yml` の `dependencies.apm` に `owner/repo/skills/<name>` 形式で追記し、`mise run skills-install` を実行する。

### 自作 skill を追加する

`skills/<name>/SKILL.md` を新規作成してコミット・push し、`apm.yml` の `dependencies.apm` に
`elecdeer/dotfiles/skills/<name>#main` を追記した上で `mise run skills-install` を実行する。
