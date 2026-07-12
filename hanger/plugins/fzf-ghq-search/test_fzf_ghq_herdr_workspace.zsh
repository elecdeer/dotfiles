#!/usr/bin/env zsh

set -eu
set -o pipefail

SCRIPT_DIR=${0:A:h}
REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
LIST_SCRIPT="$SCRIPT_DIR/executable_fzf-ghq-list"
WORKSPACE_SCRIPT="$REPO_ROOT/dot_local/bin/executable_fzf-ghq-herdr-workspace"

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/fzf-ghq-herdr-test.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT

stub_bin="$tmpdir/bin"
mkdir -p "$stub_bin" "$tmpdir/ghq/github.com/owner/repo" "$tmpdir/clone/repo"

cat <<'EOF' > "$stub_bin/gdn"
#!/usr/bin/env zsh
if [[ "$1 $2" == "repo root" ]]; then
  print -r -- "$GHQ_ROOT"
elif [[ "$1 $2" == "repo list" ]]; then
  printf 'github.com/owner/repo\t100\t1 minute ago\n'
elif [[ "$1 $2" == "repo clone" ]]; then
  print -r -- "$3" >> "$GDN_CLONE_LOG"
  [[ "${GDN_CLONE_FAIL:-}" == "1" ]] && exit 1
  print -r -- "$CLONE_PATH"
else
  exit 1
fi
EOF

cat <<'EOF' > "$stub_bin/fzf"
#!/usr/bin/env zsh
print -r -- "$*" > "$FZF_ARGS_LOG"
cat >/dev/null
[[ "${FZF_CANCEL:-}" == "1" ]] && exit 130
print -r -- "$FZF_RESULT"
EOF

cat <<'EOF' > "$stub_bin/herdr"
#!/usr/bin/env zsh
print -r -- "$*" >> "$HERDR_LOG"
if [[ "$1 $2" == "workspace list" ]]; then
  print '{"result":{"workspaces":[]}}'
elif [[ "$1 $2" == "workspace create" ]]; then
  print '{"result":{"workspace":{"workspace_id":"workspace-1"}}}'
elif [[ "$1 $2" == "pane list" ]]; then
  print '{"result":{"panes":[{"pane_id":"pane-1"}]}}'
elif [[ "$1 $2" == "pane split" ]]; then
  print '{"result":{}}'
else
  exit 1
fi
EOF

chmod +x "$stub_bin/gdn" "$stub_bin/fzf" "$stub_bin/herdr"

export PATH="$stub_bin:$PATH"
export GHQ_ROOT="$tmpdir/ghq"
export CLONE_PATH="$tmpdir/clone/repo"
export GDN_CLONE_LOG="$tmpdir/gdn-clone.log"
export FZF_ARGS_LOG="$tmpdir/fzf-args.log"
export HERDR_LOG="$tmpdir/herdr.log"
export HERDR_BIN_PATH="$stub_bin/herdr"
export FZF_GHQ_LIST_SCRIPT="$LIST_SCRIPT"

list_without_query=$("$LIST_SCRIPT")
[[ "$list_without_query" != *"__GDN_CLONE__"* ]]

list_with_query=$("$LIST_SCRIPT" "owner/new-repo")
[[ "$list_with_query" == *$'__GDN_CLONE__:owner/new-repo\t'* ]]
[[ "$list_with_query" == *"* clone: owner/new-repo"* ]]

: > "$GDN_CLONE_LOG"
: > "$HERDR_LOG"
export FZF_RESULT=$'100\tgithub.com/owner/repo\towner/repo\t1 minute ago'
"$WORKSPACE_SCRIPT"
[[ ! -s "$GDN_CLONE_LOG" ]]
grep -Fq "workspace create --cwd $GHQ_ROOT/github.com/owner/repo --label repo --focus" "$HERDR_LOG"
grep -Fq "pane split pane-1 --direction right --ratio 0.5 --cwd $GHQ_ROOT/github.com/owner/repo --no-focus" "$HERDR_LOG"
grep -Fq 'change:reload("$FZF_GHQ_LIST_SCRIPT" {q})' "$FZF_ARGS_LOG"

: > "$GDN_CLONE_LOG"
: > "$HERDR_LOG"
clone_target='git@github.com:owner/new-repo.git'
export FZF_RESULT=$'0\t__GDN_CLONE__:'"$clone_target"$'\t* clone\tclone'
"$WORKSPACE_SCRIPT"
[[ "$(<"$GDN_CLONE_LOG")" == "$clone_target" ]]
grep -Fq "workspace create --cwd $CLONE_PATH --label repo --focus" "$HERDR_LOG"
grep -Fq "pane split pane-1 --direction right --ratio 0.5 --cwd $CLONE_PATH --no-focus" "$HERDR_LOG"

: > "$GDN_CLONE_LOG"
: > "$HERDR_LOG"
export GDN_CLONE_FAIL=1
if "$WORKSPACE_SCRIPT"; then
  print -u2 "clone failure unexpectedly succeeded"
  exit 1
fi
unset GDN_CLONE_FAIL
[[ ! -s "$HERDR_LOG" ]]

: > "$HERDR_LOG"
export FZF_CANCEL=1
if "$WORKSPACE_SCRIPT"; then
  print -u2 "fzf cancellation unexpectedly succeeded"
  exit 1
else
  exit_status=$?
fi
unset FZF_CANCEL
[[ "$exit_status" == "130" ]]
[[ ! -s "$HERDR_LOG" ]]

print "test_fzf_ghq_herdr_workspace: ok"
