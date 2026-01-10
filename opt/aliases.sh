#!/bin/bash
# aliases-setup.sh
# Configures bash aliases for the Reggie Ubuntu Workspace
# Run standalone or as part of setup.sh

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

# Markers for managed aliases block
START_MARKER="# >>> REGGIE-WORKSPACE-ALIASES >>>"
END_MARKER="# <<< REGGIE-WORKSPACE-ALIASES <<<"

# Target file
BASHRC="$HOME/.bashrc"

# ============================================
# Helper Functions
# ============================================

show_realtime_header() {
    echo -e "  ${YELLOW}┌─ Installation Output ─┐${NC}"
}

show_realtime_footer() {
    echo -e "  ${YELLOW}└───────────────────────┘${NC}"
}

check_aliases_installed() {
    if grep -q "$START_MARKER" "$BASHRC" 2>/dev/null; then
        return 0  # Already installed
    else
        return 1  # Not installed
    fi
}

# ============================================
# Aliases Content
# ============================================

read -r -d '' ALIASES_CONTENT <<'EOF' || true
# >>> REGGIE-WORKSPACE-ALIASES >>>
# Git Aliases
alias gs='git status'
alias ga='git add'
alias gp='git push'
alias gl='git log --oneline --decorate --graph'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias gpull='git pull'
alias gc='git commit'

gsw() {
    git switch "$@"
}

gr() {
    git remote "$@"
}

gcp() {
    git cherry-pick "$@"
}

# personal shortcuts
alias ~='cd ~'
alias ..='cd ..'
alias ...='cd ../..'
alias te='gnome-text-editor'
alias claude='claude --dangerously-skip-permissions'
alias folders='nautilus &'
alias t='tldr'
alias cat='batcat'
alias m='micro'
alias ls='eza -a'
alias ll='eza -la'
alias llt='eza -l -a --total-size'
alias sleep='systemctl suspend'
alias reboot='systemctl reboot'
alias poff='systemctl poweroff'
alias ubash='source ~/.bashrc'
alias sbash='source /etc/bash.bashrc'
alias dockerlun='nohup /opt/docker-desktop/bin/docker-desktop >/dev/null 2>&1 & >/dev/null 2>&1 &'
alias ft='file  --mime-type *'




# ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -cF'
# Common commands
alias cls='clear'
alias md='mkdir -p'

