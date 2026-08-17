# dotfiles

[中文](./README.md)

![desktop](Docs/Pictures/desktop.png)

Personal dotfiles on Linux (Arch-based) — niri + DMS + Kitty + fish + Neovim.
The repo's `.config/` is the actual `~/.config` tree in use.

## What's included

| Component | Config |
|-----------|--------|
| **WM** | niri with Material You shell (DMS) |
| **Terminal** | Kitty (dank theme), FantasqueSansM Nerd Font |
| **Editor** | Neovim + LazyVim, catppuccin, LSP (rust-analyzer, pyright, ruff), DAP, treesitter, rainbow-delimiters, indent-blankline |
| **File manager** | Yazi terminal file manager, editing via nvim, in-terminal video preview |
| **Code editor** | Zed (VSCode config is cloud-synced, not in repo) |
| **Prompt** | Starship (GUI / TTY / bash presets) |
| **Shell** | Fish with fastfetch alias |
| **Desktop tools** | fastfetch, mpv, btop, cava, MangoHud, GTK/fontconfig, env & autostart |
| **Wallpapers** | 33 curated wallpapers |

## Screenshots

![terminal](Docs/Pictures/terminal_info.png)

![Desktop preview](Docs/Pictures/preview.gif)

### Neovim

![Neovim preview](Docs/Pictures/nvimpreview.png)

### Yazi

![Yazi preview](Docs/Pictures/yazipreview.png)

## Quick start

One-liner (downloads and launches the installer):

```sh
curl -fsSL https://raw.githubusercontent.com/lildengzi/dotfiles/master/scripts/bootstrap.sh | sh
```

Or clone locally:

```sh
git clone https://github.com/lildengzi/dotfiles
cd dotfiles
sh scripts/install.sh
```

Choose from:
1. **Desktop** — desktop appearance (niri + DMS + wallpapers + autostart + appearance)
2. **Work** — dev environment (nvim + yazi + kitty + fish + starship + terminal tools + fonts + JDK)
3. **Agent** — AI agent toolchain (opencode + skills + claude + npm globals)
4. **Packages** — system software (per category)
5. **VMs** — VM restore (winboat / distrobox / waydroid / AVD / OSX-KVM / podman)

Each component can also be installed individually (all scripts are POSIX sh, no bash needed):

```sh
sh scripts/install-config.sh   # copy the whole .config (no software)
sh scripts/install-font.sh    # FantasqueSansM Nerd Font
sh scripts/install-kitty.sh   # Kitty terminal
sh scripts/install-nvim.sh    # Neovim (LazyVim)
sh scripts/install-yazi.sh    # Yazi file manager
sh scripts/install-niri.sh    # niri WM
sh scripts/install-fish.sh    # Fish shell
sh scripts/install-starship.sh # Starship prompt
sh scripts/install-packages.sh # install packages by category (e.g. sh install-packages.sh desktop aur)
```

Scripts auto-detect your distro (Arch, Fedora, Debian, openSUSE) and pick the right package manager,
back up existing configs, and install missing dependencies (non-Arch not fully guaranteed).

## Disaster recovery

Reinstall lost your machine? Restore step by step:

**1. Install packages (by category)**

```sh
git clone https://github.com/lildengzi/dotfiles
cd dotfiles
sh scripts/install-packages.sh system drivers cachyos desktop third-party
sh scripts/install-packages.sh aur        # requires paru
sh scripts/install-agent-tools.sh         # agent npm globals (codex, etc.)
```

`packages/` holds 7 categorized lists: system / desktop / drivers / cachyos / third-party / aur / toolchain.

