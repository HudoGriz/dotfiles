#!/bin/bash
set -euo pipefail

DOTFILES="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

for dependency in git tmux; do
    command -v "$dependency" >/dev/null || { echo "Install $dependency first." >&2; exit 1; }
done

git -C "$DOTFILES" submodule update --init --recursive

# Backup existing configs
backup_dir="$(mktemp -d "$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)_XXXXXX")"
mkdir -p "$HOME/.config"

# Neovim
{ [ -e "$HOME/.config/nvim" ] || [ -L "$HOME/.config/nvim" ]; } && mv "$HOME/.config/nvim" "$backup_dir/"
ln -sf "$DOTFILES/nvim" "$HOME/.config/nvim"

# Tmux
{ [ -e "$HOME/.tmux.conf" ] || [ -L "$HOME/.tmux.conf" ]; } && mv "$HOME/.tmux.conf" "$backup_dir/"
ln -sf "$DOTFILES/tmux.conf" "$HOME/.tmux.conf"

# Install TPM and every plugin declared in tmux.conf.
tpm_dir="$HOME/.tmux/plugins/tpm"
if [ ! -d "$tpm_dir" ]; then
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
fi
"$tpm_dir/bin/install_plugins"

echo "✅ Dotfiles installed! Backups in $backup_dir"
echo "Start tmux, or press Ctrl+a then r in an existing session to load the plugins."
