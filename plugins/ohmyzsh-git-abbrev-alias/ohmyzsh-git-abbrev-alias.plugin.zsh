# original: https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/git/git.plugin.zsh
# 

# https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/git.zsh#L149-L162
function git_current_branch() {
  local ref
  ref=$(git symbolic-ref --quiet HEAD 2> /dev/null)
  local ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && return  # no git repo.
    ref=$(git rev-parse --short HEAD 2> /dev/null) || return
  fi
  echo ${ref#refs/heads/}
}

# Check for develop and similarly named branches
function git_develop_branch() {
  command git rev-parse --git-dir &>/dev/null || return
  local branch
  for branch in dev devel develop development; do
    if command git show-ref -q --verify refs/heads/$branch; then
      echo $branch
      return 0
    fi
  done

  echo develop
  return 1
}

# Check if main exists and use instead of master
function git_main_branch() {
  command git rev-parse --git-dir &>/dev/null || return
  local ref
  for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,mainline,default,master}; do
    if command git show-ref -q --verify $ref; then
      echo ${ref:t}
      return 0
    fi
  done

  # If no main branch was found, fall back to master but return error
  echo master
  return 1
}

function grename() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: $0 old_branch new_branch"
    return 1
  fi

  # Rename branch locally
  git branch -m "$1" "$2"
  # Rename branch in origin remote
  if git push origin :"$1"; then
    git push --set-upstream origin "$2"
  fi
}

#
# Functions Work in Progress (WIP)
# (sorted alphabetically by function name)
# (order should follow README)
#

# Similar to `gunwip` but recursive "Unwips" all recent `--wip--` commits not just the last one
function gunwipall() {
  local _commit=$(git log --grep='--wip--' --invert-grep --max-count=1 --format=format:%H)

  # Check if a commit without "--wip--" was found and it's not the same as HEAD
  if [[ "$_commit" != "$(git rev-parse HEAD)" ]]; then
    git reset $_commit || return 1
  fi
}

# Warn if the current branch is a WIP
function work_in_progress() {
  command git -c log.showSignature=false log -n 1 2>/dev/null | grep -q -- "--wip--" && echo "WIP!!"
}

#
# Aliases
# (sorted alphabetically by command)
# (order should follow README)
# (in some cases force the alisas order to match README, like for example gke and gk)
#

abbrev-alias -ce grt='cd "$(git rev-parse --show-toplevel || echo .)"'

# function ggpnp() {
#   if [[ "$#" == 0 ]]; then
#     ggl && ggp
#   else
#     ggl "${*}" && ggp "${*}"
#   fi
# }
# compdef _git ggpnp=git-checkout

abbrev-alias -c ggpur='ggu'
abbrev-alias -c g='git'
abbrev-alias -c ga='git add'
abbrev-alias -c gaa='git add --all'
abbrev-alias -c gapa='git add --patch'
abbrev-alias -c gau='git add --update'
abbrev-alias -c gav='git add --verbose'
abbrev-alias -c gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"'
abbrev-alias -c gam='git am'
abbrev-alias -c gama='git am --abort'
abbrev-alias -c gamc='git am --continue'
abbrev-alias -c gamscp='git am --show-current-patch'
abbrev-alias -c gams='git am --skip'
abbrev-alias -c gap='git apply'
abbrev-alias -c gapt='git apply --3way'
abbrev-alias -c gbs='git bisect'
abbrev-alias -c gbsb='git bisect bad'
abbrev-alias -c gbsg='git bisect good'
abbrev-alias -c gbsn='git bisect new'
abbrev-alias -c gbso='git bisect old'
abbrev-alias -c gbsr='git bisect reset'
abbrev-alias -c gbss='git bisect start'
abbrev-alias -c gbl='git blame -w'
abbrev-alias -c gb='git branch'
abbrev-alias -c gba='git branch --all'
abbrev-alias -c gbd='git branch --delete'
abbrev-alias -c gbD='git branch --delete --force'

function gbda() {
  git branch --no-color --merged | command grep -vE "^([+*]|\s*($(git_main_branch)|$(git_develop_branch))\s*$)" | command xargs git branch --delete 2>/dev/null
}

# Copied and modified from James Roeder (jmaroeder) under MIT License
# https://github.com/jmaroeder/plugin-git/blob/216723ef4f9e8dde399661c39c80bdf73f4076c4/functions/gbda.fish
function gbds() {
  local default_branch=$(git_main_branch)
  (( ! $? )) || default_branch=$(git_develop_branch)

  git for-each-ref refs/heads/ "--format=%(refname:short)" | \
    while read branch; do
      local merge_base=$(git merge-base $default_branch $branch)
      if [[ $(git cherry $default_branch $(git commit-tree $(git rev-parse $branch\^{tree}) -p $merge_base -m _)) = -* ]]; then
        git branch -D $branch
      fi
    done
}

