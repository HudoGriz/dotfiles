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

# Neovim builds tree-sitter parsers with the tree-sitter CLI. LazyVim installs it
# with Mason, but that upstream binary needs glibc 2.39+, so older systems
# (e.g. RHEL 9) get the conda-forge build instead, which runs on glibc 2.17+.
glibc="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')" || true
if command -v nvim >/dev/null && [ -n "$glibc" ] &&
    [ "$(printf '%s\n' 2.39 "$glibc" | sort -V | head -n1)" != 2.39 ]; then
    if ! "$HOME/.local/bin/tree-sitter" --version >/dev/null 2>&1; then
        echo "glibc $glibc is too old for Mason's tree-sitter; installing it from conda-forge."
        mamba_tmp="$(mktemp -d)"
        trap 'rm -rf "$mamba_tmp"' EXIT
        micromamba="$(command -v micromamba || true)"
        if [ -z "$micromamba" ]; then
            curl -fsSL "https://micro.mamba.pm/api/micromamba/linux-$(uname -m | sed 's/^x86_64$/64/')/latest" |
                tar -xj -C "$mamba_tmp" bin/micromamba
            micromamba="$mamba_tmp/bin/micromamba"
        fi
        ts_prefix="$HOME/.local/opt/tree-sitter"
        rm -rf "$ts_prefix"
        "$micromamba" create -y -q -r "$mamba_tmp/root" -p "$ts_prefix" \
            -c conda-forge --override-channels 'tree-sitter-cli>=0.26.1'
        mkdir -p "$HOME/.local/bin"
        ln -sf "$ts_prefix/bin/tree-sitter" "$HOME/.local/bin/tree-sitter"
        case ":$PATH:" in
            *":$HOME/.local/bin:"*) ;;
            *) echo "Add ~/.local/bin to PATH so Neovim can find tree-sitter." >&2 ;;
        esac
    fi
    # Mason's bin dir comes first on Neovim's PATH, so drop its copy if it cannot run here.
    mason_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason"
    if { [ -e "$mason_dir/bin/tree-sitter" ] || [ -L "$mason_dir/bin/tree-sitter" ]; } &&
        ! "$mason_dir/bin/tree-sitter" --version >/dev/null 2>&1; then
        rm -rf "$mason_dir/bin/tree-sitter" "$mason_dir/packages/tree-sitter-cli"
    fi
fi

echo "✅ Dotfiles installed! Backups in $backup_dir"
echo "Start tmux, or press Ctrl+a then r in an existing session to load the plugins."
