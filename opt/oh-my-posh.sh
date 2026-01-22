#!/usr/bin/env bash
# oh-my-posh.sh
# Oh My Posh installation & configuration script (Bash)

set -e

############################
# Colors
############################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

############################
# Helpers
############################
run_silent() {
    "$@" >/dev/null 2>&1
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo -e "  ${RED}✗ Required command '$1' not found${NC}"
        exit 1
    fi
}

append_if_missing() {
    local line="$1"
    local file="$2"
    grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

############################
# Header
############################
echo -e "\n${CYAN}===================================${NC}"
echo -e "${WHITE}        Oh My Posh Setup${NC}"
echo -e "${CYAN}===================================${NC}"

############################
# Pre-flight checks
############################
require_cmd curl
require_cmd bash
require_cmd grep

############################
# 1. Install Oh My Posh
############################
echo -e "\n${WHITE}[1/5] Installing Oh My Posh binary${NC}"

INSTALL_DIR="$HOME/bin"
mkdir -p "$INSTALL_DIR"

if curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$INSTALL_DIR"; then
    echo -e "  ${GREEN}✓ Installed to $INSTALL_DIR${NC}"
else
    echo -e "  ${RED}✗ Failed to install Oh My Posh${NC}"
    exit 1
fi

############################
# 2. Configure PATH
############################
echo -e "\n${WHITE}[2/5] Configuring PATH${NC}"

if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    export PATH="$HOME/bin:$PATH"
fi

append_if_missing 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"
echo -e "  ${GREEN}✓ PATH configured${NC}"

############################
# 3. Install Font
############################
echo -e "\n${WHITE}[3/5] Installing Meslo Nerd Font${NC}"

if command -v oh-my-posh >/dev/null 2>&1; then
    if oh-my-posh font install meslo; then
        echo -e "  ${GREEN}✓ Meslo Nerd Font installed${NC}"
    else
        echo -e "  ${YELLOW}! Font installation may require manual confirmation${NC}"
    fi
else
    echo -e "  ${YELLOW}! oh-my-posh not yet in PATH; skipping font install${NC}"
fi

############################
# 4. Install Themes
############################
echo -e "\n${WHITE}[4/5] Installing Themes${NC}"

require_cmd wget
require_cmd unzip

THEME_DIR="$HOME/.poshthemes"
TMP_ZIP="/tmp/oh-my-posh-themes.zip"

mkdir -p "$THEME_DIR"
rm -f "$TMP_ZIP"

if wget -q https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip -O "$TMP_ZIP"; then
    if unzip -oq "$TMP_ZIP" -d "$THEME_DIR"; then
        chmod +r "$THEME_DIR"/*.omp.json
        echo -e "  ${GREEN}✓ Themes installed to $THEME_DIR${NC}"
    else
        echo -e "  ${RED}✗ Failed to extract themes${NC}"
    fi
    rm -f "$TMP_ZIP"
else
    echo -e "  ${RED}✗ Failed to download themes${NC}"
fi

############################
# 5. Configure Bash
############################
echo -e "\n${WHITE}[5/5] Configuring Bash${NC}"

INIT_CMD='eval "$(oh-my-posh init bash --config ~/.poshthemes/catppuccin_macchiato.omp.json)"'

if ! grep -q 'oh-my-posh init bash' "$HOME/.bashrc"; then
    {
        echo ""
        echo "# oh-my-posh"
        echo "$INIT_CMD"
    } >> "$HOME/.bashrc"

    echo -e "  ${GREEN}✓ Oh My Posh initialized in .bashrc${NC}"
else
    echo -e "  ${GREEN}✓ Bash already configured${NC}"
    echo -e "  ${YELLOW}ℹ Edit ~/.bashrc to change the theme${NC}"
fi

############################
# Done
############################
echo -e "\n${GREEN}✔ Oh My Posh setup complete!${NC}"
echo -e "${YELLOW}→ Restart your terminal or run:${NC}"
echo -e "${CYAN}  source ~/.bashrc${NC}\n"
