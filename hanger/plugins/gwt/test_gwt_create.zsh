#!/usr/bin/env zsh

set -eu
set -o pipefail

SCRIPT_DIR=${0:A:h}
GWT_CREATE_SCRIPT="$SCRIPT_DIR/executable_gwt-create"

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/gwt-create-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/home"
export HOME="$tmpdir/home"

stub_bin="$tmpdir/bin"
mkdir -p "$stub_bin"
mise_log="$tmpdir/mise.log"
cat <<'EOF' > "$stub_bin/mise"
#!/usr/bin/env zsh
print "$PWD $*" >> "$MISE_LOG"
EOF
chmod +x "$stub_bin/mise"
export PATH="$stub_bin:$PATH"
export MISE_LOG="$mise_log"

remote_repo="$tmpdir/remote.git"
repo_root="$tmpdir/repo"

git init --bare "$remote_repo" >/dev/null
git init "$repo_root" >/dev/null
git -C "$repo_root" config user.name "Codex Test"
git -C "$repo_root" config user.email "codex@example.com"
git -C "$repo_root" config wt.basedir "../{gitroot}.wt"
git -C "$repo_root" config wt.hook ""

printf 'base\n' > "$repo_root/file.txt"
git -C "$repo_root" add file.txt
git -C "$repo_root" commit -m "initial commit" >/dev/null
git -C "$repo_root" branch -M main
git -C "$repo_root" remote add origin "$remote_repo"
git -C "$repo_root" push -u origin main >/dev/null

origin_main_hash=$(git -C "$repo_root" rev-parse origin/main)

printf 'local only\n' >> "$repo_root/file.txt"
git -C "$repo_root" commit -am "local main ahead" >/dev/null
local_main_hash=$(git -C "$repo_root" rev-parse HEAD)

origin_feature_path=$(
  cd "$repo_root" &&
    "$GWT_CREATE_SCRIPT" origin-feature "__BASE__:origin/main"
)
origin_feature_hash=$(git -C "$repo_root" rev-parse origin-feature)

[[ -d "$origin_feature_path" ]]
[[ "$(realpath "$origin_feature_path")" == "$(realpath "$tmpdir/repo.wt/origin-feature")" ]]
[[ "$origin_feature_hash" == "$origin_main_hash" ]]
[[ "$origin_feature_hash" != "$local_main_hash" ]]

git -C "$repo_root" checkout -b feature-base >/dev/null
printf 'feature base\n' >> "$repo_root/file.txt"
git -C "$repo_root" commit -am "feature base" >/dev/null
feature_base_hash=$(git -C "$repo_root" rev-parse HEAD)
git -C "$repo_root" checkout main >/dev/null

local_feature_path=$(
  cd "$repo_root" &&
    "$GWT_CREATE_SCRIPT" local-feature "__BASE__:feature-base"
)
local_feature_hash=$(git -C "$repo_root" rev-parse local-feature)

[[ -d "$local_feature_path" ]]
[[ "$(realpath "$local_feature_path")" == "$(realpath "$tmpdir/repo.wt/local-feature")" ]]
[[ "$local_feature_hash" == "$feature_base_hash" ]]
[[ "$local_feature_hash" != "$local_main_hash" ]]

cat <<'EOF' > "$repo_root/.mise.toml"
[tools]
node = "24"
EOF
printf 'lockfileVersion: 9\n' > "$repo_root/pnpm-lock.yaml"
git -C "$repo_root" add .mise.toml pnpm-lock.yaml
git -C "$repo_root" commit -m "add mise config" >/dev/null

trusted_details=$(
  cd "$repo_root" &&
    "$GWT_CREATE_SCRIPT" --details trusted-feature "__BASE__:main"
)
trusted_path=$(printf '%s' "$trusted_details" | cut -f1)
trusted_status=$(printf '%s' "$trusted_details" | cut -f2)
trusted_install_command=$(printf '%s' "$trusted_details" | cut -f3)
trusted_root_branch=$(printf '%s' "$trusted_details" | cut -f4)

[[ -d "$trusted_path" ]]
[[ "$trusted_status" == "created" ]]
[[ "$trusted_install_command" == "pnpm install" ]]
[[ "$trusted_root_branch" == "main" ]]
[[ "$(wc -l < "$mise_log" | tr -d ' ')" == "1" ]]
[[ "$(<"$mise_log")" == "$trusted_path trust" ]]

existing_details=$(
  cd "$repo_root" &&
    "$GWT_CREATE_SCRIPT" --details trusted-feature "$trusted_path"
)
existing_path=$(printf '%s' "$existing_details" | cut -f1)
existing_status=$(printf '%s' "$existing_details" | cut -f2)
existing_install_command=$(printf '%s' "$existing_details" | cut -f3)

[[ "$existing_path" == "$trusted_path" ]]
[[ -z "$existing_status" ]]
[[ -z "$existing_install_command" ]]

git -C "$repo_root" switch -c mise-changed-base >/dev/null
cat <<'EOF' > "$repo_root/.mise.toml"
[tools]
node = "25"
EOF
git -C "$repo_root" commit -am "change mise config" >/dev/null
git -C "$repo_root" switch main >/dev/null

changed_details=$(
  cd "$repo_root" &&
    "$GWT_CREATE_SCRIPT" --details mise-diff-feature "__BASE__:mise-changed-base"
)
changed_path=$(printf '%s' "$changed_details" | cut -f1)
changed_status=$(printf '%s' "$changed_details" | cut -f2)
changed_install_command=$(printf '%s' "$changed_details" | cut -f3)
changed_root_branch=$(printf '%s' "$changed_details" | cut -f4)

[[ -d "$changed_path" ]]
[[ "$changed_status" == "mise-diff-needed" ]]
[[ "$changed_install_command" == "pnpm install" ]]
[[ "$changed_root_branch" == "main" ]]
[[ "$(wc -l < "$mise_log" | tr -d ' ')" == "1" ]]

print "test_gwt_create: ok"
