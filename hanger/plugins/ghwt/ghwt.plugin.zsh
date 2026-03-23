#!/usr/bin/env zsh

# セッション単位でキャッシュするグローバル変数
typeset -g _GHWT_CURRENT_USER

zsh-defer +12 -c "_GHWT_CURRENT_USER=$(gh api user --jq '.login')"

function ghwt() {
  # 引数が渡された場合は直接処理
  if [[ $# -gt 0 ]]; then
    local arg="$1"
    # 全て数字ならPR番号として扱う
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
      local branch_name=$(gh pr view "$arg" --json headRefName --jq '.headRefName')
      if [[ -n "$branch_name" ]]; then
        git wt "$branch_name"
      else
        echo "PR #$arg not found"
        return 1
      fi
    else
      # ブランチ名として扱う
      git wt "$arg"
    fi
    return
  fi

  local worktrees
  worktrees=$(git worktree list --porcelain | awk '/^branch refs\/heads\// { sub(/^branch refs\/heads\//, ""); print }')
  
  # セッションキャッシュを使用（まだ取得されていない場合はその場で取得）
  local current_user="${_GHWT_CURRENT_USER:-$(gh api user --jq '.login')}"
  local pr_cache_file
  pr_cache_file=$(mktemp -t ghwt-prs.XXXXXX) || return 1

  if ! gh pr list --json number,title,headRefName,statusCheckRollup,updatedAt,author,reviewRequests,additions,deletions,changedFiles,body > "$pr_cache_file"; then
    rm -f "$pr_cache_file"
    return 1
  fi

  export GHWT_PR_CACHE="$pr_cache_file"

  local selected_branch
  selected_branch=$(jq -jr --arg worktrees "$worktrees" --arg current_user "$current_user" '
      sort_by(.updatedAt) | reverse | .[] |
      .headRefName as $branch |
      (now - (.updatedAt | fromdateiso8601)) as $diff |
      (if $diff < 3600 then
        "about " + (($diff / 60 | floor | if . < 1 then 1 else . end) | tostring) + " minutes ago"
       elif $diff < 86400 then
        "about " + (($diff / 3600 | floor) | tostring) + " hours ago"
       elif $diff < 2592000 then
        "about " + (($diff / 86400 | floor) | tostring) + " days ago"
       elif $diff < 31536000 then
        "about " + (($diff / 2592000 | floor) | tostring) + " months ago"
       else
        "about " + (($diff / 31536000 | floor) | tostring) + " years ago"
       end) as $relative |
      (.statusCheckRollup // [] |
        if length == 0 then " "
        elif all(.[]; .conclusion == "SUCCESS") then "\u001b[32m✓\u001b[0m"
        elif any(.[]; .conclusion == "FAILURE") then "\u001b[31m✗\u001b[0m"
        else "\u001b[33m○\u001b[0m"
        end) as $ci |
      ((.reviewRequests // [] | map(.login) | any(. == $current_user)) as $is_reviewer |
        if $is_reviewer then " 󰭑" else "  " end) as $review_icon |
      (if ($worktrees | split("\n") | any(. == $branch)) then "\u001b[32m\u001b[0m "
       else ""
       end) as $wt_icon |
      (.number | tostring) + "\t" + $branch + "\t" +
      "\u001b[36m#" + (.number | tostring) + "\u001b[0m " + $ci + $review_icon + " " +
      "\u001b[34m" + $branch + "\u001b[0m " + $wt_icon +
      "\u001b[90m" + $relative + "\u001b[0m " +
      "\u001b[35m" + .author.login + "\u001b[0m" +
      "\n  " + .title + "\u0000"' "$pr_cache_file" |
    fzf --read0 --gap \
      --delimiter $'\t' \
      --with-nth 3.. \
      --header "Select PR" \
      --preview 'pr_num={1}; jq -r --argjson pr "$pr_num" '\''first(.[] | select(.number == $pr) | "\u001b[33m+" + (.additions | tostring) + "\u001b[0m \u001b[31m-" + (.deletions | tostring) + "\u001b[0m \u001b[90m(" + (.changedFiles | tostring) + " files)\u001b[0m")'\'' "$GHWT_PR_CACHE"; jq -r --argjson pr "$pr_num" '\''first(.[] | select(.number == $pr) | (.body // ""))'\'' "$GHWT_PR_CACHE" | bat --paging=never -l markdown --color=always --style=plain' \
      --preview-window 'right:30%:wrap' |
    head -1 |
    cut -f2)

  rm -f "$pr_cache_file"
  unset GHWT_PR_CACHE

  if [[ -n "$selected_branch" ]]; then
    print -s "git wt \"$selected_branch\""
    git wt "$selected_branch"
  fi
}
