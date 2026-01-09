#!/bin/bash
# apps.sh - Development applications installation
# Can be run standalone or from setup.sh
#
# Flags:
#   -y, --yes             Auto-accept all prompts
#   --reinstall           Force reinstall even if already installed
#   --skip-vscode         Skip VS Code installation
#   --skip-cursor         Skip Cursor installation
#   --skip-antigravity    Skip Antigravity installation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m'

# Default flags
AUTO_YES=false
FORCE_REINSTALL=false
SKIP_VSCODE=false
SKIP_CURSOR=false
SKIP_ANTIGRAVITY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes) AUTO_YES=true; shift ;;
        --reinstall) FORCE_REINSTALL=true; shift ;;
        --skip-vscode) SKIP_VSCODE=true; shift ;;
        --skip-cursor) SKIP_CURSOR=true; shift ;;
        --skip-antigravity) SKIP_ANTIGRAVITY=true; shift ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: apps.sh [-y|--yes] [--reinstall] [--skip-vscode] [--skip-cursor] [--skip-antigravity]"
            exit 1
            ;;
    esac
done

# Tracking
INSTALLED_APPS=()
SKIPPED_APPS=()
FAILED_APPS=()

# Helper functions
command_exists() {
    command -v "$1" &> /dev/null
}

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
    echo -e "  ${YELLOW}┌─ Installation Output ─┐${NC}"
}

show_realtime_footer() {
    echo -e "  ${YELLOW}└───────────────────────┘${NC}"
}

# DRY: AppImage installation helper
install_appimage() {
    local app_name="$1"
    local download_url="$2"
    local bin_dir="$HOME/.local/bin"
    local appimage_path="$bin_dir/${app_name}.AppImage"
    local symlink_path="$bin_dir/$app_name"

    mkdir -p "$bin_dir"
    echo "Downloading from $download_url..."

    # ERROR HANDLING: Catch download failures
    if curl -fSL "$download_url" -o "$appimage_path" --progress-bar; then
        chmod +x "$appimage_path"
        ln -sf "$appimage_path" "$symlink_path"
        export PATH="$bin_dir:$PATH"
        echo "Downloaded to $appimage_path"
        return 0
    else
        echo -e "${RED}Download failed${NC}"
        return 1
    fi
}

# Installation functions
install_vscode() {
    echo -e "\n${WHITE}[1/3] VS Code${NC}"

    if [ "$SKIP_VSCODE" = true ]; then
        echo -e "  ${GRAY}○ Skipped by flag${NC}"
        log_skipped "VS Code"
        return 0
    fi

    if command_exists code && [ "$FORCE_REINSTALL" = false ]; then
        echo -e "  ${GREEN}✓ Already installed: v$(code --version 2>/dev/null | head -1)${NC}"
        log_skipped "VS Code v$(code --version 2>/dev/null | head -1)"
        return 0
    fi

    echo -e "  ${YELLOW}○ Not installed${NC}"
    if prompt_install "VS Code"; then
        echo -e "  ${CYAN}> Installing VS Code via snap (realtime output)...${NC}"
        show_realtime_header

        if sudo snap install code --classic; then
            show_realtime_footer

            if command_exists code; then
                echo -e "  ${GREEN}✓ Installed: v$(code --version 2>/dev/null | head -1)${NC}"
                log_installed "VS Code v$(code --version 2>/dev/null | head -1)"
                return 0
            else
                echo -e "  ${YELLOW}! Installed (restart terminal to use)${NC}"
                log_installed "VS Code (restart needed)"
                return 0
            fi
        else
            show_realtime_footer
            echo -e "  ${RED}✗ Installation failed${NC}"
            log_failed "VS Code"
            return 1
        fi
    else
        log_skipped "VS Code"
    fi
}

