#!/bin/bash
# setup.sh
# Run with: curl -fsSL https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/setup.sh | bash
#
# Install overrides:
#   -y, --yes           Auto-accept all prompts
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
WHITE='\033[1;37m'
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

# ============================================
# Helper Functions
# ============================================

command_exists() {
    command -v "$1" &> /dev/null
}

# Prompt for installation (respects AUTO_YES)
prompt_install() {
    if [ "$AUTO_YES" = true ]; then
        echo -e "  ${CYAN}> Auto-accepting${NC}"
        return 0
    fi
    while true; do
        read -p "  > Install $1? (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            return 0
        elif [[ $REPLY =~ ^[Nn]$ ]]; then
            return 1
        else
            echo -e "  ${RED}! Invalid input. Please enter 'y' or 'n'${NC}"
        fi
    done
}

# Prompt for optional modules
prompt_optional() {
    if [ "$SKIP_OPTIONAL" = true ]; then
        return 1
    fi
    if [ "$AUTO_YES" = true ]; then
        echo -e "  ${CYAN}> Auto-accepting${NC}"
        return 0
    fi
    while true; do
        read -p "  > Install $1? (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            return 0
        elif [[ $REPLY =~ ^[Nn]$ ]]; then
            return 1
        else
            echo -e "  ${RED}! Invalid input. Please enter 'y' or 'n'${NC}"
        fi
    done
}

# Track installation progress
TOTAL_STEPS=8
CURRENT_STEP=0
INSTALLED_APPS=()
SKIPPED_APPS=()

update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    echo -e "\n  ${CYAN}Progress: ${WHITE}${CURRENT_STEP}/${TOTAL_STEPS}${NC} (${percent}%)"
    echo -e "  ${CYAN}────────────────────────────────${NC}"
}

log_installed() {
    INSTALLED_APPS+=("$1")
    echo -e "  ${GREEN}✓ Added to installed: $1${NC}"
}

log_skipped() {
    SKIPPED_APPS+=("$1")
    echo -e "  ${GRAY}○ Skipped: $1${NC}"
}

show_realtime_header() {
    echo -e "\n  ${YELLOW}┌─ Installation Output ─┐${NC}"
}

show_realtime_footer() {
    echo -e "  ${YELLOW}└───────────────────────┘${NC}"
}

# ============================================
# Main Setup
# ============================================

echo -e "\n${CYAN}========================================${NC}"
echo -e "${WHITE}   Reggie Ubuntu Workspace Setup${NC}"
echo -e "${CYAN}========================================${NC}"

if [ "$AUTO_YES" = true ]; then
    echo -e "${GRAY}  Mode: Auto-accept all${NC}"
fi
if [ "$SKIP_OPTIONAL" = true ]; then
    echo -e "${GRAY}  Mode: Skip optional modules${NC}"
fi

echo -e "\n${CYAN}You will be prompted for each installation.${NC}"

# ============================================
# [1/8] Node.js
# ============================================
echo -e "\n${WHITE}[1/8] Node.js${NC}"
if command_exists node; then
    echo -e "  ${GREEN}✓ Already installed: $(node --version)${NC}"
    log_installed "Node.js $(node --version)"
else
    echo -e "  ${YELLOW}○ Not installed${NC}"
    if prompt_install "Node.js"; then
        echo -e "  ${CYAN}> Installing Node.js (realtime output)...${NC}"
        show_realtime_header
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
        show_realtime_footer
        if command_exists node; then
            echo -e "  ${GREEN}✓ Installed: $(node --version)${NC}"
            log_installed "Node.js $(node --version)"
        else
            echo -e "  ${RED}✗ Installation failed${NC}"
        fi
    else
        log_skipped "Node.js"
    fi
fi
update_progress

# ============================================
# [2/8] Git
# ============================================
echo -e "\n${WHITE}[2/8] Git${NC}"
if command_exists git; then
    echo -e "  ${GREEN}✓ Already installed: $(git --version)${NC}"
    log_installed "Git $(git --version | cut -d' ' -f3)"
