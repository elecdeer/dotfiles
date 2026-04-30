#!/usr/bin/env zsh

# worktree layout migrator:
#   project/              main repository
#   project.wt/<branch>/  linked worktrees

_mtpw_basedir='../{gitroot}.wt'

_mtpw_realpath() {
  realpath "$1"
}

_mtpw_copy_item() {
  if cp -rcP "$1" "$2" 2>/dev/null; then
    return 0
  fi
  cp -rP "$1" "$2"
}

_mtpw_copy_tree() {
  local src="$1"
  local dst="$2"
  shift 2
  local -a extra_excludes=("$@")

  mkdir -p "$dst"
  if command -v rsync &>/dev/null; then
    local -a excludes=('--exclude=node_modules/')
    local exclude
    for exclude in "${extra_excludes[@]}"; do
      excludes+=("--exclude=${exclude}")
    done
    rsync -a "${excludes[@]}" "${src}/" "${dst}/"
    return $?
  fi

  local item item_name exclude skipped
  for item in "${src}"/*(D); do
    item_name="${item:t}"
    [[ "$item_name" == "node_modules" ]] && continue
    skipped=false
    for exclude in "${extra_excludes[@]}"; do
      [[ "$exclude" == "${item_name}/" || "$exclude" == "$item_name" ]] && skipped=true
    done
    [[ "$skipped" == "true" ]] && continue
    _mtpw_copy_item "$item" "${dst}/${item_name}" || return 1
  done
}

_mtpw_copy_git_dir_from_bare() {
  local bare_dir="$1"
  local git_dir="$2"
  mkdir -p "$git_dir"

  local item item_name
  for item in "${bare_dir}"/*(D); do
    item_name="${item:t}"
    [[ "$item_name" == ".wt" ]] && continue
    _mtpw_copy_item "$item" "${git_dir}/${item_name}" || return 1
  done
}

_mtpw_set_main_config() {
  local main_repo="$1"
  git -C "$main_repo" config core.bare false
  git -C "$main_repo" config --unset core.worktree 2>/dev/null || true
  git -C "$main_repo" config wt.basedir "$_mtpw_basedir"
}

_mtpw_current_branch() {
  local repo="$1"
  if [[ "$(git -C "$repo" rev-parse --is-bare-repository 2>/dev/null)" == "true" ]]; then
    local ref
    ref="$(git -C "$repo" symbolic-ref HEAD 2>/dev/null)" || return 1
    print -r -- "${ref#refs/heads/}"
    return 0
  fi

  git -C "$repo" branch --show-current 2>/dev/null
}

_mtpw_backup_path() {
  local original="$1"
  local parent name stamp
  parent="$(dirname "$original")"
  name="$(basename "$original")"
  stamp="$(date +%Y%m%d%H%M%S)"
  print -r -- "${parent}/_${name}.project-wt-backup-${stamp}"
}

_mtpw_confirm() {
  local assume_yes="$1"
  [[ "$assume_yes" == "true" ]] && return 0

  print -n "続行しますか? [y/N]: "
  local answer
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" ]]
}

_mtpw_collect_linked_worktrees() {
  local repo="$1"
  shift
  local -a skip_paths=("$@")
  local -a skip_realpaths=()
  local skip_path
  for skip_path in "${skip_paths[@]}"; do
    skip_realpaths+=("$(_mtpw_realpath "$skip_path" 2>/dev/null || print -r -- "$skip_path")")
  done

  MTPW_WT_PATHS=()
  MTPW_WT_BRANCHES=()

  local wt_path="" wt_branch="" line
  local process_entry
  process_entry() {
    [[ -z "$wt_path" ]] && return 0

    local wt_real skip_real should_skip
    wt_real="$(_mtpw_realpath "$wt_path" 2>/dev/null || print -r -- "$wt_path")"
    should_skip=false
    for skip_real in "${skip_realpaths[@]}"; do
      [[ "$wt_real" == "$skip_real" ]] && should_skip=true
    done
    [[ "$should_skip" == "true" ]] && return 0
    [[ ! -d "$wt_path" ]] && return 0

    MTPW_WT_PATHS+=("$wt_path")
    MTPW_WT_BRANCHES+=("${wt_branch:-${wt_path:t}}")
  }

  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      process_entry || return 1
      wt_path="${line#worktree }"
      wt_branch=""
    elif [[ "$line" == branch\ refs/heads/* ]]; then
      wt_branch="${line#branch refs/heads/}"
    elif [[ -z "$line" ]]; then
      process_entry || return 1
      wt_path=""
      wt_branch=""
    fi
  done < <(git -C "$repo" worktree list --porcelain 2>/dev/null)
  process_entry
}

_mtpw_rebase_internal_sources() {
  local old_root="$1"
  local new_root="$2"
  local old_real new_real path_real rel i
  old_real="$old_root"
  new_real="$(_mtpw_realpath "$new_root")"

  for (( i = 1; i <= ${#MTPW_WT_PATHS[@]}; i++ )); do
    path_real="$(_mtpw_realpath "${MTPW_WT_PATHS[$i]}" 2>/dev/null || print -r -- "${MTPW_WT_PATHS[$i]}")"
    if [[ "$path_real" == "$old_real/"* ]]; then
      rel="${path_real#${old_real}/}"
      MTPW_WT_PATHS[$i]="${new_real}/${rel}"
    fi
  done
}

_mtpw_prepare_destinations() {
  local wt_dir="$1"
  local i branch dest
  typeset -A seen=()
  MTPW_NEW_WT_PATHS=()

  for (( i = 1; i <= ${#MTPW_WT_BRANCHES[@]}; i++ )); do
    branch="${MTPW_WT_BRANCHES[$i]}"
    dest="${wt_dir}/${branch}"
    if [[ -n "${seen[$dest]:-}" ]]; then
      print -u2 "エラー: worktree の移行先が重複します: ${dest}"
      return 1
    fi
    if [[ -e "$dest" ]]; then
      print -u2 "エラー: worktree の移行先が既に存在します: ${dest}"
      return 1
    fi
    seen[$dest]=1
    MTPW_NEW_WT_PATHS+=("$dest")
  done
}

_mtpw_copy_linked_worktrees() {
  local i src dest
  for (( i = 1; i <= ${#MTPW_WT_PATHS[@]}; i++ )); do
    src="${MTPW_WT_PATHS[$i]}"
    dest="${MTPW_NEW_WT_PATHS[$i]}"
    mkdir -p "$(dirname "$dest")"
    _mtpw_copy_tree "$src" "$dest" || return 1
    print "  ${src} -> ${dest}"
  done
}

_mtpw_repair_worktrees() {
  local main_repo="$1"
  if [[ ${#MTPW_NEW_WT_PATHS[@]} -eq 0 ]]; then
    print "  linked worktree なし"
    return 0
  fi

  git -C "$main_repo" worktree repair "${MTPW_NEW_WT_PATHS[@]}"
}

_mtpw_print_summary() {
  local title="$1"
  local main_repo="$2"
  local wt_dir="$3"
  local backup="$4"

  print "=== ${title} ==="
  print ""
  print "  main repo : ${main_repo}"
  print "  worktrees : ${wt_dir}"
  [[ -n "$backup" ]] && print "  backup    : ${backup}"
  if [[ ${#MTPW_WT_BRANCHES[@]} -gt 0 ]]; then
    print ""
    print "  移行する linked worktree:"
    local i
    for (( i = 1; i <= ${#MTPW_WT_BRANCHES[@]}; i++ )); do
      print "    ${MTPW_WT_PATHS[$i]} -> ${MTPW_NEW_WT_PATHS[$i]} (${MTPW_WT_BRANCHES[$i]})"
    done
  fi
  print ""
}

_mtpw_migrate_normal_repo() {
  local target="$1"
  local assume_yes="$2"

  local common_dir
  common_dir="$(git -C "$target" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  if [[ "$common_dir" != "${target}/.git" ]]; then
    print -u2 "エラー: linked worktree ではなくメインリポジトリを指定してください: ${target}"
    return 1
  fi

  local parent repo_name wt_dir backup_dir
  parent="$(dirname "$target")"
  repo_name="$(basename "$target")"
  wt_dir="${parent}/${repo_name}.wt"
  backup_dir="$(_mtpw_backup_path "$target")"

  [[ -e "$backup_dir" ]] && { print -u2 "エラー: backup が既に存在します: ${backup_dir}"; return 1; }
  [[ -e "$wt_dir" ]] && { print -u2 "エラー: worktree 置き場が既に存在します: ${wt_dir}"; return 1; }

  _mtpw_collect_linked_worktrees "$target" "$target" || return 1
  _mtpw_prepare_destinations "$wt_dir" || return 1
  _mtpw_print_summary "通常リポジトリを project.wt 構成へ移行" "$target" "$wt_dir" "$backup_dir"
  _mtpw_confirm "$assume_yes" || { print "中止しました"; return 1; }

  mv "$target" "$backup_dir" || return 1
  _mtpw_rebase_internal_sources "$target" "$backup_dir"

  print "[1/4] main repo を復元中..."
  _mtpw_copy_tree "$backup_dir" "$target" ".wt/" || return 1
  _mtpw_set_main_config "$target"

  print "[2/4] linked worktree をコピー中..."
  mkdir -p "$wt_dir"
  _mtpw_copy_linked_worktrees || return 1

  print "[3/4] worktree 参照を修復中..."
  _mtpw_repair_worktrees "$target" || return 1

  print "[4/4] 設定を確認中..."
  git -C "$target" status --porcelain >/dev/null
  print "  wt.basedir = $(git -C "$target" config wt.basedir)"
}

_mtpw_migrate_root_layout() {
  local wrapper="$1"
  local assume_yes="$2"

  local root_dir="${wrapper}/\$root"
  if [[ ! -d "$root_dir/.git" ]]; then
    print -u2 "エラー: \$root リポジトリが見つかりません: ${root_dir}"
    return 1
  fi

  local parent repo_name wt_dir backup_dir
  parent="$(dirname "$wrapper")"
  repo_name="$(basename "$wrapper")"
  wt_dir="${parent}/${repo_name}.wt"
  backup_dir="$(_mtpw_backup_path "$wrapper")"

  [[ -e "$backup_dir" ]] && { print -u2 "エラー: backup が既に存在します: ${backup_dir}"; return 1; }
  [[ -e "$wt_dir" ]] && { print -u2 "エラー: worktree 置き場が既に存在します: ${wt_dir}"; return 1; }

  _mtpw_collect_linked_worktrees "$root_dir" "$root_dir" || return 1
  _mtpw_prepare_destinations "$wt_dir" || return 1
  _mtpw_print_summary "\$root 構成を project.wt 構成へ移行" "$wrapper" "$wt_dir" "$backup_dir"
  _mtpw_confirm "$assume_yes" || { print "中止しました"; return 1; }

  mv "$wrapper" "$backup_dir" || return 1
  _mtpw_rebase_internal_sources "$wrapper" "$backup_dir"

  print "[1/4] main repo を復元中..."
  _mtpw_copy_tree "${backup_dir}/\$root" "$wrapper" || return 1
  _mtpw_set_main_config "$wrapper"

  print "[2/4] linked worktree をコピー中..."
  mkdir -p "$wt_dir"
  _mtpw_copy_linked_worktrees || return 1

  print "[3/4] worktree 参照を修復中..."
  _mtpw_repair_worktrees "$wrapper" || return 1

  print "[4/4] 設定を確認中..."
  git -C "$wrapper" status --porcelain >/dev/null
  print "  wt.basedir = $(git -C "$wrapper" config wt.basedir)"
}

_mtpw_find_bare_main_worktree() {
  local bare_dir="$1"
  local branch="$2"
  [[ -z "$branch" ]] && return 1

  local preferred_name="${branch//\//-}"
  local preferred="${bare_dir}/.wt/${preferred_name}"
  if [[ -d "$preferred" ]]; then
    print -r -- "$preferred"
    return 0
  fi

  local wt_path="" wt_branch="" line
  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      wt_path="${line#worktree }"
      wt_branch=""
    elif [[ "$line" == branch\ refs/heads/* ]]; then
      wt_branch="${line#branch refs/heads/}"
      if [[ "$wt_branch" == "$branch" && -d "$wt_path" ]]; then
        print -r -- "$wt_path"
        return 0
      fi
    fi
  done < <(git -C "$bare_dir" worktree list --porcelain 2>/dev/null)
}

_mtpw_migrate_bare_repo() {
  local bare_dir="$1"
  local assume_yes="$2"

  local branch
  branch="$(_mtpw_current_branch "$bare_dir" 2>/dev/null || true)"

  local parent bare_name repo_name main_repo wt_dir main_wt_src backup_dir
  parent="$(dirname "$bare_dir")"
  bare_name="$(basename "$bare_dir")"
  repo_name="${bare_name%.git}"
  main_repo="${parent}/${repo_name}"
  wt_dir="${parent}/${repo_name}.wt"
  main_wt_src="$(_mtpw_find_bare_main_worktree "$bare_dir" "$branch" 2>/dev/null || true)"
  backup_dir="$(_mtpw_backup_path "$bare_dir")"

  [[ -e "$main_repo" ]] && { print -u2 "エラー: main repo の作成先が既に存在します: ${main_repo}"; return 1; }
  [[ -e "$wt_dir" ]] && { print -u2 "エラー: worktree 置き場が既に存在します: ${wt_dir}"; return 1; }
  [[ -e "$backup_dir" ]] && { print -u2 "エラー: backup が既に存在します: ${backup_dir}"; return 1; }

  local -a skip_paths=("$bare_dir")
  [[ -n "$main_wt_src" ]] && skip_paths+=("$main_wt_src")
  _mtpw_collect_linked_worktrees "$bare_dir" "${skip_paths[@]}" || return 1
  _mtpw_prepare_destinations "$wt_dir" || return 1
  _mtpw_print_summary "bare repository を project.wt 構成へ移行" "$main_repo" "$wt_dir" "$backup_dir"
  print "  元 bare repository は保持し、backup としてコピーも作成します: ${backup_dir}"
  print ""
  _mtpw_confirm "$assume_yes" || { print "中止しました"; return 1; }

  print "[1/5] bare repository を backup にコピー中..."
  _mtpw_copy_tree "$bare_dir" "$backup_dir" || return 1

  print "[2/5] main repo を作成中..."
  mkdir -p "$main_repo"
  if [[ -n "$main_wt_src" ]]; then
    _mtpw_copy_tree "$main_wt_src" "$main_repo" ".git" || return 1
  fi
  _mtpw_copy_git_dir_from_bare "$bare_dir" "${main_repo}/.git" || return 1
  _mtpw_set_main_config "$main_repo"
  if [[ -z "$main_wt_src" ]]; then
    git -C "$main_repo" reset --hard "${branch:-HEAD}" >/dev/null
  fi

  print "[3/5] linked worktree をコピー中..."
  mkdir -p "$wt_dir"
  _mtpw_copy_linked_worktrees || return 1

  print "[4/5] worktree 参照を修復中..."
  _mtpw_repair_worktrees "$main_repo" || return 1

  print "[5/5] 設定を確認中..."
  git -C "$main_repo" status --porcelain >/dev/null
  print "  wt.basedir = $(git -C "$main_repo" config wt.basedir)"
}

migrate-to-project-wt() {
  local assume_yes=false
  local target_arg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)
        assume_yes=true
        ;;
      -*)
        print -u2 "Usage: migrate-to-project-wt [-y|--yes] [path]"
        return 1
        ;;
      *)
        if [[ -n "$target_arg" ]]; then
          print -u2 "Usage: migrate-to-project-wt [-y|--yes] [path]"
          return 1
        fi
        target_arg="$1"
        ;;
    esac
    shift
  done

  local target
  if [[ -n "$target_arg" ]]; then
    target="$(_mtpw_realpath "$target_arg")"
  else
    if git rev-parse --is-inside-work-tree &>/dev/null; then
      target="$(git rev-parse --show-toplevel)"
      local common_dir
      common_dir="$(git -C "$target" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
      if [[ "$common_dir" != "${target}/.git" && -d "$common_dir" ]]; then
        if [[ "${common_dir:t}" == ".git" ]]; then
          target="${common_dir:h}"
        else
          target="$common_dir"
        fi
      fi
    else
      target="$(_mtpw_realpath "$(pwd)")"
    fi
  fi

  if [[ ! -e "$target" ]]; then
    print -u2 "エラー: 対象が存在しません: ${target}"
    return 1
  fi

  if [[ "$(basename "$target")" == "\$root" ]]; then
    _mtpw_migrate_root_layout "$(dirname "$target")" "$assume_yes"
    return $?
  fi

  if [[ -d "${target}/\$root/.git" ]]; then
    _mtpw_migrate_root_layout "$target" "$assume_yes"
    return $?
  fi

  if [[ "$(git -C "$target" rev-parse --is-bare-repository 2>/dev/null)" == "true" ]]; then
    _mtpw_migrate_bare_repo "$target" "$assume_yes"
    return $?
  fi

  if git -C "$target" rev-parse --git-dir &>/dev/null; then
    _mtpw_migrate_normal_repo "$target" "$assume_yes"
    return $?
  fi

  print -u2 "エラー: git repository ではありません: ${target}"
  return 1
}
