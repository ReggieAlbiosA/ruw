#!/bin/bash
# claude-code-setup.sh
# Automated Claude Code installation with Node.js/npm dependency checking

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Detect if running as root/sudo for scope determination
if [ "$EUID" -eq 0 ]; then
    MCP_SCOPE="system"
    BASHRC_PATH="/root/.bashrc"
else
    MCP_SCOPE="user"
    BASHRC_PATH="$HOME/.bashrc"
fi

# Helper function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Helper function to prompt user - FIXED VERSION
prompt_install() {
    while true; do
        read -p "  > Install $1? (y/n): " -r REPLY
        case "${REPLY,,}" in  # Convert to lowercase
            y|yes)
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                echo -e "  ${RED}! Invalid input. Please enter 'y' or 'n'${NC}"
                ;;
        esac
    done
}

# Helper function to prompt for reconfiguration - FIXED VERSION
prompt_reconfigure() {
    while true; do
        read -p "  > $1 failed to connect. Reconfigure? (y/n): " -r REPLY
        case "${REPLY,,}" in
            y|yes)
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                echo -e "  ${RED}! Invalid input. Please enter 'y' or 'n'${NC}"
                ;;
        esac
    done
}

# Check and install Node.js
install_nodejs() {
    echo -e "\n${NC}[1/4] Checking Node.js...${NC}"

    if command_exists node; then
        echo -e "  ${GREEN}+ Already installed: $(node --version)${NC}"
        return 0
    fi

    echo -e "  ${YELLOW}! Not installed${NC}"

    if prompt_install "Node.js (required for Claude Code)"; then
        echo -e "  ${CYAN}> Installing Node.js...${NC}"

        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs

        if command_exists node; then
            echo -e "  ${GREEN}+ Installed: $(node --version)${NC}"
            return 0
        else
            echo -e "  ${YELLOW}! Installed but not detected. You may need to restart your terminal.${NC}"
            return 1
        fi
    else
        echo -e "  ${RED}! Node.js is required for Claude Code. Setup cancelled.${NC}"
        return 1
    fi
}

# Check npm availability
check_npm() {
    echo -e "\n${NC}[2/4] Checking npm...${NC}"

    if command_exists npm; then
        echo -e "  ${GREEN}+ Already installed: v$(npm --version)${NC}"
        return 0
    fi

    echo -e "  ${RED}! npm not found. npm should come with Node.js installation.${NC}"
    echo -e "  ${YELLOW}! Please restart your terminal or reinstall Node.js.${NC}"
    return 1
}

# Install Claude Code
install_claude_code() {
    echo -e "\n${NC}[3/4] Checking Claude Code...${NC}"

    if command_exists claude; then
        local claude_version=$(claude --version 2>/dev/null)
        echo -e "  ${GREEN}+ Already installed: $claude_version${NC}"
        return 0
    fi

    echo -e "  ${YELLOW}! Not installed${NC}"

    if prompt_install "Claude Code"; then
        echo -e "  ${CYAN}> Installing Claude Code via npm...${NC}"

        sudo npm install -g @anthropic-ai/claude-code

        if [ $? -eq 0 ]; then
            if command_exists claude; then
                local claude_version=$(claude --version 2>/dev/null)
                echo -e "  ${GREEN}+ Installed successfully: $claude_version${NC}"
                return 0
            else
                echo -e "  ${YELLOW}! Installed but not detected. Restart your terminal to use 'claude'.${NC}"
                return 0
            fi
        else
            echo -e "  ${RED}! Installation failed${NC}"
            return 1
        fi
    else
        echo -e "  ${GRAY}> Skipped${NC}"
        return 1
    fi
}

# Get MCP server status
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

# Install GitHub MCP server (extracted for reuse)
install_github_mcp() {
    echo -e "  ${CYAN}> Configure github MCP server...${NC}"
    read -p "  > Enter your GitHub Personal Access Token: " github_token

    if [ -z "$github_token" ]; then
        echo -e "  ${YELLOW}! No token provided, skipping github MCP server${NC}"
        return 1
    fi

    # Set GITHUB_TOKEN in .bashrc for persistence
    echo -e "  ${CYAN}> Setting GITHUB_TOKEN environment variable...${NC}"

    # Remove old GITHUB_TOKEN if exists
    sed -i '/^export GITHUB_TOKEN=/d' "$BASHRC_PATH"

    # Add new GITHUB_TOKEN
    echo "export GITHUB_TOKEN=\"$github_token\"" >> "$BASHRC_PATH"

    # Set for current session
    export GITHUB_TOKEN="$github_token"

    echo -e "  ${GREEN}+ GITHUB_TOKEN set${NC}"

    # Add GitHub MCP server
    echo -e "  ${CYAN}> Adding github MCP server...${NC}"
    claude mcp add github --scope user -- npx @modelcontextprotocol/server-github

    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}+ github added${NC}"
        echo -e "  ${YELLOW}! Restart terminal for GITHUB_TOKEN to take full effect${NC}"
        return 0
    else
        echo -e "  ${RED}! Failed to add github${NC}"
        return 1
    fi
}

