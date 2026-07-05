#!/bin/bash
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

echo "Installing dotfiles..."

# niri
mkdir -p ~/.config/niri/dms
cp "$DOTFILES/config/niri/config.kdl" ~/.config/niri/
cp "$DOTFILES/config/niri/dms/"*.kdl ~/.config/niri/dms/

# DMS
mkdir -p ~/.config/DankMaterialShell
cp "$DOTFILES/config/DankMaterialShell/settings.json" ~/.config/DankMaterialShell/

# kitty
mkdir -p ~/.config/kitty
cp "$DOTFILES/config/kitty/kitty.conf" ~/.config/kitty/

# starship
cp "$DOTFILES/config/starship.toml" ~/.config/

# fish
mkdir -p ~/.config/fish
cp "$DOTFILES/config/fish/config.fish" ~/.config/fish/

# wallpapers
mkdir -p ~/Pictures/wallpaper
cp "$DOTFILES/wallpapers/"*.png ~/Pictures/wallpaper/

echo "Done! Log out and back in to apply."
