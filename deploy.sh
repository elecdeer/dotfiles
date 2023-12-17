#!/usr/bin/env bash

. ~/dotfiles/util.sh

section "Deploy dotfiles"

section "Create symbolic links"

ln -sfv ~/dotfiles/.zshrc ~/.zshrc
ln -sfv ~/dotfiles/.zprofile ~/.zprofile
ln -sfv ~/dotfiles/config/lsd/config.yaml ~/.config/lsd/config.yaml
ln -sfv ~/dotfiles/config/wezterm ~/.config/wezterm

section "Done!"