# Configure MCP Servers (smart check first, then install missing only)
add_mcp_servers() {
    echo -e "\n${NC}[4/4] Configuring MCP Servers (${MCP_SCOPE} scope)...${NC}"

    if ! command_exists claude; then
        echo -e "  ${RED}! Claude Code not found. Cannot configure MCP servers.${NC}"
        return 1
    fi

    # Check all MCPs first using claude mcp list
    echo -e "  ${CYAN}> Checking existing MCP configurations...${NC}"

    local expected_mcps=("better-auth" "sequential-thinking" "github")
    local missing_mcps=()
    local connected_mcps=()

    for mcp in "${expected_mcps[@]}"; do
        local status=$(get_mcp_status "$mcp")
        if [ "$status" = "connected" ]; then
            connected_mcps+=("$mcp")
        else
            missing_mcps+=("$mcp")
        fi
    done

    # Show status summary
    echo -e "\n${NC}─── MCP Status ───${NC}"
    for mcp in "${connected_mcps[@]}"; do
        echo -e "  ${GREEN}✓ $mcp - Connected${NC}"
    done
    for mcp in "${missing_mcps[@]}"; do
        echo -e "  ${YELLOW}○ $mcp - Not configured${NC}"
    done

    # If all connected, we're done
    if [ ${#missing_mcps[@]} -eq 0 ]; then
        echo -e "\n${GREEN}All MCP servers already configured!${NC}"
        return 0
    fi

    # Ask once if user wants to configure missing MCPs - FIXED VERSION
    echo ""
    while true; do
        read -p "  > Configure ${#missing_mcps[@]} missing MCP(s)? (y/n): " -r REPLY
        case "${REPLY,,}" in
            y|yes)
                break
                ;;
            n|no)
                echo -e "  ${GRAY}> Skipped MCP configuration${NC}"
                return 0
                ;;
            *)
                echo -e "  ${RED}! Invalid input. Please enter 'y' or 'n'${NC}"
                ;;
        esac
    done

    # Install only missing MCPs
    local success=0
    for mcp in "${missing_mcps[@]}"; do
        echo -e "\n  ${CYAN}> Installing $mcp...${NC}"

        # Remove if exists (in case it's in failed state)
        claude mcp remove "$mcp" --scope user 2>/dev/null

        case "$mcp" in
            "better-auth")
                claude mcp add better-auth --scope user --transport http \
                    https://mcp.chonkie.ai/better-auth/better-auth-builder/mcp
                if [ $? -eq 0 ]; then
                    echo -e "  ${GREEN}+ better-auth added${NC}"
                else
                    echo -e "  ${RED}! Failed to add better-auth${NC}"
                    success=1
                fi
                ;;
            "sequential-thinking")
                claude mcp add sequential-thinking --scope user -- \
                    npx @modelcontextprotocol/server-sequential-thinking
                if [ $? -eq 0 ]; then
                    echo -e "  ${GREEN}+ sequential-thinking added${NC}"
                else
                    echo -e "  ${RED}! Failed to add sequential-thinking${NC}"
                    success=1
                fi
                ;;
            "github")
                install_github_mcp || success=1
                ;;
        esac
    done

    return $success
}

