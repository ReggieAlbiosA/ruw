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
SKIP_OBSIDIAN=false
SKIP_CHROME=false
SKIP_DOCKER_DESKTOP=false

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
        --skip-obsidian) SKIP_OBSIDIAN=true ;;
        --skip-chrome) SKIP_CHROME=true ;;
        --skip-docker-desktop) SKIP_DOCKER_DESKTOP=true ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: apps.sh [-y|--yes] [--reinstall] [--skip-vscode] [--skip-cursor] [--skip-antigravity] [--skip-obsidian] [--skip-chrome] [--skip-docker-desktop]"
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
# Docker Desktop Prerequisites
# ===============================
check_docker_desktop_prerequisites() {
    local errors=0

    echo -e "  ${CYAN}Checking prerequisites...${NC}"

    # 1. Check 64-bit kernel
    if [ "$(uname -m)" != "x86_64" ]; then
        echo -e "  ${RED}✗ Requires 64-bit (x86_64) system${NC}"
        ((errors++))
    else
        echo -e "  ${GREEN}✓ 64-bit system${NC}"
    fi

    # 2. Check systemd
    if ! pidof systemd >/dev/null 2>&1; then
        echo -e "  ${RED}✗ Requires systemd init system${NC}"
        ((errors++))
    else
        echo -e "  ${GREEN}✓ systemd init system${NC}"
    fi

    # 3. Check RAM (at least 4GB)
    local ram_kb
    ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local ram_gb=$((ram_kb / 1024 / 1024))
    if [ "$ram_gb" -lt 4 ]; then
        echo -e "  ${RED}✗ Requires at least 4GB RAM (found: ${ram_gb}GB)${NC}"
        ((errors++))
    else
        echo -e "  ${GREEN}✓ RAM: ${ram_gb}GB${NC}"
    fi

    # 4. Check Ubuntu version (22.04, 24.04, or latest)
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        case "$VERSION_ID" in
            22.04|24.04|24.10|25.04)
                echo -e "  ${GREEN}✓ Ubuntu $VERSION_ID${NC}"
                ;;
            *)
                echo -e "  ${YELLOW}! Ubuntu $VERSION_ID may not be officially supported${NC}"
                ;;
        esac
    fi

    # 5. Check CPU virtualization support
    if ! grep -qE '(vmx|svm)' /proc/cpuinfo; then
        echo -e "  ${RED}✗ CPU virtualization not enabled (VT-x/AMD-V)${NC}"
        ((errors++))
    else
        echo -e "  ${GREEN}✓ CPU virtualization supported${NC}"
    fi

    # 6. Check desktop environment, install gnome-terminal if needed
    local desktop="${XDG_CURRENT_DESKTOP:-unknown}"
    echo -e "  ${CYAN}  Desktop: $desktop${NC}"
    if [[ ! "$desktop" =~ ^(GNOME|KDE|MATE) ]]; then
        if ! command_exists gnome-terminal; then
            echo -e "  ${YELLOW}! Installing gnome-terminal for non-GNOME desktop...${NC}"
            sudo apt install -y gnome-terminal
        fi
    fi

    return $errors
}

# ===============================
# Docker Credentials Setup
# ===============================
setup_docker_credentials() {
    echo -e "\n  ${CYAN}Setting up Docker Hub credentials...${NC}"

    # Check if pass is installed
    if ! command_exists pass; then
        echo -e "  ${CYAN}> Installing pass...${NC}"
        sudo apt install -y pass
    fi

    local gpg_id=""

    # Check if GPG key already exists
    if gpg --list-keys 2>/dev/null | grep -q "^pub"; then
        echo -e "  ${GREEN}✓ GPG key already exists${NC}"
        gpg_id=$(gpg --list-keys --keyid-format LONG 2>/dev/null | grep "^pub" | head -1 | awk '{print $2}' | cut -d'/' -f2)
    else
        echo -e "  ${CYAN}> Generating GPG key for Docker credentials...${NC}"
        echo -e "  ${YELLOW}  You will be prompted for your name, email, and passphrase${NC}"

        # Generate GPG key (requires user interaction)
        gpg --generate-key

        # Get the GPG key ID
        gpg_id=$(gpg --list-keys --keyid-format LONG 2>/dev/null | grep "^pub" | head -1 | awk '{print $2}' | cut -d'/' -f2)
    fi

    # Initialize pass if not already done
    if [ ! -d "$HOME/.password-store" ]; then
        echo -e "  ${CYAN}> Initializing pass with GPG key...${NC}"
        pass init "$gpg_id"
    else
        echo -e "  ${GREEN}✓ pass already initialized${NC}"
    fi

    echo -e "  ${GREEN}✓ Docker credentials setup complete${NC}"
    echo -e "  ${CYAN}  You can now sign in to Docker Desktop${NC}"
}

# ===============================
# Installers
# ===============================

