#!/bin/bash
# setup.sh
# Run with: curl -fsSL https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/setup.sh | bash -s -- -y
#
# Install overrides:
#   -y, --yes           Auto-accept all prompts
#   --skip-optional     Skip optional modules (Claude Code, CLI Tools, Git Identity)
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

# Check if running in non-interactive mode (piped from curl)
if [ ! -t 0 ] && [ "$AUTO_YES" != true ]; then
    echo ""
    echo "ERROR: This script requires interactive input or the -y flag."
    echo ""
    echo "Please run with one of these methods:"
    echo "  1. Auto-accept all prompts:"
    echo "     curl -fsSL https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/setup.sh | bash -s -- -y"
    echo ""
    echo "  2. Download and run:"
    echo "     curl -fsSL https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/setup.sh -o setup.sh"
    echo "     chmod +x setup.sh"
    echo "     ./setup.sh"
    echo ""
    exit 1
fi

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
TOTAL_STEPS=7
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

# Get MCP server status using claude mcp list
get_mcp_status() {
    local server_name="$1"
    local mcp_list=$(claude mcp list 2>/dev/null)

    if echo "$mcp_list" | grep -q "^$server_name:.*Connected"; then
        echo "connected"
    elif echo "$mcp_list" | grep -q "^$server_name:.*Failed"; then
        echo "failed"
    else
        echo "notfound"
    fi
}

