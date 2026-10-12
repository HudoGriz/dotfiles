# Tmux and Neovim Configuration

## Installation

1. **Install Git and tmux** (and Neovim to use the editor config).
   On Debian/Ubuntu:
   ```sh
   sudo apt install git tmux
   ```

2. **Clone and install** (requires internet access):
   ```sh
   git clone https://github.com/HudoGriz/dotfiles.git ~/dotfiles
   bash ~/dotfiles/install.sh
   ```

   The installer initializes the Neovim submodule, backs up existing configs to
   `~/dotfiles_backup_*`, links the tmux and Neovim configs, and installs TPM
   (Tmux Plugin Manager) and all configured tmux plugins. The repo can also be
   cloned elsewhere; run `install.sh` from that location. Rerunning it preserves
   existing plugin installations and installs missing plugins.

3. **Start tmux**:
   ```sh
   tmux
   ```

   If tmux is already running, press `Ctrl+a`, release, then `r` to reload the
   config and activate the installed plugins.

## Saving and restoring sessions

All shortcuts below mean press `Ctrl+a`, release, then the second key.

- **Save all sessions now:** `Ctrl+a` then `Ctrl+s`.
- **Restore all saved sessions:** `Ctrl+a` then `Ctrl+r`.
- **Automatic save:** every 15 minutes while tmux is running with a client attached.
- **Automatic restore:** when the tmux server starts, the latest saved snapshot
  is restored. A fresh installation needs a first save before it can restore anything.

To restore manually from a shell while tmux is running:

```sh
tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh
```

List restored sessions with `tmux ls` and open one with `tmux attach -t SESSION_NAME`.
Snapshots are stored in `~/.tmux/resurrect/`, outside this repository. Each user
creates their own snapshots; copying this repo does not copy saved sessions.
Restoration recreates layouts, working directories, and supported programs;
it does not resume running jobs from their previous execution state.

## Features

- **Prefix key:** `Ctrl+a` (instead of default `Ctrl+b`)
- **Pane navigation:** Use `Ctrl+h/j/k/l` to move between Vim and tmux panes (requires [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) in Vim/Neovim)
- **Splitting:** `Ctrl+a |` (vertical), `Ctrl+a -` (horizontal)
- **Copy mode:** `v` to select, `y` to copy to system clipboard
- **Mouse support:** Enabled
- **Session restore:** Automatic with tmux-resurrect and tmux-continuum

## Troubleshooting

- If plugins are not installed, check `~/.tmux/plugins/` for plugin folders.
- To reinstall plugins, press `Ctrl+a` then `I` inside tmux.
- For Vim pane navigation, ensure the Vim plugin is installed.

