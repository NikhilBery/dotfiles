#!/usr/bin/env bash
# Dotfiles installer for Fedora KDE
# Replicates numbery's system setup on a fresh Fedora KDE install
#
# Usage:
#   git clone <this-repo> ~/Projects/dotfiles
#   cd ~/Projects/dotfiles
#   ./install.sh [--all | --packages | --shell | --kitty | --kde | --claude | --git | --fonts]
#
# Optional tools (not in --all):
#   ./install.sh --tools         # All optional tools at once
#   ./install.sh --eza           # Modern ls replacement
#   ./install.sh --bat           # Modern cat replacement
#   ./install.sh --zoxide        # Smarter cd
#   ./install.sh --lazygit       # Terminal git UI
#   ./install.sh --direnv        # Per-directory env vars
#   ./install.sh --tmux          # tmux config (Catppuccin, vi keys)
#   ./install.sh --taskwarrior   # Task management CLI
#   ./install.sh --butler        # ASUS Zenbook S 14 power/backlight daemon
#   ./install.sh --email         # Terminal email (aerc + notmuch + lieer for Gmail)
#   ./install.sh --upwork        # Upwork Wayland patch + screenshot bridge
#
# With no arguments, runs --all

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERR]${NC} $*"; }

backup_file() {
    local target="$1"
    if [[ -e "$target" ]]; then
        mkdir -p "$BACKUP_DIR"
        local rel="${target#$HOME/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        cp -a "$target" "$BACKUP_DIR/$rel"
        info "Backed up $target"
    fi
}

link_file() {
    local src="$1" dst="$2"
    backup_file "$dst"
    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
    ok "Linked $dst -> $src"
}

copy_file() {
    local src="$1" dst="$2"
    backup_file "$dst"
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
    ok "Copied $src -> $dst"
}

# ─────────────────────────────────────────────────────────────────────────────
# Packages
# ─────────────────────────────────────────────────────────────────────────────
install_packages() {
    info "Installing system packages..."

    if ! command -v dnf &>/dev/null; then
        err "dnf not found — this script targets Fedora"
        return 1
    fi

    # DNF performance tweaks
    if ! grep -q 'max_parallel_downloads' /etc/dnf/dnf.conf 2>/dev/null; then
        info "Optimizing DNF config..."
        sudo tee -a /etc/dnf/dnf.conf > /dev/null <<'DNFEOF'
max_parallel_downloads=10
fastestmirror=True
DNFEOF
    fi

    # System update first
    info "Running system update..."
    sudo dnf upgrade --refresh -y

    # RPM Fusion (needed for codecs)
    if ! dnf repolist | grep -q rpmfusion; then
        info "Enabling RPM Fusion..."
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    fi

    # Multimedia codecs
    info "Installing multimedia codecs..."
    sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y 2>/dev/null || true
    sudo dnf install -y gstreamer1-plugins-{bad-*,good-*,base} gstreamer1-plugin-openh264 gstreamer1-libav 2>/dev/null || true
    sudo dnf install -y lame* --exclude=lame-devel 2>/dev/null || true

    # Core tools
    sudo dnf install -y \
        zsh \
        kitty \
        git \
        gh \
        curl \
        wget \
        jq \
        ripgrep \
        fzf \
        tmux \
        htop \
        btop \
        fastfetch \
        tree \
        make \
        gcc \
        gcc-c++ \
        openssl-devel \
        unzip \
        p7zip \
        p7zip-plugins \
        kde-connect \
        firewall-config

    # Node.js 22
    if ! command -v node &>/dev/null; then
        sudo dnf install -y nodejs
        info "Node.js installed: $(node --version)"
    else
        info "Node.js already installed: $(node --version)"
    fi

    # Go
    if ! command -v go &>/dev/null; then
        sudo dnf install -y golang
        info "Go installed: $(go version)"
    else
        info "Go already installed: $(go version)"
    fi

    # Rust/Cargo
    if ! command -v cargo &>/dev/null; then
        info "Installing Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        info "Rust installed: $(rustc --version)"
    else
        info "Rust already installed: $(rustc --version)"
    fi

    # Bun
    if ! command -v bun &>/dev/null; then
        info "Installing Bun..."
        curl -fsSL https://bun.sh/install | bash
    else
        info "Bun already installed: $(bun --version)"
    fi

    # uv (Python)
    if ! command -v uv &>/dev/null; then
        info "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
    else
        info "uv already installed: $(uv --version)"
    fi

    # npm global directory (avoid sudo for global installs)
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global" 2>/dev/null || true

    # Python CLI tools via pipx/uv
    info "Installing Python CLI tools..."
    uv tool install poetry 2>/dev/null || true
    uv tool install pre-commit 2>/dev/null || true
    uv tool install ruff 2>/dev/null || true

    # Firmware updates
    info "Checking for firmware updates..."
    sudo fwupdmgr refresh --force 2>/dev/null || true
    sudo fwupdmgr get-updates 2>/dev/null || true
    sudo fwupdmgr update -y 2>/dev/null || true

    # Ensure SSD TRIM is enabled
    sudo systemctl enable --now fstrim.timer 2>/dev/null || true

    ok "System packages done"
}

