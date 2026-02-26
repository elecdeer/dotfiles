#!/usr/bin/env zsh

# .wtにworktreeをおいていると、linterなどに読まれてしまい邪魔になるので、.wtのあるディレクトリをbare repositoryにして、作業は全てworktreeで行うようにする
# そのための移行スクリプト
#
# 移行の流れ:
#   myrepo/          (元のリポジトリ、変更しない)
#   myrepo.git/      (新しいbare repository)
#   myrepo.git/.wt/  (既存のworktreeを移動 + 現在のブランチのworktreeを新規作成)
#
# 確認後に手動で:
#   rm -rf myrepo/
#   mv myrepo.git/ myrepo/

# APFS clonefile (CoW) が使えれば高速コピー、なければ通常コピーにフォールバック
_cp_clone() {
  if cp -rc "$1" "$2" 2>/dev/null; then
    return 0
  fi
  cp -r "$1" "$2"
}

migrate_to_bare() {
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

  # すでにbare repositoryかチェック
  if [[ "$(git -C "$target" rev-parse --is-bare-repository 2>/dev/null)" == "true" ]]; then
    print "既にbare repositoryです: ${target}"
    return 0
  fi

  # gitリポジトリかチェック
  if ! git -C "$target" rev-parse --git-dir &>/dev/null; then
    print -u2 "エラー: gitリポジトリではありません: ${target}"
    return 1
  fi

  # detached HEADチェック
  local current_branch
  current_branch="$(git -C "$target" branch --show-current 2>/dev/null)"
  if [[ -z "$current_branch" ]]; then
    print -u2 "エラー: detached HEAD状態では移行できません。先にブランチをチェックアウトしてください"
    return 1
  fi

  local parent_dir repo_name wt_name bare_dir
  parent_dir="$(dirname "$target")"
  repo_name="$(basename "$target")"
  wt_name="${current_branch//\//-}"  # ブランチ名のスラッシュをハイフンに変換
  bare_dir="${parent_dir}/${repo_name}.git"

  # 作成先が既に存在する場合はエラー
  if [[ -e "$bare_dir" ]]; then
    print -u2 "エラー: 作成先が既に存在します: ${bare_dir}"
    return 1
  fi

  # 既存のlinked worktreeを収集（.wt/配下かつディレクトリが存在するもの）
  local -a existing_wt_paths
  local wt_p
  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      wt_p="${line#worktree }"
      if [[ "$wt_p" == "${target}/.wt/"* && -d "$wt_p" ]]; then
        existing_wt_paths+=("$wt_p")
      fi
    fi
  done < <(git -C "$target" worktree list --porcelain 2>/dev/null)

  print "=== bare repository への移行 ==="
  print ""
  print "  元のリポジトリ  : ${target}  (変更しません)"
  print "  新しいbare repo : ${bare_dir}"
  print "  新規worktree    : ${bare_dir}/.wt/${wt_name}  (${current_branch})"

  if [[ ${#existing_wt_paths[@]} -gt 0 ]]; then
    print ""
    print "  移行するlinked worktree:"
    for wt_p in "${existing_wt_paths[@]}"; do
      local wt_rel="${wt_p#${target}/}"
      print "    ${wt_p}"
      print "    → ${bare_dir}/${wt_rel}"
    done
  fi

  print ""

  # 未コミットの変更を警告（ブロックはしない）
  if [[ -n "$(git -C "$target" status --porcelain 2>/dev/null)" ]]; then
    print "  ⚠ 未コミットの変更があります"
    print "    新規worktreeはHEADのクリーンな状態で作成されます"
    print "    変更は元のリポジトリに残ります"
    print ""
  fi

  print -n "続行しますか? [y/N]: "
  read -r answer
  [[ "$answer" != "y" && "$answer" != "Y" ]] && { print "中止しました"; return 1; }
  print ""

  # [1/4] bare repositoryを作成（.git の中身を新しいディレクトリに展開）
  print "[1/4] bare repositoryを作成中..."
  mkdir -p "$bare_dir"
  _cp_clone "${target}/.git/." "${bare_dir}/"
  git -C "$bare_dir" config core.bare true
  git config --file "${bare_dir}/config" --unset core.worktree 2>/dev/null || true

  # [2/4] 既存のworktreeをコピー
  # mv ではなく cp にすることで target/ は .wt/ 含めて完全にそのまま動作し続ける
  # uncommitted な変更もコピーされるため、新旧どちらでも作業できる
  local -a new_wt_paths
  if [[ ${#existing_wt_paths[@]} -gt 0 ]]; then
    print "[2/4] 既存のlinked worktreeをコピー中..."
    for wt_p in "${existing_wt_paths[@]}"; do
      local wt_rel="${wt_p#${target}/}"
      local new_wt_p="${bare_dir}/${wt_rel}"
      mkdir -p "$(dirname "$new_wt_p")"
      _cp_clone "$wt_p" "$new_wt_p"
      new_wt_paths+=("$new_wt_p")
      print "  → ${new_wt_p}"
    done

    # [3/4] コピーしたworktreeの参照を修復
    # bare_dir/worktrees/*/gitdir は target/.wt/.../git を指し（stale）、
    # bare_dir/.wt/*/.git は target/.git/worktrees/... を指している（stale）。
    # git docs: "both moved → run repair from main worktree passing new worktree paths"
    # target/ 側のファイルは一切変更されない。
    print "[3/4] worktreeの参照を修復中..."
    git -C "$bare_dir" worktree repair "${new_wt_paths[@]}" 2>/dev/null || true
  else
    print "[2/4] 移行するlinked worktreeなし（スキップ）"
    print "[3/4] worktree修復: スキップ"
  fi

  # [4/4] 現在のブランチのworktreeを新規作成
  local main_wt_path="${bare_dir}/.wt/${wt_name}"
  print "[4/4] worktreeを作成中: .wt/${wt_name}"
  mkdir -p "${bare_dir}/.wt"
  if ! git -C "$bare_dir" worktree add "$main_wt_path" "$current_branch" 2>/dev/null; then
    print -u2 "エラー: worktreeの作成に失敗しました。ロールバック中..."
    # コピーなので bare_dir を削除するだけでよい（target/ は無傷）
    rm -rf "$bare_dir"
    return 1
  fi

  print ""
  print "✓ 移行完了!"
  print ""
  print "新しいworktreeで作業を開始:"
  print "  cd ${main_wt_path}"
  print ""
  print "動作確認後、元のリポジトリを削除してください:"
  print "  rm -rf '${target}'"
}