# abbrev-alias -ce gbgd='LANG=C git branch --no-color -vv | grep ": gone\]" | awk '"'"'{print $1}'"'"' | xargs git branch -d'
# abbrev-alias -ce gbgD='LANG=C git branch --no-color -vv | grep ": gone\]" | awk '"'"'{print $1}'"'"' | xargs git branch -D'
abbrev-alias -c gbm='git branch --move'
abbrev-alias -c gbnm='git branch --no-merged'
abbrev-alias -c gbr='git branch --remote'
abbrev-alias -ce ggsup='git branch --set-upstream-to=origin/$(git_current_branch)'
# abbrev-alias -ce gbg='LANG=C git branch -vv | grep ": gone\]"'
abbrev-alias -c gco='git checkout'
abbrev-alias -c gcor='git checkout --recurse-submodules'
abbrev-alias -c gcb='git checkout -b'
abbrev-alias -c gcB='git checkout -B'
abbrev-alias -ce gcd='git checkout $(git_develop_branch)'
abbrev-alias -ce gcm='git checkout $(git_main_branch)'
abbrev-alias -c gcp='git cherry-pick'
abbrev-alias -c gcpa='git cherry-pick --abort'
abbrev-alias -c gcpc='git cherry-pick --continue'
abbrev-alias -c gclean='git clean --interactive -d'
abbrev-alias -c gcl='git clone --recurse-submodules'

# function gccd() {
#   setopt localoptions extendedglob

#   # get repo URI from args based on valid formats: https://git-scm.com/docs/git-clone#URLS
#   local repo="${${@[(r)(ssh://*|git://*|ftp(s)#://*|http(s)#://*|*@*)(.git/#)#]}:-$_}"

#   # clone repository and exit if it fails
#   command git clone --recurse-submodules "$@" || return

#   # if last arg passed was a directory, that's where the repo was cloned
#   # otherwise parse the repo URI and use the last part as the directory
#   [[ -d "$_" ]] && cd "$_" || cd "${${repo:t}%.git/#}"
# }
# compdef _git gccd=git-clone
# abbrev-alias -c gccd=''

abbrev-alias -c gcam='git commit --all --message'
abbrev-alias -c gcas='git commit --all --signoff'
abbrev-alias -c gcasm='git commit --all --signoff --message'
abbrev-alias -c gcs='git commit --gpg-sign'
abbrev-alias -c gcss='git commit --gpg-sign --signoff'
abbrev-alias -c gcssm='git commit --gpg-sign --signoff --message'
abbrev-alias -c gcmsg='git commit --message'
abbrev-alias -c gcsm='git commit --signoff --message'
abbrev-alias -c gc='git commit --verbose'
abbrev-alias -c gca='git commit --verbose --all'
abbrev-alias -c gca!='git commit --verbose --all --amend'
abbrev-alias -c gcan!='git commit --verbose --all --no-edit --amend'
abbrev-alias -c gcans!='git commit --verbose --all --signoff --no-edit --amend'
abbrev-alias -c gcann!='git commit --verbose --all --date=now --no-edit --amend'
abbrev-alias -c gc!='git commit --verbose --amend'
abbrev-alias -c gcn!='git commit --verbose --no-edit --amend'
abbrev-alias -c gcf='git config --list'
abbrev-alias -ce gdct='git describe --tags $(git rev-list --tags --max-count=1)'
abbrev-alias -c gd='git diff'
abbrev-alias -c gdca='git diff --cached'
abbrev-alias -c gdcw='git diff --cached --word-diff'
abbrev-alias -c gds='git diff --staged'
abbrev-alias -c gdw='git diff --word-diff'

# function gdv() { git diff -w "$@" | view - }
# compdef _git gdv=git-diff

abbrev-alias -ce gdup='git diff @{upstream}'

# function gdnolock() {
#   git diff "$@" ":(exclude)package-lock.json" ":(exclude)*.lock"
# }
# compdef _git gdnolock=git-diff

