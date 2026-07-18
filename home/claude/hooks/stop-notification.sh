#!/bin/bash

# StopフックはStdinからJSONを受け取る
INPUT=$(cat)

TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
if [ -z "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# ~/を展開
TRANSCRIPT_PATH="${TRANSCRIPT_PATH/#~\//$HOME/}"

# セキュリティチェック: 許可されたパス配下か確認
ALLOWED_BASE="$HOME/.claude/projects"
REAL_PATH=$(realpath "$TRANSCRIPT_PATH" 2>/dev/null) || exit 0

if [[ "$REAL_PATH" != "$ALLOWED_BASE"* ]]; then
  exit 0
fi

# ファイルが存在するか確認
if [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# 最後の非空行を取得
LAST_LINE=$(grep -v '^\s*$' "$TRANSCRIPT_PATH" | tail -1)
if [ -z "$LAST_LINE" ]; then
  exit 0
fi

# 最後のメッセージのテキストを抽出
LAST_MESSAGE=$(echo "$LAST_LINE" | jq -r '.message.content[0].text // empty')
if [ -z "$LAST_MESSAGE" ]; then
  exit 0
fi

# macOS通知を表示 (失敗しても致命的ではない)
osascript - "Claude Code" "$LAST_MESSAGE" 2>/dev/null <<'APPLESCRIPT' || true
on run {notificationTitle, notificationMessage}
  try
    display notification notificationMessage with title notificationTitle sound name "Crystal"
  end try
end run
APPLESCRIPT

exit 0
