# dotfiles 重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 dotfiles 重构为可解耦安装（Desktop/Work/Agent/Packages/VMs）、包清单分类、壁纸归位、无敏感信息、虚拟机可恢复的备份仓库。

**Architecture:** 仓库 `.config/` 保留软配置（脱敏、机器无关）；`packages/` 放 7 个分类包清单；`scripts/` 拆分 profile 安装脚本 + 嵌套菜单 + 恢复脚本；`vms/` 放虚拟机小配置；壁纸减到 24 张与本机一致。

**Tech Stack:** POSIX sh、pacman/paru、git、npm（agent 工具）。

**Spec:** `docs/superpowers/specs/2026-08-17-dotfiles-restructure-design.md`

## Global Constraints

- 所有脚本 **POSIX sh**，`sh -n` 语法检查必须通过
- 仓库中**不得出现**：真实用户名 `lildengzi`（路径用 `$HOME`/`~`）、密码明文、NAS/VPN 端点、token/API key
- 壁纸仅保留 24 张，与本机 `~/Pictures/wallpapers` 完全一致
- VSCode 配置（`.config/Code/`）与 `scripts/install-vscode.sh` 移除（云端同步）；Zed 保留
- 包清单 7 个分类文件，总数与本机 `pacman -Qqe` 一致（343）
- 大数据（winboat 29G、podman 4G、AVD 6G 等）不入库，恢复时从 `/mnt/E/Rescue` 拷贝
- 硬件相关配置保持通用（DP-1、通用 i2c），本机硬件位由 `apply-machine.sh` 单独覆盖

---

### Task 1: 壁纸缩减到 24 张并修正 DMS 路径

**Files:**
- Modify: `wallpapers/`（删除 10 个、新增 1 个）
- Modify: `.config/DankMaterialShell/plugin_settings.json`

**Interfaces:**
- Produces: 仓库壁纸与本机 `~/Pictures/wallpapers` 完全一致；`plugin_settings.json` 的 `wallpaperDirectory` 指向 `~/Pictures/wallpapers`

- [ ] **Step 1: 删除 10 张仅在仓库的壁纸**

删除（本机没有的 10 张）：
```
wallhaven-45yew5_1920x1080.png
wallhaven-g72257_1920x1080.png
wallhaven-lyjwv2_1920x1080.png
wallhaven-og1ko5_1920x1080.png
wallhaven-po7kp3_1920x1080.png
wallhaven-qr2wd5.png
wallhaven-w5de9r_1920x1080.png
wallhaven-xlmlxv_1920x1080.png
【哲风壁纸】云-冬天-山.jpg
【哲风壁纸】云-奇点-异常艺术.jpg
```

```bash
cd /home/lildengzi/Projects/orca/workspaces/dotfiles/chinook
git rm 'wallpapers/wallhaven-45yew5_1920x1080.png' \
        'wallpapers/wallhaven-g72257_1920x1080.png' \
        'wallpapers/wallhaven-lyjwv2_1920x1080.png' \
        'wallpapers/wallhaven-og1ko5_1920x1080.png' \
        'wallpapers/wallhaven-po7kp3_1920x1080.png' \
        'wallpapers/wallhaven-qr2wd5.png' \
        'wallpapers/wallhaven-w5de9r_1920x1080.png' \
        'wallpapers/wallhaven-xlmlxv_1920x1080.png' \
        'wallpapers/【哲风壁纸】云-冬天-山.jpg' \
        'wallpapers/【哲风壁纸】云-奇点-异常艺术.jpg'
```

- [ ] **Step 2: 新增本机有但仓库没有的壁纸**

```bash
cp '/home/lildengzi/Pictures/wallpapers/【哲风壁纸】动漫女孩-报纸墙.jpg' \
   '/home/lildengzi/Projects/orca/workspaces/dotfiles/chinook/wallpapers/'
git add 'wallpapers/【哲风壁纸】动漫女孩-报纸墙.jpg'
```

- [ ] **Step 3: 修正 DMS wallpaperDirectory 路径**

编辑 `.config/DankMaterialShell/plugin_settings.json` 第 98 行：
`"wallpaperDirectory": "~/Pictures/wallpaper"` → `"wallpaperDirectory": "~/Pictures/wallpapers"`

- [ ] **Step 4: 验证壁纸数量一致**

```bash
cd /home/lildengzi/Projects/orca/workspaces/dotfiles/chinook
ls wallpapers | sort > /tmp/wp_repo.txt
ls ~/Pictures/wallpapers | sort > /tmp/wp_local.txt
diff /tmp/wp_repo.txt /tmp/wp_local.txt && echo "MATCH: $(wc -l < /tmp/wp_repo.txt) wallpapers"
```

期望输出：`MATCH: 24 wallpapers`，diff 无输出。

- [ ] **Step 5: 提交**

```bash
git add -A
git commit -m "chore: 壁纸减至 24 张（与本机一致），修正 DMS 壁纸目录为 ~/Pictures/wallpapers"
```

---

### Task 2: 移除 VSCode 配置与脚本

**Files:**
- Delete: `.config/Code/`（整个目录）
- Delete: `scripts/install-vscode.sh`
- Modify: `README.md`、`README.en.md`

**Interfaces:**
- Consumes: 无
- Produces: 仓库不再含 VSCode 配置

- [ ] **Step 1: 删除 VSCode 配置与脚本**

