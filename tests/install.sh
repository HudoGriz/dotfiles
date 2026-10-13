#!/bin/bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
export HOME="$test_dir/home"
mkdir -p "$HOME" "$test_dir/bin" "$test_dir/repo with spaces/nvim"
cp "$repo/install.sh" "$repo/tmux.conf" "$test_dir/repo with spaces/"

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
else
    test "$1" = -C
    test -f "$2/install.sh"
    test "${FAIL_SUBMODULE:-0}" = 0
fi
EOF
printf '#!/bin/bash\nexit 0\n' > "$test_dir/bin/tmux"
printf '#!/bin/bash\nexit 0\n' > "$test_dir/bin/nvim"
printf '#!/bin/bash\necho "glibc ${FAKE_GLIBC:-2.39}"\n' > "$test_dir/bin/getconf"
cat > "$test_dir/bin/micromamba" <<'EOF'
#!/bin/bash
set -eu
touch "$HOME/micromamba-ran"
while [ "$1" != -p ]; do shift; done
mkdir -p "$2/bin"
printf '#!/bin/bash\necho tree-sitter 0.26.9\n' > "$2/bin/tree-sitter"
chmod +x "$2/bin/tree-sitter"
EOF
chmod +x "$test_dir"/bin/*
export PATH="$test_dir/bin:$PATH"
unset XDG_DATA_HOME

cd "$test_dir"
bash "$test_dir/repo with spaces/install.sh"
test "$(readlink "$HOME/.tmux.conf")" = "$test_dir/repo with spaces/tmux.conf"
test "$(readlink "$HOME/.config/nvim")" = "$test_dir/repo with spaces/nvim"
test -f "$HOME/plugins-installed"

# A rerun must preserve configs and the existing TPM installation.
rm "$HOME/.tmux.conf" "$HOME/.config/nvim"
printf 'old config\n' > "$HOME/.tmux.conf"
mkdir "$HOME/.config/nvim"
printf 'old editor\n' > "$HOME/.config/nvim/init.lua"
touch "$HOME/.tmux/plugins/tpm/keep"
bash "$test_dir/repo with spaces/install.sh"
grep -qx 'old config' "$HOME"/dotfiles_backup_*/.tmux.conf
grep -qx 'old editor' "$HOME"/dotfiles_backup_*/nvim/init.lua
test -f "$HOME/.tmux/plugins/tpm/keep"

# glibc 2.39+ keeps Mason's tree-sitter; older glibc gets the conda-forge build
# and loses Mason's copy, which cannot run there.
test ! -e "$HOME/micromamba-ran"
mason="$HOME/.local/share/nvim/mason"
mkdir -p "$mason/bin" "$mason/packages/tree-sitter-cli"
printf '#!/bin/bash\nexit 1\n' > "$mason/bin/tree-sitter"
chmod +x "$mason/bin/tree-sitter"
FAKE_GLIBC=2.34 bash "$test_dir/repo with spaces/install.sh"
test -f "$HOME/micromamba-ran"
"$HOME/.local/bin/tree-sitter" --version >/dev/null
test ! -e "$mason/bin/tree-sitter"
test ! -e "$mason/packages/tree-sitter-cli"

# A rerun keeps a working tree-sitter instead of reinstalling it.
rm "$HOME/micromamba-ran"
FAKE_GLIBC=2.34 bash "$test_dir/repo with spaces/install.sh"
test ! -e "$HOME/micromamba-ran"

if FAIL_SUBMODULE=1 bash "$test_dir/repo with spaces/install.sh"; then
    echo 'Expected submodule failure to stop installation' >&2
    exit 1
fi
if FAIL_PLUGINS=1 bash "$test_dir/repo with spaces/install.sh"; then
    echo 'Expected plugin failure to stop installation' >&2
    exit 1
fi
echo 'Installer checks passed.'
