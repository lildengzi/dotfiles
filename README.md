# dotfiles

[English](./README.en.md)

![desktop](Docs/Pictures/desktop.png)

个人 dotfiles，运行于 Linux（基于 Arch 系）— niri + DMS + Kitty + fish + Neovim。
仓库的 `.config/` 就是实际使用的 `~/.config` 目录树（去除了代理/密钥等隐私）。

## 包含什么

| 组件 | 配置 |
|------|------|
| **窗口管理器** | niri + Material You 桌面壳 (DMS) |
| **终端** | Kitty（dank 主题），字体 FantasqueSansM Nerd Font |
| **编辑器** | Neovim + LazyVim，配色 catppuccin，LSP (rust-analyzer / pyright / ruff)，DAP 调试，treesitter 语法高亮，彩虹括号，缩进线 |
| **文件管理器** | Yazi 终端文件管理器，编辑默认使用 nvim，支持终端内播放视频 |
| **代码编辑器** | VSCode + Zed，catppuccin 主题，自动保存 |
| **提示符** | Starship（GUI / TTY / bash 三套配置） |
| **Shell** | Fish，带 fastfetch 别名 |
| **桌面工具** | fastfetch、mpv、btop、cava、MangoHud、GTK/fontconfig、环境变量与自启动 |
| **壁纸** | 33 张精选壁纸 |

## 截图

![terminal](Docs/Pictures/terminal_info.png)

![桌面预览](Docs/Pictures/preview.gif)

### Neovim

![Neovim 预览](Docs/Pictures/nvimpreview.png)

### Yazi

![Yazi 预览](Docs/Pictures/yazipreview.png)

### VSCode

![VSCode 预览](Docs/Pictures/vscodepreview.png)

![VSCode 预览 2](Docs/Pictures/vscodepreview2.png)

![VSCode 已装插件](Docs/Pictures/vscode-used-plugin.png)

## 快速安装

一行命令（自动下载并启动安装器）：

```sh
curl -fsSL https://raw.githubusercontent.com/lildengzi/dotfiles/master/scripts/bootstrap.sh | sh
```

或者克隆到本地：

```sh
git clone https://github.com/lildengzi/dotfiles
cd dotfiles
sh scripts/install.sh
```

选择菜单：
1. **完整桌面** — niri + DMS + Kitty + nvim + yazi + fish + starship + vscode + 字体 + 全部配置
2. **仅终端 + 编辑器** — Kitty + nvim + yazi + starship + 字体
3. **自定义** — 勾选你想要的组件
4. **仅复制全部配置** — 只拷 `.config/`，不装软件

也可以单独安装某个组件（脚本全部为 POSIX sh，无需 bash）：

```sh
sh scripts/install-config.sh   # 复制全部 .config 配置（不装软件）
sh scripts/install-font.sh    # FantasqueSansM Nerd Font 字体
sh scripts/install-kitty.sh   # Kitty 终端
sh scripts/install-nvim.sh    # Neovim 编辑器 (LazyVim)
sh scripts/install-yazi.sh    # Yazi 文件管理器
sh scripts/install-niri.sh    # niri 窗口管理器
sh scripts/install-fish.sh    # Fish shell
sh scripts/install-starship.sh # Starship 提示符
sh scripts/install-vscode.sh  # VSCode 配置（本体请自行安装）
```

安装脚本会自动检测你的发行版（Arch、Fedora、Debian、openSUSE 等）并选择合适的包管理器，
备份已有配置，并安装缺少的依赖（非 Arch 系不保证完全可用）。

## 灾难恢复

电脑重装/系统炸了，一键恢复所有软件包（`packages/pkglist.txt` 是显式安装包的快照，含 AUR 包）：

```sh
git clone https://github.com/lildengzi/dotfiles
cd dotfiles
paru -S --needed $(cat packages/pkglist.txt)
```

> 注意：清单含 cachyos 仓库的包（如 `linux-cachyos`）。
> 若重装的是纯净 Arch，先安装并启用 [cachyos-mirrorlist](https://github.com/CachyOS/CachyOS-PKGBUILDS/tree/master/cachyos-mirrorlist)，
> 或用 Arch 内核替代 `linux-cachyos`。

更新清单（装新包后）：

```sh
pacman -Qqe > packages/pkglist.txt
```

## 与众不同之处

- **POSIX sh 安装脚本** — 所有 `scripts/*.sh` 都是纯 sh，不依赖 bash，任何发行版都能直接 `sh` 运行
- **fish 的 fetch 回退** — `ff` = `fastfetch`；如果系统没有 fastfetch，`fetch` 命令会优雅降级，不会在 distrobox/SSH 里启动失败
- **SSH / 容器自动检测** — fish 检测到 SSH、TTY、容器时会自动切换到保守的 ASCII 提示符，避免把桌面/GPU 假设泄漏进远程环境
- **CUDA 路径自动注入** — 只有宿主机检测到 `/opt/cuda` 和 DankMaterialShell 时才设置 `CUDA_HOME`，SSH/容器里自动清理
- **distrobox 稳定性修复** — 容器缺 passwd 条目时自动用 `--root`，tty 分配失败时自动 `--no-tty` 重试
- **Yazi 终端内播放视频** — `mpv --vo=kitty` 直接在文件管理器里预览视频，不弹独立窗口
- **Kitty 淡雅主题** — 内置 `dank-tabs.conf` / `dank-theme.conf`（slanted powerline 标签栏 + 灰紫配色），CJK 字体自动回退
- **niri 录屏快捷键** — `Mod+Alt+R` 开始 / `Mod+Alt+Shift+R` 停止录屏

## 手动复制

仓库的 `.config/` 就是完整的 `~/.config` 目录树，直接拷就能用：

```sh
git clone --depth 1 https://github.com/lildengzi/dotfiles
cd dotfiles
cp -r .config/* ~/.config/   # 合并进你的 ~/.config
nvim  # 打开后自动安装插件
```

只拿部分组件，可用 sparse checkout：

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/lildengzi/dotfiles
cd dotfiles
git sparse-checkout set .config/kitty .config/nvim .config/yazi .config/starship.toml .config/fish
cp -r .config/* ~/.config/
nvim  # 打开后自动安装插件
```

## 前置依赖

- [FantasqueSansM Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases)（或运行 `scripts/install-font.sh`）
- [Neovim](https://github.com/neovim/neovim) ≥ 0.10
- [Kitty](https://sw.kovidgoyal.net/kitty/)（也可以用你自己的终端）
- [Yazi](https://yazi-rs.github.io/) 文件管理器
- [VSCode](https://code.visualstudio.com/) 代码编辑器
- [Starship](https://starship.rs/) 提示符
- [Fish](https://fishshell.com/) shell

## 备注

- niri/DMS 是可选的 — 终端 + 编辑器在任何窗口管理器下都能用
- PipeWire 音频配置和 ananicy 规则不含在内（机器相关）
- 代理相关配置不含在内（v2ray / sing-box / proxyd / nas-conn 等）
- 隐私敏感项已清除：musixmatch token、VPN/NAS 服务器地址、clangd 机器路径等
- Neovim 配置使用 lazy.nvim，首次打开会自动安装所有插件
- 基于 Linux（Arch 系），脚本会自动检测发行版并选择包管理器，但非 Arch 系不保证完全可用
