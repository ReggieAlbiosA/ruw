# Reggie Ubuntu Workspace

Automated Ubuntu workspace setup - opens browser tabs and apps on login.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/setup.sh | bash
```

## What It Does

- Installs dev tools (Node.js, Git, pnpm, VS Code, Cursor, Antigravity)
- Downloads workspace launcher to Desktop
- Creates autostart entry for login
- Sets up bash aliases (git shortcuts, common commands)
- Optional: Claude Code CLI with MCP servers
- Optional: Git Identity Manager (multi-identity commits)

## Scripts

| Script | Purpose |
|--------|---------|
| `setup.sh` | Main installer - runs all setup steps |
| `logon-launch-workspace.sh` | Sets up autostart for login automation |
| `launch-workspace.sh` | Workspace launcher (browser tabs + apps) |
| `claude-code-setup.sh` | Claude Code CLI + MCP server setup |
| `git-identity-setup.sh` | Git multi-identity manager |

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
curl -fsSL https://raw.githubusercontent.com/blueivy828/reggie-ubuntu-workspace/main/logon-launch-workspace.sh | bash
```

## Requirements

- Ubuntu 20.04+ / Debian-based distro
- bash
- curl
- snap (for VS Code)
