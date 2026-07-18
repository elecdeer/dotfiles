#!/bin/bash

# PostToolUseフックはStdinからJSONを受け取る
# settings.json のmatcherでEdit|MultiEdit|Writeに絞り込み済み
INPUT=$(cat)

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
if [ -z "$CWD" ]; then
  exit 0
fi

# package.jsonが存在するか確認
if [ ! -f "$CWD/package.json" ]; then
  exit 0
fi

# lint:fixスクリプトが存在するか確認
HAS_LINT=$(jq -r '.scripts["lint:fix"] // empty' "$CWD/package.json")
if [ -z "$HAS_LINT" ]; then
  exit 0
fi

# pnpm-lock.yamlの有無でパッケージマネージャーを判断
PKG_MANAGER="npm"
if [ -f "$CWD/pnpm-lock.yaml" ]; then
  PKG_MANAGER="pnpm"
fi

# lint:fixを実行
OUTPUT=$(cd "$CWD" && "$PKG_MANAGER" run lint:fix 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "$OUTPUT"
  exit 0
else
  echo "Linting failed:" >&2
  echo "$OUTPUT" >&2
  exit 2
fi
