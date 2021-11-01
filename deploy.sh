#!/usr/bin/env bash

. ~/dotfiles/util.sh

section "Deploy dotfiles"

section "Create symbolic links"
echo ".zshrc"
ln -sf ~/dotfiles/.zshrc ~/.zshrc

section "Done!"