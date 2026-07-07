#!/bin/bash
# Ubuntu Terminal Setup — Kitty + Starship + FantasqueSansM Nerd Font
# Usage: bash setup-terminal.sh
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }

echo "=============================="
echo " Terminal Environment Setup"
echo "=============================="
echo ""

# ── 1. 检测 OS ──
. /etc/os-release 2>/dev/null || fail "Cannot detect OS"
echo "OS: $NAME $VERSION_ID"

# ── 2. 安装依赖 ──
echo ""
echo "==> Installing system dependencies..."
sudo apt update -qq
sudo apt install -y -qq curl wget unzip fontconfig git || fail "Failed to install dependencies"
pass "System dependencies installed"

# ── 3. 安装 FantasqueSansM Nerd Font ──
echo ""
echo "==> Installing FantasqueSansM Nerd Font..."
FONT_DIR="${HOME}/.local/share/fonts"
mkdir -p "$FONT_DIR"
if [ ! -f "${FONT_DIR}/FantasqueSansMNerdFontMono-Regular.ttf" ]; then
    wget -q --show-progress "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FantasqueSansM.tar.xz" \
        -O /tmp/FantasqueSansM.tar.xz
    tar xf /tmp/FantasqueSansM.tar.xz -C "$FONT_DIR" 2>/dev/null || true
    fc-cache -f "$FONT_DIR" 2>/dev/null
    rm /tmp/FantasqueSansM.tar.xz
    pass "Font installed"
else
    pass "Font already installed"
fi

# ── 4. 安装 Kitty ──
echo ""
echo "==> Installing Kitty terminal..."
if ! command -v kitty &>/dev/null; then
    curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin 2>/dev/null
    mkdir -p ~/.local/bin
    ln -sf ~/.local/kitty.app/bin/kitty ~/.local/bin/kitty
    ln -sf ~/.local/kitty.app/bin/kitten ~/.local/bin/kitten
    # 确保 ~/.local/bin 在 PATH 中
    case :$PATH: in
        *:$HOME/.local/bin:*) ;;
        *) echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc ;;
    esac
    pass "Kitty installed"
else
    pass "Kitty already installed ($(kitty --version))"
fi

# ── 5. 安装 Starship ──
echo ""
echo "==> Installing Starship prompt..."
if ! command -v starship &>/dev/null; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y 2>/dev/null
    pass "Starship installed"
else
    pass "Starship already installed ($(starship --version | head -1))"
fi

# ── 6. 配置 Kitty（使用默认 Starship 配置） ──
echo ""
echo "==> Configuring Kitty..."
mkdir -p ~/.config/kitty
cat > ~/.config/kitty/kitty.conf << 'KITTYEOF'
font_family FantasqueSansM Nerd Font Mono
font_size 14.0
background_opacity 0.9
window_padding_width 12
KITTYEOF
pass "Kitty configured"

# ── 7. 初始化 Starship（默认主题） ──
echo ""
echo "==> Enabling Starship in bash..."
STARSHIP_LINE='eval "$(starship init bash)"'
if ! grep -q "starship init bash" ~/.bashrc 2>/dev/null; then
    echo "" >> ~/.bashrc
    echo "# Starship prompt" >> ~/.bashrc
    echo "$STARSHIP_LINE" >> ~/.bashrc
    pass "Starship added to ~/.bashrc"
else
    pass "Starship already in ~/.bashrc"
fi

echo ""
echo "=============================="
echo -e "${GREEN} All done!${NC}"
echo "=============================="
echo ""
echo "Next steps:"
echo "  1. Restart your terminal:  exec bash"
echo "  2. Launch Kitty:           kitty"
echo "  3. (Optional) Set Kitty as default terminal emulator:"
echo "     sudo update-alternatives --set x-terminal-emulator ~/.local/bin/kitty"
echo ""
