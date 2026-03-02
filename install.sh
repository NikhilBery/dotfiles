#!/usr/bin/env bash
# Dotfiles installer for Fedora KDE
# Replicates numbery's system setup on a fresh Fedora KDE install
#
# Usage:
#   git clone <this-repo> ~/Projects/dotfiles
#   cd ~/Projects/dotfiles
#   ./install.sh [--all | --packages | --shell | --kitty | --kde | --claude | --git | --fonts | --scripts]
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

    ok "Shell setup done"
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

# ─────────────────────────────────────────────────────────────────────────────
# Custom Scripts (Upwork Wayland, screenshot bridge)
# ─────────────────────────────────────────────────────────────────────────────
install_scripts() {
    info "Installing custom scripts..."

    mkdir -p "$HOME/.local/bin"

    # ImageMagick (needed by Upwork patch for screenshot compression)
    sudo dnf install -y ImageMagick 2>/dev/null || true

    # Upwork Wayland support
    copy_file "$DOTFILES_DIR/scripts/upwork/patch-upwork" "$HOME/.local/bin/patch-upwork"
    chmod +x "$HOME/.local/bin/patch-upwork"
    copy_file "$DOTFILES_DIR/scripts/upwork/upwork-wayland" "$HOME/.local/bin/upwork-wayland"
    chmod +x "$HOME/.local/bin/upwork-wayland"

    # Screenshot bridge systemd service
    mkdir -p "$HOME/.config/systemd/user"
    copy_file "$DOTFILES_DIR/systemd/plasma-gnome-screenshot-bridge.service" "$HOME/.config/systemd/user/plasma-gnome-screenshot-bridge.service"

    # Install the bridge binary if the project is available
    if [[ -d "$HOME/Projects/plasma-gnome-screenshot-bridge" ]]; then
        info "Building plasma-gnome-screenshot-bridge from source..."
        (cd "$HOME/Projects/plasma-gnome-screenshot-bridge" && go build -o "$HOME/.local/bin/plasma-gnome-screenshot-bridge" .)
        systemctl --user daemon-reload
        systemctl --user enable plasma-gnome-screenshot-bridge.service
        ok "Screenshot bridge service enabled"
    else
        warn "plasma-gnome-screenshot-bridge project not found — clone it to ~/Projects/ and build manually"
    fi

    ok "Custom scripts installed"
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
    install_scripts

    echo ""
    ok "All done! Next steps:"
    echo "  1. Log out and back in (for zsh + KDE theme changes)"
    echo "  2. Run 'gh auth login' to authenticate GitHub"
    echo "  3. Run 'claude' to authenticate Claude Code"
    echo "  4. Run 'p10k configure' if the prompt looks wrong"
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
        --scripts)   install_scripts ;;
        --help|-h)
            echo "Usage: $0 [--all | --packages | --shell | --kitty | --kde | --claude | --git | --fonts | --scripts]"
            echo "  No arguments = --all"
            ;;
        *)
            err "Unknown option: $arg"
            exit 1
            ;;
    esac
done
