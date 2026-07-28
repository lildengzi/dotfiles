# dotfiles

![desktop](Docs/Pictures/desktop.png)

个人 dotfiles，运行于 CachyOS — niri + DMS + Kitty + fish + Neovim。

## 包含什么

| 组件 | 配置 |
|------|------|
| **窗口管理器** | niri + Material You 桌面壳 (DMS) |
| **终端** | Kitty，字体 FantasqueSansM Nerd Font |
| **编辑器** | Neovim + LazyVim，配色 catppuccin，LSP (rust-analyzer / clangd / pyright / ruff)，DAP 调试，treesitter 语法高亮，彩虹括号，缩进线 |
| **提示符** | Starship，powerline 风格，自动检测操作系统 |
| **Shell** | Fish，带 fastfetch 别名 |
| **壁纸** | 20 张精选壁纸 |

## 截图

![terminal](Docs/Pictures/terminal_info.png)

![桌面预览](Docs/Pictures/preview.gif)

<video src="https://lildengzi.github.io/dotfiles/Docs/Pictures/show.mp4" controls width="600"></video>

## 快速安装

```bash
git clone https://github.com/lildengzi/dotfiles
cd dotfiles
bash scripts/install.sh
```

选择菜单：
1. **完整桌面** — niri + DMS + Kitty + nvim + fish + starship + 字体
2. **仅终端 + 编辑器** — Kitty + nvim + starship + 字体
3. **自定义** — 勾选你想要的组件

也可以单独安装某个组件：

```bash
bash scripts/install-font.sh    # FantasqueSansM Nerd Font 字体
bash scripts/install-kitty.sh   # Kitty 终端
bash scripts/install-nvim.sh    # Neovim 编辑器 (LazyVim)
bash scripts/install-niri.sh    # niri 窗口管理器
bash scripts/install-fish.sh    # Fish shell
bash scripts/install-starship.sh # Starship 提示符
```

安装脚本会自动检测你的发行版（Arch、Fedora、Debian、openSUSE 等），
备份已有配置，并安装缺少的依赖。

## 手动复制

如果只想拿配置文件不跑脚本：

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/lildengzi/dotfiles
cd dotfiles
git sparse-checkout set config/kitty config/nvim config/starship.toml config/fish
cp -r config/kitty ~/.config/kitty
cp -r config/nvim ~/.config/nvim
cp config/starship.toml ~/.config/
cp -r config/fish ~/.config/fish
nvim  # 打开后自动安装插件
```

## 前置依赖

- [FantasqueSansM Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases)（或运行 `scripts/install-font.sh`）
- [Neovim](https://github.com/neovim/neovim) ≥ 0.10
- [Kitty](https://sw.kovidgoyal.net/kitty/)（也可以用你自己的终端）
- [Starship](https://starship.rs/) 提示符
- [Fish](https://fishshell.com/) shell

## 备注

- niri/DMS 是可选的 — 终端 + 编辑器在任何窗口管理器下都能用
- PipeWire 音频配置和 ananicy 规则不含在内（机器相关）
- 代理配置不含在内
- Neovim 配置使用 lazy.nvim，首次打开会自动安装所有插件
- 基于 CachyOS，但理论上兼容任何发行版（脚本会自动检测包管理器）