```bash
cd /home/lildengzi/Projects/orca/workspaces/dotfiles/chinook
git rm -r .config/Code
git rm scripts/install-vscode.sh
```

- [ ] **Step 2: 从 README 移除 VSCode 相关描述**

`README.md` 中：
- 「包含什么」表删除 `**代码编辑器** | VSCode + Zed` 行，改为只留 Zed
- 「快速安装」菜单与脚本列表删除 `install-vscode.sh`
- 「前置依赖」删除 VSCode 行
- 截图区 VSCode 相关图保留或删除均可（仅文档）

`README.en.md` 同步修改。

- [ ] **Step 3: 验证无 VSCode 引用残留**

```bash
grep -rni "vscode\|install-vscode" README.md README.en.md scripts/ .config/ 2>/dev/null
```

期望：无输出（截图区文档提及可保留，但必须无 `install-vscode.sh` 引用）。

- [ ] **Step 4: 提交**

```bash
git add -A
git commit -m "refactor: 移除 VSCode 配置（云端同步，不入仓库）"
```

---

### Task 3: 生成 7 个分类包清单

**Files:**
- Delete: `packages/pkglist.txt`
- Modify: `packages/README.md`
- Create: `packages/system.txt`、`packages/desktop.txt`、`packages/drivers.txt`、`packages/cachyos.txt`、`packages/third-party.txt`、`packages/aur.txt`、`packages/toolchain.txt`

**Interfaces:**
- Produces: 7 个分类文件，各文件内容为包名逐行排序；总数 343

- [ ] **Step 1: 用本机 pacman 数据分类**

先跑分类脚本生成 TSV（每行 `包名<TAB>仓库<TAB>安装原因`），供人工归类参考：

```bash
cd /tmp/opencode
pacman -Qqe | sort > explicit.txt
while read -r p; do
    repo=$(pacman -Qi "$p" 2>/dev/null | sed -n 's/^Repository *: //p')
    reason=$(pacman -Qi "$p" 2>/dev/null | sed -n 's/^Install Reason *: //p')
    printf "%s\t%s\t%s\n" "$p" "${repo:-AUR}" "$reason"
done < explicit.txt > pkgs_info.tsv
```

（若 120s 超时，改用分批：`split -l 60 explicit.txt part_` 然后对每块跑循环。）

- [ ] **Step 2: 人工归类到 7 个文件**

参考归类规则（AUR 包已在 `pacman -Qqm` 确认，共 13 个）：
- `aur.txt`：android-studio, biliup-rs-bin, deepseek-harness-bin, dmg2img, linuxqq, mcpp-bin, pacseek, quickemu, stably-orca-bin, ttf-lucida-fonts, ttf-ms-fonts, ttf-smiley-sans-bin, visual-studio-code-bin
- `system.txt`：base, base-devel, pacman-contrib, btrfs-progs, btrfs-assistant, cryptsetup, lvm2, mdadm, dmraid, snapper, limine*, efibootmgr, efitools, os-prober, mkinitcpio, fsarchiver, dosfstools, e2fsprogs, f2fs-tools, exfatprogs, nilfs-utils, ntfs-3g, ntfsprogs, xfsprogs, mtools, udisks, archiso, openssh, networkmanager, iwd, wpa_supplicant, dnsmasq, bind, nss-mdns, ufw, ufw-extras, ethtool, hdparm, smartmontools, nvme-cli, lsscsi, hwdetect, hwinfo, dmidecode, cpupower, powertop, power-profiles-daemon, reflector, rebuild-detector, rsync, pv, bc, less, which, wget, diffutils, texinfo, inetutils, man-db, man-pages, s-nail, sudo, bash-completion, logrotate, pkgfile, plocate, dialog, xdg-user-dirs, python-packaging, python-defusedxml, lsb-release, perl, tcpdump, nmap, iperf3, socat, sg3_utils, sysfsutils, usbutils, usb_modeswitch, upower, accountsservice, bluez*, modemmanager, pipewire-alsa, pipewire-pulse, wireplumber, alsa-*, sof-firmware, gst-plugin-pipewire, gst-libav, gst-plugins-bad, gst-plugins-ugly, gst-plugin-va, xorg-server, xorg-xinit, xwayland-satellite, mesa-utils, xf86-video-amdgpu, swtpm, edk2-ovmf, nfs-utils, qemu-user-static-binfmt, switcheroo-control, rtkit, libguestfs, libinput-tools, lmms(?), virt-manager, virt-viewer, tigervnc, docker, docker-compose, podman, podman-compose, podman-desktop, libvirt, glance, prometheus, syncthing, glances
- `desktop.txt`：niri, quickshell, DMS 相关(dms-shell, dms-shell-niri), kitty, alacritty, fish 相关(cachyos-fish-config 归 cachyos), starship, btop, cava, fastfetch, mpv, gammastep, wayland 工具(grim, slurp, wl-clipboard, wev), fcitx5*（中文输入）, gtk 主题相关(adw-gtk-theme), vimix-cursors, showmethekey, mangohud, matugen, thunar, nautilus(?), kdeconnect, pavucontrol, udiskie, firefox, telegram-desktop, discord, brave-bin(→aur), wps-office, libreoffice-fresh-zh-cn, obsidian, obs-studio, vlc, vlc-plugins-all, kicad, blender, gimp, krita, audacity, shotcut, kdenlive, lmms, godot, godot-mono, prismlauncher, steam, wine?, localsend, qbittorrent, baidupcs-go, linuxqq(→aur), cmatrix, chafa, img2pdf, mupdf-tools, poppler-glib, libopenraw, libgsf, ffmpegthumbnailer, gvfs, gvfs-mtp, gvfs-smb, zed, dgop, easytier?, cachyos-hello(→cachyos)
- `drivers.txt`：nvidia-utils, lib32-nvidia-utils, lib32-opencl-nvidia, opencl-nvidia, libva-nvidia-driver, nvidia-settings, nvidia-prime, linux-cachyos-nvidia-open, linux-cachyos-lts-nvidia-open(→cachyos), amd-ucode, linux-firmware, lact, asusctl, egl-wayland, vulkan-icd-loader, vulkan-radeon, lib32-vulkan-icd-loader, lib32-vulkan-radeon
- `cachyos.txt`：linux-cachyos, linux-cachyos-headers, linux-cachyos-lts, linux-cachyos-lts-headers, linux-cachyos-nvidia-open, linux-cachyos-lts-nvidia-open, cachyos-fish-config, cachyos-hello, cachyos-hooks, cachyos-kernel-manager, cachyos-keyring, cachyos-mirrorlist, cachyos-packageinstaller, cachyos-plymouth-bootanimation, cachyos-plymouth-theme, cachyos-rate-mirrors, cachyos-settings, cachyos-snapper-support, cachyos-v3-mirrorlist, cachyos-v4-mirrorlist, cachyos-wallpapers, chwd, greetd
- `third-party.txt`：docker, docker-compose, podman, podman-compose, podman-desktop, libvirt, virt-manager, virt-viewer, qemu-full, quickemu(→aur), distrobox, waydroid, waydroid-image, wine, wine-mono, winetricks(不在本机), steam, prismlauncher, firefox, telegram-desktop, discord, brave-bin(→aur), cloudflare-warp-bin, syncthing, tailscale(不在本机), v2ray, xl2tpd, networkmanager-openvpn, qbittorrent, baidupcs-go, obsidian, wps-office, libreoffice-fresh-zh-cn, localsend, audacity, shotcut, kdenlive, blender, gimp, krita, kicad, lmms, obs-studio, vlc, vlc-plugins-all, godot, godot-mono, 7zip, unrar, unzip, aria2, ffmpegthumbnailer, git, git-lfs, github-cli, lazygit, lazydocker, ddcutil, fbv(?), shelly, openocd, stlink, qemu-user-static-binfmt, winboat, tesseract-data-eng, graphviz, doxygen, dmg2img(→aur)
- `toolchain.txt`：先注释说明，然后放 agent npm 全局包与开发环境参考清单