# Reinstall only the specified missing MCPs
reinstall_missing_mcps() {
    local mcps=("$@")

    for mcp in "${mcps[@]}"; do
        echo -e "\n  ${CYAN}> Reinstalling $mcp...${NC}"

        # Remove existing (if any)
        claude mcp remove "$mcp" --scope user 2>/dev/null

        case "$mcp" in
            "better-auth")
                claude mcp add better-auth --scope user --transport http \
                    https://mcp.chonkie.ai/better-auth/better-auth-builder/mcp
                ;;
            "sequential-thinking")
                claude mcp add sequential-thinking --scope user -- \
                    npx @modelcontextprotocol/server-sequential-thinking
                ;;
            "github")
                # GitHub needs special handling for token
                install_github_mcp
                ;;
        esac

        # Verify after reinstall
        local status=$(get_mcp_status "$mcp")
        if [ "$status" = "connected" ]; then
            echo -e "  ${GREEN}✓ $mcp reinstalled successfully${NC}"
        else
            echo -e "  ${YELLOW}! $mcp added but not yet connected (may need terminal restart)${NC}"
        fi
    done
}

# Verify and offer to fix missing MCPs - FIXED VERSION
verify_mcp_installation() {
    echo -e "\n${CYAN}> Verifying MCP installations...${NC}"

    local expected_mcps=("better-auth" "sequential-thinking" "github")
    local missing_mcps=()
    local connected_mcps=()

    # Check each expected MCP
    for mcp in "${expected_mcps[@]}"; do
        local status=$(get_mcp_status "$mcp")
        if [ "$status" = "connected" ]; then
            connected_mcps+=("$mcp")
        else
            missing_mcps+=("$mcp")
        fi
    done

    # Show summary
    echo -e "\n${NC}─── MCP Status Summary ───${NC}"
    for mcp in "${connected_mcps[@]}"; do
        echo -e "  ${GREEN}✓ $mcp - Connected${NC}"
    done
    for mcp in "${missing_mcps[@]}"; do
        echo -e "  ${RED}✗ $mcp - Missing/Failed${NC}"
    done

    # If all connected, we're done
    if [ ${#missing_mcps[@]} -eq 0 ]; then
        echo -e "\n${GREEN}All MCP servers configured successfully!${NC}"
        return 0
    fi

    # Offer to reinstall missing MCPs
    echo -e "\n${YELLOW}${#missing_mcps[@]} MCP server(s) not connected.${NC}"
    while true; do
        read -p "  > Would you like to reconfigure missing MCPs? (y/n): " -r REPLY
        case "${REPLY,,}" in
            y|yes)
                reinstall_missing_mcps "${missing_mcps[@]}"
                return 0
                ;;
            n|no)
                echo -e "  ${GRAY}> Skipped reconfiguration${NC}"
                return 0
                ;;
            *)
                echo -e "  ${RED}! Invalid input. Please enter 'y' or 'n'${NC}"
                ;;
        esac
    done
}

# Main execution
main() {
    echo ""
    echo -e "${MAGENTA}==========================================${NC}"
    echo -e "${MAGENTA}    Claude Code Installation Script${NC}"
    echo -e "${MAGENTA}==========================================${NC}"
    if [ "$MCP_SCOPE" = "system" ]; then
        echo -e "${CYAN}    Running as root - system scope${NC}"
    else
        echo -e "${CYAN}    Running as user - user scope${NC}"
    fi
    echo ""

    # Step 1: Install Node.js
    if ! install_nodejs; then
        echo -e "\n${RED}=== Setup Failed ===${NC}"
        echo -e "${YELLOW}Please install Node.js manually and try again.${NC}"
        exit 1
    fi

    # Step 2: Verify npm
    if ! check_npm; then
        echo -e "\n${RED}=== Setup Failed ===${NC}"
        echo -e "${YELLOW}npm is required but not found.${NC}"
        exit 1
    fi

    # Step 3: Install Claude Code
    if ! install_claude_code; then
        echo -e "\n${RED}=== Setup Failed ===${NC}"
        echo -e "${YELLOW}Please check the errors above and try again.${NC}"
        exit 1
    fi

    # Step 4: Configure MCP Servers
    add_mcp_servers

    # Step 5: Verify and fix missing MCPs
    verify_mcp_installation

    # Success summary
    echo ""
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}    Setup Completed Successfully!${NC}"
    echo -e "${GREEN}==========================================${NC}"
    echo ""
    echo -e "${CYAN}You can now run 'claude' to start!${NC}"
    if [ "$MCP_SCOPE" = "system" ]; then
        echo -e "${CYAN}MCP servers are configured in system scope (/root/.claude.json)${NC}"
        echo -e "${YELLOW}Run 'sudo claude' to use MCP servers, or re-run without sudo for user scope${NC}"
    else
        echo -e "${CYAN}MCP servers are configured in user scope (~/.claude.json)${NC}"
    fi
    echo ""
}

# Run the setup
main
