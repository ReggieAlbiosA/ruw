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
# Progress Bar Functions
# ============================================

# Progress bar width
BAR_WIDTH=30

# Draw a progress bar
# Usage: draw_progress_bar <current> <total> <label>
draw_progress_bar() {
    local current=$1
    local total=$2
    local label=$3
    local percent=$((current * 100 / total))
    local filled=$((current * BAR_WIDTH / total))
    local empty=$((BAR_WIDTH - filled))

    # Build the bar
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    # Print progress bar (overwrite line)
    printf "\r  ${CYAN}[${GREEN}%s${GRAY}%s${CYAN}]${NC} ${WHITE}%3d%%${NC} %s" \
        "$(printf '█%.0s' $(seq 1 $filled 2>/dev/null) 2>/dev/null || echo "")" \
        "$(printf '░%.0s' $(seq 1 $empty 2>/dev/null) 2>/dev/null || echo "")" \
        "$percent" "$label"
}

# Simpler progress bar that works better cross-platform
show_progress() {
    local current=$1
    local total=$2
    local label=$3
    local percent=$((current * 100 / total))
    local filled=$((current * BAR_WIDTH / total))
    local empty=$((BAR_WIDTH - filled))

    local bar_filled=""
    local bar_empty=""

    for ((i=0; i<filled; i++)); do bar_filled+="█"; done
    for ((i=0; i<empty; i++)); do bar_empty+="░"; done

    echo -e "  ${CYAN}[${GREEN}${bar_filled}${GRAY}${bar_empty}${CYAN}]${NC} ${WHITE}${percent}%${NC} ${label}"
}

