#!/usr/bin/env zsh

# 通常のgit clone後のリポジトリを、migrate-from-bare の移行後と同じ構造に変換するスクリプト
#
# 現在の構造:
#   myrepo/               (通常のgitリポジトリ、変更しない)
#   myrepo/.wt/...        (既存のlinked worktreeがあれば移行対象)
#
# 移行後の構造:
#   myrepo.wt-layout/     (新しい親ディレクトリ)
#   ├── $root/            (メインのリポジトリ、.git本体がある場所)
#   ├── feature-alpha/    (worktree 1)
#   └── hotfix-issue-12/  (worktree 2)
#
# $root というディレクトリ名はブランチ名に使えない文字($)を含むため、
# worktreeのディレクトリ名と衝突しない。
#
# 確認後に手動で:
#   rm -rf myrepo/
#   mv myrepo.wt-layout/ myrepo/

# APFS clonefile (CoW) が使えれば高速コピー、なければ通常コピーにフォールバック
# -P: シンボリックリンクを解決せずそのままコピー（node_modules等の壊れたリンクを避ける）
_cp_clone_to_worktree() {
  if cp -rcP "$1" "$2" 2>/dev/null; then
    return 0
  fi
  cp -rP "$1" "$2"
}

# ワーキングツリーをコピー（node_modules を除外）
#
# exclude_git=true の場合は .git も除外する。
# - メインのワーキングツリーコピー時に使用（後で .git ディレクトリをコピーするため）
# - 他のworktreeコピー時は false にして .git ファイルを保持する（worktree repair に必要）
_copy_worktree_to_worktree_layout() {
  local src="$1"
  local dst="$2"
  local exclude_git="${3:-false}"
  local exclude_wt="${4:-false}"
  mkdir -p "$dst"
  if command -v rsync &>/dev/null; then
    local -a excludes=('--exclude=node_modules/')
    [[ "$exclude_git" == "true" ]] && excludes+=('--exclude=.git')
    [[ "$exclude_wt" == "true" ]] && excludes+=('--exclude=.wt/')
    rsync -a "${excludes[@]}" "${src}/" "${dst}/"
    return $?
  fi

  # フォールバック: トップレベルの node_modules（と必要なら .git/.wt）のみ除外
  local item item_name
  for item in "${src}"/*(D); do
    item_name="${item:t}"
    [[ "$item_name" == "node_modules" ]] && continue
    [[ "$exclude_git" == "true" && "$item_name" == ".git" ]] && continue
    [[ "$exclude_wt" == "true" && "$item_name" == ".wt" ]] && continue
    _cp_clone_to_worktree "$item" "${dst}/${item_name}"
  done
}

migrate_clone_to_worktree() {
  # 引数があればそのディレクトリを対象にする、なければカレントリポジトリのrootを使う
  local target
  if [[ $# -gt 0 ]]; then
    target="$(realpath "$1")"
  else
    target="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [[ -z "$target" ]]; then
      print -u2 "エラー: gitリポジトリではありません"
      return 1
    fi
  fi

  # gitリポジトリかチェック
  if ! git -C "$target" rev-parse --git-dir &>/dev/null; then
    print -u2 "エラー: gitリポジトリではありません: ${target}"
    return 1
  fi

  # bare repositoryは対象外
  if [[ "$(git -C "$target" rev-parse --is-bare-repository 2>/dev/null)" == "true" ]]; then
    print -u2 "エラー: bare repositoryは対象外です。migrate_from_bare を使ってください: ${target}"
    return 1
  fi

  # linked worktree内ではなく、.git本体を持つメインリポジトリだけを対象にする
  local git_common_dir
  git_common_dir="$(git -C "$target" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  if [[ "$git_common_dir" != "${target}/.git" ]]; then
    print -u2 "エラー: linked worktreeでは実行できません。メインリポジトリで実行してください: ${target}"
    return 1
  fi

  # detached HEADチェック
  local current_branch
  current_branch="$(git -C "$target" branch --show-current 2>/dev/null)"
  if [[ -z "$current_branch" ]]; then
    print -u2 "エラー: detached HEAD状態では移行できません。先にブランチをチェックアウトしてください"
    return 1
  fi

  local parent_dir repo_name output_dir main_repo_path
  parent_dir="$(dirname "$target")"
  repo_name="$(basename "$target")"
  output_dir="${parent_dir}/${repo_name}.wt-layout"
  main_repo_path="${output_dir}/\$root"

  # 作成先が既に存在する場合はエラー
  if [[ -e "$output_dir" ]]; then
    print -u2 "エラー: 作成先が既に存在します: ${output_dir}"
    return 1
  fi

  # .wt/配下のworktreeを収集
  local -a wt_paths
  # .wt/外にあるworktreeを検出して警告用に収集
  local -a external_wt_paths
  local wt_p
  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      wt_p="${line#worktree }"
      if [[ "$wt_p" == "$target" ]]; then
        continue
      elif [[ "$wt_p" == "${target}/.wt/"* && -d "$wt_p" ]]; then
        wt_paths+=("$wt_p")
      elif [[ -d "$wt_p" ]]; then
        external_wt_paths+=("$wt_p")
      fi
    fi
  done < <(git -C "$target" worktree list --porcelain 2>/dev/null)

  print "=== 通常リポジトリからworktree構造への移行 ==="
  print ""
  print "  元のリポジトリ      : ${target}  (変更しません)"
  print "  新しい親ディレクトリ: ${output_dir}"
  print "  メインリポジトリ    : ${main_repo_path}  (${current_branch})"

  if [[ ${#wt_paths[@]} -gt 0 ]]; then
    print ""
    print "  移行するworktree:"
    for wt_p in "${wt_paths[@]}"; do
      local wt_rel="${wt_p#${target}/.wt/}"
      print "    ${wt_p}"
      print "    → ${output_dir}/${wt_rel}"
    done
  fi

  if [[ ${#external_wt_paths[@]} -gt 0 ]]; then
    print ""
    print "  ⚠ .wt/外のworktreeは移行されません（手動で対応してください）:"
    for wt_p in "${external_wt_paths[@]}"; do
      print "    ${wt_p}"
    done
  fi

  print ""

  # 未コミットの変更を警告（ブロックはしない）
  if [[ -n "$(git -C "$target" status --porcelain 2>/dev/null)" ]]; then
    print "  ⚠ 未コミットの変更があります"
    print "    変更は新しいメインリポジトリにもコピーされ、元のリポジトリにも残ります"
    print ""
  fi

  print -n "続行しますか? [y/N]: "
  read -r answer
  [[ "$answer" != "y" && "$answer" != "Y" ]] && { print "中止しました"; return 1; }
  print ""

  # [1/4] メインのワーキングツリーを作成
  print "[1/4] メインのワーキングツリーを作成中..."
  if ! _copy_worktree_to_worktree_layout "$target" "$main_repo_path" true true; then
    print -u2 "エラー: メインのワーキングツリーのコピーに失敗しました。ロールバック中..."
    rm -rf "$output_dir"
    return 1
  fi

  # [2/4] .gitディレクトリを作成
  print "[2/4] .gitディレクトリを作成中..."
  local git_dir="${main_repo_path}/.git"
  mkdir -p "$git_dir"
  local item item_name
  for item in "${target}/.git"/*(D); do
    item_name="${item:t}"
    _cp_clone_to_worktree "$item" "${git_dir}/${item_name}"
  done
  git config --file "${git_dir}/config" core.bare false
  git config --file "${git_dir}/config" --unset core.worktree 2>/dev/null || true
  git config --file "${git_dir}/config" wt.basedir ".."
  print "  ✓ core.bare = false, wt.basedir = .."

  # [3/4] 既存worktreeをコピー
  local -a new_wt_paths
  if [[ ${#wt_paths[@]} -gt 0 ]]; then
    print "[3/4] worktreeをコピー中..."
    for wt_p in "${wt_paths[@]}"; do
      local wt_rel="${wt_p#${target}/.wt/}"
      local new_wt_p="${output_dir}/${wt_rel}"
      mkdir -p "$(dirname "$new_wt_p")"
      if ! _copy_worktree_to_worktree_layout "$wt_p" "$new_wt_p"; then
        print -u2 "エラー: worktreeのコピーに失敗しました。ロールバック中..."
        rm -rf "$output_dir"
        return 1
      fi
      new_wt_paths+=("$new_wt_p")
      print "  → ${new_wt_p}"
    done
  else
    print "[3/4] 移行するworktreeなし（スキップ）"
  fi

  # [4/4] worktreeの参照を修復
  print "[4/4] worktreeの参照を修復中..."
  if [[ ${#new_wt_paths[@]} -gt 0 ]]; then
    if git -C "$main_repo_path" worktree repair "${new_wt_paths[@]}"; then
      print "  ✓ 参照修復完了"
    else
      print -u2 "  ⚠ worktree repair が失敗しました。手動で確認してください:"
      print -u2 "    git -C '${main_repo_path}' worktree repair ${new_wt_paths[*]}"
    fi
  else
    print "  スキップ（worktreeなし）"
  fi

  print ""
  print "✓ 移行完了!"
  print ""
  print "新しいリポジトリで作業を開始:"
  print "  cd ${main_repo_path}"
  print ""
  print "動作確認後、元のリポジトリと置き換えてください:"
  print "  rm -rf '${target}'"
  print "  mv '${output_dir}' '${target}'"
}