install_cursor() {
    echo -e "\n${WHITE}[1/5] Cursor${NC}"

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
    echo -e "\n${WHITE}[2/5] Antigravity${NC}"

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

install_obsidian() {
    echo -e "\n${WHITE}[3/5] Obsidian${NC}"

    if [ "$SKIP_OBSIDIAN" = true ]; then
        echo -e "  ${GRAY}○ Skipped by flag${NC}"
        log_skipped "Obsidian"
        return 0
    fi

    if command_exists obsidian && [ "$FORCE_REINSTALL" = false ]; then
        echo -e "  ${GREEN}✓ Already installed${NC}"
        log_skipped "Obsidian"
        return 0
    fi

    echo -e "  ${YELLOW}○ Not installed${NC}"

    if prompt_install "Obsidian"; then
        show_realtime_header
        if install_deb "obsidian" "https://github.com/obsidianmd/obsidian-releases/releases/download/v1.11.5/obsidian_1.11.5_amd64.deb"; then
            show_realtime_footer
            log_installed "Obsidian"
        else
            show_realtime_footer
            log_failed "Obsidian"
        fi
    else
        log_skipped "Obsidian"
    fi
}

install_chrome() {
    echo -e "\n${WHITE}[4/5] Google Chrome${NC}"

    if [ "$SKIP_CHROME" = true ]; then
        echo -e "  ${GRAY}○ Skipped by flag${NC}"
        log_skipped "Google Chrome"
        return 0
    fi

    if command_exists google-chrome && [ "$FORCE_REINSTALL" = false ]; then
        echo -e "  ${GREEN}✓ Already installed${NC}"
        log_skipped "Google Chrome"
        return 0
    fi

    echo -e "  ${YELLOW}○ Not installed${NC}"

    if prompt_install "Google Chrome"; then
        show_realtime_header
        if install_deb "google-chrome" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"; then
            show_realtime_footer
            log_installed "Google Chrome"
        else
            show_realtime_footer
            log_failed "Google Chrome"
        fi
    else
        log_skipped "Google Chrome"
    fi
}

install_docker_engine() {
    echo -e "  ${CYAN}> Installing Docker Engine (required dependency)...${NC}"

    # Add Docker's official GPG key
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to apt sources
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

    # Install Docker Engine packages
    if sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        echo -e "  ${GREEN}✓ Docker Engine installed${NC}"
        return 0
    else
        echo -e "  ${RED}✗ Failed to install Docker Engine${NC}"
        return 1
    fi
}

install_docker_desktop() {
    echo -e "\n${WHITE}[5/5] Docker Desktop${NC}"

    if [ "$SKIP_DOCKER_DESKTOP" = true ]; then
        echo -e "  ${GRAY}○ Skipped by flag${NC}"
        log_skipped "Docker Desktop"
        return 0
    fi

    # Check if Docker Desktop is already installed (check for docker-desktop package)
    if dpkg -l docker-desktop 2>/dev/null | grep -q "^ii" && [ "$FORCE_REINSTALL" = false ]; then
        local version
        version=$(docker --version 2>/dev/null)
        echo -e "  ${GREEN}✓ Already installed: $version${NC}"
        log_skipped "Docker Desktop"
        return 0
    fi

    echo -e "  ${YELLOW}○ Not installed${NC}"

    # Check prerequisites
    if ! check_docker_desktop_prerequisites; then
        echo -e "  ${RED}✗ Prerequisites not met. Cannot install Docker Desktop.${NC}"
        log_failed "Docker Desktop (prerequisites)"
        return 1
    fi

    if prompt_install "Docker Desktop"; then
        show_realtime_header

        # Install Docker Engine first (provides docker-ce-cli dependency)
        if ! command_exists docker; then
            if ! install_docker_engine; then
                show_realtime_footer
                log_failed "Docker Desktop (Docker Engine dependency failed)"
                return 1
            fi
        fi

        # Now install Docker Desktop
        local docker_url="https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb"
        if install_deb "docker-desktop" "$docker_url"; then
            show_realtime_footer
            log_installed "Docker Desktop"

            # Ask about credentials setup
            echo -e "\n  ${CYAN}Docker Desktop installed successfully!${NC}"
            if prompt_install "Docker Hub credentials setup (recommended for pushing images)"; then
                setup_docker_credentials
            else
                echo -e "  ${GRAY}○ Skipped credentials setup${NC}"
                echo -e "  ${CYAN}  Run later: gpg --generate-key && pass init <GPG_ID>${NC}"
            fi
        else
            show_realtime_footer
            log_failed "Docker Desktop"
        fi
    else
        log_skipped "Docker Desktop"
    fi
}

# ===============================
# Main
# ===============================
main() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${WHITE}    Apps Installation${NC}"
    echo -e "${CYAN}========================================${NC}"

    install_cursor || true
    install_antigravity || true
    install_obsidian || true
    install_chrome || true
    install_docker_desktop || true

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
}

main