**注意**：分类结果必须两两核对无重复、无遗漏；总数 = 343。用下面的验证命令确认。

- [ ] **Step 3: 验证分类完整性与数量**

```bash
cd /home/lildengzi/Projects/orca/workspaces/dotfiles/chinook
cat packages/system.txt packages/desktop.txt packages/drivers.txt \
    packages/cachyos.txt packages/third-party.txt packages/aur.txt \
    packages/toolchain.txt 2>/dev/null | sort -u > /tmp/wp_classified.txt
# 若 toolchain.txt 含注释，需先过滤：grep -v '^#'
diff <(sort /tmp/opencode/explicit.txt) /tmp/wp_classified.txt && echo "ALL 343 accounted"
```

期望：`ALL 343 accounted`（总数 343 且与机器 `pacman -Qqe` 一致）。

- [ ] **Step 4: 删除旧 pkglist，更新 README**

```bash
git rm packages/pkglist.txt
```

`packages/README.md` 重写为 7 分类说明 + 安装/更新命令。

- [ ] **Step 5: 提交**

```bash
git add packages/
git commit -m "feat: 包清单拆分为 system/desktop/drivers/cachyos/third-party/aur/toolchain 七类"
```

---

### Task 4: 重写 lib.sh + 新增 install-packages.sh

**Files:**
- Modify: `scripts/lib.sh`
- Create: `scripts/install-packages.sh`
- Create: `scripts/install-agent-tools.sh`

**Interfaces:**
- Consumes: `packages/*.txt`（Task 3）
- Produces: `install_pkg_category <cat>` 函数；`install-packages.sh`（CLI：`sh install-packages.sh [category...]`）

- [ ] **Step 1: 重写 lib.sh**

保留 `detect_distro`、`backup_config`、`install_deps`（原样），新增 `install_pkg_category`：

```sh
# 按分类安装包清单：官方仓库用 pacman，AUR 用 paru
install_pkg_category() {
    category="$1"
    list="$DOTFILES/packages/$category.txt"
    [ -f "$list" ] || { echo "  未知分类: $category" >&2; return 1; }
    echo "=== 安装 $category 包 ($(grep -c . "$list" 2>/dev/null || echo 0) 个) ==="
    # 过滤注释/空行
    pkgs=$(grep -v '^#' "$list" | grep -v '^[[:space:]]*$')
    [ -n "$pkgs" ] || { echo "  $category 列表为空"; return 0; }
    case "$category" in
        aur)
            if command -v paru >/dev/null 2>&1; then
                paru -S --needed $pkgs
            elif command -v yay >/dev/null 2>&1; then
                yay -S --needed $pkgs
            else
                echo "  未找到 paru/yay，无法安装 AUR 包" >&2
                echo "  请先安装 paru: sudo pacman -S paru" >&2
                return 1
            fi
            ;;
        *)
            install_deps $pkgs
            ;;
    esac
}
```