install_cursor() {
    echo -e "\n${WHITE}[2/3] Cursor${NC}"

    if [ "$SKIP_CURSOR" = true ]; then
        echo -e "  ${GRAY}○ Skipped by flag${NC}"
        log_skipped "Cursor"
        return 0
    fi

    if command_exists cursor && [ "$FORCE_REINSTALL" = false ]; then
        echo -e "  ${GREEN}✓ Already installed${NC}"
        log_skipped "Cursor"
        return 0
    fi

    echo -e "  ${YELLOW}○ Not installed${NC}"
    if prompt_install "Cursor"; then
        echo -e "  ${CYAN}> Downloading Cursor AppImage (realtime output)...${NC}"
        show_realtime_header

        if install_appimage "cursor" "https://downloader.cursor.sh/linux/appImage/x64"; then
            show_realtime_footer

            if [ -f "$HOME/.local/bin/cursor.AppImage" ]; then
                echo -e "  ${GREEN}✓ Installed to ~/.local/bin${NC}"
                log_installed "Cursor"
                return 0
            else
                echo -e "  ${RED}✗ Installation failed${NC}"
                log_failed "Cursor"
                return 1
            fi
        else
            show_realtime_footer
            echo -e "  ${RED}✗ Download failed (check network connection)${NC}"
            log_failed "Cursor"
            return 1
        fi
    else
        log_skipped "Cursor"
    fi
}

install_antigravity() {
    echo -e "\n${WHITE}[3/3] Google Antigravity${NC}"

    if [ "$SKIP_ANTIGRAVITY" = true ]; then
        echo -e "  ${GRAY}○ Skipped by flag${NC}"
        log_skipped "Antigravity"
        return 0
    fi

    if command_exists antigravity && [ "$FORCE_REINSTALL" = false ]; then
        echo -e "  ${GREEN}✓ Already installed${NC}"
        log_skipped "Antigravity"
        return 0
    fi

    echo -e "  ${YELLOW}○ Not installed${NC}"
    if prompt_install "Google Antigravity"; then
        echo -e "  ${CYAN}> Downloading Antigravity AppImage (realtime output)...${NC}"
        show_realtime_header

        if install_appimage "antigravity" "https://antigravity.codes/download/linux"; then
            show_realtime_footer

            if [ -f "$HOME/.local/bin/antigravity.AppImage" ]; then
                echo -e "  ${GREEN}✓ Installed to ~/.local/bin${NC}"
                log_installed "Antigravity"
                return 0
            else
                echo -e "  ${RED}✗ Installation failed${NC}"
                log_failed "Antigravity"
                return 1
            fi
        else
            show_realtime_footer
            echo -e "  ${RED}✗ Download failed (check network connection)${NC}"
            log_failed "Antigravity"
            return 1
        fi
    else
        log_skipped "Antigravity"
    fi
}

# Main execution
main() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${WHITE}   Development Apps Installation${NC}"
    echo -e "${CYAN}========================================${NC}"

    if [ "$AUTO_YES" = true ]; then
        echo -e "${GRAY}  Mode: Auto-accept all${NC}"
    fi

    echo ""
    echo -e "${CYAN}Apps to install:${NC}"
    echo -e "  ${WHITE}VS Code${NC}       - Microsoft's code editor (snap)"
    echo -e "  ${WHITE}Cursor${NC}        - AI-first code editor (AppImage)"
    echo -e "  ${WHITE}Antigravity${NC}   - Google's AI code editor (AppImage)"
    echo ""

    # Run installations (continue even if one fails)
    install_vscode || true
    install_cursor || true
    install_antigravity || true

    # Summary
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${WHITE}   Apps Installation Complete${NC}"
    echo -e "${GREEN}========================================${NC}"

    if [ ${#INSTALLED_APPS[@]} -gt 0 ]; then
        echo -e "\n${GREEN}Installed:${NC}"
        for app in "${INSTALLED_APPS[@]}"; do
            echo -e "  ${GREEN}✓${NC} $app"
        done
    fi

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
        echo ""
        echo -e "${YELLOW}Some apps failed to install. This may be due to:${NC}"
        echo -e "${YELLOW}  - Network connectivity issues${NC}"
        echo -e "${YELLOW}  - Insufficient disk space${NC}"
        echo -e "${YELLOW}  - Missing snap daemon (for VS Code)${NC}"
        echo -e "${YELLOW}You can retry by running: ./def/apps.sh --reinstall${NC}"
    fi

    echo ""
    echo -e "${YELLOW}Note: Restart terminal if commands aren't in PATH${NC}"
    echo ""
}

main
