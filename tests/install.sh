#!/bin/bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
export HOME="$test_dir/home"
mkdir -p "$HOME" "$test_dir/bin" "$test_dir/sys" "$test_dir/repo with spaces/nvim"
cp "$repo/install.sh" "$repo/tmux.conf" "$test_dir/repo with spaces/"

# PATH holds only stubs and basic utilities, so tools on this machine cannot leak in.
for cmd in awk bash cat chmod cp date dirname grep head ln mkdir mktemp mv readlink rm sed sort touch tr uname; do
    ln -s "$(command -v "$cmd")" "$test_dir/sys/$cmd"
done

# Stub network and tmux calls so the check cannot touch real sessions.
cat > "$test_dir/bin/git" <<'EOF'
#!/bin/bash
set -eu
if [ "$1" = clone ]; then
    mkdir -p "$3/bin"
    cat > "$3/bin/install_plugins" <<'PLUGIN'
#!/bin/bash
test "${FAIL_PLUGINS:-0}" = 0 || exit 1
touch "$HOME/plugins-installed"
PLUGIN
    chmod +x "$3/bin/install_plugins"
elif [ "$3" = rev-parse ]; then
    # Plugin checkouts sit at "head"; their pinned ref resolves elsewhere unless PIN_MATCHES=1.
    if [ "$4" = HEAD ] || [ "${PIN_MATCHES:-0}" = 1 ]; then echo head; else echo pinned; fi
else
    test "$1" = -C
    test -f "$2/install.sh"
    test "${FAIL_SUBMODULE:-0}" = 0
fi
EOF
# Like real tmux when no server is running, e.g. kill-server after TPM's server exited.
printf '#!/bin/bash\nexit 1\n' > "$test_dir/bin/tmux"
printf '#!/bin/bash\nexit 0\n' > "$test_dir/bin/nvim"
printf '#!/bin/bash\nexit 0\n' > "$test_dir/bin/fzf"
printf '#!/bin/bash\necho "glibc ${FAKE_GLIBC:-2.39}"\n' > "$test_dir/bin/getconf"
cat > "$test_dir/bin/micromamba" <<'EOF'
#!/bin/bash
set -eu
echo "$*" >> "$HOME/micromamba-calls"
while [ "$1" != -p ]; do shift; done
mkdir -p "$2/bin" "$2/conda-meta"
for arg in "$@"; do
    case "$arg" in
        ripgrep) cmds=rg ;;
        fd-find) cmds=fd ;;
        fzf | lazygit) cmds="$arg" ;;
        nodejs*) cmds="node npm npx" ;;
        tree-sitter-cli*) cmds=tree-sitter ;;
        *) continue ;;
    esac
    for cmd in $cmds; do
        printf '#!/bin/bash\necho %s\n' "$cmd" > "$2/bin/$cmd"
        chmod +x "$2/bin/$cmd"
    done
done
EOF
chmod +x "$test_dir"/bin/*
export PATH="$test_dir/bin:$test_dir/sys"
unset XDG_DATA_HOME BASH_ENV

cd "$test_dir"
bash "$test_dir/repo with spaces/install.sh"
test "$(readlink "$HOME/.tmux.conf")" = "$test_dir/repo with spaces/tmux.conf"
test "$(readlink "$HOME/.config/nvim")" = "$test_dir/repo with spaces/nvim"
test -f "$HOME/plugins-installed"

# Missing Neovim tools come from conda-forge; fzf is already on PATH and glibc 2.39+
# leaves tree-sitter to Mason.
grep -qx 'create .* ripgrep fd-find lazygit nodejs>=22' "$HOME/micromamba-calls"
for cmd in rg fd lazygit node npm npx; do
    "$HOME/.local/bin/$cmd" >/dev/null
done
test ! -e "$HOME/.local/bin/fzf"
test ! -e "$HOME/.local/bin/tree-sitter"

# A rerun must preserve configs, the existing TPM installation and installed tools.
rm "$HOME/.tmux.conf" "$HOME/.config/nvim" "$HOME/micromamba-calls"
printf 'old config\n' > "$HOME/.tmux.conf"
mkdir "$HOME/.config/nvim"
printf 'old editor\n' > "$HOME/.config/nvim/init.lua"
touch "$HOME/.tmux/plugins/tpm/keep"
bash "$test_dir/repo with spaces/install.sh"
grep -qx 'old config' "$HOME"/dotfiles_backup_*/.tmux.conf
grep -qx 'old editor' "$HOME"/dotfiles_backup_*/nvim/init.lua
test -f "$HOME/.tmux/plugins/tpm/keep"
test ! -e "$HOME/micromamba-calls"

# A plugin checkout at its pin is kept; one elsewhere is removed so TPM reinstalls it.
theme="$HOME/.tmux/plugins/tmux-tokyo-night"
mkdir -p "$theme"
PIN_MATCHES=1 bash "$test_dir/repo with spaces/install.sh"
test -d "$theme"
bash "$test_dir/repo with spaces/install.sh"
test ! -e "$theme"

# Older glibc adds the conda-forge tree-sitter and drops Mason's copy, which cannot run there.
mason="$HOME/.local/share/nvim/mason"
mkdir -p "$mason/bin" "$mason/packages/tree-sitter-cli"
printf '#!/bin/bash\nexit 1\n' > "$mason/bin/tree-sitter"
chmod +x "$mason/bin/tree-sitter"
FAKE_GLIBC=2.34 bash "$test_dir/repo with spaces/install.sh"
grep -qx 'install .* tree-sitter-cli>=0.26.1' "$HOME/micromamba-calls"
"$HOME/.local/bin/tree-sitter" --version >/dev/null
test ! -e "$mason/bin/tree-sitter"
test ! -e "$mason/packages/tree-sitter-cli"

# A rerun keeps a working tree-sitter instead of reinstalling it.
rm "$HOME/micromamba-calls"
FAKE_GLIBC=2.34 bash "$test_dir/repo with spaces/install.sh"
test ! -e "$HOME/micromamba-calls"

if FAIL_SUBMODULE=1 bash "$test_dir/repo with spaces/install.sh"; then
    echo 'Expected submodule failure to stop installation' >&2
    exit 1
fi
if FAIL_PLUGINS=1 bash "$test_dir/repo with spaces/install.sh"; then
    echo 'Expected plugin failure to stop installation' >&2
    exit 1
fi
echo 'Installer checks passed.'
