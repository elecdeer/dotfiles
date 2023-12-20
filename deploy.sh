#!/usr/bin/env bash

. ~/dotfiles/util.sh

section "Deploy dotfiles"

section "Create symbolic links"

ln -sfvn ~/dotfiles/.zshrc ~/.zshrc
ln -sfvn ~/dotfiles/.zprofile ~/.zprofile
ln -sfvn ~/dotfiles/config/lsd/config.yaml ~/.config/lsd/config.yaml
ln -sfvn ~/dotfiles/config/wezterm ~/.config/wezterm

section "Done!"
