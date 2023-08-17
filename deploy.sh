#!/usr/bin/env bash

. ~/dotfiles/util.sh

section "Deploy dotfiles"

section "Create symbolic links"

ln -sfv ~/dotfiles/.zshrc ~/.zshrc
ln -sfv ~/dotfiles/config/lsd ~/.config/lsd

section "Done!"