- [ ] **Step 2: 创建 install-packages.sh**

```sh
#!/bin/sh
# 按分类安装包。用法: sh install-packages.sh system desktop aur ...
# 无参数时列出所有分类。
set -e
. "$(dirname "$0")/lib.sh"

if [ $# -eq 0 ]; then
    echo "可用分类:"
    for f in "$DOTFILES"/packages/*.txt; do
        echo "  $(basename "$f" .txt)"
    done
    exit 0
fi

for category in "$@"; do
    install_pkg_category "$category"
done
```

- [ ] **Step 3: 创建 install-agent-tools.sh**

```sh
#!/bin/sh
# 恢复 agent 相关 npm 全局工具（codex 等）
set -e
. "$(dirname "$0")/lib.sh"

echo "=== Agent npm 全局工具 ==="
# 从 toolchain.txt 读取 npm 段（以 'npm-global:' 为标记）
if [ -f "$DOTFILES/packages/toolchain.txt" ]; then
    npm_pkgs=$(sed -n '/^# npm-global:/,/^#/p' "$DOTFILES/packages/toolchain.txt" \
               | grep -v '^#' | grep -v '^[[:space:]]*$')
    [ -n "$npm_pkgs" ] && { echo "  安装: $npm_pkgs"; npm install -g $npm_pkgs; }
fi
```

- [ ] **Step 4: 语法检查**

```bash
sh -n scripts/lib.sh scripts/install-packages.sh scripts/install-agent-tools.sh && echo OK
```

- [ ] **Step 5: 提交**

```bash
git add scripts/lib.sh scripts/install-packages.sh scripts/install-agent-tools.sh
git commit -m "feat: install-packages.sh 按分类安装，lib.sh 增加 install_pkg_category"
```

---

### Task 5: profile 脚本（desktop / work / agent）

**Files:**
- Create: `scripts/profiles/desktop.sh`
- Create: `scripts/profiles/work.sh`
- Create: `scripts/profiles/agent.sh`
- Create: `scripts/install-walls.sh`

**Interfaces:**
- Consumes: `scripts/lib.sh`、`.config/` 各目录（Task 6 同步后）
- Produces: `desktop.sh`/`work.sh`/`agent.sh` 可独立运行；`install-walls.sh` 装壁纸

- [ ] **Step 1: 创建 install-walls.sh**

```sh
#!/bin/sh
# 壁纸 → ~/Pictures/wallpapers
set -e
. "$(dirname "$0")/lib.sh"

echo "=== 安装壁纸 ==="
DEST="$HOME/Pictures/wallpapers"
mkdir -p "$DEST"
cp -n "$DOTFILES/wallpapers/"*.png "$DOTFILES/wallpapers/"*.jpg "$DEST" 2>/dev/null || true
echo "  已复制 $(ls "$DEST" 2>/dev/null | wc -l) 张壁纸到 $DEST"
```

- [ ] **Step 2: 创建 profiles/desktop.sh**

```sh
#!/bin/sh
# Desktop: niri + DMS + 壁纸 + 自启动 + 外观
set -e
. "$(dirname "$0")/../lib.sh"

echo "=== Desktop 桌面配置 ==="

ask() { # $1=提示 $2=默认(y/n)
    printf "%s [%s] " "$1" "$2"
    read ans; [ -z "$ans" ] && ans="$2"
    case "$ans" in y|Y) return 0;; *) return 1;; esac
}

if ask "安装 niri 窗口管理器?" y; then
    sh "$SCRIPT_DIR/../install-niri.sh"
fi
if ask "复制 DMS 配置?" y; then
    backup_config "$HOME/.config/DankMaterialShell"
    mkdir -p "$HOME/.config/DankMaterialShell"
    cp -r "$DOTFILES/.config/DankMaterialShell/." "$HOME/.config/DankMaterialShell/"
fi
if ask "安装壁纸?" y; then
    sh "$SCRIPT_DIR/../install-walls.sh"
fi
if ask "复制 autostart?" y; then
    backup_config "$HOME/.config/autostart"
    mkdir -p "$HOME/.config/autostart"
    cp -r "$DOTFILES/.config/autostart/." "$HOME/.config/autostart/"
fi
if ask "复制外观配置 (gtk/fontconfig)?" y; then
    for d in gtk-3.0 gtk-4.0 fontconfig; do
        backup_config "$HOME/.config/$d"
        mkdir -p "$HOME/.config/$d"
        cp -r "$DOTFILES/.config/$d/." "$HOME/.config/$d/"
    done
fi
echo "  桌面配置完成"
```

- [ ] **Step 3: 创建 profiles/work.sh**

