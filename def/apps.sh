#!/usr/bin/env bash
# apps.sh - Development applications installation
# Can be run standalone or from setup.sh

set -Eeuo pipefail

# ===============================
# Colors
# ===============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m'

# ===============================
# Default flags
# ===============================
AUTO_YES=false
FORCE_REINSTALL=false
SKIP_VSCODE=false
SKIP_CURSOR=false
SKIP_ANTIGRAVITY=false

# ===============================
# Parse arguments
# ===============================
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes) AUTO_YES=true ;;
        --reinstall) FORCE_REINSTALL=true ;;
        --skip-vscode) SKIP_VSCODE=true ;;
        --skip-cursor) SKIP_CURSOR=true ;;
        --skip-antigravity) SKIP_ANTIGRAVITY=true ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: apps.sh [-y|--yes] [--reinstall] [--skip-vscode] [--skip-cursor] [--skip-antigravity]"
            exit 1
            ;;
    esac
    shift
done

# ===============================
# Tracking
# ===============================
INSTALLED_APPS=()
SKIPPED_APPS=()
FAILED_APPS=()

# ===============================
# Helpers
# ===============================
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ensure_local_bin_path() {
    mkdir -p "$HOME/.local/bin"

    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        fi
    fi
}

prompt_install() {
    if [ "$AUTO_YES" = true ]; then
        echo -e "  ${CYAN}> Auto-accepting${NC}"
        return 0
    fi

    while true; do
        read -r -p "  > Install $1? (y/n): " REPLY
        case "$REPLY" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) echo -e "  ${RED}! Invalid input. Please enter y or n${NC}" ;;
        esac
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

# ===============================
# AppImage installer
# ===============================
install_appimage() {
    local app_name="$1"
    local download_url="$2"
    local bin_dir="$HOME/.local/bin"
    local appimage_path="$bin_dir/${app_name}.AppImage"
    local symlink_path="$bin_dir/$app_name"

    ensure_local_bin_path

    echo "Downloading from $download_url..."

    if curl -fSL --progress-bar "$download_url" -o "$appimage_path"; then
        chmod +x "$appimage_path"
        ln -sf "$appimage_path" "$symlink_path"
        echo "Downloaded to $appimage_path"
        return 0
    else
        echo -e "${RED}Download failed${NC}"
        return 1
    fi
}

# ===============================
# .deb package installer
# ===============================
install_deb() {
    local app_name="$1"
    local download_url="$2"
    local temp_deb="/tmp/${app_name}.deb"

    echo "Downloading from $download_url..."

    if curl -fSL --progress-bar "$download_url" -o "$temp_deb"; then
        echo "Installing .deb package..."
        if sudo apt install -y "$temp_deb"; then
            rm -f "$temp_deb"
            echo "Installation complete"
            return 0
        else
            echo -e "${RED}Installation failed${NC}"
            rm -f "$temp_deb"
            return 1
        fi
    else
        echo -e "${RED}Download failed${NC}"
        return 1
    fi
}

# ===============================
# Antigravity repository installer
# ===============================
install_antigravity_repo() {
    echo "Setting up Antigravity repository..."

    # Create keyrings directory
    sudo mkdir -p /etc/apt/keyrings

    # Add GPG key
    if ! curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
        sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg; then
        echo -e "${RED}Failed to add GPG key${NC}"
        return 1
    fi

    # Add repository to sources.list.d
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
        sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null

    # Update package cache
    echo "Updating package cache..."
    if ! sudo apt update; then
        echo -e "${RED}Failed to update package cache${NC}"
        return 1
    fi

    # Install antigravity
    echo "Installing antigravity..."
    if sudo apt install -y antigravity; then
        echo "Installation complete"
        return 0
    else
        echo -e "${RED}Installation failed${NC}"
        return 1
    fi
}

# ===============================
# Installers
# ===============================
install_vscode() {
    echo -e "\n${WHITE}[1/3] VS Code${NC}"

    if [ "$SKIP_VSCODE" = true ]; then
        echo -e "  ${GRAY}○ Skipped by flag${NC}"
        log_skipped "VS Code"
        return 0
    fi

    if command_exists code && [ "$FORCE_REINSTALL" = false ]; then
        echo -e "  ${GREEN}✓ Already installed: v$(code --version | head -1)${NC}"
        log_skipped "VS Code v$(code --version | head -1)"
        return 0
    fi

    echo -e "  ${YELLOW}○ Not installed${NC}"

    if prompt_install "VS Code"; then
        show_realtime_header
        if sudo snap install code --classic; then
            show_realtime_footer
            log_installed "VS Code"
        else
            show_realtime_footer
            log_failed "VS Code"
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
        show_realtime_header
        if install_deb "cursor" "https://api2.cursor.sh/updates/download/golden/linux-x64-deb/cursor/2.3"; then
            show_realtime_footer
            log_installed "Cursor"
        else
            show_realtime_footer
            log_failed "Cursor"
        fi
    else
        log_skipped "Cursor"
    fi
}

install_antigravity() {
    echo -e "\n${WHITE}[3/3] Antigravity${NC}"

    if [ "$SKIP_ANTIGRAVITY" = true ]; then
        echo -e "  ${GRAY}○ Skipped by flag${NC}"
        log_skipped "Antigravity"
        return 0
    fi

    # Check if installed via apt (not just if command exists)
    if dpkg -l antigravity 2>/dev/null | grep -q "^ii" && [ "$FORCE_REINSTALL" = false ]; then
        echo -e "  ${GREEN}✓ Already installed via apt${NC}"
        log_skipped "Antigravity"
        return 0
    fi

    # Warn about old AppImage if it exists
    if [ -e "$HOME/.local/bin/antigravity.AppImage" ]; then
        echo -e "  ${YELLOW}○ Found old AppImage installation, will be replaced${NC}"
        rm -f "$HOME/.local/bin/antigravity" "$HOME/.local/bin/antigravity.AppImage"
    fi

    echo -e "  ${YELLOW}○ Not installed${NC}"

    if prompt_install "Antigravity"; then
        show_realtime_header
        if install_antigravity_repo; then
            show_realtime_footer
            log_installed "Antigravity"
        else
            show_realtime_footer
            log_failed "Antigravity"
        fi
    else
        log_skipped "Antigravity"
    fi
}

# ===============================
# Main
# ===============================
main() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${WHITE}   Development Apps Installation${NC}"
    echo -e "${CYAN}========================================${NC}"

    install_vscode || true
    install_cursor || true
    install_antigravity || true

    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${WHITE}   Installation Summary${NC}"
    echo -e "${GREEN}========================================${NC}"

    if [ "${#INSTALLED_APPS[@]}" -gt 0 ]; then
        echo -e "\n${GREEN}Installed:${NC}"
        printf "  ${GREEN}✓${NC} %s\n" "${INSTALLED_APPS[@]}"
    fi

    if [ "${#SKIPPED_APPS[@]}" -gt 0 ]; then
        echo -e "\n${GRAY}Skipped:${NC}"
        printf "  ${GRAY}○${NC} %s\n" "${SKIPPED_APPS[@]}"
    fi

    if [ "${#FAILED_APPS[@]}" -gt 0 ]; then
        echo -e "\n${RED}Failed:${NC}"
        printf "  ${RED}✗${NC} %s\n" "${FAILED_APPS[@]}"
        echo -e "\n${YELLOW}Retry with:${NC} ./apps.sh --reinstall"
    fi

    echo -e "\n${YELLOW}Note:${NC} Restart your terminal to ensure PATH is updated"
}

main
