#!/bin/bash
DOTFILES="$HOME/dotfiles"

# Backup existing configs
backup_dir="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# Neovim
[ -d "$HOME/.config/nvim" ] && mv "$HOME/.config/nvim" "$backup_dir/"
ln -sf "$DOTFILES/nvim" "$HOME/.config/nvim"

# Tmux
[ -f "$HOME/.tmux.conf" ] && mv "$HOME/.tmux.conf" "$backup_dir/"
ln -sf "$DOTFILES/tmux/tmux.conf" "$HOME/.tmux.conf"

## Bash
# [ -f "$HOME/.bashrc" ] && mv "$HOME/.bashrc" "$backup_dir/"
# ln -sf "$DOTFILES/bash/bashrc" "$HOME/.bashrc"

echo "✅ Dotfiles installed! Backups in $backup_dir"
