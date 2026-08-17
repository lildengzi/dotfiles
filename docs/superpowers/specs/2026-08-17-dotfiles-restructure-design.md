# dotfiles 重构设计

日期：2026-08-17
分支：`lildengzi/feat-modularize-dotfiles-install`
仓库：https://github.com/lildengzi/dotfiles

## 背景与目标

这是个人 dotfiles 仓库（云端备份，以防万一）。一次灾难恢复花了一天，太慢。
痛点：

1. 一键安装脚本不够智能——功能没有按接口彻底分开；云端已有的配置（如 VSCode）也进来了
2. 包清单只有一个 `packages/pkglist.txt`，只能一把装，不分系统/桌面/驱动/CachyOS/第三方/AUR
3. 壁纸不会自动放进 `~/Pictures`，且数量偏多（本机 24 张，仓库 33 张）
4. Windows 配置备份 + 虚拟机阵列（distrobox / OSX-KVM / winboat / podman / waydroid / AVD）恢复最慢

原则：

- **以本机当前状态为准**（配置、壁纸、包清单）
- **`/mnt/E/Rescue` 为备份源**（大数据所在）
- **远端仓库为最终保险**（只放小配置，不放二进制）
- **只保存配置，不把包本体上传**；无个人敏感信息

## 目录结构

```
├── .config/              # 仅软配置，已脱敏（机器无关）
├── packages/             # 6 个分类包清单
│   ├── system.txt        # 核心系统：base, base-devel, 引导, 文件系统, 网络, 工具
│   ├── desktop.txt       # GUI/WM 应用：niri, kitty, firefox 等
│   ├── drivers.txt       # 显卡/固件：nvidia*, amd-ucode, mesa, vulkan
│   ├── cachyos.txt       # CachyOS 专属：linux-cachyos, cachyos-*, greetd
│   ├── third-party.txt   # 官方仓库的第三方：docker, steam, discord
│   └── aur.txt           # AUR：brave-bin, visual-studio-code-bin 等
│   └── toolchain.txt     # 开发工具链（独立记录，因多数为依赖安装）
├── scripts/
│   ├── install.sh            # 嵌套菜单入口
│   ├── lib.sh                # 公共函数（detect_distro / backup / install_deps）
│   ├── bootstrap.sh          # 一行命令引导
│   ├── profiles/
│   │   ├── desktop.sh        # niri / DMS / 壁纸 / 自启动 / 外观
│   │   ├── work.sh           # nvim / yazi / kitty / fish / starship / 终端工具 / 字体
│   │   └── agent.sh          # opencode / agents skills / claude / superpowers
│   ├── install-packages.sh   # 按分类安装（官方仓库用 pacman，AUR 用 paru）
│   ├── install-walls.sh      # 壁纸 → ~/Pictures/wallpapers
│   ├── apply-machine.sh      # 仅本机（lildengzi-cachyos）的硬件覆盖
│   ├── install-font.sh       # 字体：安装时下载，不入库
│   └── restore/
│       ├── winboat.sh        # winboat 配置 + 数据
│       ├── distrobox.sh      # 重建 5 个容器
│       ├── waydroid.sh       # waydroid 配置 + 数据
│       ├── avd.sh            # AVD 配置 + 数据
│       ├── osx-kvm.sh        # OSX-KVM
│       └── podman.sh         # podman 容器
├── vms/                  # 虚拟机小配置
│   ├── winboat/          # podman-compose.yml, winboat.config.json
│   ├── distrobox/        # 容器创建清单
│   ├── waydroid/         # 配置文件
│   ├── avd/              # test.ini
│   └── osx-kvm/          # 自定义文件
└── wallpapers/           # 24 张，留在 git
```

## 安装分类（解耦）