abbrev-alias -c gdt='git diff-tree --no-commit-id --name-only -r'
abbrev-alias -c gf='git fetch'
abbrev-alias -c gfa='git fetch --all --prune --jobs=10'
abbrev-alias -c gfo='git fetch origin'
abbrev-alias -c gg='git gui citool'
abbrev-alias -c gga='git gui citool --amend'
abbrev-alias -c ghh='git help'
abbrev-alias -c glgg='git log --graph'
abbrev-alias -c glgga='git log --graph --decorate --all'
abbrev-alias -c glgm='git log --graph --max-count=10'
abbrev-alias -c glods='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short'
abbrev-alias -c glod='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset"'
abbrev-alias -c glola='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all'
abbrev-alias -c glols='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat'
abbrev-alias -c glol='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"'
abbrev-alias -c glo='git log --oneline --decorate'
abbrev-alias -c glog='git log --oneline --decorate --graph'
abbrev-alias -c gloga='git log --oneline --decorate --graph --all'

# Pretty log messages
# function _git_log_prettily(){
#   if ! [ -z $1 ]; then
#     git log --pretty=$1
#   fi
# }
# compdef _git _git_log_prettily=git-log

abbrev-alias -c glp='_git_log_prettily'
abbrev-alias -c glg='git log --stat'
abbrev-alias -c glgp='git log --stat --patch'
abbrev-alias -c gignored='git ls-files -v | grep "^[[:lower:]]"'
abbrev-alias -c gfg='git ls-files | grep'
abbrev-alias -c gm='git merge'
abbrev-alias -c gma='git merge --abort'
abbrev-alias -c gmc='git merge --continue'
abbrev-alias -c gms "git merge --squash"
abbrev-alias -c gmom='git merge origin/$(git_main_branch)'
abbrev-alias -c gmum='git merge upstream/$(git_main_branch)'
abbrev-alias -c gmtl='git mergetool --no-prompt'
abbrev-alias -c gmtlvim='git mergetool --no-prompt --tool=vimdiff'

abbrev-alias -c gl='git pull'
abbrev-alias -c gpr='git pull --rebase'
abbrev-alias -c gprv='git pull --rebase -v'
abbrev-alias -c gpra='git pull --rebase --autostash'
abbrev-alias -c gprav='git pull --rebase --autostash -v'

# function ggu() {
#   [[ "$#" != 1 ]] && local b="$(git_current_branch)"
#   git pull --rebase origin "${b:=$1}"
# }
# compdef _git ggu=git-checkout
abbrev-alias -ce ggu='git pull --rebase origin "$(git_current_branch)"'

abbrev-alias -ce gprom='git pull --rebase origin $(git_main_branch)'
abbrev-alias -ce gpromi='git pull --rebase=interactive origin $(git_main_branch)'
abbrev-alias -ce ggpull='git pull origin "$(git_current_branch)"'

# function ggl() {
#   if [[ "$#" != 0 ]] && [[ "$#" != 1 ]]; then
#     git pull origin "${*}"
#   else
#     [[ "$#" == 0 ]] && local b="$(git_current_branch)"
#     git pull origin "${b:=$1}"
#   fi
# }
# compdef _git ggl=git-checkout
abbrev-alias -ce ggl='git pull origin "$(git_current_branch)"'

abbrev-alias -ce gluc='git pull upstream $(git_current_branch)'
abbrev-alias -ce glum='git pull upstream $(git_main_branch)'
abbrev-alias -c gp='git push'
abbrev-alias -c gpd='git push --dry-run'

# function ggf() {
#   [[ "$#" != 1 ]] && local b="$(git_current_branch)"
#   git push --force origin "${b:=$1}"
# }
# compdef _git ggf=git-checkout
abbrev-alias -ce ggf='git push --force origin "$(git_current_branch)"'

abbrev-alias -c gpf!='git push --force'
abbrev-alias -c gpf='git push --force-with-lease --force-if-includes'

# function ggfl() {
#   [[ "$#" != 1 ]] && local b="$(git_current_branch)"
#   git push --force-with-lease origin "${b:=$1}"
# }
# compdef _git ggfl=git-checkout
abbrev-alias -ce ggfl='git push --force-with-lease origin "$(git_current_branch)"'

abbrev-alias -ce gpsup='git push --set-upstream origin $(git_current_branch)'
abbrev-alias -ce gpsupf='git push --set-upstream origin $(git_current_branch) --force-with-lease --force-if-includes'
abbrev-alias -c gpv='git push --verbose'
abbrev-alias -c gpoat='git push origin --all && git push origin --tags'
abbrev-alias -c gpod='git push origin --delete'
abbrev-alias -ce ggpush='git push origin "$(git_current_branch)"'

