# dotfiles

Personal system configuration for Fedora KDE.

## What's included

| Component | Config | Notes |
|-----------|--------|-------|
| **Shell** | zsh + Oh My Zsh + Powerlevel10k | Plugins: git, fzf, z, sudo, zsh-completions, autosuggestions, syntax-highlighting |
| **Kitty** | Catppuccin Mocha OLED, JetBrains Mono, splits, tabs, hints, markers | Primary terminal |
| **KDE** | Catppuccin Mocha theme, Kvantum, Papirus-Dark icons, CatppuccinMocha-Modern window decoration | Tiling enabled, Night Color on |
| **Cursors** | catppuccin-mocha-lavender-cursors | |
| **Fonts** | JetBrains Mono, MesloLGS NF (p10k), Noto Sans | |
| **Git** | gh credential helper, global gitignore | |
| **Claude Code** | Custom settings.json, powerline statusline script, plugins | |
| **GitHub CLI** | config.yml (aliases, https protocol), hosts.yml (NikhilBery) | |
| **Default Apps** | mimeapps.list — Zed for text, Brave for web, Slack/Upwork handlers | |
| **Plasma Desktop** | Panel layout, applets, system tray, widget config | |
| **Custom Scripts** | Upwork Wayland patch + launcher, screenshot bridge service | |
| **Systemd** | plasma-gnome-screenshot-bridge.service | User service |

## KDE keyboard shortcuts (custom)

- `Ctrl+Alt+T` — Launch Kitty
- `Meta+T` — Toggle Tiles Editor
- `Meta+W` — Overview
- `Meta+G` — Grid View
- `Meta+D` — Peek at Desktop
- `Meta+H` — Minimize Window
- `Meta+V` — Show Clipboard at Mouse

## Quick install

```bash
# On a fresh Fedora KDE install:
sudo dnf install -y git
git clone https://github.com/numbery/dotfiles ~/Projects/dotfiles
cd ~/Projects/dotfiles
./install.sh
```

## Selective install

```bash
./install.sh --packages   # System packages only
./install.sh --shell      # zsh + oh-my-zsh + p10k + plugins
./install.sh --kitty      # Kitty terminal config
./install.sh --kde        # KDE theme + Catppuccin + shortcuts
./install.sh --claude     # Claude Code + statusline
./install.sh --git        # Git config + gh
./install.sh --fonts      # JetBrains Mono + MesloLGS NF + Noto Sans
./install.sh --upwork     # Upwork Wayland patch + screenshot bridge (not in --all)
```

## Post-install

1. Log out / log back in (zsh + KDE theme)
2. `gh auth login` (GitHub)
3. `claude` (Claude Code auth)
4. `p10k configure` if prompt looks off

## Repo structure

```
dotfiles/
  shell/          zshrc, zshenv, p10k.zsh, bashrc, npmrc
  kitty/          kitty.conf
  claude-code/    settings.json, claude-statusline
  kde/            kdeglobals, kwinrc, kglobalshortcutsrc, mimeapps.list,
                  plasma-custom-shortcuts.khotkeys, kded5rc, gtkrc-2.0,
                  Kvantum/, plasma/
  git/            gitconfig, gitignore_global
  gh/             config.yml, hosts.yml
  fonts/          MesloLGS NF .ttf, fonts.conf
  scripts/upwork/ patch-upwork, upwork-wayland
  systemd/        plasma-gnome-screenshot-bridge.service
  install.sh      Setup script
```

## Backups

The install script backs up existing files to `~/.dotfiles-backup/<timestamp>/` before overwriting.
