#!/bin/bash
# setup.sh
# Run with: curl -fsSL https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/setup.sh | bash
#
# Install overrides:
#   -y, --yes           Auto-accept all prompts (including optional modules)
#   --skip-optional     Skip optional modules (Claude Code, Git Identity)
#   --defaults-only     Same as --skip-optional

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default flags
AUTO_YES=false
SKIP_OPTIONAL=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        --skip-optional|--defaults-only)
            SKIP_OPTIONAL=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: setup.sh [-y|--yes] [--skip-optional|--defaults-only]"
            exit 1
            ;;
    esac
done

# Helper function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Helper function to prompt user (respects AUTO_YES flag)
prompt_install() {
    if [ "$AUTO_YES" = true ]; then
        return 0  # Auto-accept
    fi
    read -p "  > Install $1? (y/n) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Helper function to prompt for optional modules
prompt_optional() {
    if [ "$SKIP_OPTIONAL" = true ]; then
        return 1  # Skip
    fi
    if [ "$AUTO_YES" = true ]; then
        return 0  # Auto-accept
    fi
    read -p "  > Install $1? (y/n) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

echo -e "\n${CYAN}=== Reggie Ubuntu Workspace Setup ===${NC}"

if [ "$AUTO_YES" = true ]; then
    echo -e "${GRAY}  Running with --yes (auto-accept all)${NC}"
fi
if [ "$SKIP_OPTIONAL" = true ]; then
    echo -e "${GRAY}  Running with --skip-optional${NC}"
fi

# ============================================
# Core Dependencies (Auto-install)
# ============================================
echo -e "\n${CYAN}=== Installing Core Dependencies ===${NC}"

# --- Check Node.js ---
echo -e "\n${NC}[1/6] Node.js${NC}"
if command_exists node; then
    echo -e "  ${GREEN}+ Already installed: $(node --version)${NC}"
else
    echo -e "  ${YELLOW}- Not installed${NC}"
    echo -e "  ${CYAN}> Installing Node.js...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    if command_exists node; then
        echo -e "  ${GREEN}+ Installed: $(node --version)${NC}"
    else
        echo -e "  ${YELLOW}! Installation failed${NC}"
    fi
fi

# --- Check Git ---
echo -e "\n${NC}[2/6] Git${NC}"
if command_exists git; then
    echo -e "  ${GREEN}+ Already installed: $(git --version)${NC}"
else
    echo -e "  ${YELLOW}- Not installed${NC}"
    echo -e "  ${CYAN}> Installing Git...${NC}"
    sudo apt-get update && sudo apt-get install -y git
    if command_exists git; then
        echo -e "  ${GREEN}+ Installed: $(git --version)${NC}"
    else
        echo -e "  ${YELLOW}! Installation failed${NC}"
    fi
fi

# --- Check pnpm ---
echo -e "\n${NC}[3/6] pnpm${NC}"
if command_exists pnpm; then
    echo -e "  ${GREEN}+ Already installed: v$(pnpm --version)${NC}"
else
    echo -e "  ${YELLOW}- Not installed${NC}"
    echo -e "  ${CYAN}> Installing pnpm...${NC}"
    curl -fsSL https://get.pnpm.io/install.sh | sh -
    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
    if command_exists pnpm; then
        echo -e "  ${GREEN}+ Installed: v$(pnpm --version)${NC}"
    else
        echo -e "  ${YELLOW}! Installed. Restart terminal to use pnpm.${NC}"
    fi
fi

# --- Check VS Code ---
echo -e "\n${NC}[4/6] VS Code${NC}"
if command_exists code; then
    echo -e "  ${GREEN}+ Already installed: $(code --version | head -1)${NC}"
else
    echo -e "  ${YELLOW}- Not installed${NC}"
    echo -e "  ${CYAN}> Installing VS Code...${NC}"
    sudo snap install code --classic
    if command_exists code; then
        echo -e "  ${GREEN}+ Installed: $(code --version | head -1)${NC}"
    else
        echo -e "  ${YELLOW}! Installed. Restart terminal to use code.${NC}"
    fi
fi

# --- Check Cursor ---
echo -e "\n${NC}[5/6] Cursor${NC}"
if command_exists cursor; then
    echo -e "  ${GREEN}+ Already installed${NC}"
else
    echo -e "  ${YELLOW}- Not installed${NC}"
    echo -e "  ${CYAN}> Installing Cursor...${NC}"
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
fi

# --- Check Google Antigravity ---
echo -e "\n${NC}[6/6] Google Antigravity${NC}"
if command_exists antigravity; then
    echo -e "  ${GREEN}+ Already installed${NC}"
else
    echo -e "  ${YELLOW}- Not installed${NC}"
    echo -e "  ${CYAN}> Installing Google Antigravity...${NC}"
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
fi

# ============================================
# Workspace Launcher (Auto-setup)
# ============================================
echo -e "\n${CYAN}=== Setting up Workspace Launcher ===${NC}"

# Determine script location (local or remote)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
LAUNCHER_SETUP_SCRIPT="$SCRIPT_DIR/logon-launch-workspace.sh"

if [ -f "$LAUNCHER_SETUP_SCRIPT" ]; then
    source "$LAUNCHER_SETUP_SCRIPT"
else
    LAUNCHER_SETUP_URL="https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/logon-launch-workspace.sh"
    echo -e "  ${CYAN}> Downloading logon-launch-workspace.sh...${NC}"
    curl -fsSL "$LAUNCHER_SETUP_URL" | bash
fi

# ============================================
# Bash Aliases (Auto-setup)
# ============================================
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

if grep -q "$START_MARKER" "$BASHRC" 2>/dev/null; then
    sed -i "/$START_MARKER/,/$END_MARKER/d" "$BASHRC"
    echo "$ALIASES_CONTENT" >> "$BASHRC"
    echo -e "  ${GREEN}+ Bash aliases updated in: $BASHRC${NC}"
else
    echo "" >> "$BASHRC"
    echo "$ALIASES_CONTENT" >> "$BASHRC"
    echo -e "  ${GREEN}+ Bash aliases added to: $BASHRC${NC}"
fi

echo -e "\n${GREEN}=== Default Setup Complete ===${NC}"
echo -e "  ${GREEN}+ Core dependencies installed${NC}"
echo -e "  ${GREEN}+ Workspace launcher configured (runs at login)${NC}"
echo -e "  ${GREEN}+ Bash aliases configured (restart terminal to use)${NC}"

# ============================================
# Optional Modules (Sequential Installation)
# ============================================
if [ "$SKIP_OPTIONAL" = true ]; then
    echo -e "\n${GRAY}=== Optional Modules Skipped ===${NC}"
else
    echo -e "\n${MAGENTA}=== Optional Modules ===${NC}"
    echo -e "${GRAY}  The following modules are optional. You will be prompted for each.${NC}"

    # --- [1/2] Claude Code Setup ---
    echo -e "\n${MAGENTA}--- Step 1 of 2: Claude Code ---${NC}"

    if command_exists claude; then
        claude_version=$(claude --version 2>/dev/null)
        echo -e "  ${GREEN}+ Already installed: $claude_version${NC}"
        echo -e "  ${GRAY}i Run 'claude-code-setup.sh' separately to reconfigure MCP servers${NC}"
        echo -e "  ${GREEN}[1/2] Complete${NC}"
    else
        echo -e "  ${YELLOW}- Not installed${NC}"
        if prompt_optional "Claude Code (includes MCP servers setup)"; then
            echo -e "  ${CYAN}> Running Claude Code setup...${NC}"
            echo ""

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            CLAUDE_SETUP_SCRIPT="$SCRIPT_DIR/claude-code-setup.sh"

            if [ -f "$CLAUDE_SETUP_SCRIPT" ]; then
                bash "$CLAUDE_SETUP_SCRIPT"
            else
                CLAUDE_SETUP_URL="https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/claude-code-setup.sh"
                echo -e "  ${CYAN}> Downloading claude-code-setup.sh...${NC}"
                curl -fsSL "$CLAUDE_SETUP_URL" -o /tmp/claude-code-setup.sh
                bash /tmp/claude-code-setup.sh
                rm -f /tmp/claude-code-setup.sh
            fi

            echo -e "\n  ${GREEN}[1/2] Claude Code setup complete${NC}"
        else
            echo -e "  ${GRAY}> Skipped${NC}"
            echo -e "  ${GRAY}[1/2] Skipped${NC}"
        fi
    fi

    # Wait for user to see the completion before moving on
    echo ""

    # --- [2/2] Git Identity Manager ---
    echo -e "${MAGENTA}--- Step 2 of 2: Git Identity Manager ---${NC}"

    if [ -f "$HOME/.git-hooks/pre-commit" ] && [ -f "$HOME/.git-identities" ]; then
        identity_count=$(wc -l < "$HOME/.git-identities")
        echo -e "  ${GREEN}+ Already configured with $identity_count identity/identities${NC}"
        echo -e "  ${GRAY}i Run 'git-identity-setup.sh' separately to reconfigure${NC}"
        echo -e "  ${GREEN}[2/2] Complete${NC}"
    else
        echo -e "  ${YELLOW}- Not configured${NC}"
        if prompt_optional "Git Identity Manager (prompts for author on each commit)"; then
            echo -e "  ${CYAN}> Running Git Identity Manager setup...${NC}"
            echo ""

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            GIT_IDENTITY_SCRIPT="$SCRIPT_DIR/git-identity-setup.sh"

            if [ -f "$GIT_IDENTITY_SCRIPT" ]; then
                bash "$GIT_IDENTITY_SCRIPT"
            else
                GIT_IDENTITY_URL="https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/git-identity-setup.sh"
                echo -e "  ${CYAN}> Downloading git-identity-setup.sh...${NC}"
                curl -fsSL "$GIT_IDENTITY_URL" -o /tmp/git-identity-setup.sh
                bash /tmp/git-identity-setup.sh
                rm -f /tmp/git-identity-setup.sh
            fi

            echo -e "\n  ${GREEN}[2/2] Git Identity Manager setup complete${NC}"
        else
            echo -e "  ${GRAY}> Skipped${NC}"
            echo -e "  ${GRAY}[2/2] Skipped${NC}"
        fi
    fi
fi

echo -e "\n${GREEN}=== All Setup Complete ===${NC}"
echo -e "Restart your terminal for all changes to take effect."