# Check MCP configuration status - returns number of missing MCPs
# Also displays status summary
check_mcp_configuration() {
    local expected_mcps=("better-auth" "sequential-thinking" "github")
    local missing_mcps=()
    local connected_mcps=()

    echo -e "  ${CYAN}> Checking MCP configurations...${NC}"

    for mcp in "${expected_mcps[@]}"; do
        local status=$(get_mcp_status "$mcp")
        if [ "$status" = "connected" ]; then
            connected_mcps+=("$mcp")
        else
            missing_mcps+=("$mcp")
        fi
    done

    # Show status summary
    echo -e "\n  ${NC}─── MCP Status ───${NC}"
    for mcp in "${connected_mcps[@]}"; do
        echo -e "  ${GREEN}✓ $mcp - Connected${NC}"
    done
    for mcp in "${missing_mcps[@]}"; do
        echo -e "  ${YELLOW}○ $mcp - Not configured${NC}"
    done

    # Store count of missing MCPs in global variable for caller to use
    MISSING_MCP_COUNT=${#missing_mcps[@]}
    return 0
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
# [1/7] Core Packages (Node.js, Git, pnpm)
# ============================================
echo -e "\n${WHITE}[1/7] Core Packages${NC}"
echo -e "  ${GRAY}(Node.js, Git, pnpm - auto-install)${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
PACKAGES_SCRIPT="$SCRIPT_DIR/def/packages.sh"

if [ -f "$PACKAGES_SCRIPT" ]; then
    bash "$PACKAGES_SCRIPT" || {
        echo -e "${RED}Packages installation encountered errors. Continuing...${NC}"
    }
else
    PACKAGES_URL="https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/def/packages.sh"
    echo "Downloading packages.sh..."
    if curl -fsSL "$PACKAGES_URL" -o /tmp/packages.sh; then
        bash /tmp/packages.sh || {
            echo -e "${RED}Packages installation encountered errors. Continuing...${NC}"
        }
        rm -f /tmp/packages.sh
    else
        echo -e "${RED}Failed to download packages.sh. Skipping packages installation.${NC}"
    fi
fi

# Log results for summary
if command_exists node; then
    log_installed "Node.js $(node --version)"
fi
if command_exists git; then
    log_installed "Git $(git --version | cut -d' ' -f3)"
fi
if command_exists pnpm; then
    log_installed "pnpm v$(pnpm --version)"
fi

update_progress

# ============================================
# [2/7] Development Apps (VS Code, Cursor, Antigravity)
# ============================================
echo -e "\n${WHITE}[2/7] Development Apps${NC}"
echo -e "  ${GRAY}(VS Code, Cursor, Antigravity)${NC}"

if prompt_optional "Install development apps"; then
    echo -e "  ${CYAN}> Running apps installation...${NC}"
    show_realtime_header

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
    APPS_SCRIPT="$SCRIPT_DIR/def/apps.sh"

    APPS_FLAGS=""
    [ "$AUTO_YES" = true ] && APPS_FLAGS="$APPS_FLAGS -y"

    if [ -f "$APPS_SCRIPT" ]; then
        bash "$APPS_SCRIPT" $APPS_FLAGS || {
            echo -e "${RED}Apps installation encountered errors. Continuing...${NC}"
        }
    else
        APPS_URL="https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/def/apps.sh"
        echo "Downloading apps.sh..."
        if curl -fsSL "$APPS_URL" -o /tmp/apps.sh; then
            bash /tmp/apps.sh $APPS_FLAGS || {
                echo -e "${RED}Apps installation encountered errors. Continuing...${NC}"
            }
            rm -f /tmp/apps.sh
        else
            echo -e "${RED}Failed to download apps.sh. Skipping apps installation.${NC}"
        fi
    fi

    show_realtime_footer

    # Log results for summary
    if command_exists code; then
        log_installed "VS Code v$(code --version 2>/dev/null | head -1)"
    fi
    if command_exists cursor; then
        log_installed "Cursor"
    fi
    if command_exists antigravity; then
        log_installed "Antigravity"
    fi
else
    log_skipped "Development Apps"
fi

update_progress

# ============================================
# [3/7] Workspace Launcher (auto-install, no prompt)
# ============================================
echo -e "\n${WHITE}[3/7] Workspace Launcher${NC}"
echo -e "  ${CYAN}> Configuring workspace automation...${NC}"
{
    show_realtime_header

    # Download/run launcher setup
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
    LAUNCHER_SETUP_SCRIPT="$SCRIPT_DIR/def/logon-launch-workspace.sh"

    if [ -f "$LAUNCHER_SETUP_SCRIPT" ]; then
        echo "Running local logon-launch-workspace.sh..."
        bash "$LAUNCHER_SETUP_SCRIPT"
    else
        LAUNCHER_SETUP_URL="https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/def/logon-launch-workspace.sh"
        echo "Downloading logon-launch-workspace.sh..."
        curl -fsSL "$LAUNCHER_SETUP_URL" -o /tmp/logon-launch-workspace.sh
        bash /tmp/logon-launch-workspace.sh
        rm -f /tmp/logon-launch-workspace.sh
    fi

    show_realtime_footer
    echo -e "  ${GREEN}✓ Workspace launcher configured${NC}"
    log_installed "Workspace Launcher"
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
# [4/7] Optional Modules
# ============================================
if [ "$SKIP_OPTIONAL" = true ]; then
    echo -e "\n${GRAY}Optional modules skipped (--skip-optional)${NC}"
    update_progress
else
    echo -e "\n${MAGENTA}========================================${NC}"
    echo -e "${WHITE}   Optional Modules${NC}"
    echo -e "${MAGENTA}========================================${NC}"

    # --- Claude Code ---
    echo -e "\n${MAGENTA}[Optional 1/4] Claude Code${NC}"
    if command_exists claude; then
        claude_version=$(claude --version 2>/dev/null)
        echo -e "  ${GREEN}✓ Already installed: $claude_version${NC}"
        log_installed "Claude Code $claude_version"

        # Check MCP configuration status FIRST using claude mcp list
        check_mcp_configuration

        if [ "$MISSING_MCP_COUNT" -eq 0 ]; then
            # All MCPs already configured - no prompt needed
            echo -e "\n  ${GREEN}All MCP servers already configured!${NC}"
        else
            # Some MCPs missing - ask to configure
            if prompt_optional "Configure $MISSING_MCP_COUNT missing MCP(s)"; then
                echo -e "  ${CYAN}> Configuring missing MCP servers...${NC}"
                show_realtime_header

                SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
                CLAUDE_SETUP_SCRIPT="$SCRIPT_DIR/opt/claude-code.sh"

                if [ -f "$CLAUDE_SETUP_SCRIPT" ]; then
                    bash "$CLAUDE_SETUP_SCRIPT"
                else
                    CLAUDE_SETUP_URL="https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/opt/claude-code.sh"
                    echo "Downloading claude-code.sh..."
                    curl -fsSL "$CLAUDE_SETUP_URL" -o /tmp/claude-code.sh
                    bash /tmp/claude-code.sh
                    rm -f /tmp/claude-code.sh
                fi

                show_realtime_footer
                echo -e "  ${GREEN}✓ MCP servers configured${NC}"
            else
                log_skipped "MCP servers"
            fi
        fi
    else
        echo -e "  ${YELLOW}○ Not installed${NC}"
        if prompt_optional "Claude Code (includes MCP servers)"; then
            echo -e "  ${CYAN}> Running Claude Code setup (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            CLAUDE_SETUP_SCRIPT="$SCRIPT_DIR/opt/claude-code.sh"

            if [ -f "$CLAUDE_SETUP_SCRIPT" ]; then
                bash "$CLAUDE_SETUP_SCRIPT"
            else
                CLAUDE_SETUP_URL="https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/opt/claude-code.sh"
                echo "Downloading claude-code.sh..."
                curl -fsSL "$CLAUDE_SETUP_URL" -o /tmp/claude-code.sh
                bash /tmp/claude-code.sh
                rm -f /tmp/claude-code.sh
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ Claude Code setup complete${NC}"
            log_installed "Claude Code"
        else
            log_skipped "Claude Code"
        fi
    fi

    echo -e "\n  ${CYAN}Progress: ${WHITE}4/7${NC} (57%)"
    echo -e "  ${CYAN}────────────────────────────────${NC}"

    # --- Modern CLI Tools ---
    echo -e "\n${MAGENTA}[Optional 2/4] Modern CLI Tools${NC}"
    echo -e "  ${GRAY}(fzf, ripgrep, fd, bat, eza, zoxide)${NC}"

    # Check if most tools are already installed
    CLI_TOOLS_INSTALLED=0
    command_exists fzf && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))
    command_exists rg && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))
    (command_exists fd || command_exists fdfind) && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))
    (command_exists bat || command_exists batcat) && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))
    command_exists eza && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))
    command_exists zoxide && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))

    if [ "$CLI_TOOLS_INSTALLED" -eq 6 ]; then
        echo -e "  ${GREEN}✓ All CLI tools already installed${NC}"
        log_installed "Modern CLI Tools (all 6)"
    else
        echo -e "  ${YELLOW}○ ${CLI_TOOLS_INSTALLED}/6 tools installed${NC}"
        if prompt_optional "Modern CLI Tools"; then
            echo -e "  ${CYAN}> Running CLI Tools setup (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            CLI_TOOLS_SCRIPT="$SCRIPT_DIR/opt/cli-tools.sh"

            if [ -f "$CLI_TOOLS_SCRIPT" ]; then
                bash "$CLI_TOOLS_SCRIPT"
            else
                CLI_TOOLS_URL="https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/opt/cli-tools.sh"
                echo "Downloading cli-tools.sh..."
                curl -fsSL "$CLI_TOOLS_URL" -o /tmp/cli-tools.sh
                bash /tmp/cli-tools.sh
                rm -f /tmp/cli-tools.sh
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ Modern CLI Tools setup complete${NC}"
            log_installed "Modern CLI Tools"
        else
            log_skipped "Modern CLI Tools"
        fi
    fi

    echo -e "\n  ${CYAN}Progress: ${WHITE}5/7${NC} (71%)"
    echo -e "  ${CYAN}────────────────────────────────${NC}"

    # --- Git Identity Manager ---
    echo -e "\n${MAGENTA}[Optional 3/4] Git Identity Manager${NC}"
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
            GIT_IDENTITY_SCRIPT="$SCRIPT_DIR/opt/git-identity.sh"

            if [ -f "$GIT_IDENTITY_SCRIPT" ]; then
                bash "$GIT_IDENTITY_SCRIPT"
            else
                GIT_IDENTITY_URL="https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/opt/git-identity.sh"
                echo "Downloading git-identity.sh..."
                curl -fsSL "$GIT_IDENTITY_URL" -o /tmp/git-identity.sh
                bash /tmp/git-identity.sh
                rm -f /tmp/git-identity.sh
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ Git Identity Manager setup complete${NC}"
            log_installed "Git Identity Manager"
        else
            log_skipped "Git Identity Manager"
        fi
    fi

    echo -e "\n  ${CYAN}Progress: ${WHITE}6/7${NC} (86%)"
    echo -e "  ${CYAN}────────────────────────────────${NC}"

    # --- Bash Aliases ---
    echo -e "\n${MAGENTA}[Optional 4/4] Bash Aliases${NC}"
    echo -e "  ${GRAY}(git shortcuts, navigation, safety aliases)${NC}"
    if grep -q "REGGIE-WORKSPACE-ALIASES" "$HOME/.bashrc" 2>/dev/null; then
        echo -e "  ${GREEN}✓ Already configured${NC}"
        echo -e "  ${CYAN}> Checking for updates...${NC}"
        show_realtime_header

        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
        ALIASES_SCRIPT="$SCRIPT_DIR/opt/aliases.sh"

        if [ -f "$ALIASES_SCRIPT" ]; then
            bash "$ALIASES_SCRIPT"
        else
            ALIASES_URL="https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/opt/aliases.sh"
            echo "Downloading aliases.sh..."
            curl -fsSL "$ALIASES_URL" -o /tmp/aliases.sh
            bash /tmp/aliases.sh
            rm -f /tmp/aliases.sh
        fi

        show_realtime_footer
        log_installed "Bash Aliases"
    else
        echo -e "  ${YELLOW}○ Not configured${NC}"
        if prompt_optional "Bash Aliases"; then
            echo -e "  ${CYAN}> Running Bash Aliases setup (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            ALIASES_SCRIPT="$SCRIPT_DIR/opt/aliases.sh"

            if [ -f "$ALIASES_SCRIPT" ]; then
                bash "$ALIASES_SCRIPT"
            else
                ALIASES_URL="https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/opt/aliases.sh"
                echo "Downloading aliases.sh..."
                curl -fsSL "$ALIASES_URL" -o /tmp/aliases.sh
                bash /tmp/aliases.sh
                rm -f /tmp/aliases.sh
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ Bash Aliases setup complete${NC}"
            log_installed "Bash Aliases"
        else
            log_skipped "Bash Aliases"
        fi
    fi

    update_progress
