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
| **Git** | Aliases (lg, st, unstage, autoremove), vimdiff merge/diff, push.autoSetupRemote, pull.rebase, global gitignore | |
| **Claude Code** | Custom settings.json, powerline statusline script, plugins | |
| **GitHub CLI** | config.yml (aliases, https protocol), hosts.yml (NikhilBery) | |
| **Default Apps** | mimeapps.list — Zed for text, Brave for web, Slack/Upwork handlers | |
| **Plasma Desktop** | Panel layout, applets, system tray, widget config | |
| **Custom Scripts** | Upwork Wayland patch + launcher, screenshot bridge service | |
| **Systemd** | plasma-gnome-screenshot-bridge.service | User service |
| **Shortcuts Cheatsheet** | Searchable popup (Meta+/) — parses live configs from kitty, tmux, zsh, lazygit, aerc, superfile | Floating Catppuccin-themed kitty window with fzf |

### Shell enhancements

- **XDG compliance** — GOPATH, RUSTUP_HOME, CUDA_CACHE, Jupyter, Docker, npm all use XDG dirs
- **fd + fzf** — `Ctrl+T` (files), `Alt+C` (dirs), `Ctrl+R` (history) all use fd for speed
- **Completion** — case-insensitive matching, fzf-tab previews for cd/zoxide
- **Aliases** — `lg` (lazygit), `ff` (fd), `icat` (kitty image viewer), `whatismyip`, Docker Compose shortcuts (`dcuf`, `dcbd`, `dclf`, `dcd`)

### Optional tools (not in default install)

| Tool | What it does | Install flag |
|------|-------------|-------------|
| **eza** | Modern `ls` with icons, git status, tree view | `--eza` |
| **bat** | Modern `cat` with syntax highlighting | `--bat` |
| **zoxide** | Smarter `cd` — learns your frequent directories | `--zoxide` |
| **lazygit** | Terminal git UI with Catppuccin theme + delta pager | `--lazygit` |
| **direnv** | Per-directory environment variables | `--direnv` |
| **tmux** | Terminal multiplexer — sesh sessions, lazygit popup, TPM | `--tmux` |
| **superfile** | Terminal file manager — Catppuccin theme, zoxide | `--superfile` |
| **Taskwarrior** | CLI task management | `--taskwarrior` |
| **Butler** | ASUS Zenbook S 14 power profile + kbd backlight daemon | `--butler` |
| **Email** | Terminal email: aerc + notmuch + lieer (Gmail API sync) | `--email` |

Shell aliases for eza, bat, zoxide, direnv, and sesh activate automatically in zshrc when the tool is installed.

### Tmux keybindings (prefix: Ctrl+A)

| Key | Action |
|-----|--------|
| `C-a \|` / `C-a -` | Split vertical / horizontal |
| `C-a h/j/k/l` | Navigate panes (vi) |
| `Alt+1-9` | Go to window N |
| `C-a C-g` | Lazygit popup |
| `C-a C-s` | Sesh session picker |
| `C-a C-l` | Sesh last session |
| `Ctrl+K` | Clear screen + scrollback |

### Terminal email (aerc + notmuch + lieer)

Two-way Gmail sync via the Gmail API (not IMAP):

| Action | Timing |
|--------|--------|
| **Send** | Instant (Gmail API) |
| **Receive** | Every 5 min (`mail-sync.timer`) |
| **Push changes** (trash, archive, star) | Every 2 hours (`mail-push.timer`) |

## KDE keyboard shortcuts (custom)

- `Meta+/` — Shortcuts cheatsheet popup
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
# Core (included in --all)
./install.sh --packages   # System packages only
./install.sh --shell      # zsh + oh-my-zsh + p10k + plugins + cheatsheet
./install.sh --kitty      # Kitty terminal config
./install.sh --kde        # KDE theme + Catppuccin + shortcuts
./install.sh --claude     # Claude Code + statusline
./install.sh --git        # Git config + gh
./install.sh --fonts      # JetBrains Mono + MesloLGS NF + Noto Sans

# Optional tools (not in --all)
./install.sh --tools        # All optional tools at once
./install.sh --eza          # Modern ls with icons + git
./install.sh --bat          # Modern cat with syntax highlighting
./install.sh --zoxide       # Smarter cd (z, zi commands)
./install.sh --lazygit      # Terminal git UI + Catppuccin + delta
./install.sh --direnv       # Per-directory env vars
./install.sh --tmux         # tmux (sesh, lazygit popup, TPM)
./install.sh --superfile    # Terminal file manager
./install.sh --taskwarrior  # CLI task management
./install.sh --butler       # ASUS Zenbook S 14 power/backlight daemon
./install.sh --email        # Terminal email (aerc + notmuch + lieer for Gmail)
./install.sh --upwork       # Upwork Wayland patch + screenshot bridge
```

## Post-install

1. Log out / log back in (zsh + KDE theme + Meta+/ shortcut)
2. `gh auth login` (GitHub)
3. `claude` (Claude Code auth)
4. `p10k configure` if prompt looks off

## Repo structure

```
dotfiles/
  shell/              zshrc, zshenv, p10k.zsh, bashrc, npmrc
  kitty/              kitty.conf
  claude-code/        settings.json, claude-statusline
  kde/                kdeglobals, kwinrc, kglobalshortcutsrc, khotkeysrc,
                      kwinrulesrc, mimeapps.list, plasma-custom-shortcuts.khotkeys,
                      kded5rc, gtkrc-2.0, Kvantum/, plasma/
  git/                gitconfig, gitignore_global
  gh/                 config.yml, hosts.yml
  fonts/              MesloLGS NF .ttf, fonts.conf
  tools/
    tmux/             tmux.conf (sesh, lazygit popup, TPM, Catppuccin)
    lazygit/          config.yml (Catppuccin, delta pager)
    superfile/        config.toml (Catppuccin, zoxide, nerd fonts)
    taskwarrior/      taskrc
    butler/           butler-daemon, butler-daemon.service
    email/            aerc config, notmuch config, Catppuccin styleset,
                      query-map, mail-sync/push timers + services
  scripts/
    cheatsheet/       shortcuts, show-shortcuts, show-shortcuts.desktop
    upwork/           patch-upwork, upwork-wayland, upwork.desktop
  systemd/            plasma-gnome-screenshot-bridge.service
  install.sh          Setup script
```

## Backups

The install script backs up existing files to `~/.dotfiles-backup/<timestamp>/` before overwriting.