# CLI tools reference - responsive two-column grid
cli() {
    local Y='\033[1;33m'
    local C='\033[0;36m'
    local G='\033[0;90m'
    local W='\033[1;37m'
    local N='\033[0m'

    local width
    width=$(tput cols)
    local min_width=90

    if (( width < min_width )); then
        echo -e "${Y}Terminal too narrow ${width} cols. Resize to ≥ ${min_width}.${N}"
        return 1
    fi

    # Layout math (STRICT)
    local inner=$((width - 2))
    local col=$(( (inner - 1) / 2 ))   # two columns + center separator
    local cmd_w=12
    local desc_w=$((col - cmd_w - 2))

    repeat_char() {
        local char="$1" count="$2"
        local i
        for ((i=0; i<count; i++)); do printf '%s' "$char"; done
    }

    hline() {
        printf "${W}┌"
        repeat_char '─' "$inner"
        printf "┐${N}\n"
    }

    mline() {
        printf "${W}├"
        repeat_char '─' "$col"
        printf "┼"
        repeat_char '─' "$col"
        printf "┤${N}\n"
    }

    fline() {
        printf "${W}└"
        repeat_char '─' "$inner"
        printf "┘${N}\n"
    }

    header() {
        printf "${W}│${N} ${Y}%-*s${N} ${W}│${N}\n" $((inner - 2)) "$1"
    }

    row2() {
        local c1="$1" d1="$2" c2="$3" d2="$4"
        printf "${W}│${N} ${C}%-*s${N} ${G}%-*s${N} ${W}│${N} " \
            "$cmd_w" "$c1" "$desc_w" "$d1"

        if [[ -n "$c2" ]]; then
            printf "${C}%-*s${N} ${G}%-*s${N} ${W}│${N}\n" \
                "$cmd_w" "$c2" "$desc_w" "$d2"
        else
            printf "%-*s ${W}│${N}\n" "$col" ""
        fi
    }

    hline
    header "🔎 Core modern CLI (daily drivers)"
    mline
    row2 "fzf" "Fuzzy finder (universal)" "rg" "ripgrep – fast code search"
    row2 "fd" "Modern find" "bat" "cat with syntax highlight"
    row2 "eza" "Modern ls (exa replacement)" "zoxide" "Smart cd"

    mline
    header "📂 Files, Disk, Processes"
    mline
    row2 "duf" "df replacement" "dust" "du replacement"
    row2 "procs" "ps replacement" "btm" "htop replacement"
    row2 "tree" "Directory tree" "" ""

    mline
    header "📄 View, Diff, Inspect"
    mline
    row2 "delta" "Better git diff" "hexyl" "Hex viewer"
    row2 "tokei" "Code line counter" "viddy" "Modern watch"

    mline
    header "🌐 Network, API, Debug"
    mline
    row2 "httpie" "HTTP client" "xh" "Faster httpie (Rust)"
    row2 "curlie" "curl + httpie UX" "doggo" "DNS lookup"
    row2 "grpcurl" "gRPC CLI" "" ""

    mline
    header "📦 Data & Formats"
    mline
    row2 "jq" "JSON manipulation" "yq" "YAML manipulation"
    row2 "fx" "Interactive JSON viewer" "xsv" "CSV processing"
    row2 "csvkit" "CSV utilities" "" ""

    mline
    header "🧠 Git & Dev Workflow"
    mline
    row2 "lazygit" "Git TUI" "gh" "GitHub CLI"
    row2 "gitui" "Git TUI (lightweight)" "tig" "Git history browser"
    row2 "act" "Run GitHub Actions locally" "" ""

    mline
    header "🐳 Containers & Infra"
    mline
    row2 "lazydocker" "Docker TUI" "ctop" "Container metrics"
    row2 "k9s" "Kubernetes TUI" "kubectx" "Switch kube contexts"
    row2 "kubens" "Switch namespaces" "" ""

    mline
    header "⚙️ Automation & Runtimes"
    mline
    row2 "just" "Makefile replacement" "watchexec" "File watcher"
    row2 "entr" "Run on file change" "mise" "Runtime version manager"

    mline
    header "🧪 Shell Productivity"
    mline
    row2 "atuin" "Smart shell history" "direnv" "Per-dir env vars"
    row2 "thefuck" "Fix last command" "" ""

    fline
}

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
# <<< REGGIE-WORKSPACE-ALIASES <<<
EOF

# ============================================
# Main Logic
# ============================================

echo -e "\n${CYAN}========================================${NC}"
echo -e "${WHITE}   Bash Aliases Setup${NC}"
echo -e "${CYAN}========================================${NC}"

if check_aliases_installed; then
    echo -e "\n  ${GREEN}✓ Aliases already configured${NC}"
    echo -e "  ${CYAN}> Updating existing aliases...${NC}"
    show_realtime_header

    # Remove old block and add updated one
    sed -i "/$START_MARKER/,/$END_MARKER/d" "$BASHRC"
    echo "$ALIASES_CONTENT" >> "$BASHRC"
    echo "Updated bash aliases in $BASHRC"

    show_realtime_footer
    echo -e "  ${GREEN}✓ Aliases updated${NC}"
else
    echo -e "\n  ${YELLOW}○ Aliases not configured${NC}"
    echo -e "  ${CYAN}> Installing bash aliases...${NC}"
    show_realtime_header

    # Add aliases to .bashrc
    echo "" >> "$BASHRC"
    echo "$ALIASES_CONTENT" >> "$BASHRC"
    echo "Added bash aliases to $BASHRC"

    show_realtime_footer
    echo -e "  ${GREEN}✓ Aliases installed${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${WHITE}   Aliases Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${GRAY}Configured aliases:${NC}"
echo -e "  ${GRAY}• Git: gs, ga, gp, gl, gd, gco, gb, gpull, gc, gsw, gr, gcp${NC}"
echo -e "  ${GRAY}• Navigation: ~, .., ...${NC}"
echo -e "  ${GRAY}• Tools: te, claude, folders, t, cat, m, ls${NC}"
echo -e "  ${GRAY}• LS variants: ll, la, l${NC}"
echo -e "  ${GRAY}• Common: cls, md${NC}"
echo -e "  ${GRAY}• Help: cli (show CLI tools reference)${NC}"
echo -e "  ${GRAY}• Safety: rm, cp, mv (with -i)${NC}"

echo -e "\n${YELLOW}Restart your terminal or run 'source ~/.bashrc' to apply.${NC}"
echo ""
