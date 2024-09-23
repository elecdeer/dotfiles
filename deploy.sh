#!/usr/bin/env bash

. ~/dotfiles/util.sh

section "Deploy dotfiles"

section "Create symbolic links"

ln -sfvn ~/dotfiles/.zshrc ~/.zshrc
ln -sfvn ~/dotfiles/.zprofile ~/.zprofile
ln -sfvn ~/dotfiles/.zshenv ~/.zshenv
ln -sfvn ~/dotfiles/config/lsd/config.yaml ~/.config/lsd/config.yaml
ln -sfvn ~/dotfiles/config/wezterm ~/.config/wezterm
ln -sfvn ~/dotfiles/config/git ~/.config/git
ln -sfvn ~/dotfiles/config/zeno ~/.config/zeno

section "Done!"
