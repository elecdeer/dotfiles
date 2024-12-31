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

function git_root_directory() {
  git rev-parse --show-toplevel || echo .
}

#
# Aliases
# (sorted alphabetically by command)
# (order should follow README)
# (in some cases force the alisas order to match README, like for example gke and gk)
#

abbr grt='cd "$(git_root_directory)"'

# function ggpnp() {
#   if [[ "$#" == 0 ]]; then
#     ggl && ggp
#   else
#     ggl "${*}" && ggp "${*}"
#   fi
# }
# compdef _git ggpnp=git-checkout

abbr ggpur='ggu'
abbr g='git'
abbr ga='git add'
abbr gaa='git add --all'
abbr gapa='git add --patch'
abbr gau='git add --update'
abbr gav='git add --verbose'
abbr gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"'
abbr gam='git am'
abbr gama='git am --abort'
abbr gamc='git am --continue'
abbr gamscp='git am --show-current-patch'
abbr gams='git am --skip'
abbr gap='git apply'
abbr gapt='git apply --3way'
abbr gbs='git bisect'
abbr gbsb='git bisect bad'
abbr gbsg='git bisect good'
abbr gbsn='git bisect new'
abbr gbso='git bisect old'
abbr gbsr='git bisect reset'
abbr gbss='git bisect start'
abbr gbl='git blame -w'
abbr gb='git branch'
abbr gba='git branch --all'
abbr gbd='git branch --delete'
abbr gbD='git branch --delete --force'

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

# abbr gbgd='LANG=C git branch --no-color -vv | grep ": gone\]" | awk '"'"'{print $1}'"'"' | xargs git branch -d'
# abbr gbgD='LANG=C git branch --no-color -vv | grep ": gone\]" | awk '"'"'{print $1}'"'"' | xargs git branch -D'
abbr gbm='git branch --move'
abbr gbnm='git branch --no-merged'
abbr gbr='git branch --remote'
abbr ggsup='git branch --set-upstream-to=origin/$(git_current_branch)'
# abbr gbg='LANG=C git branch -vv | grep ": gone\]"'
abbr gco='git checkout'
abbr gcor='git checkout --recurse-submodules'
abbr gcb='git checkout -b'
abbr gcB='git checkout -B'
# abbr gcd='git checkout $(git_develop_branch)'
abbr gcd='git checkout $(git_develop_branch)'
abbr gcm='git checkout $(git_main_branch)'
abbr gcp='git cherry-pick'
abbr gcpa='git cherry-pick --abort'
abbr gcpc='git cherry-pick --continue'
abbr gclean='git clean --interactive -d'
abbr gcl='git clone --recurse-submodules'

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
# abbr gccd=''

abbr gcam='git commit --all --message'
abbr gcas='git commit --all --signoff'
abbr gcasm='git commit --all --signoff --message'
abbr gcs='git commit --gpg-sign'
abbr gcss='git commit --gpg-sign --signoff'
abbr gcssm='git commit --gpg-sign --signoff --message'
abbr gcmsg='git commit --message'
abbr gcsm='git commit --signoff --message'
abbr gc='git commit --verbose'
abbr gca='git commit --verbose --all'
abbr gca!='git commit --verbose --all --amend'
abbr gcan!='git commit --verbose --all --no-edit --amend'
abbr gcans!='git commit --verbose --all --signoff --no-edit --amend'
abbr gcann!='git commit --verbose --all --date=now --no-edit --amend'
abbr gc!='git commit --verbose --amend'
abbr gcn!='git commit --verbose --no-edit --amend'
abbr gcf='git config --list'
abbr gdct='git describe --tags $(git rev-list --tags --max-count=1)'
abbr gd='git diff'
abbr gdca='git diff --cached'
abbr gdcw='git diff --cached --word-diff'
abbr gds='git diff --staged'
abbr gdw='git diff --word-diff'