# Spinner for active installations
# Usage: run_with_spinner "command" "message"
run_with_spinner() {
    local cmd=$1
    local msg=$2
    local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local pid

    # Run command in background
    eval "$cmd" &>/dev/null &
    pid=$!

    # Show spinner while command runs
    local i=0
    while kill -0 $pid 2>/dev/null; do
        local char="${spin_chars:$i:1}"
        printf "\r  ${CYAN}%s${NC} %s" "$char" "$msg"
        i=$(( (i + 1) % ${#spin_chars} ))
        sleep 0.1
    done

    # Wait for command to finish and get exit code
    wait $pid
    local exit_code=$?

    # Clear spinner line
    printf "\r%*s\r" 60 ""

    return $exit_code
}

# Simple progress indicator that shows activity
show_installing() {
    local name=$1
    echo -e "  ${CYAN}⟳${NC} Installing ${name}..."
}

show_complete() {
    local name=$1
    local version=$2
    if [ -n "$version" ]; then
        echo -e "  ${GREEN}✓${NC} ${name} installed: ${version}"
    else
        echo -e "  ${GREEN}✓${NC} ${name} installed"
    fi
}

show_already_installed() {
    local name=$1
    local version=$2
    echo -e "  ${GREEN}✓${NC} ${name} already installed: ${version}"
}

show_failed() {
    local name=$1
    echo -e "  ${RED}✗${NC} ${name} installation failed"
}

show_skipped() {
    local name=$1
    echo -e "  ${GRAY}○${NC} ${name} skipped"
}

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

echo -e "\n${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}    ${WHITE}Reggie Ubuntu Workspace Setup${NC}       ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"

if [ "$AUTO_YES" = true ]; then
    echo -e "${GRAY}  Running with --yes (auto-accept all)${NC}"
fi
if [ "$SKIP_OPTIONAL" = true ]; then
    echo -e "${GRAY}  Running with --skip-optional${NC}"
fi

# ============================================
# Core Dependencies (Auto-install)
# ============================================
echo -e "\n${CYAN}━━━ Installing Core Dependencies ━━━${NC}"
echo ""

CORE_TOTAL=6
CORE_CURRENT=0

# --- Check Node.js ---
echo -e "${WHITE}[1/6] Node.js${NC}"
if command_exists node; then
    show_already_installed "Node.js" "$(node --version)"
else
    show_installing "Node.js"
    curl -fsSL https://deb.nodesource.com/setup_lts.x 2>/dev/null | sudo -E bash - &>/dev/null
    sudo apt-get install -y nodejs &>/dev/null
    if command_exists node; then
        show_complete "Node.js" "$(node --version)"
    else
        show_failed "Node.js"
    fi
fi
CORE_CURRENT=$((CORE_CURRENT + 1))
show_progress $CORE_CURRENT $CORE_TOTAL "Core dependencies"
echo ""

# --- Check Git ---
echo -e "${WHITE}[2/6] Git${NC}"
if command_exists git; then
    show_already_installed "Git" "$(git --version | cut -d' ' -f3)"
else
    show_installing "Git"
    sudo apt-get update &>/dev/null && sudo apt-get install -y git &>/dev/null
    if command_exists git; then
        show_complete "Git" "$(git --version | cut -d' ' -f3)"
    else
        show_failed "Git"
    fi
fi
CORE_CURRENT=$((CORE_CURRENT + 1))
show_progress $CORE_CURRENT $CORE_TOTAL "Core dependencies"
echo ""

# --- Check pnpm ---
echo -e "${WHITE}[3/6] pnpm${NC}"
if command_exists pnpm; then
    show_already_installed "pnpm" "v$(pnpm --version)"
else
    show_installing "pnpm"
    curl -fsSL https://get.pnpm.io/install.sh 2>/dev/null | sh - &>/dev/null
    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
    if command_exists pnpm; then
        show_complete "pnpm" "v$(pnpm --version)"
    else
        echo -e "  ${YELLOW}!${NC} pnpm installed (restart terminal to use)"
    fi
fi
CORE_CURRENT=$((CORE_CURRENT + 1))
show_progress $CORE_CURRENT $CORE_TOTAL "Core dependencies"
echo ""

# --- Check VS Code ---
echo -e "${WHITE}[4/6] VS Code${NC}"
if command_exists code; then
    show_already_installed "VS Code" "v$(code --version 2>/dev/null | head -1)"
else
    show_installing "VS Code"
    sudo snap install code --classic &>/dev/null
    if command_exists code; then
        show_complete "VS Code" "v$(code --version 2>/dev/null | head -1)"
    else
        echo -e "  ${YELLOW}!${NC} VS Code installed (restart terminal to use)"
    fi
fi
CORE_CURRENT=$((CORE_CURRENT + 1))
show_progress $CORE_CURRENT $CORE_TOTAL "Core dependencies"
echo ""

# --- Check Cursor ---
echo -e "${WHITE}[5/6] Cursor${NC}"
if command_exists cursor; then
    show_already_installed "Cursor" ""
else
    show_installing "Cursor"
    CURSOR_DIR="$HOME/.local/bin"
    mkdir -p "$CURSOR_DIR"
    curl -fsSL "https://downloader.cursor.sh/linux/appImage/x64" -o "$CURSOR_DIR/cursor.AppImage" 2>/dev/null
    chmod +x "$CURSOR_DIR/cursor.AppImage"
    ln -sf "$CURSOR_DIR/cursor.AppImage" "$CURSOR_DIR/cursor"
    export PATH="$CURSOR_DIR:$PATH"
    if [ -f "$CURSOR_DIR/cursor.AppImage" ]; then
        show_complete "Cursor" ""
    else
        show_failed "Cursor"
    fi
fi
CORE_CURRENT=$((CORE_CURRENT + 1))
show_progress $CORE_CURRENT $CORE_TOTAL "Core dependencies"
echo ""

# --- Check Google Antigravity ---
echo -e "${WHITE}[6/6] Google Antigravity${NC}"
if command_exists antigravity; then
    show_already_installed "Antigravity" ""
else
    show_installing "Google Antigravity"
    ANTIGRAVITY_DIR="$HOME/.local/bin"
    mkdir -p "$ANTIGRAVITY_DIR"
    curl -fsSL "https://antigravity.codes/download/linux" -o "$ANTIGRAVITY_DIR/antigravity.AppImage" 2>/dev/null
    chmod +x "$ANTIGRAVITY_DIR/antigravity.AppImage"
    ln -sf "$ANTIGRAVITY_DIR/antigravity.AppImage" "$ANTIGRAVITY_DIR/antigravity"
    export PATH="$ANTIGRAVITY_DIR:$PATH"
    if [ -f "$ANTIGRAVITY_DIR/antigravity.AppImage" ]; then
        show_complete "Antigravity" ""
    else
        show_failed "Antigravity"
    fi
fi
CORE_CURRENT=$((CORE_CURRENT + 1))
show_progress $CORE_CURRENT $CORE_TOTAL "Core dependencies"
echo ""

echo -e "${GREEN}✓ Core dependencies complete${NC}"

# ============================================
# Workspace Launcher (Auto-setup)
# ============================================
echo -e "\n${CYAN}━━━ Setting up Workspace Launcher ━━━${NC}"
echo ""

show_progress 0 2 "Workspace setup"
echo ""

# Step 1: Download launcher
echo -e "${WHITE}[1/2] Downloading launcher${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
LAUNCHER_SETUP_SCRIPT="$SCRIPT_DIR/logon-launch-workspace.sh"

if [ -f "$LAUNCHER_SETUP_SCRIPT" ]; then
    show_installing "workspace launcher"
    bash "$LAUNCHER_SETUP_SCRIPT" &>/dev/null
    show_complete "Workspace launcher" ""
else
    show_installing "workspace launcher"
    LAUNCHER_SETUP_URL="https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/logon-launch-workspace.sh"
    curl -fsSL "$LAUNCHER_SETUP_URL" -o /tmp/logon-launch-workspace.sh 2>/dev/null
    bash /tmp/logon-launch-workspace.sh &>/dev/null
    rm -f /tmp/logon-launch-workspace.sh
    show_complete "Workspace launcher" ""
fi

show_progress 1 2 "Workspace setup"
echo ""

# Step 2: Setup bash aliases
echo -e "${WHITE}[2/2] Configuring aliases${NC}"
show_installing "bash aliases"

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
else
    echo "" >> "$BASHRC"
    echo "$ALIASES_CONTENT" >> "$BASHRC"
fi

show_complete "Bash aliases" ""
show_progress 2 2 "Workspace setup"
echo ""

echo -e "${GREEN}✓ Workspace setup complete${NC}"

# ============================================
# Default Setup Summary
# ============================================
echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}      ${WHITE}Default Setup Complete${NC}            ${GREEN}║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo -e "  ${GREEN}✓${NC} Core dependencies installed"
echo -e "  ${GREEN}✓${NC} Workspace launcher configured"
echo -e "  ${GREEN}✓${NC} Bash aliases configured"

# ============================================
# Optional Modules (Sequential Installation)
# ============================================
if [ "$SKIP_OPTIONAL" = true ]; then
    echo -e "\n${GRAY}━━━ Optional Modules Skipped ━━━${NC}"
else
    echo -e "\n${MAGENTA}━━━ Optional Modules ━━━${NC}"
    echo -e "${GRAY}  You will be prompted for each optional module.${NC}"
    echo ""

    OPT_TOTAL=2
    OPT_CURRENT=0

    show_progress $OPT_CURRENT $OPT_TOTAL "Optional modules"
    echo ""

    # --- [1/2] Claude Code Setup ---
    echo -e "${MAGENTA}┌─ Step 1 of 2: Claude Code ─┐${NC}"

    if command_exists claude; then
        claude_version=$(claude --version 2>/dev/null)
        show_already_installed "Claude Code" "$claude_version"
        echo -e "  ${GRAY}ℹ Run 'claude-code-setup.sh' to reconfigure MCP servers${NC}"
    else
        echo -e "  ${YELLOW}○${NC} Not installed"
        if prompt_optional "Claude Code (includes MCP servers)"; then
            echo ""
            show_installing "Claude Code"
            echo ""

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            CLAUDE_SETUP_SCRIPT="$SCRIPT_DIR/claude-code-setup.sh"

            if [ -f "$CLAUDE_SETUP_SCRIPT" ]; then
                bash "$CLAUDE_SETUP_SCRIPT"
            else
                CLAUDE_SETUP_URL="https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/claude-code-setup.sh"
                curl -fsSL "$CLAUDE_SETUP_URL" -o /tmp/claude-code-setup.sh 2>/dev/null
                bash /tmp/claude-code-setup.sh
                rm -f /tmp/claude-code-setup.sh
            fi

            echo ""
            show_complete "Claude Code" ""
        else
            show_skipped "Claude Code"
        fi
    fi

    OPT_CURRENT=$((OPT_CURRENT + 1))
    show_progress $OPT_CURRENT $OPT_TOTAL "Optional modules"
    echo ""
    echo -e "${MAGENTA}└─ Step 1 complete ─┘${NC}"
    echo ""

    # --- [2/2] Git Identity Manager ---
    echo -e "${MAGENTA}┌─ Step 2 of 2: Git Identity Manager ─┐${NC}"

    if [ -f "$HOME/.git-hooks/pre-commit" ] && [ -f "$HOME/.git-identities" ]; then
        identity_count=$(wc -l < "$HOME/.git-identities")
        show_already_installed "Git Identity Manager" "$identity_count identities"
        echo -e "  ${GRAY}ℹ Run 'git-identity-setup.sh' to reconfigure${NC}"
    else
        echo -e "  ${YELLOW}○${NC} Not configured"
        if prompt_optional "Git Identity Manager"; then
            echo ""
            show_installing "Git Identity Manager"
            echo ""

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            GIT_IDENTITY_SCRIPT="$SCRIPT_DIR/git-identity-setup.sh"

            if [ -f "$GIT_IDENTITY_SCRIPT" ]; then
                bash "$GIT_IDENTITY_SCRIPT"
            else
                GIT_IDENTITY_URL="https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/git-identity-setup.sh"
                curl -fsSL "$GIT_IDENTITY_URL" -o /tmp/git-identity-setup.sh 2>/dev/null
                bash /tmp/git-identity-setup.sh
                rm -f /tmp/git-identity-setup.sh
            fi

            echo ""
            show_complete "Git Identity Manager" ""
        else
            show_skipped "Git Identity Manager"
        fi
    fi

    OPT_CURRENT=$((OPT_CURRENT + 1))
    show_progress $OPT_CURRENT $OPT_TOTAL "Optional modules"
    echo ""
    echo -e "${MAGENTA}└─ Step 2 complete ─┘${NC}"
fi

# ============================================
# Final Summary
# ============================================
echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}        ${WHITE}All Setup Complete!${NC}             ${GREEN}║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
show_progress 8 8 "Total progress"
echo ""
echo -e "${YELLOW}Restart your terminal for all changes to take effect.${NC}"
echo ""
