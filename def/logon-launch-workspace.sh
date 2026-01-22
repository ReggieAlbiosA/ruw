#!/bin/bash
# logon-launch-workspace.sh
# Sets up workspace launcher to run at login via XDG autostart
# Can be run standalone or called from setup.sh

# Note: set -e removed to allow graceful error handling - script continues on failures

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_NAME="launch-workspace.sh"
SCRIPT_DEST="$HOME/Desktop/$SCRIPT_NAME"
AUTOSTART_DIR="$HOME/.config/autostart"
DESKTOP_FILE="$AUTOSTART_DIR/reggie-workspace.desktop"
GITHUB_RAW_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main"

echo -e "\n${CYAN}=== Setting up Workspace Launcher ===${NC}"

# --- Check if already configured ---
if [ -f "$SCRIPT_DEST" ] && [ -f "$DESKTOP_FILE" ]; then
    echo -e "\n${GREEN}✓ Workspace launcher already configured${NC}"
    echo -e "  ${GREEN}+ Launcher: $SCRIPT_DEST${NC}"
    echo -e "  ${GREEN}+ Autostart: $DESKTOP_FILE${NC}"
    echo -e "\n${YELLOW}To reconfigure, delete these files and run again.${NC}"
    echo -e "${YELLOW}To customize, edit: $SCRIPT_DEST${NC}"
    exit 0
fi

# --- Step 1: Install workspace launcher to Desktop ---
echo -e "\n${NC}[1/3] Installing workspace launcher${NC}"

# Create Desktop directory if it doesn't exist
DESKTOP_DIR="$HOME/Desktop"
if [ ! -d "$DESKTOP_DIR" ]; then
    mkdir -p "$DESKTOP_DIR"
    echo -e "  ${YELLOW}+ Created Desktop directory: $DESKTOP_DIR${NC}"
fi

# Check if launcher already exists
if [ -f "$SCRIPT_DEST" ]; then
    echo -e "  ${GREEN}✓ Launcher already exists: $SCRIPT_DEST${NC}"
else
    # Determine script location (local or remote)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
    LOCAL_LAUNCHER="$SCRIPT_DIR/$SCRIPT_NAME"

    if [ -f "$LOCAL_LAUNCHER" ]; then
        # Local: copy the script
        if cp "$LOCAL_LAUNCHER" "$SCRIPT_DEST"; then
            echo -e "  ${GREEN}+ Copied from local: $LOCAL_LAUNCHER${NC}"
        else
            echo -e "  ${RED}! Failed to copy launcher script${NC}"
        fi
    else
        # Remote: download from GitHub
        LAUNCHER_URL="$GITHUB_RAW_URL/$SCRIPT_NAME"
        echo -e "  ${CYAN}> Downloading $SCRIPT_NAME...${NC}"
        if curl -fsSL "$LAUNCHER_URL" -o "$SCRIPT_DEST"; then
            echo -e "  ${GREEN}+ Downloaded from GitHub${NC}"
        else
            echo -e "  ${RED}! Failed to download launcher (network error or 404)${NC}"
        fi
    fi

    if [ -f "$SCRIPT_DEST" ]; then
        chmod +x "$SCRIPT_DEST"
        echo -e "  ${GREEN}+ Installed to: $SCRIPT_DEST${NC}"
    fi
fi

# --- Step 2: Setup autostart directory ---
echo -e "\n${NC}[2/3] Setting up autostart${NC}"

# Create autostart directory if it doesn't exist
if [ ! -d "$AUTOSTART_DIR" ]; then
    mkdir -p "$AUTOSTART_DIR"
    echo -e "  ${YELLOW}+ Created autostart directory${NC}"
else
    echo -e "  ${GREEN}✓ Autostart directory exists${NC}"
fi

# --- Step 3: Create XDG autostart entry ---
echo -e "\n${NC}[3/3] Creating autostart entry${NC}"

if [ -f "$DESKTOP_FILE" ]; then
    echo -e "  ${GREEN}✓ Autostart entry already exists${NC}"
else
    if cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Type=Application
Name=Reggie Workspace
Comment=Opens browser tabs and apps on login
Exec=$SCRIPT_DEST
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    then
        echo -e "  ${GREEN}+ Autostart entry created${NC}"
    else
        echo -e "  ${RED}! Failed to create autostart entry${NC}"
    fi
fi

# --- Summary ---
echo -e "\n${CYAN}=== Workspace Launcher Setup Complete ===${NC}"
echo -e "  ${GREEN}✓ Launcher: $SCRIPT_DEST${NC}"
echo -e "  ${GREEN}✓ Autostart: $DESKTOP_FILE${NC}"
echo -e "\n${YELLOW}To customize:${NC}"
echo -e "  Edit: $SCRIPT_DEST"
echo -e "\n${YELLOW}To test now:${NC}"
echo -e "  Run: $SCRIPT_DEST"
echo -e "\n${YELLOW}To disable autostart:${NC}"
echo -e "  Delete: $DESKTOP_FILE"
