# Tmux Configuration Guide

## Installation

1. **Install tmux**  
   On Linux:  
   ```sh
   sudo apt install tmux
   ```

2. **Clone this config**  
   Symlink or copy `tmux.conf` to your home directory as `.tmux.conf`.

3. **Install TPM (Tmux Plugin Manager)**  
   ```sh
   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
   ```

4. **Start tmux**  
   ```sh
   tmux
   ```

5. **Install plugins**  
   Press `Ctrl+a` then `I` (capital i) to install plugins via TPM.

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