else
    echo -e "  ${YELLOW}○ Not installed${NC}"
    if prompt_install "Git"; then
        echo -e "  ${CYAN}> Installing Git (realtime output)...${NC}"
        show_realtime_header
        sudo apt-get update
        sudo apt-get install -y git
        show_realtime_footer
        if command_exists git; then
            echo -e "  ${GREEN}✓ Installed: $(git --version)${NC}"
            log_installed "Git $(git --version | cut -d' ' -f3)"
        else
            echo -e "  ${RED}✗ Installation failed${NC}"
        fi
    else
        log_skipped "Git"
    fi
fi
update_progress

# ============================================
# [3/8] pnpm
# ============================================
echo -e "\n${WHITE}[3/8] pnpm${NC}"
if command_exists pnpm; then
    echo -e "  ${GREEN}✓ Already installed: v$(pnpm --version)${NC}"
    log_installed "pnpm v$(pnpm --version)"
else
    echo -e "  ${YELLOW}○ Not installed${NC}"
    if prompt_install "pnpm"; then
        echo -e "  ${CYAN}> Installing pnpm (realtime output)...${NC}"
        show_realtime_header
        curl -fsSL https://get.pnpm.io/install.sh | sh -
        export PNPM_HOME="$HOME/.local/share/pnpm"
        export PATH="$PNPM_HOME:$PATH"
        show_realtime_footer
        if command_exists pnpm; then
            echo -e "  ${GREEN}✓ Installed: v$(pnpm --version)${NC}"
            log_installed "pnpm v$(pnpm --version)"
        else
            echo -e "  ${YELLOW}! Installed (restart terminal to use)${NC}"
            log_installed "pnpm (restart needed)"
        fi
    else
        log_skipped "pnpm"
    fi
fi
update_progress

# ============================================
# [4/8] VS Code
# ============================================
echo -e "\n${WHITE}[4/8] VS Code${NC}"
if command_exists code; then
    echo -e "  ${GREEN}✓ Already installed: v$(code --version 2>/dev/null | head -1)${NC}"
    log_installed "VS Code v$(code --version 2>/dev/null | head -1)"
else
    echo -e "  ${YELLOW}○ Not installed${NC}"
    if prompt_install "VS Code"; then
        echo -e "  ${CYAN}> Installing VS Code via snap (realtime output)...${NC}"
        show_realtime_header
        sudo snap install code --classic
        show_realtime_footer
        if command_exists code; then
            echo -e "  ${GREEN}✓ Installed: v$(code --version 2>/dev/null | head -1)${NC}"
            log_installed "VS Code v$(code --version 2>/dev/null | head -1)"
        else
            echo -e "  ${YELLOW}! Installed (restart terminal to use)${NC}"
            log_installed "VS Code (restart needed)"
        fi
    else
        log_skipped "VS Code"
    fi
fi
update_progress

# ============================================
# [5/8] Cursor
# ============================================
echo -e "\n${WHITE}[5/8] Cursor${NC}"
if command_exists cursor; then
    echo -e "  ${GREEN}✓ Already installed${NC}"
    log_installed "Cursor"
else
    echo -e "  ${YELLOW}○ Not installed${NC}"
    if prompt_install "Cursor"; then
        echo -e "  ${CYAN}> Downloading Cursor AppImage (realtime output)...${NC}"
        show_realtime_header
        CURSOR_DIR="$HOME/.local/bin"
        mkdir -p "$CURSOR_DIR"
        echo "Downloading from https://downloader.cursor.sh/linux/appImage/x64..."
        curl -fSL "https://downloader.cursor.sh/linux/appImage/x64" -o "$CURSOR_DIR/cursor.AppImage" --progress-bar
        chmod +x "$CURSOR_DIR/cursor.AppImage"
        ln -sf "$CURSOR_DIR/cursor.AppImage" "$CURSOR_DIR/cursor"
        export PATH="$CURSOR_DIR:$PATH"
        echo "Downloaded to $CURSOR_DIR/cursor.AppImage"
        show_realtime_footer
        if [ -f "$CURSOR_DIR/cursor.AppImage" ]; then
            echo -e "  ${GREEN}✓ Installed to ~/.local/bin${NC}"
            log_installed "Cursor"
        else
            echo -e "  ${RED}✗ Installation failed${NC}"
        fi
    else
        log_skipped "Cursor"
    fi
fi
update_progress

# ============================================
# [6/8] Google Antigravity
# ============================================
echo -e "\n${WHITE}[6/8] Google Antigravity${NC}"
if command_exists antigravity; then
    echo -e "  ${GREEN}✓ Already installed${NC}"
    log_installed "Antigravity"
