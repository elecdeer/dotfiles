#!/usr/bin/env zsh

# bare repositoryから通常のworktree構造に移行するスクリプト（migrate-to-bare の逆操作）
#
# 現在の構造（bare）:
#   myrepo.git/           (bare repository、変更しない)
#   myrepo.git/.wt/main/  (HEADブランチのworktree)
#   myrepo.git/.wt/...    (その他のworktreeたち)
#
# 移行後の構造:
#   myrepo/               (新しい親ディレクトリ)
#   ├── $root/            (メインのリポジトリ、.git本体がある場所)
#   ├── feature-alpha/    (worktree 1)
#   └── hotfix-issue-12/  (worktree 2)
#
# $root というディレクトリ名はブランチ名に使えない文字($)を含むため、
# worktreeのディレクトリ名と衝突しない。
#
# 確認後に手動で:
#   rm -rf myrepo.git/

# APFS clonefile (CoW) が使えれば高速コピー、なければ通常コピーにフォールバック
# -P: シンボリックリンクを解決せずそのままコピー（node_modules等の壊れたリンクを避ける）
_cp_clone_from_bare() {
  if cp -rcP "$1" "$2" 2>/dev/null; then
    return 0
  fi
  cp -rP "$1" "$2"
}

# ワーキングツリーをコピー（.git と node_modules を除外）
# rsync が使えれば全階層の node_modules を除外、なければトップレベルのみ除外
_copy_worktree() {
  local src="$1"
  local dst="$2"
  mkdir -p "$dst"
  if command -v rsync &>/dev/null; then
    rsync -a --exclude='.git' --exclude='node_modules/' "${src}/" "${dst}/"
    return $?
  fi
  # フォールバック: トップレベルの .git と node_modules のみ除外
  local item item_name
  for item in "${src}"/*(D); do
    item_name="${item:t}"
    [[ "$item_name" == ".git" || "$item_name" == "node_modules" ]] && continue
    _cp_clone_from_bare "$item" "${dst}/${item_name}"
  done
}

migrate_from_bare() {
  # 引数があればそのディレクトリを対象にする、なければカレントディレクトリ
  local bare_dir
  if [[ $# -gt 0 ]]; then
    bare_dir="$(realpath "$1")"
  else
    bare_dir="$(pwd)"
  fi

  # bare repositoryかチェック
  if [[ "$(git -C "$bare_dir" rev-parse --is-bare-repository 2>/dev/null)" != "true" ]]; then
    print -u2 "エラー: bare repositoryではありません: ${bare_dir}"
    return 1
  fi

  # detached HEADチェック
  local current_branch
  current_branch="$(git -C "$bare_dir" symbolic-ref HEAD 2>/dev/null)"
  if [[ -z "$current_branch" ]]; then
    print -u2 "エラー: detached HEAD状態では移行できません。先にブランチをチェックアウトしてください"
    return 1
  fi
  current_branch="${current_branch#refs/heads/}"

  local parent_dir bare_name repo_name output_dir
  parent_dir="$(dirname "$bare_dir")"
  bare_name="$(basename "$bare_dir")"
  repo_name="${bare_name%.git}"  # myrepo.git → myrepo（.gitサフィックスがなければそのまま）
  output_dir="${parent_dir}/${repo_name}"

  # 作成先が既に存在する場合はエラー
  if [[ -e "$output_dir" ]]; then
    print -u2 "エラー: 作成先が既に存在します: ${output_dir}"
    return 1
  fi

  # ソースworktreeのディレクトリ名（migrate_to_bareがブランチ名で作った名前）
  local main_wt_src_name="${current_branch//\//-}"
  local main_wt_src="${bare_dir}/.wt/${main_wt_src_name}"
  # メインリポジトリは常に "$root" というディレクトリ名にする
  # ブランチ名に $ は使えないためworktreeと衝突しない
  # \$ でzshの変数展開を防ぎリテラルの $ にする
  local main_repo_path="${output_dir}/\$root"

  # .wt/配下のworktreeを収集（メインブランチのworktree以外）
  local -a other_wt_paths
  # .wt/外にあるworktreeを検出して警告用に収集
  local -a external_wt_paths
  local wt_p
  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      wt_p="${line#worktree }"
      if [[ "$wt_p" == "$bare_dir" || "$wt_p" == "$main_wt_src" ]]; then
        # bare_dir自体とメインブランチworktreeはスキップ
        continue
      elif [[ "$wt_p" == "${bare_dir}/.wt/"* && -d "$wt_p" ]]; then
        other_wt_paths+=("$wt_p")
      elif [[ -d "$wt_p" ]]; then
        external_wt_paths+=("$wt_p")
      fi
    fi
  done < <(git -C "$bare_dir" worktree list --porcelain 2>/dev/null)

  print "=== bare repository から通常構造への移行 ==="
  print ""
  print "  bare repository     : ${bare_dir}  (変更しません)"
  print "  新しい親ディレクトリ: ${output_dir}"
  print "  メインリポジトリ    : ${main_repo_path}  (${current_branch}, ソース: ${main_wt_src})"

  if [[ ! -d "$main_wt_src" ]]; then
    print "    ⚠ ソースworktreeが見つかりません: ${main_wt_src}"
    print "      空のワーキングツリーを作成します（後で git checkout が必要）"
  fi

  if [[ ${#other_wt_paths[@]} -gt 0 ]]; then
    print ""
    print "  移行するworktree:"
    for wt_p in "${other_wt_paths[@]}"; do
      local wt_rel="${wt_p#${bare_dir}/.wt/}"
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
  print -n "続行しますか? [y/N]: "
  read -r answer
  [[ "$answer" != "y" && "$answer" != "Y" ]] && { print "中止しました"; return 1; }
  print ""

  # [1/4] メインのワーキングツリーを作成
  print "[1/4] メインのワーキングツリーを作成中..."
  if [[ -d "$main_wt_src" ]]; then
    _copy_worktree "${main_wt_src}" "${main_repo_path}"
    print "  コピー元: ${main_wt_src}"
  else
    mkdir -p "$main_repo_path"
    print "  ⚠ ソースworktreeなし: ${main_wt_src}"
  fi

  # [2/4] .gitディレクトリを作成（bare_dir の中身から .wt/ を除外してコピー）
  print "[2/4] .gitディレクトリを作成中..."
  local git_dir="${main_repo_path}/.git"
  mkdir -p "$git_dir"
  for item in "${bare_dir}"/*(D); do
    item_name="${item:t}"
    # .wtディレクトリは除外（worktreeのファイルは別途配置する）
    [[ "$item_name" == ".wt" ]] && continue
    _cp_clone_from_bare "$item" "${git_dir}/${item_name}"
  done
  # non-bareリポジトリとして設定
  git config --file "${git_dir}/config" core.bare false
  # core.worktreeはデフォルト（.gitの親ディレクトリ）を使うので削除
  git config --file "${git_dir}/config" --unset core.worktree 2>/dev/null || true
  # worktreeを親ディレクトリ（my-project/）直下に作成するよう設定
  # root/ から git wt feature-xxx すると ../feature-xxx/ = my-project/feature-xxx/ に作られる
  git config --file "${git_dir}/config" wt.basedir ".."
  print "  ✓ core.bare = false, wt.basedir = .."

  # [3/4] 他のworktreeをコピー
  # mv ではなく cp にすることで bare_dir は完全にそのまま動作し続ける
  local -a new_wt_paths
  if [[ ${#other_wt_paths[@]} -gt 0 ]]; then
    print "[3/4] worktreeをコピー中..."
    for wt_p in "${other_wt_paths[@]}"; do
      local wt_rel="${wt_p#${bare_dir}/.wt/}"
      local new_wt_p="${output_dir}/${wt_rel}"
      # claude/feature のようにサブディレクトリがある場合は親を先に作成
      mkdir -p "$(dirname "$new_wt_p")"
      _copy_worktree "$wt_p" "$new_wt_p"
      new_wt_paths+=("$new_wt_p")
      print "  → ${new_wt_p}"
    done
  else
    print "[3/4] 移行するworktreeなし（スキップ）"
  fi

  # [4/4] worktreeの参照を修復
  # .git/worktrees/*/gitdir は bare_dir/.wt/.../git を指し（stale）、
  # output_dir/*/.git は bare_dir/.git/worktrees/... を指している（stale）。
  # git docs: "both moved → run repair from main worktree passing new worktree paths"
  # bare_dir 側のファイルは一切変更されない。
  print "[4/4] worktreeの参照を修復中..."
  if [[ ${#new_wt_paths[@]} -gt 0 ]]; then
    git -C "$main_repo_path" worktree repair "${new_wt_paths[@]}" 2>/dev/null || true
    print "  ✓ 参照修復完了"
  else
    print "  スキップ（worktreeなし）"
  fi

  print ""
  print "✓ 移行完了!"
  print ""
  print "新しいリポジトリで作業を開始:"
  print "  cd ${main_repo_path}"
  print ""
  print "動作確認後、元のbare repositoryを削除してください:"
  print "  rm -rf '${bare_dir}'"
}
