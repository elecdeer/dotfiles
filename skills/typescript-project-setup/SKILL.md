---
name: typescript-project-setup
description: >
  vite-plus（vp）と pnpm を使った TypeScript プロジェクトのセットアップ方針。
  TypeScript のライブラリ・アプリケーション・monorepo を新規作成するとき、既存プロジェクトの初期設定や作り直しをするとき、
  tsconfig.json / vite.config.ts / package.json（scripts・imports・exports）の設定を追加・変更するときに必ず使うこと。
  「TS プロジェクトを作って」「ライブラリの雛形を作りたい」「tsconfig を設定して」「vite.config を直して」「パスエイリアスを張りたい」と言われた場合にも適用する。
---

# TypeScript プロジェクトセットアップ

新規・既存を問わず、TypeScript プロジェクトの土台を以下の方針で揃える。
既存プロジェクトで方針と異なる構成になっている場合は、勝手に移行せず差分をユーザーに提示して確認する。

vite-plus の詳細が必要なときは https://viteplus.dev/llms-full.txt を参照する。

## ツールチェーン

- **vite-plus** を使う。グローバルの `vp` CLI と、ローカルの devDependency `vite-plus` パッケージの両方を使う
- パッケージマネージャーは **pnpm**

### 雛形の作成

`vp create` の組み込みテンプレートを使う。

```bash
vp create vite:library      # ライブラリ
vp create vite:application  # アプリケーション
vp create vite:monorepo     # monorepo
```

非対話で作る場合は `--package-manager pnpm --no-interactive` などを付ける（`vp create --help` で確認）。
生成後は下記の方針に合わせて設定を調整する。

### vite.config.ts にすべての設定を集約する

各ツールの設定は `vite.config.ts` のブロックにまとめる。
**`vitest.config.ts`・`tsdown.config.ts`・`.oxlintrc.json`・`.oxfmtrc.json` などの個別設定ファイルは作らない。**

| ブロック | ツール | 対応コマンド |
| -------- | ------ | ------------ |
| `pack`   | tsdown | `vp pack`    |
| `test`   | Vitest | `vp test`    |
| `lint`   | Oxlint | `vp lint`    |
| `fmt`    | Oxfmt  | `vp fmt`     |

`lint.options` で `typeAware: true` と `typeCheck: true` を有効にし、`vp check` 1 コマンドでフォーマット・lint・型チェックをまとめて行えるようにする。

```ts
// vite.config.ts（ライブラリの例）
import { defineConfig } from "vite-plus";

export default defineConfig({
  pack: {
    entry: ["src/index.ts"],
    dts: {
      generator: "tsgo",
    },
    exports: true,
  },
  test: {
    include: ["src/**/*.test.{ts,tsx}"],
  },
  lint: {
    options: {
      typeAware: true,
      typeCheck: true,
    },
  },
  fmt: {},
});
```

- `typeAware` / `typeCheck` の経路（tsgolint）は tsconfig の `baseUrl` をサポートしない。`baseUrl` は使わない

### テスト

- テスト API は **`vite-plus/test`** から import する（`vitest` から直接 import しない）

  ```ts
  import { describe, expect, test, vi } from "vite-plus/test";
  ```

- テストファイルは実装と同じディレクトリに `*.test.ts` / `*.test.tsx` として置く（`src/foo.ts` ↔ `src/foo.test.ts`）
- テストの書き方自体は `writing-test-using-vitest` スキルに従う（import 元だけ `vite-plus/test` に読み替える）

### package.json の scripts

scripts は次の 4 つを基本とする。

```json
{
  "scripts": {
    "build": "vp pack",
    "dev": "vp pack --watch",
    "test": "vp test",
    "check": "vp check"
  }
}
```

- アプリケーションの場合は `build` / `dev` を `vp build` / `vp dev` にする
- `vp build` や `vp test` は組み込みコマンドなので、scripts を呼ぶときは `vp run <name>`（または `pnpm run <name>`）を使う

## tsconfig.json

```jsonc
{
  "compilerOptions": {
    "target": "esnext",
    "lib": ["es2023"],
    "module": "preserve",
    "moduleResolution": "bundler",
    "moduleDetection": "force",
    "strict": true,
    "noUnusedLocals": true,
    "noEmit": true,
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
  },
}
```

- `strict: true` は必須
- **`moduleResolution: "bundler"`（`module: "preserve"`）にする。`nodenext` にはしない**
  - ビルドは tsdown（vp pack）が行い、tsc は型チェック専用（`noEmit`）なので、バンドラー前提の解決で十分
- **`paths` と `baseUrl` は使わない**（エイリアスは次節の subpath imports で行う）

## エイリアス・自己参照は package.json の `imports` を使う

パスのエイリアスやパッケージの自己参照には、tsconfig の `paths` ではなく package.json の **`imports`（subpath imports、`#` で始まる指定子）** を使う。

```json
{
  "imports": {
    "#pkg/*": "./src/*.ts"
  }
}
```

```ts
import { render } from "#pkg/render";
```

- Vite（vp）も TypeScript（`moduleResolution: "bundler"`）も `imports` をそのまま解決するので、vite.config.ts 側の `resolve.alias` 設定は不要
- ビルド時は内部 import としてバンドルされ、dist には `#pkg/...` の指定子は残らない
- `#pkg` の部分はパッケージ名などプロジェクトに合わせた名前にする

### 例: JSX ランタイムを自作するライブラリ

ライブラリ自身の JSX ランタイムを、ライブラリ内のコード・テストから参照したい場合:

```jsonc
// package.json
{
  "imports": { "#pkg/*": "./src/*.ts" },
  "exports": {
    ".": "./dist/index.mjs",
    "./jsx-runtime": "./dist/jsx-runtime.mjs",
    "./jsx-dev-runtime": "./dist/jsx-dev-runtime.mjs",
    "./package.json": "./package.json",
  },
}
```

```jsonc
// tsconfig.json
{
  "compilerOptions": {
    "jsx": "react-jsx",
    "jsxImportSource": "#pkg",
  },
}
```

`#pkg/jsx-runtime` が `./src/jsx-runtime.ts` に解決されるため、ビルド前でも自分自身のランタイムで JSX を型チェック・テストできる。

## ライブラリの依存

- 型だけ使う依存（例: `discord-api-types`）は **`import type`** で取り込み、実行時の import を発生させない
  - `verbatimModuleSyntax: true` により、型のみの import に `import type` を付け忘れると検出できる
- 公開物は `"files": ["dist"]`、`"type": "module"` とし、`exports` は `pack.exports: true` で tsdown に生成させる

## 注意点: タグ付きテンプレートの関数名

タグ付きテンプレートの関数名を `md` / `markdown` / `html` / `css` / `graphql` / `gql` などにすると、Prettier や Oxfmt がテンプレートの中身を**埋め込み言語として整形**し、実行時の文字列が変わってしまう。

```ts
// NG: Oxfmt が中身を Markdown として整形し、文字列が変わる
const text = md`
  * item
`;

// OK: 整形対象にならない名前にする
const text = discordMd`
  * item
`;
```

中身をそのまま保持したい独自のタグ関数は、これらと衝突しない別名にする。

## セットアップ後の確認

```bash
pnpm install
pnpm run check
pnpm run test
pnpm run build
```

すべて通ることを確認してから最初のコミットを行う。