```sh
#!/bin/sh
# Work: nvim + yazi + kitty + fish + starship + 终端工具 + 字体 + JDK
set -e
. "$(dirname "$0")/../lib.sh"

echo "=== Work 工作环境 ==="

ask() {
    printf "%s [%s] " "$1" "$2"
    read ans; [ -z "$ans" ] && ans="$2"
    case "$ans" in y|Y) return 0;; *) return 1;; esac
}

if ask "安装 Neovim?" y; then sh "$SCRIPT_DIR/../install-nvim.sh"; fi
if ask "安装 Yazi?" y; then sh "$SCRIPT_DIR/../install-yazi.sh"; fi
if ask "安装 Kitty?" y; then sh "$SCRIPT_DIR/../install-kitty.sh"; fi
if ask "安装 Fish?" y; then sh "$SCRIPT_DIR/../install-fish.sh"; fi
if ask "安装 Starship?" y; then sh "$SCRIPT_DIR/../install-starship.sh"; fi
if ask "复制终端工具配置 (alacritty/btop/cava/mpv/MangoHud/fastfetch/env)?" y; then
    for d in alacritty btop cava mpv MangoHud fastfetch environment.d; do
        backup_config "$HOME/.config/$d"
        mkdir -p "$HOME/.config/$d"
        cp -r "$DOTFILES/.config/$d/." "$HOME/.config/$d/" 2>/dev/null || true
    done
fi
if ask "安装 Nerd Font 字体?" y; then sh "$SCRIPT_DIR/../install-font.sh"; fi
if ask "安装最新 JDK (jdk-openjdk)?" n; then
    install_deps jdk-openjdk
    mkdir -p "$HOME/.config/environment.d"
    if ! grep -q JAVA_HOME "$HOME/.config/environment.d/java.conf" 2>/dev/null; then
        cat >> "$HOME/.config/environment.d/java.conf" << 'EOF'
JAVA_HOME=/usr/lib/jvm/java-openjdk
PATH=$HOME/.cargo/bin:/usr/lib/jvm/java-openjdk/bin:$PATH
EOF
    fi
fi
echo "  工作环境配置完成"
```

- [ ] **Step 4: 创建 profiles/agent.sh**

```sh
#!/bin/sh
# Agent: opencode + agents skills + claude + superpowers + agent npm 工具
set -e
. "$(dirname "$0")/../lib.sh"

echo "=== Agent 工具链 ==="

ask() {
    printf "%s [%s] " "$1" "$2"
    read ans; [ -z "$ans" ] && ans="$2"
    case "$ans" in y|Y) return 0;; *) return 1;; esac
}

if ask "复制 opencode 配置?" y; then
    backup_config "$HOME/.config/opencode"
    mkdir -p "$HOME/.config/opencode"
    cp -r "$DOTFILES/.config/opencode/." "$HOME/.config/opencode/"
fi
if ask "复制 agents skills?" y; then
    backup_config "$HOME/.agents"
    mkdir -p "$HOME/.agents"
    cp -r "$DOTFILES/.agents/." "$HOME/.agents/"
fi
if ask "复制 claude 配置?" y; then
    backup_config "$HOME/.claude/settings.json"
    mkdir -p "$HOME/.claude"
    [ -f "$DOTFILES/.claude/settings.json" ] && cp "$DOTFILES/.claude/settings.json" "$HOME/.claude/"
fi
if ask "安装 agent npm 全局工具 (codex 等)?" y; then
    sh "$SCRIPT_DIR/../install-agent-tools.sh"
fi
echo "  Agent 配置完成"
```

- [ ] **Step 5: 语法检查**

```bash
sh -n scripts/profiles/*.sh scripts/install-walls.sh && echo OK
```

- [ ] **Step 6: 提交**

```bash
git add scripts/profiles/ scripts/install-walls.sh
git commit -m "feat: profile 脚本（desktop/work/agent）解耦安装 + install-walls.sh"
```

---

### Task 6: Agent 配置入库 + 配置同步（软配置）

**Files:**
- Create: `.config/opencode/opencode.jsonc`、`.config/opencode/AGENTS.md`
- Create: `.agents/skills/`（computer-use, orca-cli, orchestration）
- Create: `.claude/settings.json`（脱敏）
- Modify: `.config/kitty/dank-theme.conf`、`.config/kitty/dank-tabs.conf`
- Create: `.config/fish/conf.d/fish_frozen_theme.fish`
- Modify: `.config/niri/config.kdl`
- Modify: `.config/DankMaterialShell/settings.json`

**Interfaces:**
- Consumes: 本机 `~/.config/opencode`、`~/.agents`、`~/.claude`、`~/.config/fish` 等
- Produces: 仓库 Agent 配置 + 同步后的软配置

- [ ] **Step 1: 复制 opencode 配置（脱敏）**

```bash
cd /home/lildengzi/Projects/orca/workspaces/dotfiles/chinook
mkdir -p .config/opencode
cp ~/.config/opencode/opencode.jsonc .config/opencode/
cp ~/.config/opencode/AGENTS.md .config/opencode/
# 检查无敏感信息
grep -niE "token|api[_-]?key|password|lildengzi|127\.0\.0\.1:1080" .config/opencode/
```

若 grep 命中，先脱敏再入库。opencode.jsonc 里 `~/.local/share/superpowers` 插件路径保持 `~` 相对写法。

- [ ] **Step 2: 复制 agents skills**

```bash
mkdir -p .agents/skills
cp -r ~/.agents/skills/computer-use .agents/skills/
cp -r ~/.agents/skills/orca-cli .agents/skills/
cp -r ~/.agents/skills/orchestration .agents/skills/
```

检查 `.agents/skills/*/SKILL.md` 无 `lildengzi` 真实路径。

- [ ] **Step 3: 复制 claude 配置（脱敏）**

```bash
mkdir -p .claude
cp ~/.claude/settings.json .claude/
# 脱敏: 替换 /home/lildengzi 为 $HOME
sed -i "s#/home/lildengzi#\$HOME#g" .claude/settings.json
grep -niE "token|password|lildengzi" .claude/settings.json || echo "clean"
```

- [ ] **Step 4: 同步软配置（kitty/fish/niri/DMS 非硬件部分）**