fi

# ============================================
# [Optional 5/4] ruw CLI Tool
# ============================================
if [ "$SKIP_OPTIONAL" != true ]; then
    echo -e "\n${MAGENTA}[Optional 5/4] ruw CLI Tool${NC}"
    echo -e "  ${GRAY}(Manage workspace from anywhere with 'ruw' command)${NC}"

    if command_exists ruw; then
        echo -e "  ${GREEN}✓ Already installed${NC}"
        log_installed "ruw CLI Tool"
    else
        echo -e "  ${YELLOW}○ Not installed${NC}"
        if prompt_optional "ruw CLI Tool"; then
            echo -e "  ${CYAN}> Running ruw installation (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            RUW_INSTALL_SCRIPT="$SCRIPT_DIR/bin/install-ruw.sh"

            if [ -f "$RUW_INSTALL_SCRIPT" ]; then
                bash "$RUW_INSTALL_SCRIPT"
            else
                echo -e "${RED}Error: bin/install-ruw.sh not found${NC}"
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ ruw CLI Tool setup complete${NC}"
            log_installed "ruw CLI Tool"
        else
            log_skipped "ruw CLI Tool"
        fi
    fi
fi

# ============================================
# Final Summary
# ============================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${WHITE}   All Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n  ${CYAN}Progress: ${WHITE}7/7${NC} (100%)"
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