# function gdv() { git diff -w "$@" | view - }
# compdef _git gdv=git-diff

abbr gdup='git diff @{upstream}'

# function gdnolock() {
#   git diff "$@" ":(exclude)package-lock.json" ":(exclude)*.lock"
# }
# compdef _git gdnolock=git-diff

abbr gdt='git diff-tree --no-commit-id --name-only -r'
abbr gf='git fetch'
abbr gfa='git fetch --all --prune --jobs=10'
abbr gfo='git fetch origin'
abbr gg='git gui citool'
abbr gga='git gui citool --amend'
abbr ghh='git help'
abbr glgg='git log --graph'
abbr glgga='git log --graph --decorate --all'
abbr glgm='git log --graph --max-count=10'
abbr glods='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short'
abbr glod='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset"'
abbr glola='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all'
abbr glols='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat'
abbr glol='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"'
abbr glo='git log --oneline --decorate'
abbr glog='git log --oneline --decorate --graph'
abbr gloga='git log --oneline --decorate --graph --all'

# Pretty log messages
# function _git_log_prettily(){
#   if ! [ -z $1 ]; then
#     git log --pretty=$1
#   fi
# }
# compdef _git _git_log_prettily=git-log

abbr glp='_git_log_prettily'
abbr glg='git log --stat'
abbr glgp='git log --stat --patch'
abbr gignored='git ls-files -v | grep "^[[:lower:]]"'
abbr gfg='git ls-files | grep'
abbr gm='git merge'
abbr gma='git merge --abort'
abbr gmc='git merge --continue'
abbr gms "git merge --squash"
abbr gmom='git merge origin/$(git_main_branch)'
abbr gmum='git merge upstream/$(git_main_branch)'
abbr gmtl='git mergetool --no-prompt'
abbr gmtlvim='git mergetool --no-prompt --tool=vimdiff'

abbr gl='git pull'
abbr gpr='git pull --rebase'
abbr gprv='git pull --rebase -v'
abbr gpra='git pull --rebase --autostash'
abbr gprav='git pull --rebase --autostash -v'

# function ggu() {
#   [[ "$#" != 1 ]] && local b="$(git_current_branch)"
#   git pull --rebase origin "${b:=$1}"
# }
# compdef _git ggu=git-checkout
abbr ggu='git pull --rebase origin "$(git_current_branch)"'

abbr gprom='git pull --rebase origin $(git_main_branch)'
abbr gpromi='git pull --rebase=interactive origin $(git_main_branch)'
abbr ggpull='git pull origin "$(git_current_branch)"'

# function ggl() {
#   if [[ "$#" != 0 ]] && [[ "$#" != 1 ]]; then
#     git pull origin "${*}"
#   else
#     [[ "$#" == 0 ]] && local b="$(git_current_branch)"
#     git pull origin "${b:=$1}"
#   fi
# }
# compdef _git ggl=git-checkout
abbr ggl='git pull origin "$(git_current_branch)"'

abbr gluc='git pull upstream $(git_current_branch)'
abbr glum='git pull upstream $(git_main_branch)'
abbr gp='git push'
abbr gpd='git push --dry-run'

# function ggf() {
#   [[ "$#" != 1 ]] && local b="$(git_current_branch)"
#   git push --force origin "${b:=$1}"
# }
# compdef _git ggf=git-checkout
abbr ggf='git push --force origin "$(git_current_branch)"'

abbr gpf!='git push --force'
abbr gpf='git push --force-with-lease --force-if-includes'

# function ggfl() {
#   [[ "$#" != 1 ]] && local b="$(git_current_branch)"
#   git push --force-with-lease origin "${b:=$1}"
# }
# compdef _git ggfl=git-checkout
abbr ggfl='git push --force-with-lease origin "$(git_current_branch)"'