用 diff 确认差异后逐项复制：
```bash
cp ~/.config/kitty/dank-theme.conf .config/kitty/
cp ~/.config/kitty/dank-tabs.conf .config/kitty/
cp ~/.config/fish/conf.d/fish_frozen_theme.fish .config/fish/conf.d/
```
- niri `config.kdl`：补上本机的 Emulator 窗口规则，保留录屏绑定
- DMS `settings.json`：同步非硬件字段（iconTheme 等），保留通用 i2c/设备名

注意：`proxy.fish`、`nas-conn.fish`、`phone-conn.fish` **不进仓库**（含端点）。

- [ ] **Step 5: 验证无敏感信息**

```bash
grep -rn "lildengzi\|/home/" .config/opencode .agents .claude 2>/dev/null || echo "clean"
grep -rn "password" .claude/settings.json 2>/dev/null || echo "no password"
```

- [ ] **Step 6: 提交**

```bash
git add .config/opencode .agents .claude .config/kitty .config/fish .config/niri .config/DankMaterialShell
git commit -m "feat: Agent 配置入库（opencode/skills/claude）+ 同步软配置"
```

---

### Task 7: apply-machine.sh 硬件覆盖脚本

**Files:**
- Create: `scripts/apply-machine.sh`

**Interfaces:**
- Consumes: `.config/niri/dms/outputs.kdl`（保持通用）、本机硬件信息
- Produces: 仅在本机（hostname=lildengzi-cachyos）写入 HDMI-A-1/i2c-5 等硬件位

- [ ] **Step 1: 创建 apply-machine.sh**

```sh
#!/bin/sh
# 仅在本机（lildengzi-cachyos）应用硬件相关覆盖。
# 其余机器运行本脚本直接退出，不影响仓库通用配置。
set -e
. "$(dirname "$0")/lib.sh"

HOST=$(hostname)

case "$HOST" in
    lildengzi-cachyos)
        echo "=== 应用 lildengzi-cachyos 硬件覆盖 ==="
        # 输出: HDMI-A-1 @ 1920x1080@165
        cat > "$HOME/.config/niri/dms/outputs.kdl" << 'EOF'
output "HDMI-A-1" {
    mode "1920x1080@165.000"
    position "1920x0"
}
output "eDP-1" {
    mode "2560x1600@120.000"
    position "0x0"
}
EOF
        echo "  已写入 outputs.kdl (HDMI-A-1)"
        # DMS ddc i2c-5
        if [ -f "$HOME/.config/DankMaterialShell/settings.json" ]; then
            sed -i 's/"deviceName": "ddc:i2c-3"/"deviceName": "ddc:i2c-5"/' \
                "$HOME/.config/DankMaterialShell/settings.json"
        fi
        echo "  已应用 ddc:i2c-5"
        ;;
    *)
        echo "非本机 ($HOST)，跳过硬件覆盖。"
        ;;
esac
```

- [ ] **Step 2: 语法检查**

```bash
sh -n scripts/apply-machine.sh && echo OK
```

- [ ] **Step 3: 提交**

```bash
git add scripts/apply-machine.sh
git commit -m "feat: apply-machine.sh 仅本机应用硬件覆盖（HDMI-A-1/i2c-5）"
```

---

### Task 8: 重写 install.sh 嵌套菜单

**Files:**
- Modify: `scripts/install.sh`

**Interfaces:**
- Consumes: Task 4/5/7 的脚本
- Produces: 五组嵌套菜单入口

- [ ] **Step 1: 重写 install.sh**

```sh
#!/bin/sh
set -e
SCRIPT_DIR="$(dirname "$0")"

echo "================================"
echo "      dotfiles 安装器"
echo "================================"

while :; do
    echo ""
    echo "  1) Desktop   — 桌面外观"
    echo "  2) Work      — 工作环境"
    echo "  3) Agent     — AI agent 工具链"
    echo "  4) Packages  — 系统软件（分类）"
    echo "  5) VMs       — 虚拟机恢复"
    echo "  0) 退出"
    printf "选择 [0-5]: "
    read choice

    case "$choice" in
        1) sh "$SCRIPT_DIR/profiles/desktop.sh" ;;
        2) sh "$SCRIPT_DIR/profiles/work.sh" ;;
        3) sh "$SCRIPT_DIR/profiles/agent.sh" ;;
        4)
            echo "包分类:"
            for f in "$SCRIPT_DIR"/../packages/*.txt; do
                echo "  $(basename "$f" .txt)"
            done
            printf "输入要安装的分类（空格分隔，或回车跳过）: "
            read cats
            [ -n "$cats" ] && sh "$SCRIPT_DIR/install-packages.sh" $cats
            ;;
        5)
            echo "虚拟机:"
            for f in "$SCRIPT_DIR"/restore/*.sh; do
                echo "  $(basename "$f" .sh)"
            done
            printf "输入要恢复的虚拟机（空格分隔，或回车跳过）: "
            read vms
            [ -n "$vms" ] && for vm in $vms; do sh "$SCRIPT_DIR/restore/$vm.sh"; done
            ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
done
```

- [ ] **Step 2: 语法检查**

```bash
sh -n scripts/install.sh && echo OK
```

- [ ] **Step 3: 提交**

```bash
git add scripts/install.sh
git commit -m "refactor: install.sh 嵌套菜单（Desktop/Work/Agent/Packages/VMs）"
```

---

