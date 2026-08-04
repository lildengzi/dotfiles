# dotfiles

[中文](./README.md)

![desktop](Docs/Pictures/desktop.png)

Personal dotfiles on CachyOS — niri + DMS + Kitty + fish + Neovim.

## What's included

| Component | Config |
|-----------|--------|
| **WM** | niri with Material You shell (DMS) |
| **Terminal** | Kitty with FantasqueSansM Nerd Font |
| **Editor** | Neovim with LazyVim, catppuccin, LSP (rust-analyzer, pyright, ruff), DAP, treesitter, rainbow-delimiters, indent-blankline |
| **File manager** | Yazi terminal file manager, editing via nvim |
| **Code editor** | VSCode with catppuccin theme + vscode-icons, autosave |
| **Prompt** | Starship powerline-style with OS detection |
| **Shell** | Fish with fastfetch alias |
| **Wallpapers** | 33 curated wallpapers |

## Screenshots

![terminal](Docs/Pictures/terminal_info.png)

![Desktop preview](Docs/Pictures/preview.gif)

### Neovim

![Neovim preview](Docs/Pictures/nvimpreview.png)

### Yazi

![Yazi preview](Docs/Pictures/yazipreview.png)

### VSCode

![VSCode preview](Docs/Pictures/vscodepreview.png)

![VSCode preview 2](Docs/Pictures/vscodepreview2.png)

![VSCode installed plugins](Docs/Pictures/vscode-used-plugin.png)

## Quick start

```bash
git clone https://github.com/lildengzi/dotfiles
cd dotfiles
bash scripts/install.sh
```

Choose from:
1. **Full desktop** — niri + DMS + Kitty + nvim + yazi + fish + starship + vscode + font
2. **Terminal + editor only** — Kitty + nvim + yazi + starship + font
3. **Pick your own** — select individual components

Each component can also be installed individually:

```bash
bash scripts/install-font.sh    # FantasqueSansM Nerd Font
bash scripts/install-kitty.sh   # Kitty terminal
bash scripts/install-nvim.sh    # Neovim (LazyVim)
bash scripts/install-yazi.sh    # Yazi file manager
bash scripts/install-niri.sh    # niri WM
bash scripts/install-fish.sh    # Fish shell
bash scripts/install-starship.sh # Starship prompt
bash scripts/install-vscode.sh  # VSCode config (install VSCode itself manually)
```

Scripts auto-detect your distro (Arch, Fedora, Debian, openSUSE),
back up existing configs, and install missing dependencies.

## Manual copy

If you only want the config files without running scripts:

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/lildengzi/dotfiles
cd dotfiles
git sparse-checkout set config/kitty config/nvim config/yazi config/vscode config/starship.toml config/fish
cp -r config/kitty ~/.config/kitty
cp -r config/nvim ~/.config/nvim
cp -r config/yazi ~/.config/yazi
mkdir -p ~/.config/Code/User && cp config/vscode/settings.json ~/.config/Code/User/
cp config/starship.toml ~/.config/
cp -r config/fish ~/.config/fish
nvim  # auto-installs plugins
```

## Prerequisites

- [FantasqueSansM Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases) (or run `scripts/install-font.sh`)
- [Neovim](https://github.com/neovim/neovim) ≥ 0.10
- [Kitty](https://sw.kovidgoyal.net/kitty/) (or use your own terminal)
- [Yazi](https://yazi-rs.github.io/) file manager
- [VSCode](https://code.visualstudio.com/) code editor
- [Starship](https://starship.rs/) prompt
- [Fish](https://fishshell.com/) shell

## Notes

- niri/DMS are optional — the terminal + editor work on any WM
- PipeWire audio config and ananicy rules are not included (machine-specific)
- Proxy configuration is not included
- Neovim config uses lazy.nvim and will auto-install all plugins on first launch
- VSCode config has machine-specific clangd path removed; add it yourself if needed
- Built on CachyOS, but should work on any distro (scripts auto-detect package manager)
