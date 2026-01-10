#!/bin/bash
# install-ruw.sh - Install ruw CLI tool
# Can be run standalone or from setup.sh

set -e

# ============================================
# Colors
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}Installing ruw CLI tool...${NC}"

# ============================================
# Determine Workspace Path
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUW_SOURCE="$WORKSPACE_DIR/bin/ruw"

if [ ! -f "$RUW_SOURCE" ]; then
    echo -e "${RED}Error: bin/ruw not found at $RUW_SOURCE${NC}"
    exit 1
fi

# ============================================
# Ensure ~/.local/bin Exists and is in PATH
# ============================================
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

# Add to PATH if not already there
if ! echo "$PATH" | grep -q "$LOCAL_BIN"; then
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
        echo -e "${YELLOW}Adding $LOCAL_BIN to PATH in ~/.bashrc${NC}"
        echo '' >> "$HOME/.bashrc"
        echo '# Added by ruw installation' >> "$HOME/.bashrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        export PATH="$LOCAL_BIN:$PATH"
    fi
fi

# ============================================
# Create Symlink
# ============================================
RUW_LINK="$LOCAL_BIN/ruw"

if [ -L "$RUW_LINK" ]; then
    # Symlink exists, check if it points to correct location
    CURRENT_TARGET=$(readlink "$RUW_LINK")
    if [ "$CURRENT_TARGET" = "$RUW_SOURCE" ]; then
        echo -e "${GREEN}✓ ruw already installed and up-to-date${NC}"
    else
        echo -e "${YELLOW}Updating existing ruw symlink${NC}"
        rm "$RUW_LINK"
        ln -s "$RUW_SOURCE" "$RUW_LINK"
        echo -e "${GREEN}✓ ruw symlink updated${NC}"
    fi
elif [ -e "$RUW_LINK" ]; then
    echo -e "${RED}Error: $RUW_LINK exists but is not a symlink${NC}"
    exit 1
else
    ln -s "$RUW_SOURCE" "$RUW_LINK"
    echo -e "${GREEN}✓ Created ruw symlink${NC}"
fi

# Make source executable
chmod +x "$RUW_SOURCE"

# ============================================
# Initialize Workspace Cache
# ============================================
CONFIG_DIR="$HOME/.config/ruw"
mkdir -p "$CONFIG_DIR"
echo "$WORKSPACE_DIR" > "$CONFIG_DIR/workspace-path"

echo -e "${GREEN}✓ Workspace path cached: $WORKSPACE_DIR${NC}"

# ============================================
# Success Message
# ============================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${WHITE}   ruw CLI Tool Installed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}Usage:${NC}"
echo "  ruw --local-update              Update workspace from anywhere"
echo "  ruw --local-update -y           Auto-accept all prompts"
echo "  ruw --help                      Show all commands"
echo ""
echo -e "${YELLOW}Note: Restart your terminal or run 'source ~/.bashrc' to use ruw${NC}"
