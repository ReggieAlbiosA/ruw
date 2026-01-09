#!/bin/bash
# packages.sh - Core development packages installation
# Can be run standalone or from setup.sh
#
# Flags:
#   -y, --yes        Auto-accept (for consistency, already auto-installs)
#   --reinstall      Force reinstall even if already installed
#   --skip-nodejs    Skip Node.js installation
#   --skip-git       Skip Git installation
#   --skip-pnpm      Skip pnpm installation

set -e  # Exit on error

# Colors (consistent with setup.sh)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m'

# Default flags
FORCE_REINSTALL=false
SKIP_NODEJS=false
SKIP_GIT=false
SKIP_PNPM=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes) shift ;;  # Accept but no-op (auto-installs anyway)
        --reinstall) FORCE_REINSTALL=true; shift ;;
        --skip-nodejs) SKIP_NODEJS=true; shift ;;
        --skip-git) SKIP_GIT=true; shift ;;
        --skip-pnpm) SKIP_PNPM=true; shift ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: packages.sh [-y|--yes] [--reinstall] [--skip-nodejs] [--skip-git] [--skip-pnpm]"
            exit 1
            ;;
    esac
done

# Tracking arrays
INSTALLED_PACKAGES=()
SKIPPED_PACKAGES=()
FAILED_PACKAGES=()

# Helper functions
command_exists() {
    command -v "$1" &> /dev/null
}

log_installed() {
    INSTALLED_PACKAGES+=("$1")
    echo -e "  ${GREEN}✓ Added to installed: $1${NC}"
}

log_skipped() {
    SKIPPED_PACKAGES+=("$1")
    echo -e "  ${GRAY}○ Skipped: $1${NC}"
}

log_failed() {
    FAILED_PACKAGES+=("$1")
    echo -e "  ${RED}✗ Failed: $1${NC}"
}

show_realtime_header() {
    echo -e "  ${YELLOW}┌─ Installation Output ─┐${NC}"
}

show_realtime_footer() {
    echo -e "  ${YELLOW}└───────────────────────┘${NC}"
}

# Installation functions
install_nodejs() {
    echo -e "\n${WHITE}[1/3] Node.js${NC}"

    if [ "$SKIP_NODEJS" = true ]; then
        echo -e "  ${GRAY}○ Skipped by flag${NC}"
        log_skipped "Node.js"
        return 0
    fi

    if command_exists node && [ "$FORCE_REINSTALL" = false ]; then
        echo -e "  ${GREEN}✓ Already installed: $(node --version)${NC}"
        log_skipped "Node.js $(node --version)"
        return 0
    fi

    echo -e "  ${CYAN}> Installing Node.js (realtime output)...${NC}"
    show_realtime_header

    # ERROR HANDLING: Wrap in if/else to catch failures
    if curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && \
       sudo apt-get install -y nodejs; then
        show_realtime_footer

        if command_exists node; then
            echo -e "  ${GREEN}✓ Installed: $(node --version)${NC}"
            log_installed "Node.js $(node --version)"
            return 0
        else
            echo -e "  ${YELLOW}! Installed but not detected (restart terminal)${NC}"
            log_installed "Node.js (restart needed)"
            return 0
        fi
    else
        show_realtime_footer
        echo -e "  ${RED}✗ Installation failed${NC}"
        log_failed "Node.js"
        return 1
    fi
}

install_git() {
    echo -e "\n${WHITE}[2/3] Git${NC}"

    if [ "$SKIP_GIT" = true ]; then
        echo -e "  ${GRAY}○ Skipped by flag${NC}"
        log_skipped "Git"
        return 0
    fi

    if command_exists git && [ "$FORCE_REINSTALL" = false ]; then
        echo -e "  ${GREEN}✓ Already installed: $(git --version)${NC}"
        log_skipped "Git $(git --version | cut -d' ' -f3)"
        return 0
    fi

    echo -e "  ${CYAN}> Installing Git (realtime output)...${NC}"
    show_realtime_header

    if sudo apt-get update && sudo apt-get install -y git; then
        show_realtime_footer

        if command_exists git; then
            echo -e "  ${GREEN}✓ Installed: $(git --version)${NC}"
            log_installed "Git $(git --version | cut -d' ' -f3)"
            return 0
        else
            echo -e "  ${RED}✗ Installation failed${NC}"
            log_failed "Git"
            return 1
        fi
    else
        show_realtime_footer
        echo -e "  ${RED}✗ Installation failed${NC}"
        log_failed "Git"
        return 1
    fi
}

install_pnpm() {
    echo -e "\n${WHITE}[3/3] pnpm${NC}"

    if [ "$SKIP_PNPM" = true ]; then
        echo -e "  ${GRAY}○ Skipped by flag${NC}"
        log_skipped "pnpm"
        return 0
    fi

    if command_exists pnpm && [ "$FORCE_REINSTALL" = false ]; then
        echo -e "  ${GREEN}✓ Already installed: v$(pnpm --version)${NC}"
        log_skipped "pnpm v$(pnpm --version)"
        return 0
    fi

    echo -e "  ${CYAN}> Installing pnpm (realtime output)...${NC}"
    show_realtime_header

    if curl -fsSL https://get.pnpm.io/install.sh | sh -; then
        export PNPM_HOME="$HOME/.local/share/pnpm"
        export PATH="$PNPM_HOME:$PATH"
        show_realtime_footer

        if command_exists pnpm; then
            echo -e "  ${GREEN}✓ Installed: v$(pnpm --version)${NC}"
            log_installed "pnpm v$(pnpm --version)"
            return 0
        else
            echo -e "  ${YELLOW}! Installed (restart terminal to use)${NC}"
            log_installed "pnpm (restart needed)"
            return 0
        fi
    else
        show_realtime_footer
        echo -e "  ${RED}✗ Installation failed${NC}"
        log_failed "pnpm"
        return 1
    fi
}

# Main execution
main() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${WHITE}   Core Packages Installation${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GRAY}Installing: Node.js, Git, pnpm${NC}"
    echo -e "${GRAY}This runs automatically (no prompts)${NC}"
    echo ""

    # Run installations (continue even if one fails)
    install_nodejs || true
    install_git || true
    install_pnpm || true

    # Summary
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${WHITE}   Packages Installation Complete${NC}"
    echo -e "${GREEN}========================================${NC}"

    if [ ${#INSTALLED_PACKAGES[@]} -gt 0 ]; then
        echo -e "\n${GREEN}Installed:${NC}"
        for pkg in "${INSTALLED_PACKAGES[@]}"; do
            echo -e "  ${GREEN}✓${NC} $pkg"
        done
    fi

    if [ ${#SKIPPED_PACKAGES[@]} -gt 0 ]; then
        echo -e "\n${GRAY}Skipped:${NC}"
        for pkg in "${SKIPPED_PACKAGES[@]}"; do
            echo -e "  ${GRAY}○${NC} $pkg"
        done
    fi

    if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
        echo -e "\n${RED}Failed:${NC}"
        for pkg in "${FAILED_PACKAGES[@]}"; do
            echo -e "  ${RED}✗${NC} $pkg"
        done
        echo ""
        echo -e "${YELLOW}Some packages failed to install. This may cause issues with dependent tools.${NC}"
        echo -e "${YELLOW}You can retry by running: ./def/packages.sh --reinstall${NC}"
    fi

    echo ""
}

main
