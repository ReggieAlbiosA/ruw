#!/bin/bash
# setup.sh
# Run with: curl -fsSL https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/setup.sh | bash -s -- -y
#
# Install overrides:
#   -y, --yes           Auto-accept all prompts

# Note: set -e removed to allow graceful error handling - script continues on failures

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ============================================
# Environment Detection
# ============================================
is_container() {
    # Check for Docker
    [ -f /.dockerenv ] && return 0
    # Check cgroup for docker/lxc/podman/containerd
    grep -qE '(docker|lxc|podman|containerd)' /proc/1/cgroup 2>/dev/null && return 0
    # Check for container environment variable
    [ -n "$container" ] && return 0
    return 1
}

is_vm() {
    # Check systemd-detect-virt if available
    if command -v systemd-detect-virt &>/dev/null; then
        local virt
        virt=$(systemd-detect-virt 2>/dev/null)
        [[ "$virt" != "none" && "$virt" != "" ]] && return 0
    fi
    # Check DMI for hypervisor markers
    if [ -r /sys/class/dmi/id/product_name ]; then
        grep -qiE '(virtualbox|vmware|qemu|kvm|hyper-v|xen|parallels)' /sys/class/dmi/id/product_name 2>/dev/null && return 0
    fi
    # Check CPU flags for hypervisor
    grep -q "^flags.*hypervisor" /proc/cpuinfo 2>/dev/null && return 0
    return 1
}

detect_environment() {
    if is_container; then
        ENV_TYPE="container"
    elif is_vm; then
        ENV_TYPE="vm"
    else
        ENV_TYPE="baremetal"
    fi
    export ENV_TYPE
}

# Run detection
detect_environment

# Default flags
AUTO_YES=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: setup.sh [-y|--yes]"
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
    echo "     curl -fsSL https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/setup.sh | bash -s -- -y"
    echo ""
    echo "  2. Download and run:"
    echo "     curl -fsSL https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/setup.sh -o setup.sh"
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
FAILED_APPS=()

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

log_failed() {
    FAILED_APPS+=("$1")
    echo -e "  ${RED}✗ Failed: $1${NC}"
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
echo -e "${GRAY}  Environment: ${WHITE}${ENV_TYPE}${NC}"

if [ "$ENV_TYPE" = "container" ]; then
    echo -e "${YELLOW}  Note: Some modules will be skipped (GUI apps, desktop features)${NC}"
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
        echo -e "${YELLOW}! Packages installation encountered errors. Continuing...${NC}"
    }
else
    PACKAGES_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/def/packages.sh"
    echo "Downloading packages.sh..."
    if curl -fsSL "$PACKAGES_URL" -o /tmp/packages.sh; then
        bash /tmp/packages.sh || {
            echo -e "${YELLOW}! Packages installation encountered errors. Continuing...${NC}"
        }
        rm -f /tmp/packages.sh
    else
        echo -e "${RED}! Failed to download packages.sh (network error or 404)${NC}"
        log_failed "Core Packages (download failed)"
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
# [2/7]  Apps (Cursor, Antigravity)
# ============================================
echo -e "\n${WHITE}[2/7] Apps${NC}"
echo -e "  ${GRAY}(Cursor, Antigravity)${NC}"

if [ "$ENV_TYPE" = "container" ]; then
    echo -e "  ${YELLOW}○ Skipped: GUI apps not supported in containers${NC}"
    log_skipped "Apps (container environment)"
elif prompt_optional "Install apps"; then
    echo -e "  ${CYAN}> Running apps installation...${NC}"
    show_realtime_header

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
    APPS_SCRIPT="$SCRIPT_DIR/def/apps.sh"

    APPS_FLAGS=""
    [ "$AUTO_YES" = true ] && APPS_FLAGS="$APPS_FLAGS -y"

    if [ -f "$APPS_SCRIPT" ]; then
        bash "$APPS_SCRIPT" $APPS_FLAGS || {
            echo -e "${YELLOW}! Apps installation encountered errors. Continuing...${NC}"
        }
    else
        APPS_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/def/apps.sh"
        echo "Downloading apps.sh..."
        if curl -fsSL "$APPS_URL" -o /tmp/apps.sh; then
            bash /tmp/apps.sh $APPS_FLAGS || {
                echo -e "${YELLOW}! Apps installation encountered errors. Continuing...${NC}"
            }
            rm -f /tmp/apps.sh
        else
            echo -e "${RED}! Failed to download apps.sh (network error or 404)${NC}"
            log_failed " Apps (download failed)"
        fi
    fi

    show_realtime_footer

    # Log results for summary
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