else
    echo -e "  ${YELLOW}○ Not installed${NC}"
    if prompt_install "Google Antigravity"; then
        echo -e "  ${CYAN}> Downloading Antigravity AppImage (realtime output)...${NC}"
        show_realtime_header
        ANTIGRAVITY_DIR="$HOME/.local/bin"
        mkdir -p "$ANTIGRAVITY_DIR"
        echo "Downloading from https://antigravity.codes/download/linux..."
        curl -fSL "https://antigravity.codes/download/linux" -o "$ANTIGRAVITY_DIR/antigravity.AppImage" --progress-bar
        chmod +x "$ANTIGRAVITY_DIR/antigravity.AppImage"
        ln -sf "$ANTIGRAVITY_DIR/antigravity.AppImage" "$ANTIGRAVITY_DIR/antigravity"
        export PATH="$ANTIGRAVITY_DIR:$PATH"
        echo "Downloaded to $ANTIGRAVITY_DIR/antigravity.AppImage"
        show_realtime_footer
        if [ -f "$ANTIGRAVITY_DIR/antigravity.AppImage" ]; then
            echo -e "  ${GREEN}✓ Installed to ~/.local/bin${NC}"
            log_installed "Antigravity"
        else
            echo -e "  ${RED}✗ Installation failed${NC}"
        fi
    else
        log_skipped "Antigravity"
    fi
fi
update_progress

# ============================================
# [7/8] Workspace Launcher + Aliases (auto-install, no prompt)
# ============================================
echo -e "\n${WHITE}[7/8] Workspace Launcher & Bash Aliases${NC}"
echo -e "  ${CYAN}> Configuring workspace automation...${NC}"
{
    echo -e "  ${CYAN}> Configuring workspace launcher...${NC}"
    show_realtime_header

    # Download/run launcher setup
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
    LAUNCHER_SETUP_SCRIPT="$SCRIPT_DIR/logon-launch-workspace.sh"

    if [ -f "$LAUNCHER_SETUP_SCRIPT" ]; then
        echo "Running local logon-launch-workspace.sh..."
        bash "$LAUNCHER_SETUP_SCRIPT"
    else
        LAUNCHER_SETUP_URL="https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/logon-launch-workspace.sh"
        echo "Downloading logon-launch-workspace.sh..."
        curl -fsSL "$LAUNCHER_SETUP_URL" -o /tmp/logon-launch-workspace.sh
        bash /tmp/logon-launch-workspace.sh
        rm -f /tmp/logon-launch-workspace.sh
    fi

    # Setup bash aliases
    echo ""
    echo "Configuring bash aliases..."

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
        echo "Updated bash aliases in $BASHRC"
    else
        echo "" >> "$BASHRC"
        echo "$ALIASES_CONTENT" >> "$BASHRC"
        echo "Added bash aliases to $BASHRC"
    fi

    show_realtime_footer
    echo -e "  ${GREEN}✓ Workspace launcher configured${NC}"
    echo -e "  ${GREEN}✓ Bash aliases configured${NC}"
    log_installed "Workspace Launcher"
    log_installed "Bash Aliases"
}
update_progress

# ============================================
# Summary After Core Setup
# ============================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${WHITE}   Core Setup Complete${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${GREEN}Installed:${NC}"
for app in "${INSTALLED_APPS[@]}"; do
    echo -e "  ${GREEN}✓${NC} $app"
done