| 分类 | 内容 | 组件 |
|------|------|------|
| **Desktop** | 桌面外观 | niri、DankMaterialShell、壁纸、autostart、gtk/fontconfig 外观 |
| **Work** | 工作环境 | nvim、yazi、kitty、fish、starship、终端工具（alacritty/btop/cava/mpv/MangoHud/fastfetch/environment.d）、字体、最新 JDK（`jdk-openjdk`，写入 environment.d 的 JAVA_HOME） || **Agent** | AI agent 配置 | opencode 配置、~/.agents/skills、~/.claude/settings.json、superpowers skills |
| **Packages** | 系统软件 | 6 类包清单，按类安装 |
| **VMs** | 虚拟机恢复 | winboat / distrobox / waydroid / AVD / OSX-KVM / podman |

说明：本机目前没有独立 JDK（仅 Android Studio 自带 JBR），
为保险起见 Work 分类会安装 Arch 系最新 `jdk-openjdk` 并配置 JAVA_HOME。

规则：

- **VSCode 配置移出仓库**（云端同步，本地有 851M 的 Code 配置）。`install-vscode.sh` 删除
- **Zed 保留**（未登录云端，68K 小配置，保留在 work 分类）
- 组件级脚本（install-kitty.sh 等）保留，可直接调用
- Work 分类安装最新 JDK（`jdk-openjdk`），并把 `JAVA_HOME=/usr/lib/jvm/java-openjdk` 与 `PATH` 写入 `~/.config/environment.d/java.conf`

## 嵌套菜单

```
1) Desktop   → 1) niri  2) DMS shell  3) wallpapers  4) autostart  5) appearance(gtk/fontconfig)
2) Work      → 1) nvim  2) yazi  3) kitty  4) fish  5) starship  6) terminal tools  7) fonts
3) Agent     → 1) opencode  2) agents skills  3) claude  4) superpowers
4) Packages  → 1) system  2) desktop  3) drivers  4) cachyos  5) third-party  6) aur  7) toolchain
5) VMs       → 1) winboat  2) distrobox  3) waydroid  4) AVD  5) OSX-KVM  6) podman
0) Quit
```

- 每组内子项可单独勾选（y/n），支持「全部 / 全部不装」快捷键
- 全部脚本 POSIX sh，无需 bash

## 包清单

- 以本机 `pacman -Qqe`（343 个）为源手工分类，分成 7 个文件
  （system / desktop / drivers / cachyos / third-party / aur / toolchain）
- 官方仓库包归入 system/desktop/drivers/cachyos/third-party
- AUR 包（`pacman -Qqm`）归入 aur.txt
- **toolchain.txt 独立记录开发工具链**：本机 rust/go/nodejs/bun/python 等多为
  依赖安装（`pacman -Qqe` 抓不到，如 rust、go、pnpm、bun 均为 dependency）。
  toolchain.txt 手写完整开发环境清单，供一键复现开发环境
- `install-packages.sh` 参数：分类名（如 `sh install-packages.sh desktop`），
  官方仓库用 pacman 装，AUR 用 paru 装
- 更新方式：`pacman -Qqe | sort > 分类文件`（脚本辅助）

## 开发工具链（toolchain）

本机实际开发环境（多数是依赖安装，不在 `pacman -Qqe` 中）：

| 工具 | 版本（本机） | 备注 |
|------|-------------|------|
| rust / cargo / rust-src | 1.97.1 | pacman 安装，非 rustup；无 `~/.rustup` |
| go | 1.26.5 | 依赖安装 |
| node / npm | 26.7.0 / 12.0.2 | nodejs/npm 显式，pnpm 11.3.0 为依赖 |
| bun | 1.3.14 | 依赖安装 |
| python | 3.14.7 | 显式 |
| gcc / gdb / clang / llvm | 16.2 / 17.2 / 22.1 | 编译器套件 |
| cmake / meson / ninja | 4.4 / 1.12 / 1.13 | 构建工具 |
| git / ripgrep / tmux | 2.55 / 15.2 / 3.7 | 基础工具 |
| JDK | （无独立安装） | work 分类安装 `jdk-openjdk` + JAVA_HOME |

`packages/toolchain.txt` 覆盖以上，确保重装后能一键复现完整开发环境。

## 壁纸

