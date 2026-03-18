---
name: github-actions
description: >
  GitHub Actions ワークフロー（.github/workflows/*.yml）の作成・レビュー・改善を行う。
  新しいワークフローをゼロから書く場合、既存ワークフローをレビュー・改善する場合の両方に使う。
  ユーザーが「ワークフローを書いて」「CI を作りたい」「GitHub Actions を追加して」「このワークフローを直して」「ワークフローをレビューして」と言ったら必ずこのスキルを使うこと。
  CI/CD・PRチェック・リリース自動化・定期実行・再利用可能ワークフロー・コンポジットアクションにもすべて適用する。
---

# GitHub Actions スキル

## このスキルの使い方

- **新規作成**: 要件を聞いてからワークフローを書く
- **レビュー/改善**: 既存ファイルを読んで問題点を指摘・修正案を提示する

---

## 重要な規約（必ず守ること）

### 1. アクションのバージョン管理: pinact を使う

アクションは必ずコミット SHA でピン留めする。タグ参照（`@v4` 等）はサプライチェーン攻撃のリスクがある。

**ピン留めには `pinact`（suzuki-shunsuke/pinact）を使う:**

```bash
# ファイルを直接更新してピン留め（最もよく使う）
pinact run .github/workflows/your-workflow.yml

# 引数なしで .github/workflows/ 配下を全て処理
pinact run

# コンポジットアクションも対象に含める場合はパスを明示
pinact run .github/workflows/ .github/actions/

# -u: 全アクションを最新バージョンに更新しつつピン留め
pinact run -u .github/workflows/your-workflow.yml

# --diff: ファイルを変更せず差分だけ確認したい場合
pinact run --diff .github/workflows/your-workflow.yml

# --check: CI でピン留めが漏れていないか確認（非ゼロ終了でエラー）
pinact run --check
```

**新規ワークフローを書く場合のフロー:**

1. まずタグ参照（`@v4` 等）でワークフローを書く
2. `pinact run -u <file>` で最新バージョンに更新しつつ SHA にピン留め
3. メジャーバージョンが上がっていた場合は changelog を確認して使い方の変更がないか確認する

**既存ワークフローをピン留め漏れなく管理するには:**

- `pinact run --diff` で現状を確認してからレビューに使える
- `pinact run --check` を CI に組み込んでピン留め漏れを防ぐことも可能

- SHA にはコメントでバージョン番号を必ず併記する（pinact が自動で付けてくれる）

```yaml
# ✅ 良い例
uses: actions/checkout@93cb6efe18208431cddfb8368fd83d5badbf9bfd # v5.0.1

# ❌ 悪い例
uses: actions/checkout@v4
uses: actions/checkout@main
```

### 2. Runner の選択

- **処理が軽量な場合**（バージョン取得・ファイル操作・スクリプト実行程度）: `ubuntu-latest-slim` を使う
- **通常のビルド・テスト・デプロイ**: `ubuntu-latest`

```yaml
# 軽量な処理（例: バージョン取得、outputs だけ返すジョブ）
runs-on: ubuntu-latest-slim

# 重い処理（ビルド、テスト等）
runs-on: ubuntu-latest
```

### 3. `run:` 内で `${{ }}` 展開を使わない

シェルスクリプトの中で直接 `${{ github.sha }}` のような式を展開するとインジェクション攻撃のリスクがある。必ず `env:` を介して環境変数として渡す。

```yaml
# ✅ 良い例: env を介して渡す
- name: Get version
  env:
    PR_HEAD_REF: ${{ github.head_ref }}
  run: echo "branch: $PR_HEAD_REF"

# ❌ 悪い例: run の中で直接展開する
- name: Get version
  run: echo "branch: ${{ github.head_ref }}"
```

例外: `if:` 条件式と `uses:` の `with:` / `env:` キーへの代入は `${{ }}` を使って良い。

### 4. 結果を出力するステップでは Job Summaries を使う

チェック結果・デプロイ情報・レポートなど、人が読むべき出力は `$GITHUB_STEP_SUMMARY` に書き込む。GitHub の Actions タブで確認できる。

```yaml
- name: Report results
  if: always()
  env:
    ESLINT_OUTCOME: ${{ steps.eslint.outcome }}
    STYLELINT_OUTCOME: ${{ steps.stylelint.outcome }}
  run: |
    {
      echo "## Lint Results"
      echo "| Check | Result |"
      echo "|-------|--------|"
      echo "| ESLint | $( [ "$ESLINT_OUTCOME" = "success" ] && echo "✅ Passed" || echo "❌ Failed" ) |"
      echo "| Stylelint | $( [ "$STYLELINT_OUTCOME" = "success" ] && echo "✅ Passed" || echo "❌ Failed" ) |"
    } >> $GITHUB_STEP_SUMMARY
```

### 5. `actions/github-script` の使い所

単純な API 呼び出しやデータ取得は `gh` コマンドで十分。`actions/github-script` を使うのは、**複数のAPIを組み合わせた複雑なフロー制御**が必要な場合に限る。

```yaml
# ✅ gh コマンドで十分な例（シンプルなAPI呼び出し）
- name: Get PR info
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    PR_NUMBER: ${{ github.event.pull_request.number }}
  run: |
    SHA=$(gh api repos/${{ github.repository }}/pulls/$PR_NUMBER --jq '.head.sha')
    echo "sha=$SHA" >> $GITHUB_OUTPUT

# ✅ github-script を使うべき例（複数APIを使ったフロー制御）
- uses: actions/github-script@<SHA> # vX.X.X
  with:
    script: |
      // PRのラベルを見て、条件分岐しながら複数のAPIを呼ぶような複雑なケース
      const { data: pr } = await github.rest.pulls.get({
        owner: context.repo.owner,
        repo: context.repo.repo,
        pull_number: context.issue.number,
      });
      if (pr.labels.some(l => l.name === 'skip-review')) {
        await github.rest.pulls.merge({ ... });
      } else {
        await github.rest.pulls.requestReviewers({ ... });
      }
```

### 6. GitHub Packages の認証

organization internal なパッケージ（`@your-org/package-name` 等）を GitHub Packages から取得する場合、インストール時に認証が必要。`setup-node` の `registry-url` と `NODE_AUTH_TOKEN` を設定する。

```yaml
- name: Setup Node.js
  uses: actions/setup-node@<SHA> # vX.X.X
  with:
    cache: pnpm
    registry-url: "https://npm.pkg.github.com"
    scope: "@your-org" # パッケージの organization スコープ
    node-version-file: package.json

- name: Install dependencies
  run: pnpm install --frozen-lockfile
  env:
    NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 7. コンポジットアクションでは `shell:` を必ず明記する

コンポジットアクション（`using: 'composite'`）内の `run:` ステップは、通常のワークフローと異なり `shell:` のデフォルトが存在しない。**必ず `shell: bash` を明記する**（省略するとエラーになる）。

```yaml
# ✅ 良い例
runs:
  using: 'composite'
  steps:
    - name: Install dependencies
      shell: bash  # コンポジットアクションでは必須
      run: pnpm install --frozen-lockfile

# ❌ 悪い例（エラーになる）
runs:
  using: 'composite'
  steps:
    - name: Install dependencies
      run: pnpm install --frozen-lockfile  # shell: が無いとエラー
```

### 8. jq で値を取得する際の null 文字列問題

`jq` でフィールドを取り出すとき、**フィールドが存在しない・値が null の場合に文字列 `"null"` が出力される**。
これをシェル変数に格納すると `-n "$VAR"` チェックが真になり、`null` を含む値をそのまま後続処理に渡してバグを引き起こす。
`gh --jq`・`jq` 単体・`actions/github-script` の出力を `$GITHUB_OUTPUT` 経由で受け渡すケースすべてに当てはまる。

**対処法: jq 側で `// empty` を使う**

`// empty` を使うと jq が null のときに何も出力しないため、変数が空文字になる。

```bash
# ✅ 良い例: null を空文字に変換する
BRANCH=$(gh pr list --search "..." --jq '.[0].headRefName // empty')
if [ -n "$BRANCH" ]; then
  echo "Found: $BRANCH"
fi

# ✅ jq 単体でも同様
VALUE=$(echo "$JSON" | jq -r '.some.field // empty')

# ❌ 悪い例: null 文字列がそのまま入ってしまう
BRANCH=$(gh pr list --search "..." --jq '.[0].headRefName')
if [ -n "$BRANCH" ]; then
  # $BRANCH が "null" になっていても真になってしまう
  git checkout "$BRANCH"  # => fatal: "null" という名前のブランチは存在しない
fi
```

### 9. コメントで処理の意図を残す

- ジョブ・ステップの目的が自明でない場合はコメントを書く
- 特に「なぜこの順番で実行するか」「なぜこの値を使っているか」が分かりにくい箇所にコメントを入れる

```yaml
# pnpm list でインストール済みのバージョンを取得し、
# 対応するコンテナイメージのタグとして使用する
- id: set-version
  run: |
    VERSION=$(pnpm list playwright --depth=0 --json | jq -r '...')
    echo "version=$VERSION" >> $GITHUB_OUTPUT
```

---

## ベストプラクティス チェックリスト

### セキュリティ

- [ ] アクションは SHA でピン留め（`pinact` で管理）
- [ ] `permissions` は最小権限で明示
- [ ] `run:` 内に `${{ }}` 式を書いていない（`env:` を使う）
- [ ] シークレットはハードコードしていない
- [ ] `pull_request_target` を使う場合は慎重に（フォーク PR でシークレットが漏れるリスク）

### 信頼性・保守性

- [ ] `timeout-minutes` を全ジョブに設定（目安: lint/test 15〜30 分、build 30 分、deploy 60 分）
- [ ] `concurrency` でダブル実行を防止
- [ ] `$GITHUB_OUTPUT` を使う（非推奨の `set-output` は使わない）
- [ ] jq の出力は `// empty` を使うか `!= "null"` チェックを追加して null 文字列を防ぐ
- [ ] 処理の意図がわかるコメントを書く

### 効率化・UX

- [ ] 軽量ジョブは `ubuntu-latest-slim` を使う
- [ ] 依存関係はキャッシュ（`setup-node` の `cache: pnpm` 等）
- [ ] 並列実行できるジョブを不要に直列にしていない
- [ ] 繰り返すセットアップはコンポジットアクション（`.github/actions/`）にまとめる（再利用可能ワークフローより優先）
- [ ] 結果を出力するステップは Job Summaries を使う
- [ ] 複数 API を組み合わせた複雑なフロー制御は `actions/github-script` を使う（単純な API 呼び出しは `gh` コマンドで十分）
- [ ] コンポジットアクション内の `run:` には `shell: bash` を明記する

---

## よくあるパターン集

### パターン1: PRチェック（Lint/Test/Build）

**ジョブを分けるかどうかはユーザーに確認する。**  
処理を別ジョブに分けると「どのチェックが落ちたか一目でわかる・並列実行になる」メリットがあるが、各ジョブで checkout + 依存インストールが走るためオーバーヘッドがある。プロジェクトの規模・実行時間・好みによって判断が変わるため、ワークフロー新規作成時は「各チェックを別ジョブに分けますか、それとも1ジョブにまとめますか？」と確認する。

以下のサンプルは別ジョブに分けた例:

```yaml
name: PR Check

on:
  push:
    branches: ["main"]
  pull_request:
    types: [opened, synchronize, reopened]
  merge_group:
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.event_name == 'pull_request' && github.head_ref || github.sha }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  lint:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@<SHA> # vX.X.X
      - uses: ./.github/actions/setup-node-pnpm
        with:
          node-auth-token: ${{ secrets.GITHUB_TOKEN }}
      - name: Run ESLint
        id: eslint
        continue-on-error: true
        run: pnpm run lint:eslint
      - name: Run Stylelint
        id: stylelint
        continue-on-error: true
        run: pnpm run lint:stylelint
      - name: Report and fail
        if: always()
        env:
          ESLINT_OUTCOME: ${{ steps.eslint.outcome }}
          STYLELINT_OUTCOME: ${{ steps.stylelint.outcome }}
        run: |
          FAILED=0
          {
            echo "## Lint Results"
            echo "| Check | Result |"
            echo "|-------|--------|"
          } >> $GITHUB_STEP_SUMMARY

          if [ "$ESLINT_OUTCOME" = "failure" ]; then
            echo "| ESLint | ❌ Failed |" >> $GITHUB_STEP_SUMMARY
            FAILED=1
          else
            echo "| ESLint | ✅ Passed |" >> $GITHUB_STEP_SUMMARY
          fi

          if [ "$STYLELINT_OUTCOME" = "failure" ]; then
            echo "| Stylelint | ❌ Failed |" >> $GITHUB_STEP_SUMMARY
            FAILED=1
          else
            echo "| Stylelint | ✅ Passed |" >> $GITHUB_STEP_SUMMARY
          fi

          if [ $FAILED -eq 1 ]; then exit 1; fi

  test:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@<SHA> # vX.X.X
      - uses: ./.github/actions/setup-node-pnpm
        with:
          node-auth-token: ${{ secrets.GITHUB_TOKEN }}
      - name: Run tests
        run: pnpm run test

  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@<SHA> # vX.X.X
      - uses: ./.github/actions/setup-node-pnpm
        with:
          node-auth-token: ${{ secrets.GITHUB_TOKEN }}
      - name: Run build
        run: pnpm run build
```

### パターン2: ジョブ間でデータを引き渡す（outputs）

outputs を使うジョブは軽量なので `ubuntu-latest-slim` でよい。

```yaml
jobs:
  get-version:
    runs-on: ubuntu-latest-slim
    outputs:
      version: ${{ steps.set-version.outputs.version }}
    steps:
      - id: set-version
        run: echo "version=$(cat VERSION)" >> $GITHUB_OUTPUT

  build:
    needs: get-version
    runs-on: ubuntu-latest
    env:
      APP_VERSION: ${{ needs.get-version.outputs.version }}
    steps:
      # env を介して渡しているので run の中で直接 ${{ }} を使わない
      - run: echo "Building version $APP_VERSION"
```

### パターン3: コンポジットアクション（セットアップの共通化）

セットアップ手順など、複数ワークフローで繰り返す処理をまとめるのに適している。  
**既存のコンポジットアクションをレビューする際は、`node-auth-token` input と `registry-url` の設定がなければ GitHub Packages 認証の追加を提案する。**

```yaml
# .github/actions/setup-node-pnpm/action.yml
name: "Setup Node.js with pnpm"
description: "pnpm と Node.js のセットアップ、および internal パッケージの認証"

inputs:
  node-auth-token:
    description: "GitHub Packages 認証用トークン（@org スコープのパッケージに必要）"
    required: true

runs:
  using: "composite"
  steps:
    - name: Install pnpm
      uses: pnpm/action-setup@<SHA> # vX.X.X

    # package.json の devEngines.runtime.version からバージョンを取得
    - name: Setup Node.js
      uses: actions/setup-node@<SHA> # vX.X.X
      with:
        cache: pnpm
        registry-url: "https://npm.pkg.github.com"
        scope: "@your-org"
        node-version-file: package.json

    - name: Install dependencies
      shell: bash
      run: pnpm install --frozen-lockfile
      env:
        NODE_AUTH_TOKEN: ${{ inputs.node-auth-token }}
```

呼び出し元:

```yaml
- uses: ./.github/actions/setup-node-pnpm
  with:
    node-auth-token: ${{ secrets.GITHUB_TOKEN }}
```

### パターン4: actions/github-script でAPIを使う

```yaml
- name: Get latest release version
  uses: actions/github-script@<SHA> # vX.X.X
  id: get-version
  with:
    result-encoding: string
    script: |
      const { data } = await github.rest.repos.getLatestRelease({
        owner: context.repo.owner,
        repo: context.repo.repo,
      });
      return data.tag_name;

- name: Use the version
  env:
    LATEST_VERSION: ${{ steps.get-version.outputs.result }}
  run: echo "Latest: $LATEST_VERSION"
```

### パターン5: スケジュール実行

```yaml
on:
  schedule:
    - cron: "0 9 * * 1-5" # 平日9時(UTC) = 日本時間18時
  workflow_dispatch: # 手動実行も可能にしておく
```

---

## レビュー時の確認フロー

既存ワークフローをレビューするときは、以下の順で問題を探す。

1. **セキュリティ**: SHA ピン留めされているか？`run:` 内に `${{ }}` はないか？権限は最小か？
2. **信頼性**: タイムアウト設定はあるか？concurrency はあるか？
3. **非推奨 API**: `set-output`、`save-state` など古いコマンドを使っていないか
4. **効率**: キャッシュを活用しているか？並列化できるジョブが直列になっていないか？軽量ジョブに重いランナーを使っていないか？
5. **UX**: 結果は Job Summaries で表示されているか？処理の意図がコメントで分かるか？

---

## よくある失敗パターンと対処法

| 問題                                                | 原因                                                         | 対処                                                                                                      |
| --------------------------------------------------- | ------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| `Context access might be invalid`                   | 存在しない context キー                                      | `github.event.pull_request` の `pull_request` イベント限定フィールドを他のトリガーでも使っている          |
| ビルドが毎回キャッシュミス                          | `cache-dependency-path` の指定ミス                           | `pnpm-lock.yaml` のパスを正確に指定                                                                       |
| `set-output` の警告                                 | 非推奨コマンド                                               | `$GITHUB_OUTPUT` に移行                                                                                   |
| fork PR でシークレットが使えない                    | セキュリティ制限                                             | `pull_request_target` + 明示的チェックアウト or Environments を使う                                       |
| ワークフローが終わらない                            | `timeout-minutes` 未設定                                     | タイムアウトを設定する                                                                                    |
| GitHub Packages のインストール失敗                  | 認証未設定                                                   | `setup-node` で `registry-url` と `scope` を設定し、`NODE_AUTH_TOKEN` を `env:` で渡す                    |
| jq の結果が `"null"` 文字列になり後続処理が失敗する | フィールドが null/存在しない場合に jq が `"null"` を出力する | jq フィルタに `// empty` を付けて空文字に変換するか、シェル側で `[ "$VAR" != "null" ]` を追加チェックする |
