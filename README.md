# niri dotfiles

![desktop](Docs/Pictures/desktop.png)

A niri + DMS desktop configuration on CachyOS.

## What's included

| Component | Config |
|-----------|--------|
| **WM** | niri 26.04 with Material You shell (DMS) |
| **Terminal** | Kitty 0.47 with FantasqueSansM Nerd Font |
| **Editor** | Neovim with LazyVim, catppuccin, LSP (rust-analyzer, clangd, pyright, ruff), DAP, treesitter, rainbow-delimiters, indent-blankline |
| **Prompt** | Starship powerline-style with OS detection |
| **Shell** | Fish with fastfetch alias |
| **Wallpapers** | 20 curated wallpapers |

## Screenshots

![terminal](Docs/Pictures/terminal_info.png)

![Desktop preview](Docs/Pictures/preview.gif)

<video src="https://lildengzi.github.io/dotfiles/Docs/Pictures/show.mp4" controls width="600"></video>

## Install

```bash
git clone https://github.com/lildengzi/dotfiles
cd dotfiles
bash install.sh
```

Restart your session after installation.

## Only want the terminal & editor?

Sparse checkout — only pull what you need:

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/lildengzi/dotfiles
cd dotfiles
git sparse-checkout set config/kitty config/nvim config/starship.toml config/fish
cp -r config/kitty ~/.config/kitty
cp -r config/nvim ~/.config/nvim
cp config/starship.toml ~/.config/
cp -r config/fish ~/.config/fish
nvim  # auto-installs plugins on first launch
```

Make sure you have the required fonts and tools installed:
- [FantasqueSansM Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases)
- [Neovim](https://github.com/neovim/neovim) ≥ 0.10
- [Kitty](https://sw.kovidgoyal.net/kitty/) or keep your own terminal
- [Starship](https://starship.rs/) prompt
- [Fish](https://fishshell.com/) shell

## Notes

- Requires niri Wayland compositor and DMS (not needed if you only take terminal/editor)
- PipeWire audio config and ananicy rules are not included (machine-specific)
- Proxy configuration is not included
- Neovim config uses lazy.nvim and will auto-install all plugins on first launch
- Built on CachyOS, but should work on any Arch-based distro
