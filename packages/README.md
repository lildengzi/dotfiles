# Package snapshots

按分类保存的显式安装包快照（`pacman -Qqe`），方便灾难恢复时按需安装。

## 分类

| 文件 | 说明 | 安装方式 |
|------|------|----------|
| `system.txt` | 核心系统：base、引导、文件系统、网络、系统服务 | pacman |
| `desktop.txt` | 桌面/WM 应用：niri、kitty、fcitx5、字体、外观 | pacman |
| `drivers.txt` | 显卡/固件：nvidia、vulkan、amd-ucode、linux-firmware | pacman |
| `cachyos.txt` | CachyOS 专属：linux-cachyos 内核、cachyos-*、paru、chwd | pacman |
| `third-party.txt` | 官方仓库第三方应用：docker、steam、texlive 等 | pacman |
| `aur.txt` | AUR 包：visual-studio-code-bin、brave-bin 等 | paru |
| `toolchain.txt` | 开发工具链（多数为依赖安装，pacman -Qqe 抓不到） | pacman + npm |

## 安装

```sh
# 安装单个分类（官方仓库用 pacman，aur 用 paru）
sh scripts/install-packages.sh desktop aur

# 恢复 agent npm 全局工具（codex 等）
sh scripts/install-agent-tools.sh
```

或在交互式安装器中选择 Packages 分类。

## 更新快照

```sh
pacman -Qqe | sort > packages/system.txt   # 逐个分类维护
# 或更新后手动归入对应分类文件
```

> 注意：`toolchain.txt` 含依赖安装的工具（rust/go/nodejs 等），需手动维护；
> `aur.txt` 内容来自 `pacman -Qqm`。