### Task 9: vms/ 配置目录 + restore 脚本

**Files:**
- Create: `vms/winboat/podman-compose.yml`、`vms/winboat/winboat.config.json`（脱敏）
- Create: `vms/distrobox/containers.list`
- Create: `vms/avd/test.ini`
- Create: `scripts/restore/winboat.sh`
- Create: `scripts/restore/distrobox.sh`
- Create: `scripts/restore/waydroid.sh`
- Create: `scripts/restore/avd.sh`
- Create: `scripts/restore/osx-kvm.sh`
- Create: `scripts/restore/podman.sh`

**Interfaces:**
- Consumes: 本机 `~/.winboat`、`~/.config/libvirt`、`/mnt/E/Rescue`
- Produces: 6 个 restore 脚本，小配置入库，大数据从 Rescue 拷贝

- [ ] **Step 1: 创建 vms/winboat 配置（脱敏）**

```bash
cd /home/lildengzi/Projects/orca/workspaces/dotfiles/chinook
mkdir -p vms/winboat
cp ~/.winboat/podman-compose.yml vms/winboat/
cp ~/.winboat/winboat.config.json vms/winboat/
# 脱敏: 密码换占位符
sed -i 's/PASSWORD: ".*"/PASSWORD: "__CHANGE_ME__"/' vms/winboat/podman-compose.yml
# 验证
grep -n "PASSWORD" vms/winboat/podman-compose.yml
```

- [ ] **Step 2: 创建 vms/distrobox/containers.list**

记录本机 5 个容器（名称 + 镜像）：
```
arch-VM  docker.io/library/archlinux:latest
fedora-VM docker.io/library/fedora:latest
ubuntu-VM docker.io/library/ubuntu:latest
alpine-VM localhost/alpine-fix:latest
gentoo-VM docker.io/gentoo/stage3:latest
```

- [ ] **Step 3: 创建 vms/avd/test.ini**

```bash
cp ~/.android/avd/test.ini vms/avd/
# 路径改为相对/占位
sed -i "s#path=.*#path=~\\.android\\/avd\\/test.avd#" vms/avd/test.ini
```

- [ ] **Step 4: 创建 scripts/restore/winboat.sh**

```sh
#!/bin/sh
# 恢复 winboat（Windows 虚拟机）
set -e
. "$(dirname "$0")/../lib.sh"

RESCUE="/mnt/E/Rescue"
echo "=== 恢复 winboat ==="

# 1. 配置
mkdir -p "$HOME/.winboat" "$HOME/winboat"
cp -r "$DOTFILES/vms/winboat/." "$HOME/.winboat/" 2>/dev/null || true
# 2. 数据（从 Rescue 拷贝）
if [ -d "$RESCUE/home_core/winboat" ]; then
    echo "  从 Rescue 拷贝 winboat 数据..."
    cp -rn "$RESCUE/home_core/winboat/." "$HOME/winboat/"
else
    echo "  未找到 $RESCUE/home_core/winboat，跳过数据拷贝"
fi
# 3. 启动
echo "  运行: cd ~/winboat && podman compose up -d（需自行确认 compose 配置）"
```

- [ ] **Step 5: 创建 scripts/restore/distrobox.sh**

```sh
#!/bin/sh
# 重建 distrobox 容器
set -e
. "$(dirname "$0")/../lib.sh"

LIST="$DOTFILES/vms/distrobox/containers.list"
[ -f "$LIST" ] || { echo "缺少 $LIST" >&2; exit 1; }

echo "=== 重建 distrobox 容器 ==="
grep -v '^#' "$LIST" | grep -v '^[[:space:]]*$' | while read -r name image; do
    if distrobox list 2>/dev/null | grep -qw "$name"; then
        echo "  $name 已存在，跳过"
    else
        echo "  创建 $name ($image)..."
        distrobox create --name "$name" --image "$image"
    fi
done
```

- [ ] **Step 6: 创建其余 restore 脚本（waydroid/avd/osx-kvm/podman）**

`waydroid.sh`：
```sh
#!/bin/sh
set -e
. "$(dirname "$0")/../lib.sh"
echo "=== 恢复 waydroid ==="
# 配置
if [ -d "$DOTFILES/vms/waydroid" ]; then
    mkdir -p "$HOME/.config/waydroid"
    cp -r "$DOTFILES/vms/waydroid/." "$HOME/.config/waydroid/"
fi
# 数据（若 Rescue 有备份）
if [ -d /mnt/E/Rescue/waydroid-data ]; then
    mkdir -p "$HOME/.local/share/waydroid"
    cp -rn /mnt/E/Rescue/waydroid-data/. "$HOME/.local/share/waydroid/"
fi
echo "  完成。运行 waydroid 前需 systemctl start waydroid-container"
```

`avd.sh`：
```sh
#!/bin/sh
set -e
. "$(dirname "$0")/../lib.sh"
echo "=== 恢复 AVD ==="
mkdir -p "$HOME/.android/avd"
if [ -f "$DOTFILES/vms/avd/test.ini" ]; then
    cp "$DOTFILES/vms/avd/test.ini" "$HOME/.android/avd/test.ini"
fi
if [ -d /mnt/E/Rescue/android-avd ]; then
    cp -rn /mnt/E/Rescue/android-avd/test.avd "$HOME/.android/avd/" 2>/dev/null || true
fi
echo "  完成。若 Rescue 无 AVD 数据备份，需用 Android Studio 重建 test.avd"
```