if [ "$ENV_TYPE" = "container" ]; then
    echo -e "  ${YELLOW}○ Skipped: Desktop launcher not supported in containers${NC}"
    log_skipped "Workspace Launcher (container environment)"
else
    echo -e "  ${CYAN}> Configuring workspace automation...${NC}"

    show_realtime_header

    # Download/run launcher setup
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
    LAUNCHER_SETUP_SCRIPT="$SCRIPT_DIR/def/logon-launch-workspace.sh"
    LAUNCHER_SUCCESS=false

    if [ -f "$LAUNCHER_SETUP_SCRIPT" ]; then
        echo "Running local logon-launch-workspace.sh..."
        if bash "$LAUNCHER_SETUP_SCRIPT"; then
            LAUNCHER_SUCCESS=true
        else
            echo -e "  ${RED}! Workspace launcher script failed${NC}"
        fi
    else
        LAUNCHER_SETUP_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/def/logon-launch-workspace.sh"
        echo "Downloading logon-launch-workspace.sh..."
        if curl -fsSL "$LAUNCHER_SETUP_URL" -o /tmp/logon-launch-workspace.sh; then
            if bash /tmp/logon-launch-workspace.sh; then
                LAUNCHER_SUCCESS=true
            else
                echo -e "  ${RED}! Workspace launcher script failed${NC}"
            fi
            rm -f /tmp/logon-launch-workspace.sh
        else
            echo -e "  ${RED}! Failed to download logon-launch-workspace.sh${NC}"
        fi
    fi

    show_realtime_footer

    if [ "$LAUNCHER_SUCCESS" = true ]; then
        echo -e "  ${GREEN}✓ Workspace launcher configured${NC}"
        log_installed "Workspace Launcher"
    else
        log_failed "Workspace Launcher"
    fi
fi

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
echo -e "\n${MAGENTA}========================================${NC}"
echo -e "${WHITE}   Optional Modules${NC}"
echo -e "${MAGENTA}========================================${NC}"

# --- Claude Code ---
echo -e "\n${MAGENTA}[Optional 1/4] Claude Code${NC}"
if [ "$ENV_TYPE" = "container" ]; then
    echo -e "  ${YELLOW}! Note: MCP servers may have limited functionality in containers${NC}"
fi
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

            CLAUDE_FLAGS=""
            [ "$AUTO_YES" = true ] && CLAUDE_FLAGS="-y"

            if [ -f "$CLAUDE_SETUP_SCRIPT" ]; then
                bash "$CLAUDE_SETUP_SCRIPT" $CLAUDE_FLAGS || {
                    echo -e "  ${YELLOW}! MCP configuration had errors. Continuing...${NC}"
                }
            else
                CLAUDE_SETUP_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/opt/claude-code.sh"
                echo "Downloading claude-code.sh..."
                if curl -fsSL "$CLAUDE_SETUP_URL" -o /tmp/claude-code.sh; then
                    bash /tmp/claude-code.sh $CLAUDE_FLAGS || {
                        echo -e "  ${YELLOW}! MCP configuration had errors. Continuing...${NC}"
                    }
                    rm -f /tmp/claude-code.sh
                else
                    echo -e "  ${RED}! Failed to download claude-code.sh (network error or 404)${NC}"
                    log_failed "MCP servers (download failed)"
                fi
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

        CLAUDE_FLAGS=""
        [ "$AUTO_YES" = true ] && CLAUDE_FLAGS="-y"

        if [ -f "$CLAUDE_SETUP_SCRIPT" ]; then
            bash "$CLAUDE_SETUP_SCRIPT" $CLAUDE_FLAGS || {
                echo -e "  ${YELLOW}! Claude Code setup had errors. Continuing...${NC}"
            }
        else
            CLAUDE_SETUP_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/opt/claude-code.sh"
            echo "Downloading claude-code.sh..."
            if curl -fsSL "$CLAUDE_SETUP_URL" -o /tmp/claude-code.sh; then
                bash /tmp/claude-code.sh $CLAUDE_FLAGS || {
                    echo -e "  ${YELLOW}! Claude Code setup had errors. Continuing...${NC}"
                }
                rm -f /tmp/claude-code.sh
            else
                echo -e "  ${RED}! Failed to download claude-code.sh (network error or 404)${NC}"
                log_failed "Claude Code (download failed)"
            fi
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

