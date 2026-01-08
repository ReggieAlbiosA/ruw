#!/bin/bash
# git-identity-setup.sh
# Interactive Git Identity Manager - prompts for author on each commit

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# File paths
IDENTITIES_FILE="$HOME/.git-identities"
HOOKS_DIR="$HOME/.git-hooks"
HOOK_FILE="$HOOKS_DIR/pre-commit"

# Helper function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Helper function to validate email format
validate_email() {
    local email="$1"
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check Git installation
check_git() {
    echo -e "\n${NC}[1/5] Checking Git...${NC}"

    if command_exists git; then
        echo -e "  ${GREEN}+ Git installed: $(git --version)${NC}"
        return 0
    else
        echo -e "  ${RED}! Git is not installed. Please install Git first.${NC}"
        return 1
    fi
}

# Check for existing identities file - FIXED VERSION
check_existing_identities() {
    echo -e "\n${NC}[2/5] Checking existing identities...${NC}"

    if [ -f "$IDENTITIES_FILE" ]; then
        local count=$(wc -l < "$IDENTITIES_FILE")
        echo -e "  ${YELLOW}! Found existing identities file with $count identity/identities${NC}"
        echo -e "  ${GRAY}  Location: $IDENTITIES_FILE${NC}"
        echo ""
        echo -e "  ${CYAN}Current identities:${NC}"
        while IFS=: read -r num name email label; do
            echo -e "    $num) $label ($email)"
        done < "$IDENTITIES_FILE"
        echo ""
        
        while true; do
            read -p "  > Keep existing identities? (y = keep, n = reconfigure): " -r REPLY
            case "${REPLY,,}" in
                y|yes)
                    echo -e "  ${GREEN}+ Keeping existing identities${NC}"
                    return 1  # Skip collection
                    ;;
                n|no)
                    echo -e "  ${YELLOW}> Will reconfigure identities${NC}"
                    rm -f "$IDENTITIES_FILE"
                    return 0  # Proceed with collection
                    ;;
                *)
                    echo -e "  ${RED}! Invalid input. Please enter 'y' or 'n'${NC}"
                    ;;
            esac
        done
    else
        echo -e "  ${GRAY}i No existing identities found${NC}"
        return 0  # Proceed with collection
    fi
}

# Collect identities from user - FIXED VERSION
collect_identities() {
    echo -e "\n${NC}[3/5] Collecting Git identities...${NC}"
    echo -e "  ${GRAY}i You can add multiple identities (Work, Personal, Client, etc.)${NC}"
    echo ""

    local identity_count=0

    while true; do
        echo -e "  ${MAGENTA}--- Identity #$((identity_count + 1)) ---${NC}"

        # Get label
        local label=""
        while [ -z "$label" ]; do
            read -p "  > Enter identity name (e.g., 'Work', 'Personal', 'Client'): " label
            if [ -z "$label" ]; then
                echo -e "    ${RED}! Identity name cannot be empty${NC}"
            fi
        done

        # Get full name
        local name=""
        while [ -z "$name" ]; do
            read -p "  > Enter full name for commits: " name
            if [ -z "$name" ]; then
                echo -e "    ${RED}! Name cannot be empty${NC}"
            fi
        done

        # Get email
        local email=""
        while true; do
            read -p "  > Enter email for commits: " email
            if [ -z "$email" ]; then
                echo -e "    ${RED}! Email cannot be empty${NC}"
            elif ! validate_email "$email"; then
                echo -e "    ${RED}! Invalid email format. Please include @${NC}"
            else
                break
            fi
        done

        # Save identity
        identity_count=$((identity_count + 1))
        echo "$identity_count:$name:$email:$label" >> "$IDENTITIES_FILE"
        echo -e "  ${GREEN}+ Added: $label ($email)${NC}"
        echo ""

        # Ask for more - FIXED VERSION
        while true; do
            read -p "  > Add another identity? (a = add more, x = done): " -r REPLY
            case "${REPLY,,}" in
                a)
                    break 2  # Break both while loops to add another
                    ;;
                x)
                    break 2  # Break to exit main loop
                    ;;
                *)
                    echo -e "    ${RED}! Invalid input. Please enter 'a' or 'x'${NC}"
                    ;;
            esac
        done
        
        # If we get here via 'x', break the outer loop
        if [[ ${REPLY,,} == "x" ]]; then
            break
        fi
        
        echo ""
    done

    if [ $identity_count -eq 0 ]; then
        echo -e "  ${RED}! At least one identity is required${NC}"
        return 1
    fi

    echo -e "  ${GREEN}+ Saved $identity_count identity/identities to $IDENTITIES_FILE${NC}"
    return 0
}