`osx-kvm.sh`：
```sh
#!/bin/sh
set -e
. "$(dirname "$0")/../lib.sh"
echo "=== 恢复 OSX-KVM ==="
if [ -d "$DOTFILES/vms/osx-kvm" ]; then
    mkdir -p "$HOME/osx-kvm"
    cp -rn "$DOTFILES/vms/osx-kvm/." "$HOME/osx-kvm/"
fi
if [ -d /mnt/E/Rescue/osx-kvm ]; then
    cp -rn /mnt/E/Rescue/osx-kvm/. "$HOME/osx-kvm/" 2>/dev/null || true
fi
echo "  完成。OSX-KVM 需重新下载 macOS 镜像: python3 fetch-macOS-v2.py"
```

`podman.sh`：
```sh
#!/bin/sh
set -e
. "$(dirname "$0")/../lib.sh"
echo "=== 恢复 podman 容器 ==="
# 大数据从 Rescue 恢复（若存在）
if [ -d /mnt/E/Rescue/podman-storage ]; then
    mkdir -p "$HOME/.local/share/containers"
    cp -rn /mnt/E/Rescue/podman-storage/. "$HOME/.local/share/containers/"
fi
# 容器清单重建
if [ -f "$DOTFILES/vms/distrobox/containers.list" ]; then
    echo "  提示: distrobox 容器请运行 restore/distrobox.sh"
fi
echo "  完成。podman 容器可用 'podman ps -a' 检查"
```

- [ ] **Step 7: 语法检查**

```bash
sh -n scripts/restore/*.sh && echo OK
```

- [ ] **Step 8: 提交**

```bash
git add vms/ scripts/restore/
git commit -m "feat: vms 配置目录 + 6 个虚拟机恢复脚本（数据从 Rescue 拷贝）"
```

---

### Task 10: README 更新 + 全量验证

**Files:**
- Modify: `README.md`、`README.en.md`、`packages/README.md`

**Interfaces:**
- Consumes: 前面所有任务
- Produces: 文档与新结构一致

- [ ] **Step 1: 更新 README.md**

重写以下章节：
- 「包含什么」表格：去掉 VSCode，加 Agent 工具链
- 「快速安装」：改为嵌套菜单说明（Desktop/Work/Agent/Packages/VMs）
- 「灾难恢复」：更新为 7 分类包清单 + restore 脚本 + Rescue 备份说明
- 「与众不同之处」：补充无敏感信息、壁纸自动归位、硬件通用 + apply-machine
- 「前置依赖」：去 VSCode，加 JDK（可选）

README.en.md 同步。

- [ ] **Step 2: 全量语法检查**

```bash
cd /home/lildengzi/Projects/orca/workspaces/dotfiles/chinook
for f in scripts/*.sh scripts/profiles/*.sh scripts/restore/*.sh; do
    sh -n "$f" || echo "SYNTAX FAIL: $f"
done
echo "syntax check done"
```

- [ ] **Step 3: 敏感信息扫描**

```bash
grep -rn "lildengzi\|PASSWORD:\|/home/" .config/ packages/ scripts/ vms/ .agents/ .claude/ 2>/dev/null || echo "clean"
```

期望：无真实用户名、无密码明文。注意 `apply-machine.sh` 里的 `$HOME` 是安全的。

- [ ] **Step 4: 壁纸核对**

```bash
ls wallpapers | sort > /tmp/wp_final.txt
ls ~/Pictures/wallpapers | sort > /tmp/wp_local_final.txt
diff /tmp/wp_final.txt /tmp/wp_local_final.txt && echo "壁纸 24 张一致"
```

- [ ] **Step 5: 包分类核对**

```bash
cat packages/*.txt | grep -v '^#' | grep -v '^$' | sort -u | wc -l  # 期望 343
diff <(sort /tmp/opencode/explicit.txt) <(cat packages/*.txt | grep -v '^#' | grep -v '^$' | sort -u) && echo "包清单与机器一致"
```

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "docs: README 更新为嵌套菜单 + 分类包清单 + 虚拟机恢复"
```

---

### Task 11: 端到端验证 + 收尾

**Files:**
- 无新增文件（仅验证）

**Interfaces:**
- Consumes: 全部任务产物
- Produces: 验收通过

- [ ] **Step 1: 在副本上试跑 install.sh 无破坏性路径**

```bash
cd /tmp/opencode
cp -r /home/lildengzi/Projects/orca/workspaces/dotfiles/chinook dotfiles-test
cd dotfiles-test
# 只验证菜单能列出、语法通过（不实际执行安装）
sh -c 'for f in scripts/*.sh scripts/profiles/*.sh scripts/restore/*.sh; do sh -n "$f" || exit 1; done; echo "ALL SYNTAX OK"'
```

- [ ] **Step 2: 验证 git 状态干净**

```bash
cd /home/lildengzi/Projects/orca/workspaces/dotfiles/chinook
git status --short
```

期望：无未提交文件（或仅剩明确标记的临时文件）。

- [ ] **Step 3: 分支收尾**

当前分支 `lildengzi/feat-modularize-dotfiles-install`，按仓库惯例提交即可（不自动 push，除非用户要求）。

- [ ] **Step 4: 报告结果**

向用户汇报：结构变更清单、包分类统计、壁纸数、恢复脚本列表、以及需要用户手动确认的事项（如 winboat 启动、AVD 数据缺失、`~/.winboat` 未在 Rescue 备份）。