if [ "$SKIP_OPTIONAL" != true ]; then
    # --- Modern CLI Tools ---
    echo -e "\n${MAGENTA}[Optional 2/4] Modern CLI Tools${NC}"
    echo -e "  ${GRAY}(fzf, ripgrep, fd, bat, eza, zoxide, curl, tealdeer, cht.sh, gh)${NC}"

    # Check if tools are already installed
    CLI_TOOLS_INSTALLED=0
    command_exists fzf && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))
    command_exists rg && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))
    (command_exists fd || command_exists fdfind) && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))
    (command_exists bat || command_exists batcat) && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))
    command_exists eza && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))
    command_exists zoxide && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))
    command_exists curl && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))
    (command_exists tealdeer || command_exists tldr) && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))
    (command_exists cht.sh || [ -f "$HOME/.local/bin/cht.sh" ]) && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))
    command_exists gh && CLI_TOOLS_INSTALLED=$((CLI_TOOLS_INSTALLED + 1))

    if [ "$CLI_TOOLS_INSTALLED" -eq 10 ]; then
        echo -e "  ${GREEN}✓ All CLI tools already installed${NC}"
        log_installed "Modern CLI Tools (all 10)"
        
        # Ask if user wants to reinstall
        if prompt_optional "Reinstall Modern CLI Tools"; then
            echo -e "  ${CYAN}> Running CLI Tools setup (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            CLI_TOOLS_SCRIPT="$SCRIPT_DIR/opt/cli-tools.sh"

            CLI_FLAGS=""
            [ "$AUTO_YES" = true ] && CLI_FLAGS="-y"

            if [ -f "$CLI_TOOLS_SCRIPT" ]; then
                bash "$CLI_TOOLS_SCRIPT" $CLI_FLAGS || {
                    echo -e "  ${YELLOW}! CLI Tools setup had errors. Continuing...${NC}"
                }
            else
                CLI_TOOLS_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/opt/cli-tools.sh"
                echo "Downloading cli-tools.sh..."
                if curl -fsSL "$CLI_TOOLS_URL" -o /tmp/cli-tools.sh; then
                    bash /tmp/cli-tools.sh $CLI_FLAGS || {
                        echo -e "  ${YELLOW}! CLI Tools setup had errors. Continuing...${NC}"
                    }
                    rm -f /tmp/cli-tools.sh
                else
                    echo -e "  ${RED}! Failed to download cli-tools.sh (network error or 404)${NC}"
                    log_failed "Modern CLI Tools (download failed)"
                fi
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ Modern CLI Tools reinstalled${NC}"
        else
            log_skipped "Modern CLI Tools (reinstall)"
        fi
    else
        echo -e "  ${YELLOW}○ ${CLI_TOOLS_INSTALLED}/10 tools installed${NC}"
        if prompt_optional "Modern CLI Tools"; then
            echo -e "  ${CYAN}> Running CLI Tools setup (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            CLI_TOOLS_SCRIPT="$SCRIPT_DIR/opt/cli-tools.sh"

            CLI_FLAGS=""
            [ "$AUTO_YES" = true ] && CLI_FLAGS="-y"

            if [ -f "$CLI_TOOLS_SCRIPT" ]; then
                bash "$CLI_TOOLS_SCRIPT" $CLI_FLAGS || {
                    echo -e "  ${YELLOW}! CLI Tools setup had errors. Continuing...${NC}"
                }
            else
                CLI_TOOLS_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/opt/cli-tools.sh"
                echo "Downloading cli-tools.sh..."
                if curl -fsSL "$CLI_TOOLS_URL" -o /tmp/cli-tools.sh; then
                    bash /tmp/cli-tools.sh $CLI_FLAGS || {
                        echo -e "  ${YELLOW}! CLI Tools setup had errors. Continuing...${NC}"
                    }
                    rm -f /tmp/cli-tools.sh
                else
                    echo -e "  ${RED}! Failed to download cli-tools.sh (network error or 404)${NC}"
                    log_failed "Modern CLI Tools (download failed)"
                fi
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
        
        # Ask if user wants to reconfigure
        if prompt_optional "Reconfigure Git Identity Manager"; then
            echo -e "  ${CYAN}> Running Git Identity setup (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            GIT_IDENTITY_SCRIPT="$SCRIPT_DIR/opt/git-identity.sh"

            GIT_FLAGS=""
            [ "$AUTO_YES" = true ] && GIT_FLAGS="-y"

            if [ -f "$GIT_IDENTITY_SCRIPT" ]; then
                bash "$GIT_IDENTITY_SCRIPT" $GIT_FLAGS || {
                    echo -e "  ${YELLOW}! Git Identity setup had errors. Continuing...${NC}"
                }
            else
                GIT_IDENTITY_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/opt/git-identity.sh"
                echo "Downloading git-identity.sh..."
                if curl -fsSL "$GIT_IDENTITY_URL" -o /tmp/git-identity.sh; then
                    bash /tmp/git-identity.sh $GIT_FLAGS || {
                        echo -e "  ${YELLOW}! Git Identity setup had errors. Continuing...${NC}"
                    }
                    rm -f /tmp/git-identity.sh
                else
                    echo -e "  ${RED}! Failed to download git-identity.sh (network error or 404)${NC}"
                    log_failed "Git Identity Manager (download failed)"
                fi
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ Git Identity Manager reconfigured${NC}"
        else
            log_skipped "Git Identity Manager (reconfigure)"
        fi
    else
        echo -e "  ${YELLOW}○ Not configured${NC}"
        if prompt_optional "Git Identity Manager"; then
            echo -e "  ${CYAN}> Running Git Identity setup (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            GIT_IDENTITY_SCRIPT="$SCRIPT_DIR/opt/git-identity.sh"

            GIT_FLAGS=""
            [ "$AUTO_YES" = true ] && GIT_FLAGS="-y"

            if [ -f "$GIT_IDENTITY_SCRIPT" ]; then
                bash "$GIT_IDENTITY_SCRIPT" $GIT_FLAGS || {
                    echo -e "  ${YELLOW}! Git Identity setup had errors. Continuing...${NC}"
                }
            else
                GIT_IDENTITY_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/opt/git-identity.sh"
                echo "Downloading git-identity.sh..."
                if curl -fsSL "$GIT_IDENTITY_URL" -o /tmp/git-identity.sh; then
                    bash /tmp/git-identity.sh $GIT_FLAGS || {
                        echo -e "  ${YELLOW}! Git Identity setup had errors. Continuing...${NC}"
                    }
                    rm -f /tmp/git-identity.sh
                else
                    echo -e "  ${RED}! Failed to download git-identity.sh (network error or 404)${NC}"
                    log_failed "Git Identity Manager (download failed)"
                fi
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
        log_installed "Bash Aliases"
        
        # Ask if user wants to reconfigure
        if prompt_optional "Reconfigure Bash Aliases"; then
            echo -e "  ${CYAN}> Running Bash Aliases setup (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            ALIASES_SCRIPT="$SCRIPT_DIR/opt/aliases.sh"

            if [ -f "$ALIASES_SCRIPT" ]; then
                bash "$ALIASES_SCRIPT" || {
                    echo -e "  ${YELLOW}! Bash Aliases setup had errors. Continuing...${NC}"
                }
            else
                ALIASES_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/opt/aliases.sh"
                echo "Downloading aliases.sh..."
                if curl -fsSL "$ALIASES_URL" -o /tmp/aliases.sh; then
                    bash /tmp/aliases.sh || {
                        echo -e "  ${YELLOW}! Bash Aliases setup had errors. Continuing...${NC}"
                    }
                    rm -f /tmp/aliases.sh
                else
                    echo -e "  ${RED}! Failed to download aliases.sh (network error or 404)${NC}"
                    log_failed "Bash Aliases (download failed)"
                fi
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ Bash Aliases reconfigured${NC}"
        else
            log_skipped "Bash Aliases (reconfigure)"
        fi
    else
        echo -e "  ${YELLOW}○ Not configured${NC}"
        if prompt_optional "Bash Aliases"; then
            echo -e "  ${CYAN}> Running Bash Aliases setup (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            ALIASES_SCRIPT="$SCRIPT_DIR/opt/aliases.sh"

            if [ -f "$ALIASES_SCRIPT" ]; then
                bash "$ALIASES_SCRIPT" || {
                    echo -e "  ${YELLOW}! Bash Aliases setup had errors. Continuing...${NC}"
                }
            else
                ALIASES_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/opt/aliases.sh"
                echo "Downloading aliases.sh..."
                if curl -fsSL "$ALIASES_URL" -o /tmp/aliases.sh; then
                    bash /tmp/aliases.sh || {
                        echo -e "  ${YELLOW}! Bash Aliases setup had errors. Continuing...${NC}"
                    }
                    rm -f /tmp/aliases.sh
                else
                    echo -e "  ${RED}! Failed to download aliases.sh (network error or 404)${NC}"
                    log_failed "Bash Aliases (download failed)"
                fi
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ Bash Aliases setup complete${NC}"
            log_installed "Bash Aliases"
        else
            log_skipped "Bash Aliases"
        fi
    fi

    # --- Oh My Posh ---
    echo -e "\n${MAGENTA}[Optional 5/5] Oh My Posh${NC}"
    echo -e "  ${GRAY}(Theming for your terminal)${NC}"

    if command_exists oh-my-posh; then
        omp_version=$(oh-my-posh --version 2>/dev/null | head -1)
        echo -e "  ${GREEN}✓ Already installed: $omp_version${NC}"
        log_installed "Oh My Posh ($omp_version)"
        
        # Ask if user wants to reconfigure/update
        if prompt_optional "Reinstall/Update Oh My Posh"; then
            echo -e "  ${CYAN}> Running Oh My Posh setup (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            OMP_SCRIPT="$SCRIPT_DIR/opt/oh-my-posh.sh"

            if [ -f "$OMP_SCRIPT" ]; then
                bash "$OMP_SCRIPT" || {
                    echo -e "  ${YELLOW}! Oh My Posh setup had errors. Continuing...${NC}"
                }
            else
                OMP_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/opt/oh-my-posh.sh"
                echo "Downloading oh-my-posh.sh..."
                if curl -fsSL "$OMP_URL" -o /tmp/oh-my-posh.sh; then
                    bash /tmp/oh-my-posh.sh || {
                        echo -e "  ${YELLOW}! Oh My Posh setup had errors. Continuing...${NC}"
                    }
                    rm -f /tmp/oh-my-posh.sh
                else
                    echo -e "  ${RED}! Failed to download oh-my-posh.sh (network error or 404)${NC}"
                    log_failed "Oh My Posh (download failed)"
                fi
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ Oh My Posh configured${NC}"
        else
            log_skipped "Oh My Posh (reinstall)"
        fi
    else
        echo -e "  ${YELLOW}○ Not installed${NC}"
        if prompt_optional "Oh My Posh"; then
            echo -e "  ${CYAN}> Running Oh My Posh setup (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            OMP_SCRIPT="$SCRIPT_DIR/opt/oh-my-posh.sh"

            if [ -f "$OMP_SCRIPT" ]; then
                bash "$OMP_SCRIPT" || {
                    echo -e "  ${YELLOW}! Oh My Posh setup had errors. Continuing...${NC}"
                }
            else
                OMP_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/opt/oh-my-posh.sh"
                echo "Downloading oh-my-posh.sh..."
                if curl -fsSL "$OMP_URL" -o /tmp/oh-my-posh.sh; then
                    bash /tmp/oh-my-posh.sh || {
                        echo -e "  ${YELLOW}! Oh My Posh setup had errors. Continuing...${NC}"
                    }
                    rm -f /tmp/oh-my-posh.sh
                else
                    echo -e "  ${RED}! Failed to download oh-my-posh.sh (network error or 404)${NC}"
                    log_failed "Oh My Posh (download failed)"
                fi
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ Oh My Posh setup complete${NC}"
            log_installed "Oh My Posh"
        else
            log_skipped "Oh My Posh"
        fi
    fi

    update_progress

    # --- Google Drive Integration ---
    echo -e "\n${MAGENTA}[Optional 6/6] Google Drive Integration${NC}"
    echo -e "  ${GRAY}(GNOME Online Accounts for cloud storage)${NC}"

    if [ "$ENV_TYPE" = "container" ]; then
        echo -e "  ${YELLOW}○ Skipped: Google Drive needs desktop environment${NC}"
        log_skipped "Google Drive (container environment)"
    elif dpkg -l gnome-online-accounts 2>/dev/null | grep -q "^ii"; then
        echo -e "  ${GREEN}✓ Already installed${NC}"
        log_installed "Google Drive Integration"

        # Ask if user wants to reconfigure
        if prompt_optional "Open Google Drive settings"; then
            echo -e "  ${CYAN}> Opening Online Accounts settings...${NC}"
            gnome-control-center online-accounts &
            echo -e "  ${GREEN}✓ Settings panel opened${NC}"
        else
            log_skipped "Google Drive (settings)"
        fi
    else
        echo -e "  ${YELLOW}○ Not configured${NC}"
        if prompt_optional "Google Drive Integration"; then
            echo -e "  ${CYAN}> Running Google Drive setup (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            GDRIVE_SCRIPT="$SCRIPT_DIR/opt/google-drive.sh"
            GDRIVE_FLAGS=""
            [ "$AUTO_YES" = true ] && GDRIVE_FLAGS="$GDRIVE_FLAGS -y"

            if [ -f "$GDRIVE_SCRIPT" ]; then
                bash "$GDRIVE_SCRIPT" $GDRIVE_FLAGS || {
                    echo -e "  ${YELLOW}! Google Drive setup had errors. Continuing...${NC}"
                }
            else
                GDRIVE_URL="https://raw.githubusercontent.com/ReggieAlbiosA/ruw/main/opt/google-drive.sh"
                echo "Downloading google-drive.sh..."
                if curl -fsSL "$GDRIVE_URL" -o /tmp/google-drive.sh; then
                    bash /tmp/google-drive.sh $GDRIVE_FLAGS || {
                        echo -e "  ${YELLOW}! Google Drive setup had errors. Continuing...${NC}"
                    }
                    rm -f /tmp/google-drive.sh
                else
                    echo -e "  ${RED}! Failed to download google-drive.sh (network error or 404)${NC}"
                    log_failed "Google Drive (download failed)"
                fi
            fi

            show_realtime_footer
            echo -e "  ${GREEN}✓ Google Drive setup complete${NC}"
            log_installed "Google Drive Integration"
        else
            log_skipped "Google Drive Integration"
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
        ruw_version=$(ruw --version 2>/dev/null || echo "version unknown")
        echo -e "  ${GREEN}✓ Already installed: $ruw_version${NC}"
        log_installed "ruw CLI Tool ($ruw_version)"
        
        # Ask if user wants to reinstall/update
        if prompt_optional "Reinstall/update ruw CLI Tool"; then
            echo -e "  ${CYAN}> Running ruw installation (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            RUW_INSTALL_SCRIPT="$SCRIPT_DIR/bin/install-ruw.sh"

            if [ -f "$RUW_INSTALL_SCRIPT" ]; then
                bash "$RUW_INSTALL_SCRIPT" || {
                    echo -e "  ${YELLOW}! ruw CLI installation had errors. Continuing...${NC}"
                }
            else
                echo -e "${RED}! bin/install-ruw.sh not found (run from repo directory)${NC}"
                log_failed "ruw CLI Tool (script not found)"
            fi

            show_realtime_footer
            if command_exists ruw; then
                new_version=$(ruw --version 2>/dev/null || echo "version unknown")
                echo -e "  ${GREEN}✓ ruw CLI Tool updated to $new_version${NC}"
            else
                echo -e "  ${YELLOW}! ruw CLI Tool may not have installed correctly${NC}"
            fi
        else
            log_skipped "ruw CLI Tool (reinstall)"
        fi
    else
        echo -e "  ${YELLOW}○ Not installed${NC}"
        if prompt_optional "ruw CLI Tool"; then
            echo -e "  ${CYAN}> Running ruw installation (realtime output)...${NC}"
            show_realtime_header

            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
            RUW_INSTALL_SCRIPT="$SCRIPT_DIR/bin/install-ruw.sh"

            if [ -f "$RUW_INSTALL_SCRIPT" ]; then
                bash "$RUW_INSTALL_SCRIPT" || {
                    echo -e "  ${YELLOW}! ruw CLI installation had errors. Continuing...${NC}"
                }
            else
                echo -e "${RED}! bin/install-ruw.sh not found (run from repo directory)${NC}"
                log_failed "ruw CLI Tool (script not found)"
            fi

            show_realtime_footer
            if command_exists ruw; then
                echo -e "  ${GREEN}✓ ruw CLI Tool setup complete${NC}"
                log_installed "ruw CLI Tool"
            else
                echo -e "  ${YELLOW}! ruw CLI Tool may not have installed correctly${NC}"
            fi
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

if [ ${#FAILED_APPS[@]} -gt 0 ]; then
    echo -e "\n${RED}Failed:${NC}"
    for app in "${FAILED_APPS[@]}"; do
        echo -e "  ${RED}✗${NC} $app"
    done
    echo -e "\n${YELLOW}Some installations failed. You can retry by running setup.sh again.${NC}"
fi

echo -e "\n${YELLOW}Restart your terminal for all changes to take effect.${NC}"
echo ""