- 仓库壁纸从 33 张减到 24 张，与本机 `~/Pictures/wallpapers` 完全一致
- 删除 10 张仅在仓库的文件；补 1 张本机有但仓库没有的（`【哲风壁纸】动漫女孩-报纸墙.jpg`）
- 新增 `install-walls.sh`：把 `wallpapers/` 拷到 `~/Pictures/wallpapers`
- 修正 DMS `plugin_settings.json` 的 `wallpaperDirectory`：仓库里是 `~/Pictures/wallpaper`（单数，少 s），改为 `~/Pictures/wallpapers`
- 壁纸是唯一留在 git 的二进制

## 敏感信息脱敏

| 位置 | 处理 |
|------|------|
| `~/.winboat/podman-compose.yml` 密码 | 换成占位符 |
| 配置中的 `/home/lildengzi` | 换成 `$HOME` / `~` |
| proxy.fish、nas-conn/phone-conn 函数 | 不进仓库（NAS/VPN 端点） |
| v2ray / sing-box / easytier 端点 | 脱敏或剔除 |
| token / API key（musixmatch 等） | 剔除 |
| VSCode 配置 | 整个移出（其中含大量个人设置） |

## 配置同步

- 从本机同步**软配置**进仓库：
  - kitty 颜色（dank-theme.conf / dank-tabs.conf）
  - fish 主题（fish_frozen_theme.fish）与 conf.d
  - DMS 软设置（settings.json 中非硬件部分）
  - niri config.kdl（录屏绑定保留，补 Emulator 窗口规则）
- 保持**硬件相关通用**：
  - `outputs.kdl` 保持通用（DP-1），不写死 HDMI-A-1
  - `monitors.json` 保持通用
  - i2c 设备不写死
- `apply-machine.sh`：仅当 `hostname == lildengzi-cachyos` 时写入
  本机硬件位（HDMI-A-1、i2c-5），其余机器跳过

## 虚拟机恢复

每个 restore 脚本的模式：

1. 从 `vms/` 放小配置到对应位置
2. 从 `/mnt/E/Rescue` 拷贝大数据（winboat data.img、podman storage、AVD 数据等）
3. 启动/注册（distrobox create、podman compose up 等）

| 虚拟机 | 配置来源 | 数据来源 |
|--------|----------|----------|
| winboat | `vms/winboat/` → `~/.winboat/` + `~/winboat/` | `/mnt/E/Rescue/home_core/winboat/` |
| distrobox | `vms/distrobox/` 清单 → distrobox create | 无（重新 pull 镜像） |
| waydroid | `vms/waydroid/` → `~/.config/waydroid` + `~/.local/share/waydroid` | `/mnt/E/Rescue/` |
| AVD | `vms/avd/test.ini` → `~/.android/avd/` | `/mnt/E/Rescue/` |
| OSX-KVM | `vms/osx-kvm/` 自定义文件 | `/mnt/E/Rescue/` |
| podman | 容器定义 | `/mnt/E/Rescue/`（podman storage） |

注：winboat 数据在 `/mnt/E/Rescue/home_core/winboat/` 中已有（data.img 等），
`~/.winboat`（配置）目前**未**在 Rescue 中，恢复脚本应提示先备份该目录。

## 验收标准

1. `install.sh` 嵌套菜单 5 组 × 子项，均可单独勾选，POSIX sh
2. `packages/` 下 7 个分类文件，包数与本机一致（343），AUR 包全部在 aur.txt，toolchain.txt 覆盖完整开发环境
3. `wallpapers/` 24 张，与本机 `~/Pictures/wallpapers` 一致；`install-walls.sh` 能装到正确目录
4. 仓库中无 `lildengzi` 用户名、无密码明文、无 NAS/VPN 端点、无 token
5. VSCode 配置与 install-vscode.sh 已移除
6. `scripts/restore/` 6 个脚本存在，winboat 能从 Rescue 恢复数据
7. `apply-machine.sh` 只在目标主机写硬件位，其余机器无影响
8. 所有脚本 `sh -n` 语法检查通过