# Create the pre-commit hook
create_hook() {
    echo -e "\n${NC}[4/5] Creating pre-commit hook...${NC}"

    # Create hooks directory
    mkdir -p "$HOOKS_DIR"
    echo -e "  ${GREEN}+ Created hooks directory: $HOOKS_DIR${NC}"

    # Generate the hook script
    cat > "$HOOK_FILE" << 'HOOKEOF'
#!/bin/bash
# Global pre-commit hook - Git Identity Manager
# Dynamically generated by git-identity-setup.sh

IDENTITIES_FILE="$HOME/.git-identities"

# Check if identities file exists
if [ ! -f "$IDENTITIES_FILE" ]; then
    echo "Error: Git identities file not found at $IDENTITIES_FILE"
    echo "Run git-identity-setup.sh to configure identities."
    exit 1
fi

# Function to display menu and get selection
show_menu() {
    # Get current identity
    CURRENT_EMAIL=$(git config user.email 2>/dev/null || echo "not set")

    # Find current label if it matches
    CURRENT_LABEL=""
    while IFS=: read -r num name email label; do
        if [ "$email" = "$CURRENT_EMAIL" ]; then
            CURRENT_LABEL=" ($label)"
            break
        fi
    done < "$IDENTITIES_FILE"

    echo ""
    echo "Current identity: $CURRENT_EMAIL$CURRENT_LABEL"
    echo ""
    echo "Choose commit identity:"

    # Read and display identities
    while IFS=: read -r num name email label; do
        echo "$num) $label ($email)"
    done < "$IDENTITIES_FILE"

    echo "a) Add new identity"
    echo "Enter) Keep current"
    echo ""
}

# Function to add new identity
add_identity() {
    echo ""
    echo "--- Add New Identity ---"

    # Get next number
    local next_num=$(($(wc -l < "$IDENTITIES_FILE") + 1))

    # Get label
    local label=""
    while [ -z "$label" ]; do
        read -p "Enter identity name (e.g., 'Work', 'Personal'): " label < /dev/tty
        if [ -z "$label" ]; then
            echo "Identity name cannot be empty"
        fi
    done

    # Get full name
    local name=""
    while [ -z "$name" ]; then
        read -p "Enter full name for commits: " name < /dev/tty
        if [ -z "$name" ]; then
            echo "Name cannot be empty"
        fi
    done

    # Get email
    local email=""
    while true; do
        read -p "Enter email for commits: " email < /dev/tty
        if [ -z "$email" ]; then
            echo "Email cannot be empty"
        elif [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo "Invalid email format"
        else
            break
        fi
    done

    # Save identity
    echo "$next_num:$name:$email:$label" >> "$IDENTITIES_FILE"
    echo ""
    echo "Added: $label ($email)"
    echo ""
}

# Main loop
while true; do
    show_menu

    # Read from terminal directly (git hooks don't have stdin)
    read -p "Select: " choice < /dev/tty

    # Handle 'a' - add new identity
    if [[ "$choice" =~ ^[Aa]$ ]]; then
        add_identity
        continue
    fi

    # Handle empty - keep current
    if [ -z "$choice" ]; then
        echo "Keeping current identity"
        exit 0
    fi

    # Handle number selection
    SELECTED=$(grep "^$choice:" "$IDENTITIES_FILE")

    if [ -z "$SELECTED" ]; then
        echo "Invalid choice. Try again."
        continue
    fi

    # Parse selected identity
    NAME=$(echo "$SELECTED" | cut -d: -f2)
    EMAIL=$(echo "$SELECTED" | cut -d: -f3)
    LABEL=$(echo "$SELECTED" | cut -d: -f4)

    # Apply identity to this repo
    git config user.name "$NAME"
    git config user.email "$EMAIL"
    echo "Switched to $LABEL ($EMAIL)"
    exit 0
done
HOOKEOF

    # Make hook executable
    chmod +x "$HOOK_FILE"
    echo -e "  ${GREEN}+ Created pre-commit hook: $HOOK_FILE${NC}"

    return 0
}

# Configure Git to use global hooks
configure_git_hooks() {
    echo -e "\n${NC}[5/5] Configuring Git global hooks...${NC}"

    git config --global core.hooksPath "$HOOKS_DIR"
    echo -e "  ${GREEN}+ Set global hooks path: $HOOKS_DIR${NC}"

    # Set first identity as default (required for git to allow commits)
    if [ -f "$IDENTITIES_FILE" ]; then
        FIRST_IDENTITY=$(head -1 "$IDENTITIES_FILE")
        DEFAULT_NAME=$(echo "$FIRST_IDENTITY" | cut -d: -f2)
        DEFAULT_EMAIL=$(echo "$FIRST_IDENTITY" | cut -d: -f3)
        DEFAULT_LABEL=$(echo "$FIRST_IDENTITY" | cut -d: -f4)

        git config --global user.name "$DEFAULT_NAME"
        git config --global user.email "$DEFAULT_EMAIL"
        echo -e "  ${GREEN}+ Set default identity: $DEFAULT_LABEL ($DEFAULT_EMAIL)${NC}"
    fi

    return 0
}

# Show completion message
show_success() {
    echo ""
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}    Git Identity Manager Installed!${NC}"
    echo -e "${GREEN}==========================================${NC}"
    echo ""
    echo -e "${CYAN}How it works:${NC}"
    echo -e "  - On every commit, you'll be prompted to choose an identity"
    echo -e "  - Press Enter to keep current identity, or select a number"
    echo ""
    echo -e "${CYAN}Configuration files:${NC}"
    echo -e "  ${GRAY}Identities: $IDENTITIES_FILE${NC}"
    echo -e "  ${GRAY}Hook:       $HOOK_FILE${NC}"
    echo ""
    echo -e "${CYAN}To manage identities:${NC}"
    echo -e "  ${GRAY}Edit:   nano $IDENTITIES_FILE${NC}"
    echo -e "  ${GRAY}Format: number:Full Name:email@example.com:Label${NC}"
    echo ""
    echo -e "${YELLOW}Note: The hook runs on ALL git repositories for this user.${NC}"
    echo ""
}

# Main execution
main() {
    echo ""
    echo -e "${MAGENTA}==========================================${NC}"
    echo -e "${MAGENTA}    Git Identity Manager Setup${NC}"
    echo -e "${MAGENTA}==========================================${NC}"
    echo ""

    # Step 1: Check Git
    if ! check_git; then
        echo -e "\n${RED}=== Setup Failed ===${NC}"
        exit 1
    fi

    # Step 2: Check existing identities
    local skip_collection=false
    if ! check_existing_identities; then
        skip_collection=true
    fi

    # Step 3: Collect identities (if needed)
    if [ "$skip_collection" = false ]; then
        if ! collect_identities; then
            echo -e "\n${RED}=== Setup Failed ===${NC}"
            echo -e "${YELLOW}At least one identity is required.${NC}"
            exit 1
        fi
    fi

    # Step 4: Create hook
    if ! create_hook; then
        echo -e "\n${RED}=== Setup Failed ===${NC}"
        exit 1
    fi

    # Step 5: Configure Git
    if ! configure_git_hooks; then
        echo -e "\n${RED}=== Setup Failed ===${NC}"
        exit 1
    fi

    # Show success
    show_success
}

# Run the setup
main
