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

  local worktrees=$(git worktree list --porcelain | grep -E '^branch' | sed 's|branch refs/heads/||')
  
  # セッションキャッシュを使用（まだ取得されていない場合はその場で取得）
  local current_user="${_GHWT_CURRENT_USER:-$(gh api user --jq '.login')}"
  
  local selected_pr=$(gh pr list --json number,title,headRefName,statusCheckRollup,createdAt,author,reviewRequests \
    | jq -jr --arg worktrees "$worktrees" --arg current_user "$current_user" '
      .[] | 
      .headRefName as $branch | 
      (now - (.createdAt | fromdateiso8601)) as $diff | 
      (if $diff < 3600 then 
        ($diff / 60 | floor | tostring) + "m ago"
       elif $diff < 86400 then 
        ($diff / 3600 | floor | tostring) + "h ago"
       elif $diff < 2592000 then 
        ($diff / 86400 | floor | tostring) + "d ago"
       elif $diff < 31536000 then 
        ($diff / 2592000 | floor | tostring) + "mo ago"
       else 
        ($diff / 31536000 | floor | tostring) + "y ago"
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
      "\u001b[36m#" + (.number | tostring) + "\u001b[0m " + $ci + $review_icon + " " + 
      "\u001b[34m" + $branch + "\u001b[0m " + $wt_icon + 
      "\u001b[90m" + $relative + "\u001b[0m " + 
      "\u001b[35m" + .author.login + "\u001b[0m" + 
      "\n  " + .title + "\u0000"' \
    | fzf --read0 --gap \
      --header "Select PR" \
      --preview 'pr_num=$(echo {1} | sed "s/#//"); gh pr view $pr_num --json additions,deletions,changedFiles | jq -r "\"\\u001b[33m+\" + (.additions | tostring) + \"\\u001b[0m \\u001b[31m-\" + (.deletions | tostring) + \"\\u001b[0m \\u001b[90m(\" + (.changedFiles | tostring) + \" files)\\u001b[0m\n\""; gh pr view $pr_num --json body --jq ".body" | bat --paging=never -l markdown --color=always --style=plain' \
      --preview-window 'right:30%:wrap' \
    | head -1 \
    | sed 's/\x1b\[[0-9;]*m//g' \
    | awk '{print $1}' \
    | sed 's/#//')
  
  if [[ -n "$selected_pr" ]]; then
    local branch_name=$(gh pr view "$selected_pr" --json headRefName --jq '.headRefName')
    print -s "git wt \"$branch_name\""
    git wt "$branch_name"
  fi
}
