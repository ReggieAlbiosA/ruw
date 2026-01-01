#!/bin/bash
# setup.sh
# Run with: curl -fsSL https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/setup.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Helper function to prompt user
prompt_install() {
    read -p "  > Install $1? (y/n) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

echo -e "\n${CYAN}=== Checking Dependencies ===${NC}"

# --- Check Node.js ---
echo -e "\n${NC}[1/8] Node.js${NC}"
if command_exists node; then
    echo -e "  ${GREEN}+ Already installed: $(node --version)${NC}"
else
    echo -e "  ${YELLOW}- Not installed${NC}"
    if prompt_install "Node.js"; then
        echo -e "  ${CYAN}> Installing Node.js...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
        if command_exists node; then
            echo -e "  ${GREEN}+ Installed: $(node --version)${NC}"
        else
            echo -e "  ${YELLOW}! Installation failed${NC}"
        fi
    else
        echo -e "  > Skipped"
    fi
fi

# --- Check Git ---
echo -e "\n${NC}[2/8] Git${NC}"
if command_exists git; then
    echo -e "  ${GREEN}+ Already installed: $(git --version)${NC}"
else
    echo -e "  ${YELLOW}- Not installed${NC}"
    if prompt_install "Git"; then
        echo -e "  ${CYAN}> Installing Git...${NC}"
        sudo apt-get update && sudo apt-get install -y git
        if command_exists git; then
            echo -e "  ${GREEN}+ Installed: $(git --version)${NC}"
        else
            echo -e "  ${YELLOW}! Installation failed${NC}"
        fi
    else
        echo -e "  > Skipped"
    fi
fi

# --- Check pnpm ---
echo -e "\n${NC}[3/8] pnpm${NC}"
if command_exists pnpm; then
    echo -e "  ${GREEN}+ Already installed: v$(pnpm --version)${NC}"
else
    echo -e "  ${YELLOW}- Not installed${NC}"
    if prompt_install "pnpm"; then
        echo -e "  ${CYAN}> Installing pnpm...${NC}"
        curl -fsSL https://get.pnpm.io/install.sh | sh -
        export PNPM_HOME="$HOME/.local/share/pnpm"
        export PATH="$PNPM_HOME:$PATH"
        if command_exists pnpm; then
            echo -e "  ${GREEN}+ Installed: v$(pnpm --version)${NC}"
        else
            echo -e "  ${YELLOW}! Installed. Restart terminal to use pnpm.${NC}"
        fi
    else
        echo -e "  > Skipped"
    fi
fi

# --- Check VS Code ---
echo -e "\n${NC}[4/8] VS Code${NC}"
if command_exists code; then
    echo -e "  ${GREEN}+ Already installed: $(code --version | head -1)${NC}"
else
    echo -e "  ${YELLOW}- Not installed${NC}"
    if prompt_install "VS Code"; then
        echo -e "  ${CYAN}> Installing VS Code...${NC}"
        sudo snap install code --classic
        if command_exists code; then
            echo -e "  ${GREEN}+ Installed: $(code --version | head -1)${NC}"
        else
            echo -e "  ${YELLOW}! Installed. Restart terminal to use code.${NC}"
        fi
    else
        echo -e "  > Skipped"
    fi
fi

# --- Check Cursor ---
echo -e "\n${NC}[5/8] Cursor${NC}"
if command_exists cursor; then
    echo -e "  ${GREEN}+ Already installed${NC}"
else
    echo -e "  ${YELLOW}- Not installed${NC}"
    if prompt_install "Cursor"; then
        echo -e "  ${CYAN}> Installing Cursor...${NC}"
        # Download and install Cursor AppImage
        CURSOR_DIR="$HOME/.local/bin"
        mkdir -p "$CURSOR_DIR"
        curl -fsSL "https://downloader.cursor.sh/linux/appImage/x64" -o "$CURSOR_DIR/cursor.AppImage"
        chmod +x "$CURSOR_DIR/cursor.AppImage"
        ln -sf "$CURSOR_DIR/cursor.AppImage" "$CURSOR_DIR/cursor"
        export PATH="$CURSOR_DIR:$PATH"
        if [ -f "$CURSOR_DIR/cursor.AppImage" ]; then
            echo -e "  ${GREEN}+ Installed to $CURSOR_DIR${NC}"
        else
            echo -e "  ${YELLOW}! Installation failed${NC}"
        fi
    else
        echo -e "  > Skipped"
    fi
fi

# --- Check Google Antigravity ---
echo -e "\n${NC}[6/8] Google Antigravity${NC}"
if command_exists antigravity; then
    echo -e "  ${GREEN}+ Already installed${NC}"
else
    echo -e "  ${YELLOW}- Not installed${NC}"
    if prompt_install "Google Antigravity"; then
        echo -e "  ${CYAN}> Installing Google Antigravity...${NC}"
        # Download and install Antigravity
        ANTIGRAVITY_DIR="$HOME/.local/bin"
        mkdir -p "$ANTIGRAVITY_DIR"
        curl -fsSL "https://antigravity.codes/download/linux" -o "$ANTIGRAVITY_DIR/antigravity.AppImage"
        chmod +x "$ANTIGRAVITY_DIR/antigravity.AppImage"
        ln -sf "$ANTIGRAVITY_DIR/antigravity.AppImage" "$ANTIGRAVITY_DIR/antigravity"
        export PATH="$ANTIGRAVITY_DIR:$PATH"
        if [ -f "$ANTIGRAVITY_DIR/antigravity.AppImage" ]; then
            echo -e "  ${GREEN}+ Installed to $ANTIGRAVITY_DIR${NC}"
        else
            echo -e "  ${YELLOW}! Installation failed${NC}"
        fi
    else
        echo -e "  > Skipped"
    fi
fi

# --- Claude Code Setup (Modular) ---
echo -e "\n${NC}[7/8] Claude Code${NC}"
if command_exists claude; then
    claude_version=$(claude --version 2>/dev/null)
    echo -e "  ${GREEN}+ Already installed: $claude_version${NC}"
    echo -e "  ${GRAY}i Run 'claude-code-setup.sh' separately to configure MCP servers${NC}"
else
    echo -e "  ${YELLOW}- Not installed${NC}"
    if prompt_install "Claude Code (includes MCP servers setup)"; then
        echo -e "  ${CYAN}> Running Claude Code setup...${NC}"

        # Determine script location (local or remote)
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        CLAUDE_SETUP_SCRIPT="$SCRIPT_DIR/claude-code-setup.sh"

        if [ -f "$CLAUDE_SETUP_SCRIPT" ]; then
            # Local: source the script
            source "$CLAUDE_SETUP_SCRIPT"
        else
            # Remote: download and execute from GitHub
            CLAUDE_SETUP_URL="https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/claude-code-setup.sh"
            echo -e "  ${CYAN}> Downloading claude-code-setup.sh...${NC}"
            curl -fsSL "$CLAUDE_SETUP_URL" | bash
        fi
    else
        echo -e "  > Skipped"
    fi
fi

# --- Git Identity Manager (Modular) ---
echo -e "\n${NC}[8/8] Git Identity Manager${NC}"
if [ -f "$HOME/.git-hooks/pre-commit" ] && [ -f "$HOME/.git-identities" ]; then
    identity_count=$(wc -l < "$HOME/.git-identities")
    echo -e "  ${GREEN}+ Already configured with $identity_count identity/identities${NC}"
    echo -e "  ${GRAY}i Run 'git-identity-setup.sh' separately to reconfigure${NC}"
else
    echo -e "  ${YELLOW}- Not configured${NC}"
    read -p "  > Install Git Identity Manager (prompts for author on each commit)? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "  ${CYAN}> Running Git Identity Manager setup...${NC}"

        # Determine script location (local or remote)
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        GIT_IDENTITY_SCRIPT="$SCRIPT_DIR/git-identity-setup.sh"

        if [ -f "$GIT_IDENTITY_SCRIPT" ]; then
            # Local: source the script
            source "$GIT_IDENTITY_SCRIPT"
        else
            # Remote: download and execute from GitHub
            GIT_IDENTITY_URL="https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/git-identity-setup.sh"
            echo -e "  ${CYAN}> Downloading git-identity-setup.sh...${NC}"
            curl -fsSL "$GIT_IDENTITY_URL" | bash
        fi
    else
        echo -e "  > Skipped"
    fi
fi

echo -e "\n${CYAN}=== Setting up Workspace Launcher ===${NC}"

# Determine script location (local or remote)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
LAUNCHER_SETUP_SCRIPT="$SCRIPT_DIR/logon-launch-workspace.sh"

if [ -f "$LAUNCHER_SETUP_SCRIPT" ]; then
    # Local: source the script
    source "$LAUNCHER_SETUP_SCRIPT"
else
    # Remote: download and execute from GitHub
    LAUNCHER_SETUP_URL="https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/logon-launch-workspace.sh"
    echo -e "  ${CYAN}> Downloading logon-launch-workspace.sh...${NC}"
    curl -fsSL "$LAUNCHER_SETUP_URL" | bash
fi

# Setup bash aliases
echo -e "\n${YELLOW}Setting up bash aliases...${NC}"

START_MARKER="# >>> REGGIE-WORKSPACE-ALIASES >>>"
END_MARKER="# <<< REGGIE-WORKSPACE-ALIASES <<<"

ALIASES_CONTENT="$START_MARKER
# Git Aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --decorate --graph'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias gpull='git pull'
alias gsw='git switch'

# Directory shortcuts
alias ~='cd ~'
alias ..='cd ..'
alias ...='cd ../..'

# ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Common commands
alias cls='clear'
alias md='mkdir -p'

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
$END_MARKER"

BASHRC="$HOME/.bashrc"

# Check if markers exist in .bashrc
if grep -q "$START_MARKER" "$BASHRC" 2>/dev/null; then
    # Replace existing section
    sed -i "/$START_MARKER/,/$END_MARKER/d" "$BASHRC"
    echo "$ALIASES_CONTENT" >> "$BASHRC"
    echo -e "  ${GREEN}+ Bash aliases updated in: $BASHRC${NC}"
else
    # Append to .bashrc
    echo "" >> "$BASHRC"
    echo "$ALIASES_CONTENT" >> "$BASHRC"
    echo -e "  ${GREEN}+ Bash aliases added to: $BASHRC${NC}"
fi

echo -e "\n${CYAN}=== Setup Complete ===${NC}"
echo -e "  ${GREEN}+ Autostart configured (runs at login)${NC}"
echo -e "  ${GREEN}+ Bash aliases configured (restart terminal to use)${NC}"
echo -e "\nTo test now, run: $SCRIPT_DEST"
echo -e "To manage autostart, check: $DESKTOP_FILE"
# test