# ─────────────────────────────────────────────────────────────────────────────
# KDE Theme (Catppuccin Mocha)
# ─────────────────────────────────────────────────────────────────────────────
install_kde_theme() {
    info "Installing KDE Catppuccin Mocha theme..."

    # Kvantum + Papirus icons
    sudo dnf install -y kvantum papirus-icon-theme

    # Catppuccin Kvantum theme
    local kvantum_dir="$HOME/.config/Kvantum"
    if [[ ! -d "$kvantum_dir/catppuccin-mocha-lavender" ]]; then
        info "Installing Catppuccin Kvantum theme..."
        local tmp=$(mktemp -d)
        git clone --depth 1 https://github.com/catppuccin/Kvantum.git "$tmp/kvantum-catppuccin"
        mkdir -p "$kvantum_dir"
        cp -r "$tmp/kvantum-catppuccin/themes/catppuccin-mocha-lavender" "$kvantum_dir/"
        rm -rf "$tmp"
    fi
    copy_file "$DOTFILES_DIR/kde/Kvantum/kvantum.kvconfig" "$kvantum_dir/kvantum.kvconfig"

    # Catppuccin cursors
    if [[ ! -d "$HOME/.local/share/icons/catppuccin-mocha-lavender-cursors" ]]; then
        info "Installing Catppuccin cursors..."
        local tmp=$(mktemp -d)
        local cursor_url="https://github.com/catppuccin/cursors/releases/latest/download/catppuccin-mocha-lavender-cursors.zip"
        curl -fsSL "$cursor_url" -o "$tmp/cursors.zip"
        mkdir -p "$HOME/.local/share/icons"
        unzip -q "$tmp/cursors.zip" -d "$HOME/.local/share/icons/"
        rm -rf "$tmp"
    fi

    # Catppuccin KWin window decoration (Aurorae)
    if [[ ! -d "$HOME/.local/share/aurorae/themes/CatppuccinMocha-Modern" ]]; then
        info "Installing Catppuccin KWin decoration..."
        local tmp=$(mktemp -d)
        git clone --depth 1 https://github.com/catppuccin/kde.git "$tmp/kde-catppuccin"
        mkdir -p "$HOME/.local/share/aurorae/themes"
        if [[ -d "$tmp/kde-catppuccin/Resources/Aurorae/CatppuccinMocha-Modern" ]]; then
            cp -r "$tmp/kde-catppuccin/Resources/Aurorae/CatppuccinMocha-Modern" "$HOME/.local/share/aurorae/themes/"
        fi
        # Also copy the global look-and-feel if available
        if [[ -d "$tmp/kde-catppuccin/Resources/LookAndFeel/Catppuccin-Mocha-Global" ]]; then
            mkdir -p "$HOME/.local/share/plasma/look-and-feel"
            cp -r "$tmp/kde-catppuccin/Resources/LookAndFeel/Catppuccin-Mocha-Global" "$HOME/.local/share/plasma/look-and-feel/"
        fi
        rm -rf "$tmp"
    fi

    # Apply KDE config files
    copy_file "$DOTFILES_DIR/kde/kdeglobals" "$HOME/.config/kdeglobals"
    copy_file "$DOTFILES_DIR/kde/kwinrc" "$HOME/.config/kwinrc"
    copy_file "$DOTFILES_DIR/kde/kcminputrc" "$HOME/.config/kcminputrc"
    copy_file "$DOTFILES_DIR/kde/dolphinrc" "$HOME/.config/dolphinrc"
    copy_file "$DOTFILES_DIR/kde/Trolltech.conf" "$HOME/.config/Trolltech.conf"
    copy_file "$DOTFILES_DIR/kde/gtkrc-2.0" "$HOME/.gtkrc-2.0"
    copy_file "$DOTFILES_DIR/kde/kded5rc" "$HOME/.config/kded5rc"
    copy_file "$DOTFILES_DIR/kde/mimeapps.list" "$HOME/.config/mimeapps.list"
    copy_file "$DOTFILES_DIR/kde/baloofilerc" "$HOME/.config/baloofilerc"

    # Shortcuts — copy but warn about machine-specific UUIDs
    warn "kglobalshortcutsrc copied — some activity UUIDs may need updating"
    copy_file "$DOTFILES_DIR/kde/kglobalshortcutsrc" "$HOME/.config/kglobalshortcutsrc"
    copy_file "$DOTFILES_DIR/kde/plasma-custom-shortcuts.khotkeys" "$HOME/.config/plasma-custom-shortcuts.khotkeys"

    # Plasma panel/widget layout
    warn "Panel layout copied — may need adjustment for different screen resolution"
    copy_file "$DOTFILES_DIR/kde/plasmashellrc" "$HOME/.config/plasmashellrc"
    copy_file "$DOTFILES_DIR/kde/plasma/plasma-org.kde.plasma.desktop-appletsrc" "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

    # Plasma widgets (installed from KDE Store)
    info "Install these plasma widgets manually from KDE Store (System Settings > Add New...):"
    echo "  - Panel Colorizer (luisbocanegra.panel.colorizer)"
    echo "  - Catwalk (org.kde.plasma.catwalk)"

    ok "KDE theme done — log out/in or run 'kquitapp6 plasmashell && kstart plasmashell' to apply"
}

