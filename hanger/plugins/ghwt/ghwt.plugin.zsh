#!/usr/bin/env zsh

function ghwt() {
  local worktrees=$(git worktree list --porcelain | grep -E '^branch' | sed 's|branch refs/heads/||')
  local current_user=$(gh api user --jq '.login')
  
  local pr_list=$(gh pr list --json number,title,headRefName,statusCheckRollup,createdAt,author,reviewRequests)
  
  local selected_pr=$(echo "$pr_list" \
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
    local branch_name=$(echo "$pr_list" | jq -r --arg pr_num "$selected_pr" '.[] | select(.number == ($pr_num | tonumber)) | .headRefName')
    print -s "git wt \"$branch_name\""
    git wt "$branch_name"
  fi
}
