#!/bin/bash
DOTFILES="$HOME/dotfiles"

git submodule update --init --recursive

# Backup existing configs
backup_dir="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# Neovim
{ [ -e "$HOME/.config/nvim" ] || [ -L "$HOME/.config/nvim" ]; } && mv -h "$HOME/.config/nvim" "$backup_dir/"
ln -sf "$DOTFILES/nvim" "$HOME/.config/nvim"

# Tmux
{ [ -e "$HOME/.tmux.conf" ] || [ -L "$HOME/.tmux.conf" ]; } && mv -h "$HOME/.tmux.conf" "$backup_dir/"
ln -sf "$DOTFILES/tmux.conf" "$HOME/.tmux.conf"

## Bash
# { [ -e "$HOME/.bashrc" ] || [ -L "$HOME/.bashrc" ]; } && mv -h "$HOME/.bashrc" "$backup_dir/"
# ln -sf "$DOTFILES/bash/bashrc" "$HOME/.bashrc"

echo "✅ Dotfiles installed! Backups in $backup_dir"
