#!/usr/bin/env zsh

set -eu
set -o pipefail

SCRIPT_DIR=${0:A:h}
GWT_ENTER_SCRIPT="$SCRIPT_DIR/executable_gwt-enter"

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/gwt-enter-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/home" "$tmpdir/bin"
export HOME="$tmpdir/home"

mise_log="$tmpdir/mise.log"

cat <<'EOF' > "$tmpdir/bin/mise"
#!/usr/bin/env zsh
print "$PWD $*" >> "$MISE_LOG"
EOF
chmod +x "$tmpdir/bin/mise"

export PATH="$tmpdir/bin:$PATH"
export MISE_LOG="$mise_log"
export GWT_PLUGIN_DIR="$SCRIPT_DIR"

repo_root="$tmpdir/repo"
git init --initial-branch=main "$repo_root" >/dev/null
git -C "$repo_root" config user.name "Codex Test"
git -C "$repo_root" config user.email "codex@example.com"
git -C "$repo_root" config wt.basedir "../{gitroot}.wt"
git -C "$repo_root" config wt.hook ""

cat <<'EOF' > "$repo_root/.mise.toml"
[tools]
node = "24"
EOF
printf '{"name":"gwt-enter-test"}\n' > "$repo_root/package.json"
printf 'lockfileVersion: 9\n' > "$repo_root/pnpm-lock.yaml"
git -C "$repo_root" add .mise.toml package.json pnpm-lock.yaml
git -C "$repo_root" commit -m "initial commit" >/dev/null

cd "$repo_root"
source "$GWT_ENTER_SCRIPT" enter-feature "__BASE__:main"

expected_path="$tmpdir/repo.wt/enter-feature"
[[ "$(realpath "$PWD")" == "$(realpath "$expected_path")" ]]
[[ "$(<"$mise_log")" == "$(realpath "$expected_path") trust" ]]

print "test_gwt_enter: ok"