abbr gpsup='git push --set-upstream origin $(git_current_branch)'
abbr gpsupf='git push --set-upstream origin $(git_current_branch) --force-with-lease --force-if-includes'
abbr gpv='git push --verbose'
abbr gpoat='git push origin --all && git push origin --tags'
abbr gpod='git push origin --delete'
abbr ggpush='git push origin "$(git_current_branch)"'

# function ggp() {
#   if [[ "$#" != 0 ]] && [[ "$#" != 1 ]]; then
#     git push origin "${*}"
#   else
#     [[ "$#" == 0 ]] && local b="$(git_current_branch)"
#     git push origin "${b:=$1}"
#   fi
# }
# compdef _git ggp=git-checkout
abbr ggp='git push origin "$(git_current_branch)"'

abbr gpu='git push upstream'
abbr grb='git rebase'
abbr grba='git rebase --abort'
abbr grbc='git rebase --continue'
abbr grbi='git rebase --interactive'
abbr grbo='git rebase --onto'
abbr grbs='git rebase --skip'
abbr grbd='git rebase $(git_develop_branch)'
abbr grbm='git rebase $(git_main_branch)'
abbr grbom='git rebase origin/$(git_main_branch)'
abbr grf='git reflog'
abbr gr='git remote'
abbr grv='git remote --verbose'
abbr gra='git remote add'
abbr grrm='git remote remove'
abbr grmv='git remote rename'
abbr grset='git remote set-url'
abbr grup='git remote update'
abbr grh='git reset'
abbr gru='git reset --'
abbr grhh='git reset --hard'
abbr grhk='git reset --keep'
abbr grhs='git reset --soft'
abbr gpristine='git reset --hard && git clean --force -dfx'
abbr gwipe='git reset --hard && git clean --force -df'
abbr groh='git reset origin/$(git_current_branch) --hard'
abbr grs='git restore'
abbr grss='git restore --source'
abbr grst='git restore --staged'
abbr gunwip='git rev-list --max-count=1 --format="%s" HEAD | grep -q "\--wip--" && git reset HEAD~1'
abbr grev='git revert'
abbr greva='git revert --abort'
abbr grevc='git revert --continue'
abbr grm='git rm'
abbr grmc='git rm --cached'
abbr gcount='git shortlog --summary --numbered'
abbr gsh='git show'
abbr gsps='git show --pretty=short --show-signature'
abbr gstall='git stash --all'
abbr gstaa='git stash apply'
abbr gstc='git stash clear'
abbr gstd='git stash drop'
abbr gstl='git stash list'
abbr gstp='git stash pop'
abbr gsta='git stash push'
abbr gsts='git stash show --patch'
abbr gst='git status'
abbr gss='git status --short'
abbr gsb='git status --short --branch'
abbr gsi='git submodule init'
abbr gsu='git submodule update'
abbr gsd='git svn dcommit'
abbr git-svn-dcommit-push='git svn dcommit && git push github $(git_main_branch):svntrunk'
abbr gsr='git svn rebase'
abbr gsw='git switch'
abbr gswc='git switch --create'
abbr gswd='git switch $(git_develop_branch)'
abbr gswm='git switch $(git_main_branch)'
abbr gta='git tag --annotate'
abbr gts='git tag --sign'
abbr gtv='git tag | sort -V'
abbr gignore='git update-index --assume-unchanged'
abbr gunignore='git update-index --no-assume-unchanged'
abbr gwch='git whatchanged -p --abbrev-commit --pretty=medium'
abbr gwt='git worktree'
abbr gwta='git worktree add'
abbr gwtls='git worktree list'
abbr gwtmv='git worktree move'
abbr gwtrm='git worktree remove'
abbr gstu='gsta --include-untracked'
abbr gtl='gtl(){ git tag --sort=-v:refname -n --list "${1}*" }; noglob gtl'
# abbr gk='\gitk --all --branches &!'
# abbr gke='\gitk --all $(git log --walk-reflogs --pretty=%h) &!'