# function ggp() {
#   if [[ "$#" != 0 ]] && [[ "$#" != 1 ]]; then
#     git push origin "${*}"
#   else
#     [[ "$#" == 0 ]] && local b="$(git_current_branch)"
#     git push origin "${b:=$1}"
#   fi
# }
# compdef _git ggp=git-checkout
abbrev-alias -ce ggp='git push origin "$(git_current_branch)"'

abbrev-alias -c gpu='git push upstream'
abbrev-alias -c grb='git rebase'
abbrev-alias -c grba='git rebase --abort'
abbrev-alias -c grbc='git rebase --continue'
abbrev-alias -c grbi='git rebase --interactive'
abbrev-alias -c grbo='git rebase --onto'
abbrev-alias -c grbs='git rebase --skip'
abbrev-alias -ce grbd='git rebase $(git_develop_branch)'
abbrev-alias -ce grbm='git rebase $(git_main_branch)'
abbrev-alias -ce grbom='git rebase origin/$(git_main_branch)'
abbrev-alias -c grf='git reflog'
abbrev-alias -c gr='git remote'
abbrev-alias -c grv='git remote --verbose'
abbrev-alias -c gra='git remote add'
abbrev-alias -c grrm='git remote remove'
abbrev-alias -c grmv='git remote rename'
abbrev-alias -c grset='git remote set-url'
abbrev-alias -c grup='git remote update'
abbrev-alias -c grh='git reset'
abbrev-alias -c gru='git reset --'
abbrev-alias -c grhh='git reset --hard'
abbrev-alias -c grhk='git reset --keep'
abbrev-alias -c grhs='git reset --soft'
abbrev-alias -c gpristine='git reset --hard && git clean --force -dfx'
abbrev-alias -c gwipe='git reset --hard && git clean --force -df'
abbrev-alias -c groh='git reset origin/$(git_current_branch) --hard'
abbrev-alias -c grs='git restore'
abbrev-alias -c grss='git restore --source'
abbrev-alias -c grst='git restore --staged'
abbrev-alias -c gunwip='git rev-list --max-count=1 --format="%s" HEAD | grep -q "\--wip--" && git reset HEAD~1'
abbrev-alias -c grev='git revert'
abbrev-alias -c greva='git revert --abort'
abbrev-alias -c grevc='git revert --continue'
abbrev-alias -c grm='git rm'
abbrev-alias -c grmc='git rm --cached'
abbrev-alias -c gcount='git shortlog --summary --numbered'
abbrev-alias -c gsh='git show'
abbrev-alias -c gsps='git show --pretty=short --show-signature'
abbrev-alias -c gstall='git stash --all'
abbrev-alias -c gstaa='git stash apply'
abbrev-alias -c gstc='git stash clear'
abbrev-alias -c gstd='git stash drop'
abbrev-alias -c gstl='git stash list'
abbrev-alias -c gstp='git stash pop'
abbrev-alias -c gsta='git stash push'
abbrev-alias -c gsts='git stash show --patch'
abbrev-alias -c gst='git status'
abbrev-alias -c gss='git status --short'
abbrev-alias -c gsb='git status --short --branch'
abbrev-alias -c gsi='git submodule init'
abbrev-alias -c gsu='git submodule update'
abbrev-alias -c gsd='git svn dcommit'
abbrev-alias -ce git-svn-dcommit-push='git svn dcommit && git push github $(git_main_branch):svntrunk'
abbrev-alias -c gsr='git svn rebase'
abbrev-alias -c gsw='git switch'
abbrev-alias -c gswc='git switch --create'
abbrev-alias -ce gswd='git switch $(git_develop_branch)'
abbrev-alias -ce gswm='git switch $(git_main_branch)'
abbrev-alias -c gta='git tag --annotate'
abbrev-alias -c gts='git tag --sign'
abbrev-alias -c gtv='git tag | sort -V'
abbrev-alias -c gignore='git update-index --assume-unchanged'
abbrev-alias -c gunignore='git update-index --no-assume-unchanged'
abbrev-alias -c gwch='git whatchanged -p --abbrev-commit --pretty=medium'
abbrev-alias -c gwt='git worktree'
abbrev-alias -c gwta='git worktree add'
abbrev-alias -c gwtls='git worktree list'
abbrev-alias -c gwtmv='git worktree move'
abbrev-alias -c gwtrm='git worktree remove'
abbrev-alias -c gstu='gsta --include-untracked'
abbrev-alias -c gtl='gtl(){ git tag --sort=-v:refname -n --list "${1}*" }; noglob gtl'
# abbrev-alias -c gk='\gitk --all --branches &!'
# abbrev-alias -c gke='\gitk --all $(git log --walk-reflogs --pretty=%h) &!'


