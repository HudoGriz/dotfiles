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
# TPM never moves an installed plugin to a new pin, so drop checkouts that are not at theirs.
sed -n "s/^set -g @plugin '\([^'#]*\)#\([^']*\)'.*/\1 \2/p" "$DOTFILES/tmux.conf" |
    while read -r plugin ref; do
        plugin_dir="$HOME/.tmux/plugins/${plugin##*/}"
        if [ -d "$plugin_dir" ] && [ "$(git -C "$plugin_dir" rev-parse HEAD 2>/dev/null || true)" != \
            "$(git -C "$plugin_dir" rev-parse -q --verify "$ref^{commit}" 2>/dev/null || true)" ]; then
            rm -rf "$plugin_dir"
        fi
    done
# TPM reads its path from the tmux server, so run it on a private server that loads the
# new config: a server already running (or a $TMUX inherited via su) would make it abort.
# /tmp keeps the socket path short enough for Unix sockets.
tpm_tmp="$(mktemp -d /tmp/tpm.XXXXXX)"
(
    unset TMUX
    export TMUX_TMPDIR="$tpm_tmp"
    trap 'tmux kill-server 2>/dev/null || true; rm -rf "$TMUX_TMPDIR"' EXIT
    "$tpm_dir/bin/install_plugins"
)

# Neovim relies on command-line tools: ripgrep and fd for search, fzf, lazygit,
# Node.js for Copilot, and the tree-sitter CLI for parsers. Missing ones come from
# conda-forge, which needs no root and runs on glibc 2.17+.
if command -v nvim >/dev/null; then
    packages="" commands=""
    for tool in rg:ripgrep fd:fd-find fzf:fzf lazygit:lazygit 'node:nodejs>=22'; do
        cmd="${tool%%:*}"
        if ! command -v "$cmd" >/dev/null && [ ! -x "$HOME/.local/bin/$cmd" ]; then
            packages="$packages ${tool#*:}"
            commands="$commands $cmd"
        fi
    done
    case "$commands" in *node*) commands="$commands npm npx" ;; esac

    # LazyVim installs tree-sitter with Mason, but that binary needs glibc 2.39+.
    glibc="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')" || true
    old_glibc=false
    if [ -n "$glibc" ] && [ "$(printf '%s\n' 2.39 "$glibc" | sort -V | head -n1)" != 2.39 ]; then
        old_glibc=true
        if ! "$HOME/.local/bin/tree-sitter" --version >/dev/null 2>&1; then
            packages="$packages tree-sitter-cli>=0.26.1"
            commands="$commands tree-sitter"
        fi
    fi

    if [ -n "$packages" ]; then
        echo "Installing from conda-forge:$packages"
        mamba_tmp="$(mktemp -d)"
        trap 'rm -rf "$mamba_tmp"' EXIT
        micromamba="$(command -v micromamba || true)"
        if [ -z "$micromamba" ]; then
            platform="$(uname -s | sed 's/Linux/linux/; s/Darwin/osx/')-$(uname -m | sed 's/^x86_64$/64/')"
            curl -fsSL "https://micro.mamba.pm/api/micromamba/$platform/latest" |
                tar -xj -C "$mamba_tmp" bin/micromamba
            micromamba="$mamba_tmp/bin/micromamba"
        fi
        tools_prefix="$HOME/.local/opt/nvim-tools"
        if [ -d "$tools_prefix/conda-meta" ]; then action=install; else action=create; fi
        # Unquoted on purpose: package specs are separate words without spaces.
        # shellcheck disable=SC2086
        "$micromamba" "$action" -y -q -r "$mamba_tmp/root" -p "$tools_prefix" \
            -c conda-forge --override-channels $packages
        mkdir -p "$HOME/.local/bin"
        for cmd in $commands; do
            ln -sf "$tools_prefix/bin/$cmd" "$HOME/.local/bin/$cmd"
        done
        case ":$PATH:" in
            *":$HOME/.local/bin:"*) ;;
            *) echo "Add ~/.local/bin to PATH so Neovim can find these tools." >&2 ;;
        esac
    fi

    # Mason's bin dir comes first on Neovim's PATH, so drop its tree-sitter if it cannot run here.
    mason_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason"
    if $old_glibc && { [ -e "$mason_dir/bin/tree-sitter" ] || [ -L "$mason_dir/bin/tree-sitter" ]; } &&
        ! "$mason_dir/bin/tree-sitter" --version >/dev/null 2>&1; then
        rm -rf "$mason_dir/bin/tree-sitter" "$mason_dir/packages/tree-sitter-cli"
    fi
fi

echo "✅ Dotfiles installed! Backups in $backup_dir"
echo "Start tmux, or press Ctrl+a then r in an existing session to load the plugins."
