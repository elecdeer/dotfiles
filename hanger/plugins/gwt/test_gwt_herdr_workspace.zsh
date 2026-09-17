#!/usr/bin/env zsh

set -eu
set -o pipefail

SCRIPT_DIR=${0:A:h}
REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
WORKSPACE_SCRIPT="$REPO_ROOT/home/local/bin/gwt-herdr-workspace"

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/gwt-herdr-workspace-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/home"
export HOME="$tmpdir/home"
# 実行環境のグローバルgit設定(署名鍵など)が$XDG_CONFIG_HOME経由で漏れ込むのを防ぐ
export XDG_CONFIG_HOME="$tmpdir/home/.config"

stub_bin="$tmpdir/bin"
stub_plugin_dir="$tmpdir/gwt-plugin"
mkdir -p "$stub_bin" "$stub_plugin_dir"

herdr_log="$tmpdir/herdr.log"

cat <<'EOF' > "$stub_bin/herdr"
#!/usr/bin/env zsh
print -r -- "$*" >> "$HERDR_LOG"
if [[ "$1 $2" == "workspace list" ]]; then
  print -r -- "${HERDR_WORKSPACE_LIST:-{\"result\":{\"workspaces\":[]}}}"
elif [[ "$1 $2" == "workspace create" ]]; then
  print '{"result":{"workspace":{"workspace_id":"workspace-1"}}}'
elif [[ "$1 $2" == "workspace focus" ]]; then
  print '{"result":{}}'
elif [[ "$1 $2" == "pane list" ]]; then
  print '{"result":{"panes":[{"pane_id":"pane-1"}]}}'
elif [[ "$1 $2" == "pane split" ]]; then
  print '{"result":{}}'
else
  exit 1
fi
EOF
chmod +x "$stub_bin/herdr"

# gwt-select はfzfを介した対話選択なので、テストでは選択結果を直接返すスタブに置き換える
cat <<'EOF' > "$stub_plugin_dir/gwt-select"
#!/usr/bin/env zsh
print -r -- "$GWT_SELECT_RESULT"
EOF
chmod +x "$stub_plugin_dir/gwt-select"

export PATH="$stub_bin:$PATH"
export HERDR_LOG="$herdr_log"
export HERDR_BIN_PATH="$stub_bin/herdr"
export GWT_PLUGIN_DIR="$stub_plugin_dir"

setup_repo() {
  local repo_path="$1"
  local worktree_name="$2"
  git init --initial-branch=main "$repo_path" >/dev/null
  git -C "$repo_path" config user.name "Codex Test"
  git -C "$repo_path" config user.email "codex@example.com"
  git -C "$repo_path" commit --allow-empty -m "initial commit" >/dev/null
  git -C "$repo_path" worktree add -b "$worktree_name" "$repo_path.wt-$worktree_name" >/dev/null
}

repo_alpha="$tmpdir/repo-alpha"
repo_beta="$tmpdir/repo-beta"
setup_repo "$repo_alpha" "feature-x"
setup_repo "$repo_beta" "feature-x"

# 同じworktree名(feature-x)でも、リポジトリが異なればタブラベルは"リポジトリ名/worktree名"で区別される
: > "$herdr_log"
export GWT_SELECT_RESULT=$'feature-x\t'"$repo_alpha.wt-feature-x"
export HERDR_ACTIVE_PANE_CWD="$repo_alpha"
"$WORKSPACE_SCRIPT"
grep -Fq "workspace create --cwd $repo_alpha.wt-feature-x --label repo-alpha/feature-x --focus" "$herdr_log"

: > "$herdr_log"
export GWT_SELECT_RESULT=$'feature-x\t'"$repo_beta.wt-feature-x"
export HERDR_ACTIVE_PANE_CWD="$repo_beta"
"$WORKSPACE_SCRIPT"
grep -Fq "workspace create --cwd $repo_beta.wt-feature-x --label repo-beta/feature-x --focus" "$herdr_log"

# repo-beta向けの同名ラベルタブが既に開いていても、repo-alphaのfeature-xとは取り違えず新規作成する
: > "$herdr_log"
export HERDR_WORKSPACE_LIST='{"result":{"workspaces":[{"label":"repo-beta/feature-x","workspace_id":"existing-beta"}]}}'
export GWT_SELECT_RESULT=$'feature-x\t'"$repo_alpha.wt-feature-x"
export HERDR_ACTIVE_PANE_CWD="$repo_alpha"
"$WORKSPACE_SCRIPT"
grep -Fq "workspace create --cwd $repo_alpha.wt-feature-x --label repo-alpha/feature-x --focus" "$herdr_log"
! grep -Fq "workspace focus existing-beta" "$herdr_log"

# 完全一致するラベルのworkspaceが既に開いていれば、新規作成せずfocusする
: > "$herdr_log"
export HERDR_WORKSPACE_LIST='{"result":{"workspaces":[{"label":"repo-alpha/feature-x","workspace_id":"existing-alpha"}]}}'
export GWT_SELECT_RESULT=$'feature-x\t'"$repo_alpha.wt-feature-x"
export HERDR_ACTIVE_PANE_CWD="$repo_alpha"
"$WORKSPACE_SCRIPT"
grep -Fq "workspace focus existing-alpha" "$herdr_log"
! grep -Fq "workspace create" "$herdr_log"

print "test_gwt_herdr_workspace: ok"