if [ ${#SKIPPED_APPS[@]} -gt 0 ]; then
    echo -e "\n${GRAY}Skipped:${NC}"
    for app in "${SKIPPED_APPS[@]}"; do
        echo -e "  ${GRAY}○${NC} $app"
    done
fi

# ============================================
# [8/8] Optional Modules
# ============================================
if [ "$SKIP_OPTIONAL" = true ]; then
    echo -e "\n${GRAY}Optional modules skipped (--skip-optional)${NC}"
    update_progress
else
    echo -e "\n${MAGENTA}========================================${NC}"
    echo -e "${WHITE}   Optional Modules${NC}"
    echo -e "${MAGENTA}========================================${NC}"

    # --- Claude Code ---
    echo -e "\n${MAGENTA}[Optional 1/2] Claude Code${NC}"
    if command_exists claude; then
        claude_version=$(claude --version 2>/dev/null)
        echo -e "  ${GREEN}✓ Already installed: $claude_version${NC}"
        log_installed "Claude Code $claude_version"
        # Still run MCP configuration even if Claude Code is already installed
        if prompt_optional "Configure MCP servers"; then
            echo -e "  ${CYAN}> Configuring MCP servers...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            CLAUDE_SETUP_SCRIPT="$SCRIPT_DIR/claude-code-setup.sh"

            if [ -f "$CLAUDE_SETUP_SCRIPT" ]; then
                bash "$CLAUDE_SETUP_SCRIPT"
            else
                CLAUDE_SETUP_URL="https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/claude-code-setup.sh"
                echo "Downloading claude-code-setup.sh..."
                curl -fsSL "$CLAUDE_SETUP_URL" -o /tmp/claude-code-setup.sh
                bash /tmp/claude-code-setup.sh
                rm -f /tmp/claude-code-setup.sh
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ MCP servers configured${NC}"
        else
            log_skipped "MCP servers"
        fi
    else
        echo -e "  ${YELLOW}○ Not installed${NC}"
        if prompt_optional "Claude Code (includes MCP servers)"; then
            echo -e "  ${CYAN}> Running Claude Code setup (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            CLAUDE_SETUP_SCRIPT="$SCRIPT_DIR/claude-code-setup.sh"

            if [ -f "$CLAUDE_SETUP_SCRIPT" ]; then
                bash "$CLAUDE_SETUP_SCRIPT"
            else
                CLAUDE_SETUP_URL="https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/claude-code-setup.sh"
                echo "Downloading claude-code-setup.sh..."
                curl -fsSL "$CLAUDE_SETUP_URL" -o /tmp/claude-code-setup.sh
                bash /tmp/claude-code-setup.sh
                rm -f /tmp/claude-code-setup.sh
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ Claude Code setup complete${NC}"
            log_installed "Claude Code"
        else
            log_skipped "Claude Code"
        fi
    fi

    echo -e "\n  ${CYAN}Progress: ${WHITE}7.5/8${NC} (94%)"
    echo -e "  ${CYAN}────────────────────────────────${NC}"

    # --- Git Identity Manager ---
    echo -e "\n${MAGENTA}[Optional 2/2] Git Identity Manager${NC}"
    if [ -f "$HOME/.git-hooks/pre-commit" ] && [ -f "$HOME/.git-identities" ]; then
        identity_count=$(wc -l < "$HOME/.git-identities")
        echo -e "  ${GREEN}✓ Already configured: $identity_count identities${NC}"
        log_installed "Git Identity Manager ($identity_count identities)"
    else
        echo -e "  ${YELLOW}○ Not configured${NC}"
        if prompt_optional "Git Identity Manager"; then
            echo -e "  ${CYAN}> Running Git Identity setup (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            GIT_IDENTITY_SCRIPT="$SCRIPT_DIR/git-identity-setup.sh"

            if [ -f "$GIT_IDENTITY_SCRIPT" ]; then
                bash "$GIT_IDENTITY_SCRIPT"
            else
                GIT_IDENTITY_URL="https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/git-identity-setup.sh"
                echo "Downloading git-identity-setup.sh..."
                curl -fsSL "$GIT_IDENTITY_URL" -o /tmp/git-identity-setup.sh
                bash /tmp/git-identity-setup.sh
                rm -f /tmp/git-identity-setup.sh
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ Git Identity Manager setup complete${NC}"
            log_installed "Git Identity Manager"
        else
            log_skipped "Git Identity Manager"
        fi
    fi

    update_progress
fi

# ============================================
# Final Summary
# ============================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${WHITE}   All Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n  ${CYAN}Progress: ${WHITE}8/8${NC} (100%)"
echo -e "  ${CYAN}────────────────────────────────${NC}"

echo -e "\n${GREEN}Final Installed List:${NC}"
for app in "${INSTALLED_APPS[@]}"; do
    echo -e "  ${GREEN}✓${NC} $app"
done

if [ ${#SKIPPED_APPS[@]} -gt 0 ]; then
    echo -e "\n${GRAY}Skipped:${NC}"
    for app in "${SKIPPED_APPS[@]}"; do
        echo -e "  ${GRAY}○${NC} $app"
    done
fi

echo -e "\n${YELLOW}Restart your terminal for all changes to take effect.${NC}"
echo ""
