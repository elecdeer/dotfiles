#!/usr/bin/env bash

. ~/dotfiles/util.sh

section "Start dotfiles install"

section "Install or Update Homebrew"
# https://brew.sh/
which -s brew
if [[ $? != 0 ]] ; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    brew update
    brew upgrade
fi

section "Install Basic tap and formulae"
brew tap Homebrew/bundle

section "Install Brew base formulae"
touch Brewfile-base
brew bundle --file "./Brewfile-base"

section "Install Brew app formulae"
touch Brewfile-app
brew bundle --file "./Brewfile-app"

section "Done!"
