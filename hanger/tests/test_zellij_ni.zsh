#!/usr/bin/env zsh

set -eu
set -o pipefail

SCRIPT_DIR=${0:A:h}
ZELLIJ_NI_SCRIPT="$SCRIPT_DIR/../../dot_local/bin/executable_zellij-ni"

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/zellij-ni-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT

if ! command -v expect >/dev/null 2>&1; then
  print -u2 "expect is required for this test"
  exit 1
fi

fake_bin="$tmpdir/bin"
workspace="$tmpdir/workspace"

mkdir -p "$fake_bin" "$workspace"
printf '{}\n' > "$workspace/package.json"

cat > "$fake_bin/ni" <<'EOF'
#!/usr/bin/env zsh
if [[ "$1" != "run" ]]; then
  exit 2
fi

print 'prompt>'
read -r answer
printf 'answer=%s\n' "$answer"
EOF
chmod +x "$fake_bin/ni"

cd "$workspace"

expect <<EOF
set timeout 5
set env(PATH) "$fake_bin:\$env(PATH)"
spawn zsh -f "$ZELLIJ_NI_SCRIPT" dev
expect "prompt>"
send "typed answer\r"
expect "answer=typed answer"
expect eof
EOF

print "test_zellij_ni: ok"