> Note: the cachyos list includes CachyOS repo packages (e.g. `linux-cachyos`).
> On a clean Arch install, install and enable [cachyos-mirrorlist](https://github.com/CachyOS/CachyOS-PKGBUILDS/tree/master/cachyos-mirrorlist)
> first, or replace `linux-cachyos` with the stock Arch kernel.

**2. Install configs (nested menu)**

```sh
sh scripts/install.sh
```

Choose Desktop / Work / Agent; every sub-item can be toggled individually.

**3. Restore VMs (big data lives in `/mnt/E/Rescue`)**

```sh
sh scripts/restore/winboat.sh    # Windows VM (config + data)
sh scripts/restore/distrobox.sh  # recreate 5 distrobox containers
sh scripts/restore/waydroid.sh   # waydroid
sh scripts/restore/avd.sh        # Android emulator
sh scripts/restore/osx-kvm.sh    # macOS VM
sh scripts/restore/podman.sh     # podman containers
```

Small configs live in `vms/`, big data is copied from `/mnt/E/Rescue`.

**4. Machine hardware overlay (this host only)**

```sh
sh scripts/apply-machine.sh      # writes HDMI-A-1 etc. only on lildengzi-cachyos
```

## Updating package lists

```sh
pacman -Qqe | sort > packages/system.txt   # sort into categories manually
pacman -Qqm > packages/aur.txt             # AUR packages
```

## What makes this different

- **Decoupled install** — Desktop / Work / Agent, each with individually toggleable sub-items, no hard coupling
- **Categorized package lists** — 7 categories under `packages/`, install what you need
- **Agent toolchain recorded separately** — npm globals like codex live in `packages/toolchain.txt`, restored via `install-agent-tools.sh`
- **POSIX sh install scripts** — every `scripts/*.sh` is pure sh, no bash dependency, runnable on any distro
- **fish `fetch` fallback** — `ff` = `fastfetch`; if fastfetch is missing, the `fetch` command degrades gracefully instead of failing distrobox/SSH startup
- **SSH / container auto-detection** — fish switches to a conservative ASCII prompt over SSH/TTY/containers, so desktop/GPU assumptions don't leak into remote environments
- **CUDA path injection** — `CUDA_HOME` is only set on the host when `/opt/cuda` + DankMaterialShell are present; cleaned up automatically in SSH/containers
- **distrobox stability fixes** — retries with `--root` when the container lacks a passwd entry, and with `--no-tty` on tty allocation failure
- **In-terminal video preview in Yazi** — `mpv --vo=kitty` previews videos right in the file manager, no separate window
- **Kitty muted theme** — bundled `dank-tabs.conf` / `dank-theme.conf` (slanted powerline tabs + grey-purple palette), with CJK font fallback
- **niri recording shortcuts** — `Mod+Alt+R` start / `Mod+Alt+Shift+R` stop recording
- **Wallpapers auto-installed** — `install-walls.sh` copies them to `~/Pictures/wallpapers`, referenced by DMS
- **Generic hardware configs** — `outputs.kdl` stays generic; host-specific bits are applied by `apply-machine.sh`

## Manual copy

The repo's `.config/` is a ready-to-use `~/.config` tree — copy it straight over:

```sh
git clone --depth 1 https://github.com/lildengzi/dotfiles
cd dotfiles
cp -r .config/* ~/.config/   # merge into your ~/.config
nvim  # auto-installs plugins
```

Want only some components? Use sparse checkout:

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/lildengzi/dotfiles
cd dotfiles
git sparse-checkout set .config/kitty .config/nvim .config/yazi .config/starship.toml .config/fish
cp -r .config/* ~/.config/
nvim  # auto-installs plugins
```

## Prerequisites

- [FantasqueSansM Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases) (or run `scripts/install-font.sh`)
- [Neovim](https://github.com/neovim/neovim) ≥ 0.10
- [Kitty](https://sw.kovidgoyal.net/kitty/) (or use your own terminal)
- [Yazi](https://yazi-rs.github.io/) file manager
- [Zed](https://zed.dev/) code editor
- [Starship](https://starship.rs/) prompt
- [Fish](https://fishshell.com/) shell
- JDK (optional, `scripts/profiles/work.sh` can install `jdk-openjdk` automatically)

## Notes

- niri/DMS are optional — the terminal + editor work on any WM
- PipeWire audio config and ananicy rules are not included (machine-specific)
- VSCode config is not in the repo (cloud-synced); Zed is kept
- Neovim config uses lazy.nvim and will auto-install all plugins on first launch
- Built on Linux (Arch-based); scripts auto-detect your distro and package manager, non-Arch not fully guaranteed
