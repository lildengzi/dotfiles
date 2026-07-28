# dotfiles

![desktop](Docs/Pictures/desktop.png)

Personal dotfiles on CachyOS — niri + DMS + Kitty + fish + Neovim.

## What's included

| Component | Config |
|-----------|--------|
| **WM** | niri with Material You shell (DMS) |
| **Terminal** | Kitty with FantasqueSansM Nerd Font |
| **Editor** | Neovim with LazyVim, catppuccin, LSP (rust-analyzer, clangd, pyright, ruff), DAP, treesitter, rainbow-delimiters, indent-blankline |
| **Prompt** | Starship powerline-style with OS detection |
| **Shell** | Fish with fastfetch alias |
| **Wallpapers** | 20 curated wallpapers |

## Screenshots

![terminal](Docs/Pictures/terminal_info.png)

![Desktop preview](Docs/Pictures/preview.gif)

<video src="https://lildengzi.github.io/dotfiles/Docs/Pictures/show.mp4" controls width="600"></video>

## Quick start

```bash
git clone https://github.com/lildengzi/dotfiles
cd dotfiles
bash scripts/install.sh
```

Choose from:
1. **Full desktop** — niri + DMS + Kitty + nvim + fish + starship + font
2. **Terminal + editor only** — Kitty + nvim + starship + font
3. **Pick your own** — select individual components

Each component can also be installed individually:

```bash
bash scripts/install-font.sh    # FantasqueSansM Nerd Font
bash scripts/install-kitty.sh   # Kitty terminal
bash scripts/install-nvim.sh    # Neovim (LazyVim)
bash scripts/install-niri.sh    # niri WM
bash scripts/install-fish.sh    # Fish shell
bash scripts/install-starship.sh # Starship prompt
```

Scripts auto-detect your distro (Arch, Fedora, Debian, openSUSE),
back up existing configs, and install missing dependencies.

## Manual copy

If you only want the config files without running scripts:

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/lildengzi/dotfiles
cd dotfiles
git sparse-checkout set config/kitty config/nvim config/starship.toml config/fish
cp -r config/kitty ~/.config/kitty
cp -r config/nvim ~/.config/nvim
cp config/starship.toml ~/.config/
cp -r config/fish ~/.config/fish
nvim  # auto-installs plugins
```

## Prerequisites

- [FantasqueSansM Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases) (or run `scripts/install-font.sh`)
- [Neovim](https://github.com/neovim/neovim) ≥ 0.10
- [Kitty](https://sw.kovidgoyal.net/kitty/) (or use your own terminal)
- [Starship](https://starship.rs/) prompt
- [Fish](https://fishshell.com/) shell

## Notes

- niri/DMS are optional — the terminal + editor work on any WM
- PipeWire audio config and ananicy rules are not included (machine-specific)
- Proxy configuration is not included
- Neovim config uses lazy.nvim and will auto-install all plugins on first launch
- Built on CachyOS, but should work on any distro (scripts auto-detect package manager)
