#!/usr/bin/env bash

. ~/dotfiles/util.sh

section "Start dotfiles install"

section "Install or Update Homebrew"
which -s brew
if [[ $? != 0 ]] ; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
else
    brew update
    brew upgrade
fi

section "Install Git"
which -s git
if [[ $? != 0 ]] ; then
    brew install git
fi

section "Install Basic tap and formulae"
brew tap Homebrew/bundle
brew install mas

section "Install Brew cli formulae"
touch Brewfile-cli
brew bundle --file "./Brewfile-cli"

section "Install Brew app formulae"
touch Brewfile-app
brew bundle --file "./Brewfile-app"

section "Done!"