# ─────────────────────────────────────────────────────────────────────────────
# Fonts
# ─────────────────────────────────────────────────────────────────────────────
install_fonts() {
    info "Installing fonts..."

    # Noto Sans (used by KDE/GTK theme configs)
    sudo dnf install -y google-noto-sans-fonts 2>/dev/null || true

    # JetBrains Mono (system package)
    sudo dnf install -y jetbrains-mono-fonts-all 2>/dev/null || {
        info "JetBrains Mono not in repos, installing manually..."
        local tmp=$(mktemp -d)
        curl -fsSL "https://github.com/JetBrains/JetBrainsMono/releases/latest/download/JetBrainsMono-2.304.zip" -o "$tmp/jbm.zip"
        mkdir -p "$HOME/.local/share/fonts"
        unzip -q "$tmp/jbm.zip" -d "$tmp/jbm"
        cp "$tmp/jbm/fonts/ttf/"*.ttf "$HOME/.local/share/fonts/"
        rm -rf "$tmp"
    }

    # MesloLGS NF (Powerlevel10k recommended font)
    mkdir -p "$HOME/.local/share/fonts"
    cp "$DOTFILES_DIR/fonts/"MesloLGS*.ttf "$HOME/.local/share/fonts/" 2>/dev/null || true

    # Fontconfig
    mkdir -p "$HOME/.config/fontconfig"
    copy_file "$DOTFILES_DIR/fonts/fonts.conf" "$HOME/.config/fontconfig/fonts.conf"

    # Rebuild font cache
    fc-cache -f
    ok "Fonts installed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Shell (zsh + oh-my-zsh + p10k + plugins)
# ─────────────────────────────────────────────────────────────────────────────
install_shell() {
    info "Setting up zsh..."

    # Set zsh as default shell
    if [[ "$SHELL" != */zsh ]]; then
        chsh -s "$(which zsh)"
        info "Default shell changed to zsh (takes effect on next login)"
    fi

    # Oh My Zsh
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        info "Installing Oh My Zsh..."
        RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        info "Oh My Zsh already installed"
    fi

    # Powerlevel10k
    local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [[ ! -d "$p10k_dir" ]]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
    fi

    # Custom plugins
    local plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"

    if [[ ! -d "$plugins_dir/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions"
    fi

    if [[ ! -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$plugins_dir/zsh-syntax-highlighting"
    fi

    if [[ ! -d "$plugins_dir/zsh-completions" ]]; then
        git clone https://github.com/zsh-users/zsh-completions "$plugins_dir/zsh-completions"
    fi

    # Link config files
    link_file "$DOTFILES_DIR/shell/zshrc" "$HOME/.zshrc"
    link_file "$DOTFILES_DIR/shell/zshenv" "$HOME/.zshenv"
    link_file "$DOTFILES_DIR/shell/p10k.zsh" "$HOME/.p10k.zsh"
    link_file "$DOTFILES_DIR/shell/npmrc" "$HOME/.npmrc"
    copy_file "$DOTFILES_DIR/shell/bashrc" "$HOME/.bashrc"
    copy_file "$DOTFILES_DIR/shell/bash_profile" "$HOME/.bash_profile"

    # npm global directory
    mkdir -p "$HOME/.npm-global"
    mkdir -p "$HOME/.local/bin"

    # Shortcuts cheatsheet
    link_file "$DOTFILES_DIR/scripts/cheatsheet/shortcuts" "$HOME/.local/bin/shortcuts"
    link_file "$DOTFILES_DIR/scripts/cheatsheet/show-shortcuts" "$HOME/.local/bin/show-shortcuts"
    copy_file "$DOTFILES_DIR/scripts/cheatsheet/show-shortcuts.desktop" "$HOME/.local/share/applications/show-shortcuts.desktop"
    update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true

    # KDE window rule for cheatsheet popup
    if [[ -f "$DOTFILES_DIR/kde/kwinrulesrc" ]]; then
        copy_file "$DOTFILES_DIR/kde/kwinrulesrc" "$HOME/.config/kwinrulesrc"
        dbus-send --type=signal --dest=org.kde.KWin /KWin org.kde.KWin.reloadConfig 2>/dev/null || true
    fi

    # Meta+/ shortcut for cheatsheet (via khotkeys — works after login)
    copy_file "$DOTFILES_DIR/kde/khotkeysrc" "$HOME/.config/khotkeysrc"

    ok "Shell setup done (Meta+/ opens shortcuts cheatsheet — needs login)"
}

# ─────────────────────────────────────────────────────────────────────────────
# Kitty
# ─────────────────────────────────────────────────────────────────────────────
install_kitty() {
    info "Setting up Kitty..."

    if ! command -v kitty &>/dev/null; then
        sudo dnf install -y kitty
    fi

    mkdir -p "$HOME/.config/kitty"
    link_file "$DOTFILES_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"

    ok "Kitty configured"
}

# ─────────────────────────────────────────────────────────────────────────────
# Git
# ─────────────────────────────────────────────────────────────────────────────
install_git() {
    info "Setting up Git..."

    # Copy gitconfig (contains credential helper setup for gh)
    copy_file "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"

    mkdir -p "$HOME/.config/git"
    copy_file "$DOTFILES_DIR/git/gitignore_global" "$HOME/.config/git/ignore"

    # GitHub CLI config
    mkdir -p "$HOME/.config/gh"
    copy_file "$DOTFILES_DIR/gh/config.yml" "$HOME/.config/gh/config.yml"
    copy_file "$DOTFILES_DIR/gh/hosts.yml" "$HOME/.config/gh/hosts.yml"

    # Authenticate gh if not already
    if command -v gh &>/dev/null; then
        if ! gh auth status &>/dev/null; then
            warn "GitHub CLI not authenticated — run 'gh auth login' after install"
        else
            ok "GitHub CLI already authenticated"
        fi
    fi

    ok "Git configured"
}

# ─────────────────────────────────────────────────────────────────────────────
# Claude Code
# ─────────────────────────────────────────────────────────────────────────────
install_claude() {
    info "Setting up Claude Code..."

    # Install Claude Code
    if ! command -v claude &>/dev/null; then
        info "Installing Claude Code..."
        npm install -g @anthropic-ai/claude-code@latest
    else
        info "Claude Code already installed: $(claude --version 2>/dev/null)"
    fi

    mkdir -p "$HOME/.claude"
    copy_file "$DOTFILES_DIR/claude-code/settings.json" "$HOME/.claude/settings.json"

    # Statusline script
    mkdir -p "$HOME/.local/bin"
    copy_file "$DOTFILES_DIR/claude-code/claude-statusline" "$HOME/.local/bin/claude-statusline"
    chmod +x "$HOME/.local/bin/claude-statusline"

    warn "Run 'claude' to complete authentication"
    ok "Claude Code configured"
}

# ═════════════════════════════════════════════════════════════════════════════
# Optional tools — NOT included in --all. Install individually or use --tools.
# ═════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# eza (modern ls replacement)
# ─────────────────────────────────────────────────────────────────────────────
install_eza() {
    info "Installing eza..."
    if command -v eza &>/dev/null; then
        ok "eza already installed"
        return
    fi
    # Try dnf first (available Fedora 41+), fall back to cargo
    if sudo dnf install -y eza 2>/dev/null; then
        ok "eza installed via dnf"
    elif command -v cargo &>/dev/null; then
        info "dnf failed, installing via cargo..."
        cargo install eza
        ok "eza installed via cargo"
    else
        err "Install Rust first (--packages), then retry --eza"
        return 1
    fi
    ok "Aliases (ls, ll, la, lt) activate automatically in zshrc"
}

# ─────────────────────────────────────────────────────────────────────────────
# bat (modern cat replacement)
# ─────────────────────────────────────────────────────────────────────────────
install_bat() {
    info "Installing bat..."
    if command -v bat &>/dev/null; then
        ok "bat already installed"
        return
    fi
    sudo dnf install -y bat
    ok "Aliases (cat, catp) activate automatically in zshrc"
}

# ─────────────────────────────────────────────────────────────────────────────
# zoxide (smarter cd)
# ─────────────────────────────────────────────────────────────────────────────
install_zoxide() {
    info "Installing zoxide..."
    if command -v zoxide &>/dev/null; then
        ok "zoxide already installed"
        return
    fi
    sudo dnf install -y zoxide
    ok "Shell hook (z, zi) activates automatically in zshrc"
}

# ─────────────────────────────────────────────────────────────────────────────
# lazygit (terminal git UI)
# ─────────────────────────────────────────────────────────────────────────────
install_lazygit() {
    info "Installing lazygit..."
    if ! command -v lazygit &>/dev/null; then
        sudo dnf copr enable -y atim/lazygit 2>/dev/null || true
        sudo dnf install -y lazygit
    else
        ok "lazygit already installed"
    fi

    # delta — better git diffs (used by lazygit pager)
    if ! command -v delta &>/dev/null; then
        sudo dnf install -y git-delta 2>/dev/null || true
    fi

    mkdir -p "$HOME/.config/lazygit"
    link_file "$DOTFILES_DIR/tools/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
    ok "lazygit configured — Catppuccin colors, delta pager"
}

# ─────────────────────────────────────────────────────────────────────────────
# direnv (per-directory environment variables)
# ─────────────────────────────────────────────────────────────────────────────
install_direnv() {
    info "Installing direnv..."
    if command -v direnv &>/dev/null; then
        ok "direnv already installed"
        return
    fi
    sudo dnf install -y direnv
    ok "Shell hook activates automatically in zshrc"
}

# ─────────────────────────────────────────────────────────────────────────────
# superfile (terminal file manager)
# ─────────────────────────────────────────────────────────────────────────────
install_superfile() {
    info "Installing superfile..."
    if command -v spf &>/dev/null; then
        ok "superfile already installed"
    else
        if command -v go &>/dev/null; then
            go install github.com/yorukot/superfile@latest
        else
            warn "Go not found — install superfile manually: go install github.com/yorukot/superfile@latest"
            return 1
        fi
    fi
    mkdir -p "$HOME/.config/superfile"
    link_file "$DOTFILES_DIR/tools/superfile/config.toml" "$HOME/.config/superfile/config.toml"
    ok "superfile configured — Catppuccin theme, zoxide integration"
}

# ─────────────────────────────────────────────────────────────────────────────
# tmux config
# ─────────────────────────────────────────────────────────────────────────────
install_tmux_config() {
    info "Setting up tmux config..."
    if ! command -v tmux &>/dev/null; then
        sudo dnf install -y tmux
    fi
    mkdir -p "$HOME/.config/tmux"
    link_file "$DOTFILES_DIR/tools/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"

    # sesh — tmux session manager
    if ! command -v sesh &>/dev/null; then
        if command -v go &>/dev/null; then
            info "Installing sesh via go install..."
            go install github.com/joshmedeski/sesh@latest
        else
            warn "Go not found — install sesh manually: go install github.com/joshmedeski/sesh@latest"
        fi
    else
        ok "sesh already installed"
    fi

    # sesh config
    mkdir -p "$HOME/.config/sesh"
    link_file "$DOTFILES_DIR/tools/sesh/sesh.toml" "$HOME/.config/sesh/sesh.toml"

    ok "tmux configured — prefix: Ctrl+a, splits: | and -, vi keys, sesh: C-a C-s"
}

# ─────────────────────────────────────────────────────────────────────────────
# Taskwarrior (task management)
# ─────────────────────────────────────────────────────────────────────────────
install_taskwarrior() {
    info "Installing Taskwarrior..."
    if ! command -v task &>/dev/null; then
        sudo dnf install -y task
    fi
    mkdir -p "$HOME/.local/share/task"
    link_file "$DOTFILES_DIR/tools/taskwarrior/taskrc" "$HOME/.taskrc"
    ok "Taskwarrior installed — run 'task add <description>' to start"
}

# ─────────────────────────────────────────────────────────────────────────────
# Butler daemon (ASUS Zenbook S 14 power/backlight management)
# ─────────────────────────────────────────────────────────────────────────────
install_butler() {
    info "Installing Butler daemon..."
    sudo dnf install -y brightnessctl power-profiles-daemon 2>/dev/null || true
    mkdir -p "$HOME/.local/bin"
    copy_file "$DOTFILES_DIR/tools/butler/butler-daemon" "$HOME/.local/bin/butler-daemon"
    chmod +x "$HOME/.local/bin/butler-daemon"
    mkdir -p "$HOME/.config/systemd/user"
    copy_file "$DOTFILES_DIR/tools/butler/butler-daemon.service" \
        "$HOME/.config/systemd/user/butler-daemon.service"
    systemctl --user daemon-reload
    systemctl --user enable --now butler-daemon.service 2>/dev/null || true
    ok "Butler daemon installed — manages power profile + kbd backlight"
}

# ─────────────────────────────────────────────────────────────────────────────
# All optional tools at once
# ─────────────────────────────────────────────────────────────────────────────
install_tools() {
    install_eza
    install_bat
    install_zoxide
    install_lazygit
    install_direnv
    install_tmux_config
    install_superfile
    install_taskwarrior
    install_butler
    install_email
    echo ""
    ok "All optional tools installed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Terminal email (aerc + notmuch + lieer for Gmail)
# ─────────────────────────────────────────────────────────────────────────────
install_email() {
    info "Installing terminal email (aerc + notmuch + lieer)..."

    # Packages
    sudo dnf install -y aerc notmuch w3m

    # lieer (Gmail API sync)
    if ! command -v gmi &>/dev/null; then
        info "Installing lieer..."
        uv tool install lieer 2>/dev/null || pip install --user lieer
    else
        ok "lieer already installed"
    fi

    # aerc config
    mkdir -p "$HOME/.config/aerc/stylesets"
    copy_file "$DOTFILES_DIR/tools/email/aerc/aerc.conf" "$HOME/.config/aerc/aerc.conf"
    copy_file "$DOTFILES_DIR/tools/email/aerc/binds.conf" "$HOME/.config/aerc/binds.conf"
    copy_file "$DOTFILES_DIR/tools/email/aerc/query-map" "$HOME/.config/aerc/query-map"
    copy_file "$DOTFILES_DIR/tools/email/aerc/stylesets/catppuccin-mocha" \
        "$HOME/.config/aerc/stylesets/catppuccin-mocha"

    # accounts.conf — only copy template if no existing config
    if [[ ! -f "$HOME/.config/aerc/accounts.conf" ]]; then
        copy_file "$DOTFILES_DIR/tools/email/aerc/accounts.conf.template" \
            "$HOME/.config/aerc/accounts.conf"
        chmod 600 "$HOME/.config/aerc/accounts.conf"
    else
        info "accounts.conf already exists, not overwriting"
    fi

    # notmuch config (XDG location)
    local notmuch_dir="$HOME/.config/notmuch/default"
    if [[ ! -f "$notmuch_dir/config" ]]; then
        mkdir -p "$notmuch_dir"
        copy_file "$DOTFILES_DIR/tools/email/notmuch-config" "$notmuch_dir/config"
    else
        info "notmuch config already exists, not overwriting"
    fi

    # Mail directory
    mkdir -p "$HOME/.mail/gmail"

    # Pull timer (new mail every 5 min) + push timer (tag changes every 2 hours)
    mkdir -p "$HOME/.config/systemd/user"
    copy_file "$DOTFILES_DIR/tools/email/mail-sync.service" "$HOME/.config/systemd/user/mail-sync.service"
    copy_file "$DOTFILES_DIR/tools/email/mail-sync.timer" "$HOME/.config/systemd/user/mail-sync.timer"
    copy_file "$DOTFILES_DIR/tools/email/mail-push.service" "$HOME/.config/systemd/user/mail-push.service"
    copy_file "$DOTFILES_DIR/tools/email/mail-push.timer" "$HOME/.config/systemd/user/mail-push.timer"
    systemctl --user daemon-reload

    echo ""
    ok "Terminal email installed (aerc + notmuch + lieer)"
    echo ""
    info "Setup steps:"
    echo "  1. Go to https://console.cloud.google.com/"
    echo "  2. Create a project → enable Gmail API"
    echo "  3. Create OAuth 2.0 credentials (Desktop app)"
    echo "  4. Download client_secret.json to ~/.mail/gmail/"
    echo "  5. cd ~/.mail/gmail && gmi init YOUR_EMAIL@gmail.com"
    echo "  6. gmi pull                    (first sync — may take hours)"
    echo "  7. notmuch new"
    echo "  8. Edit ~/.config/aerc/accounts.conf (replace YOUR_NAME/YOUR_EMAIL)"
    echo "  9. Edit ~/.config/notmuch/default/config (replace YOUR_NAME/YOUR_EMAIL)"
    echo " 10. systemctl --user enable --now mail-sync.timer mail-push.timer"
    echo " 11. Run 'aerc'"
    echo ""
    echo "  Timers:  mail-sync (pull every 5 min) + mail-push (push every 2 hours)"
    echo "  Manual:  cd ~/.mail/gmail && gmi pull && notmuch new   (fetch)"
    echo "           cd ~/.mail/gmail && gmi push                  (push now)"
    echo "  Status:  systemctl --user list-timers 'mail-*'"
}

# ─────────────────────────────────────────────────────────────────────────────
# Upwork Wayland + Screenshot Bridge (requires --upwork flag)
# ─────────────────────────────────────────────────────────────────────────────
install_scripts() {
    info "Installing Upwork Wayland support + screenshot bridge..."

    mkdir -p "$HOME/.local/bin"

    # Dependencies
    sudo dnf install -y ImageMagick 2>/dev/null || true

    # Upwork Wayland scripts
    copy_file "$DOTFILES_DIR/scripts/upwork/patch-upwork" "$HOME/.local/bin/patch-upwork"
    chmod +x "$HOME/.local/bin/patch-upwork"
    copy_file "$DOTFILES_DIR/scripts/upwork/upwork-wayland" "$HOME/.local/bin/upwork-wayland"
    chmod +x "$HOME/.local/bin/upwork-wayland"

    # Upwork desktop entry (routes through wayland wrapper)
    mkdir -p "$HOME/.local/share/applications"
    copy_file "$DOTFILES_DIR/scripts/upwork/upwork.desktop" "$HOME/.local/share/applications/upwork.desktop"
    update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true

    # Screenshot bridge — clone and install from its own repo
    if ! command -v plasma-gnome-screenshot-bridge &>/dev/null; then
        if [[ ! -d "$HOME/Projects/plasma-gnome-screenshot-bridge" ]]; then
            info "Cloning plasma-gnome-screenshot-bridge..."
            git clone https://github.com/NikhilBery/plasma-gnome-screenshot-bridge.git \
                "$HOME/Projects/plasma-gnome-screenshot-bridge"
        fi
        info "Installing plasma-gnome-screenshot-bridge..."
        (cd "$HOME/Projects/plasma-gnome-screenshot-bridge" && uv pip install . 2>/dev/null || pip install --user .)
    fi

    # Systemd service
    mkdir -p "$HOME/.config/systemd/user"
    copy_file "$DOTFILES_DIR/systemd/plasma-gnome-screenshot-bridge.service" "$HOME/.config/systemd/user/plasma-gnome-screenshot-bridge.service"
    systemctl --user daemon-reload
    systemctl --user enable plasma-gnome-screenshot-bridge.service 2>/dev/null || true

    if [[ -f /opt/Upwork/upwork ]]; then
        warn "Run 'patch-upwork install' to patch Upwork for Wayland screenshots"
    else
        info "Upwork not installed — scripts are ready for when you install it"
    fi

    ok "Upwork Wayland + screenshot bridge installed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
run_all() {
    install_packages
    install_fonts
    install_kde_theme
    install_shell
    install_kitty
    install_git
    install_claude

    echo ""
    ok "All done! Next steps:"
    echo "  1. Log out and back in (for zsh + KDE theme changes)"
    echo "  2. Run 'gh auth login' to authenticate GitHub"
    echo "  3. Run 'claude' to authenticate Claude Code"
    echo "  4. Run 'p10k configure' if the prompt looks wrong"
    echo ""
    echo "  Optional tools (not installed by default):"
    echo "    ./install.sh --tools        # All optional tools at once"
    echo "    ./install.sh --eza          # Modern ls (aliases: ls, ll, la, lt)"
    echo "    ./install.sh --bat          # Modern cat (aliases: cat, catp)"
    echo "    ./install.sh --zoxide       # Smarter cd (commands: z, zi)"
    echo "    ./install.sh --lazygit      # Terminal git UI + Catppuccin config"
    echo "    ./install.sh --direnv       # Per-directory env vars"
    echo "    ./install.sh --tmux         # tmux config (sesh sessions, lazygit popup)"
    echo "    ./install.sh --superfile    # Terminal file manager"
    echo "    ./install.sh --taskwarrior  # Task management CLI"
    echo "    ./install.sh --butler       # ASUS power/backlight daemon"
    echo "    ./install.sh --email        # Terminal email (aerc + notmuch + lieer)"
    echo "    ./install.sh --upwork       # Upwork Wayland patch + screenshot bridge"
    echo ""
    echo "  Apps to install manually (not in Fedora repos):"
    echo "    - Brave Browser: https://brave.com/linux/"
    echo "    - Zed Editor: https://zed.dev/download"
    echo "  GPU drivers (check 'lspci | grep VGA'):"
    echo "    - NVIDIA: sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda"
    echo "    - Intel: sudo dnf install intel-media-driver"
    echo "    - AMD: sudo dnf install mesa-va-drivers"
    echo ""
    if [[ -d "$BACKUP_DIR" ]]; then
        info "Backups saved to: $BACKUP_DIR"
    fi
}

# Parse arguments
if [[ $# -eq 0 ]]; then
    run_all
    exit 0
fi

for arg in "$@"; do
    case "$arg" in
        --all)       run_all ;;
        --packages)  install_packages ;;
        --shell)     install_shell ;;
        --kitty)     install_kitty ;;
        --kde)       install_kde_theme ;;
        --claude)    install_claude ;;
        --git)       install_git ;;
        --fonts)     install_fonts ;;
        --eza)         install_eza ;;
        --bat)         install_bat ;;
        --zoxide)      install_zoxide ;;
        --lazygit)     install_lazygit ;;
        --direnv)      install_direnv ;;
        --tmux)        install_tmux_config ;;
        --taskwarrior) install_taskwarrior ;;
        --superfile)   install_superfile ;;
        --butler)      install_butler ;;
        --email)       install_email ;;
        --tools)       install_tools ;;
        --upwork)      install_scripts ;;
        --help|-h)
            echo "Usage: $0 [--all | --packages | --shell | --kitty | --kde | --claude | --git | --fonts]"
            echo "  No arguments = --all"
            echo ""
            echo "Optional tools (not in --all):"
            echo "  --tools --eza --bat --zoxide --lazygit --direnv --tmux --superfile --taskwarrior --butler --email --upwork"
            ;;
        *)
            err "Unknown option: $arg"
            exit 1
            ;;
    esac
done
