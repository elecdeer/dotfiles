#!/usr/bin/env zsh

set -eu
set -o pipefail

SCRIPT_DIR=${0:A:h}
GWA_SCRIPT="$SCRIPT_DIR/executable_gwa"

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/gwa-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT

repo_root="$tmpdir/repo"
worktree_root="$tmpdir/repo-feature"

mkdir -p "$repo_root"
git -C "$repo_root" init >/dev/null
git -C "$repo_root" config user.name "Codex Test"
git -C "$repo_root" config user.email "codex@example.com"

cat <<'EOF' > "$repo_root/.gitignore"
dist/
node_modules/
EOF

cat <<'EOF' > "$repo_root/tracked.txt"
root tracked
EOF

mkdir -p "$repo_root/dist" "$repo_root/node_modules/pkg"
cat <<'EOF' > "$repo_root/dist/output.txt"
root ignored
EOF
cat <<'EOF' > "$repo_root/node_modules/pkg/index.js"
root node_modules
EOF
cat <<'EOF' > "$repo_root/same-content.txt"
same content
EOF

git -C "$repo_root" add .gitignore tracked.txt
git -C "$repo_root" commit -m "test fixture" >/dev/null
git -C "$repo_root" branch feature >/dev/null
git -C "$repo_root" worktree add "$worktree_root" feature >/dev/null

cat <<'EOF' > "$repo_root/tracked.txt"
root dirty tracked
EOF

cat <<'EOF' > "$worktree_root/tracked.txt"
branch tracked
EOF

cat <<'EOF' > "$worktree_root/untracked.txt"
branch untracked
EOF

mkdir -p "$worktree_root/dist" "$worktree_root/node_modules/pkg"
cat <<'EOF' > "$worktree_root/dist/output.txt"
branch ignored
EOF
cat <<'EOF' > "$worktree_root/node_modules/pkg/index.js"
branch node_modules
EOF
cat <<'EOF' > "$worktree_root/same-content.txt"
same content
EOF

touch -t 202401010101 "$repo_root/same-content.txt"
touch -t 202501010101 "$worktree_root/same-content.txt"
same_content_before=$(stat -f '%m' "$repo_root/same-content.txt")

cd "$worktree_root" && "$GWA_SCRIPT" >/dev/null

tracked_content=$(<"$repo_root/tracked.txt")
untracked_content=$(<"$repo_root/untracked.txt")
ignored_content=$(<"$repo_root/dist/output.txt")
node_modules_content=$(<"$repo_root/node_modules/pkg/index.js")
same_content_after=$(stat -f '%m' "$repo_root/same-content.txt")

[[ "$tracked_content" == "branch tracked" ]]
[[ "$untracked_content" == "branch untracked" ]]
[[ "$ignored_content" == "root ignored" ]]
[[ "$node_modules_content" == "root node_modules" ]]
[[ "$same_content_after" == "$same_content_before" ]]

print "test_gwa: ok"
