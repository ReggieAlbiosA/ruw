# Reggie Ubuntu Workspace

Automated Ubuntu workspace setup - opens browser tabs and apps on login.

## Install

**Recommended (auto-accept all prompts):**
```bash
curl -fsSL https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/setup.sh | bash -s -- -y
```

**Or download and run interactively:**
```bash
curl -fsSL https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/setup.sh -o setup.sh
chmod +x setup.sh
./setup.sh
```

### Install Overrides

```bash
# Auto-accept all prompts (including optional modules)
curl -fsSL .../setup.sh | bash -s -- -y

# Skip optional modules (Claude Code, Git Identity)
curl -fsSL .../setup.sh | bash -s -- --skip-optional

# Or run locally with flags
./setup.sh -y
./setup.sh --skip-optional
./setup.sh --defaults-only
```

## What It Does

**Auto-installed (no prompts):**
- Core packages: Node.js, Git, pnpm
- Workspace launcher (Desktop + autostart)

**Prompted installations:**
- Development apps: VS Code, Cursor, Antigravity (individual prompts)

**Optional modules (prompted):**
- Modern CLI tools (fzf, ripgrep, fd, bat, eza, zoxide)
- Claude Code CLI with MCP servers
- Git Identity Manager (multi-identity commits)
- Bash aliases (git shortcuts, common commands)

## Scripts

| Script | Purpose |
|--------|---------|
| `setup.sh` | Main installer - orchestrates all modules |
| `def/packages.sh` | Core packages (Node.js, Git, pnpm) |
| `def/apps.sh` | Development apps (VS Code, Cursor, Antigravity) |
| `def/logon-launch-workspace.sh` | Autostart workspace launcher |
| `opt/claude-code.sh` | Claude Code CLI + MCP servers |
| `opt/cli-tools.sh` | Modern CLI tools (fzf, ripgrep, etc) |
| `opt/git-identity.sh` | Git multi-identity manager |
| `opt/aliases.sh` | Bash aliases and shortcuts |
| `launch-workspace.sh` | Workspace launcher script |

## Standalone Module Usage

Install only core packages:
```bash
curl -fsSL https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/def/packages.sh | bash
```

Install only development apps:
```bash
curl -fsSL https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/def/apps.sh | bash -s -- -y
```

Skip specific apps:
```bash
./def/apps.sh -y --skip-cursor --skip-antigravity  # Only install VS Code
```

### Module Options

**def/packages.sh:**
- `-y, --yes` - Auto-accept (no-op, always auto-installs)
- `--reinstall` - Force reinstall existing packages
- `--skip-nodejs` - Skip Node.js installation
- `--skip-git` - Skip Git installation
- `--skip-pnpm` - Skip pnpm installation

**def/apps.sh:**
- `-y, --yes` - Auto-accept all prompts
- `--reinstall` - Force reinstall existing apps
- `--skip-vscode` - Skip VS Code installation
- `--skip-cursor` - Skip Cursor installation
- `--skip-antigravity` - Skip Antigravity installation

## Customize

Edit `launch-workspace.sh` on your Desktop:

```bash
#!/bin/bash

# Open browser tabs
xdg-open "https://your-urls-here.com" &

# Open applications
gnome-terminal &
obsidian &
```

**Specific browser:** Replace `xdg-open` with `google-chrome`, `firefox`, or `brave-browser`

## Uninstall

```bash
# Remove autostart entry
rm ~/.config/autostart/reggie-workspace.desktop

# Remove launcher from Desktop
rm ~/Desktop/launch-workspace.sh
```

## Troubleshooting

**Permission denied:**
```bash
chmod +x ~/Desktop/launch-workspace.sh
```

**Autostart not working:** Check `~/.config/autostart/reggie-workspace.desktop` exists

**Re-run autostart setup only:**
```bash
curl -fsSL https://raw.githubusercontent.com/ReggieAlbiosA/reggie-ubuntu-workspace/main/logon-launch-workspace.sh | bash
```

## Requirements

- Ubuntu 20.04+ / Debian-based distro
- bash
- curl
- snap (for VS Code)
