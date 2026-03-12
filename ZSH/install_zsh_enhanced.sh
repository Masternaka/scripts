#!/bin/bash
# =============================================================================
#  Enhanced ZSH Setup — Cross-platform Installer
#  Supports: Linux (Ubuntu/Debian/Fedora/Arch), macOS (Intel/ARM)
#  Features: Modular installation, error handling, customization options
#  Plugins : zinit + zsh-autosuggestions, zsh-syntax-highlighting,
#            zsh-completions, zsh-bat, fzf-zsh-plugin, zsh-zoxide
#  Tools   : bat, fzf, zoxide, fd, eza, ripgrep
#  Font    : JetBrainsMono Nerd Font (GitHub Nerd Fonts)
# =============================================================================

set -euo pipefail

# ── Configuration globale ─────────────────────────────────────────────────────
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="2.0.0"
readonly CONFIG_FILE="${HOME}/.zsh_installer_config"
readonly LOG_FILE="${HOME}/.zsh_installer.log"
readonly BACKUP_DIR="${HOME}/.zsh_backup_$(date +%Y%m%d_%H%M%S)"

# Options par défaut
DRY_RUN=false
VERBOSE=false
SKIP_FONT=false
SKIP_BREW=false
THEME="dracula"
INSTALL_PLUGINS=true
UNINSTALL_MODE=false
PROMPT_STYLE="enhanced"

# Options de configuration des outils
FZF_HEIGHT="50%"
FZF_LAYOUT="reverse"
FZF_BORDER="rounded"
FZF_PREVIEW_WINDOW="right:60%:wrap"
BAT_THEME="dracula"
BAT_STYLE="numbers,changes,header"
BAT_PAGER="true"
ZOXIDE_CMD="z"
EZA_ICONS="true"
EZA_GIT="true"
EZA_TREE="auto"
RIPGREP_TYPE="file"
RIPGREP_FOLLOW="true"
RIPGREP_HIDDEN="false"
RIPGREP_IGNORE="true"

# ── Couleurs ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ── Fonctions utilitaires ─────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

info() { 
    echo -e "${BLUE}[INFO]${NC}  $*"
    log "INFO: $*"
}

success() { 
    echo -e "${GREEN}[OK]${NC}    $*"
    log "SUCCESS: $*"
}

warn() { 
    echo -e "${YELLOW}[WARN]${NC}  $*"
    log "WARN: $*"
}

error() { 
    echo -e "${RED}[ERROR]${NC} $*" 
    log "ERROR: $*"
    exit 1
}

debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${MAGENTA}[DEBUG]${NC} $*"
        log "DEBUG: $*"
    fi
}

section() { 
    echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $*${NC}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}\n"
}

progress() {
    local current=$1
    local total=$2
    local desc=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}[PROGRESS]${NC} %3d%% [" "$percent"
    printf "%*s" "$filled" | tr ' ' '█'
    printf "%*s" "$empty" | tr ' ' '░'
    printf "] %s" "$desc"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# ── Gestion de la configuration ─────────────────────────────────────────────
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        debug "Configuration chargée depuis $CONFIG_FILE"
    fi
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
# Configuration ZSH Installer - Généré le $(date)
DRY_RUN=$DRY_RUN
VERBOSE=$VERBOSE
SKIP_FONT=$SKIP_FONT
SKIP_BREW=$SKIP_BREW
THEME="$THEME"
INSTALL_PLUGINS=$INSTALL_PLUGINS
PROMPT_STYLE="$PROMPT_STYLE"
EOF
    debug "Configuration sauvegardée dans $CONFIG_FILE"
}

# ── Validation et sécurité ───────────────────────────────────────────────────
check_internet() {
    section "Vérification de la connexion internet"
    if ! ping -c 1 8.8.8.8 &>/dev/null && ! ping -c 1 1.1.1.1 &>/dev/null; then
        error "Pas de connexion internet. Veuillez vérifier votre connexion."
    fi
    success "Connexion internet vérifiée"
}

check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        error "Ne pas exécuter ce script en root. Utilisez votre utilisateur normal."
    fi
    
    # Vérifier les permissions d'écriture dans le home
    if [[ ! -w "$HOME" ]]; then
        error "Pas de permissions d'écriture dans le répertoire home"
    fi
}

validate_url() {
    local url=$1
    if curl --output /dev/null --silent --head --fail "$url"; then
        return 0
    else
        return 1
    fi
}

download_with_checksum() {
    local url=$1
    local output=$2
    local expected_checksum=${3:-}
    
    info "Téléchargement: $(basename "$url")"
    
    if ! validate_url "$url"; then
        error "URL invalide ou inaccessible: $url"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Téléchargement simulé: $url"
        return 0
    fi
    
    curl -fsSL "$url" -o "$output" || error "Échec du téléchargement de $url"
    
    if [[ -n "$expected_checksum" ]]; then
        local actual_checksum=$(sha256sum "$output" | cut -d' ' -f1)
        if [[ "$actual_checksum" != "$expected_checksum" ]]; then
            error "Checksum invalide pour $(basename "$url")"
        fi
        debug "Checksum vérifié pour $(basename "$url")"
    fi
}

# ── Détection du système ─────────────────────────────────────────────────────
detect_system() {
    section "Détection du système"
    
    # Détection de l'OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [[ -f /etc/os-release ]]; then
            source /etc/os-release
            DISTRO="$ID"
            DISTRO_NAME="$PRETTY_NAME"
        else
            error "Impossible de détecter la distribution Linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
        DISTRO_NAME="macOS $(sw_vers -productVersion)"
        
        # Détection Intel vs ARM
        if [[ $(uname -m) == "arm64" ]]; then
            ARCH="arm"
        else
            ARCH="intel"
        fi
    else
        error "Système d'exploitation non supporté: $OSTYPE"
    fi
    
    success "Système détecté: $DISTRO_NAME"
    debug "OS: $OS, Distribution: $DISTRO, Architecture: ${ARCH:-unknown}"
}

# ── Gestionnaire de paquets ─────────────────────────────────────────────────
install_package_manager_deps() {
    section "Installation des dépendances du gestionnaire de paquets"
    
    case "$DISTRO" in
        ubuntu|debian|linuxmint)
            if [[ "$DRY_RUN" == false ]]; then
                sudo apt update -y
                sudo apt install -y curl wget git build-essential procps file fontconfig unzip
            fi
            ;;
        fedora)
            if [[ "$DRY_RUN" == false ]]; then
                sudo dnf update -y
                sudo dnf install -y curl wget git gcc gcc-c++ make procps-ng file fontconfig unzip
            fi
            ;;
        arch|manjaro)
            if [[ "$DRY_RUN" == false ]]; then
                sudo pacman -Syu --noconfirm
                sudo pacman -S --noconfirm curl wget git base-devel procps-ng file fontconfig unzip
            fi
            ;;
        macos)
            # Xcode Command Line Tools
            if ! xcode-select -p &>/dev/null; then
                if [[ "$DRY_RUN" == false ]]; then
                    xcode-select --install
                fi
            fi
            ;;
        *)
            error "Distribution non supportée: $DISTRO"
            ;;
    esac
    
    success "Dépendances du gestionnaire de paquets installées"
}

# ── Installation Homebrew ─────────────────────────────────────────────────────
install_homebrew() {
    if [[ "$SKIP_BREW" == true ]]; then
        warn "Installation de Homebrew ignorée (--skip-brew)"
        return
    fi
    
    section "Installation de Homebrew"
    
    if command -v brew &>/dev/null; then
        success "Homebrew déjà installé: $(brew --version | head -1)"
        eval "$(brew shellenv)"
        return
    fi
    
    info "Installation de Homebrew..."
    
    local brew_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Installation Homebrew simulée"
        return
    fi
    
    # Installation non-interactive
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$brew_url")"
    
    # Configuration du PATH
    if [[ "$OS" == "linux" ]]; then
        if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        elif [[ -d "$HOME/.linuxbrew" ]]; then
            eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
        fi
    elif [[ "$OS" == "macos" ]]; then
        if [[ "$ARCH" == "arm" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
    
    success "Homebrew installé"
}

# ── Installation des paquets Homebrew ─────────────────────────────────────────
install_brew_packages() {
    if [[ "$SKIP_BREW" == true ]]; then
        warn "Installation des paquets Homebrew ignorée"
        return
    fi
    
    section "Installation des paquets via Homebrew"
    
    local packages=("bat" "fzf" "zoxide" "fd" "eza" "ripgrep")
    
    # Ajouter la police via Homebrew sur macOS
    if [[ "$OS" == "macos" && "$SKIP_FONT" == false ]]; then
        packages+=("font-jetbrains-mono-nerd-font")
    fi
    
    local total=${#packages[@]}
    local current=0
    
    for package in "${packages[@]}"; do
        current=$((current + 1))
        progress $current $total "Installation de $package"
        
        # Gestion spéciale pour les casks sur macOS
        if [[ "$OS" == "macos" && "$package" == font-* ]]; then
            if brew list --cask "$package" &>/dev/null; then
                debug "$package déjà installé (cask)"
                continue
            fi
            if [[ "$DRY_RUN" == false ]]; then
                brew install --cask "$package" || warn "Échec de l'installation de $package (cask)"
            fi
        else
            if brew list "$package" &>/dev/null; then
                debug "$package déjà installé"
                continue
            fi
            if [[ "$DRY_RUN" == false ]]; then
                brew install "$package" || warn "Échec de l'installation de $package"
            fi
        fi
    done
    
    # Configuration fzf
    if command -v fzf &>/dev/null && [[ "$DRY_RUN" == false ]]; then
        $(brew --prefix)/opt/fzf/install --all --no-bash --no-fish
    fi
    
    success "Paquets Homebrew installés"
}

# ── Installation de la police ─────────────────────────────────────────────────
install_jetbrains_font() {
    if [[ "$SKIP_FONT" == true ]]; then
        warn "Installation de la police ignorée (--skip-font)"
        return
    fi
    
    section "Installation de JetBrainsMono Nerd Font"
    
    # Sur macOS, la police est installée via Homebrew cask
    if [[ "$OS" == "macos" ]]; then
        if brew list --cask font-jetbrains-mono-nerd-font &>/dev/null; then
            success "JetBrainsMono Nerd Font déjà installée via Homebrew cask"
        else
            info "La police sera installée via Homebrew cask avec les autres paquets"
        fi
        return
    fi
    
    # Installation manuelle pour Linux
    local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    mkdir -p "$font_dir"
    
    # Vérifier si déjà installée
    if fc-list | grep -qi "JetBrainsMono Nerd"; then
        success "JetBrainsMono Nerd Font déjà installée"
        return
    fi
    
    local font_version="3.3.0"
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${font_version}/JetBrainsMono.zip"
    local tmp_dir=$(mktemp -d)
    
    info "Téléchargement de JetBrainsMono Nerd Font v${font_version}..."
    
    download_with_checksum "$font_url" "$tmp_dir/JetBrainsMono.zip"
    
    if [[ "$DRY_RUN" == false ]]; then
        unzip -q "$tmp_dir/JetBrainsMono.zip" -d "$tmp_dir/fonts"
        find "$tmp_dir/fonts" -name "*.ttf" -exec cp {} "$font_dir/" \;
        fc-cache -fv "$font_dir" &>/dev/null
        rm -rf "$tmp_dir"
    fi
    
    success "JetBrainsMono Nerd Font installée"
}

# ── Installation de ZSH et Zinit ─────────────────────────────────────────────
install_zsh() {
    section "Vérification de ZSH"
    
    if command -v zsh &>/dev/null; then
        success "ZSH déjà installé: $(zsh --version)"
        return
    fi
    
    case "$DISTRO" in
        ubuntu|debian|linuxmint)
            if [[ "$DRY_RUN" == false ]]; then
                sudo apt install -y zsh
            fi
            ;;
        fedora)
            if [[ "$DRY_RUN" == false ]]; then
                sudo dnf install -y zsh
            fi
            ;;
        arch|manjaro)
            if [[ "$DRY_RUN" == false ]]; then
                sudo pacman -S --noconfirm zsh
            fi
            ;;
        macos)
            # ZSH est préinstallé sur macOS, ne rien faire
            info "ZSH est préinstallé sur macOS"
            ;;
    esac
    
    success "ZSH disponible"
}

install_zinit() {
    if [[ "$INSTALL_PLUGINS" == false ]]; then
        warn "Installation des plugins ignorée (--no-plugins)"
        return
    fi
    
    section "Installation de Zinit"
    
    local zinit_home="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
    
    if [[ -d "$zinit_home/.git" ]]; then
        success "Zinit déjà installé"
        return
    fi
    
    info "Installation de Zinit..."
    
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$(dirname "$zinit_home")"
        git clone https://github.com/zdharma-continuum/zinit.git "$zinit_home"
    fi
    
    success "Zinit installé dans $zinit_home"
}

# ── Génération de la configuration ZSH ────────────────────────────────────────
get_brew_prefix() {
    if [[ "$OS" == "linux" ]]; then
        if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
            echo "/home/linuxbrew/.linuxbrew"
        elif [[ -d "$HOME/.linuxbrew" ]]; then
            echo "$HOME/.linuxbrew"
        fi
    elif [[ "$OS" == "macos" ]]; then
        if [[ "$ARCH" == "arm" ]]; then
            echo "/opt/homebrew"
        else
            echo "/usr/local"
        fi
    fi
}

generate_prompt() {
    case "$PROMPT_STYLE" in
        "simple")
            echo 'PROMPT="%F{green}%n%f%F{blue}@%f%F{cyan}%m%f %F{yellow}%~%f %F{red}❯%f "'
            ;;
        "enhanced")
            cat << 'EOF'
autoload -Uz vcs_info
precmd() { vcs_info }
setopt PROMPT_SUBST

zstyle ':vcs_info:git:*' formats ' %F{#bd93f9}(%b)%f'
zstyle ':vcs_info:*' enable git

PROMPT='%F{#50fa7b}%n%f%F{#6272a4}@%f%F{#8be9fd}%m%f %F{#f1fa8c}%~%f${vcs_info_msg_0_} %F{#ff79c6}❯%f '
RPROMPT='%F{#6272a4}%*%f'
EOF
            ;;
        "powerline")
            cat << 'EOF'
autoload -Uz vcs_info
precmd() { vcs_info }
setopt PROMPT_SUBST

zstyle ':vcs_info:git:*' formats ' %F{#bd93f9}(%b)%f'
zstyle ':vcs_info:*' enable git

PROMPT='%F{#8be9fd}┌──%f%F{#50fa7b}%n%f%F{#6272a4}@%f%F{#8be9fd}%m%f%F{#8be9fd}──%f%F{#f1fa8c}%~%f${vcs_info_msg_0_}
%F{#8be9fd}└──%f%F{#ff79c6}❯%f '
EOF
            ;;
    esac
}

generate_zshrc() {
    section "Génération du fichier ~/.zshrc"
    
    # Sauvegarde de l'ancien .zshrc
    if [[ -f "$HOME/.zshrc" ]]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        warn "Ancien .zshrc sauvegardé"
    fi
    
    local brew_prefix=$(get_brew_prefix)
    local prompt_config=$(generate_prompt)
    
    cat > "$HOME/.zshrc" << ZSHRC_EOF
# =============================================================================
#  ~/.zshrc — Enhanced ZSH Configuration
#  Generated by Enhanced ZSH Installer v$SCRIPT_VERSION
#  Date: $(date)
# =============================================================================

# ── Homebrew ──────────────────────────────────────────────────────────────────
if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
    eval "\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -d "\$HOME/.linuxbrew" ]]; then
    eval "\$($HOME/.linuxbrew/bin/brew shellenv)"
elif [[ -d "/opt/homebrew" ]]; then
    eval "\$(/opt/homebrew/bin/brew shellenv)"
elif [[ -d "/usr/local" ]]; then
    eval "\$(/usr/local/bin/brew shellenv)"
fi

# ── PATH supplémentaires ─────────────────────────────────────────────────────
export PATH="\$HOME/.local/bin:\$HOME/bin:\$PATH"

# ── Options ZSH ──────────────────────────────────────────────────────────────
setopt AUTO_CD              # Taper un dossier = y aller
setopt AUTO_PUSHD           # cd pousse le répertoire dans la pile
setopt PUSHD_IGNORE_DUPS    # Pas de doublons dans la pile de répertoires
setopt PUSHD_SILENT         # Pas d'affichage de la pile
setopt CORRECT              # Correction automatique des commandes
setopt CDABLE_VARS          # Permet cd vers des variables
setopt EXTENDED_GLOB        # Glob étendu
setopt NO_CASE_GLOB         # Glob insensible à la casse
setopt NUMERIC_GLOB_SORT    # Tri numérique des fichiers
setopt INTERACTIVE_COMMENTS # Commentaires en mode interactif

# ── Historique ────────────────────────────────────────────────────────────────
HISTFILE="\$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE      # Ne pas sauvegarder les cmds avec espace devant
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY          # Partage de l'historique entre sessions
setopt APPEND_HISTORY

# ── Zinit ─────────────────────────────────────────────────────────────────────
ZINIT_HOME="\${XDG_DATA_HOME:-\${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d \$ZINIT_HOME ]]; then
    print -P "%F{33}▓▒░ %F{220}Installation de Zinit...%f"
    mkdir -p "\$(dirname \$ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "\$ZINIT_HOME" && \\
        print -P "%F{33}▓▒░ %F{34}Zinit installé.%f%b" || \\
        print -P "%F{160}▓▒░ Échec de l'installation de zinit.%f%b"
fi
source "\${ZINIT_HOME}/zinit.zsh"
autoload -Uz _zinit
(( \${+_comps} )) && _comps[zinit]=_zinit

# ── Plugins ───────────────────────────────────────────────────────────────────
if [[ "$INSTALL_PLUGINS" == true ]]; then
    # Complétion améliorée
    zinit light zsh-users/zsh-completions
    
    # Suggestions automatiques (↓ ou → pour accepter)
    zinit light zsh-users/zsh-autosuggestions
    
    # Coloration syntaxique (doit être en dernier ou presque)
    zinit light zsh-users/zsh-syntax-highlighting
    
    # bat comme pager par défaut (man, git diff, etc.)
    zinit light fdellwing/zsh-bat
    
    # fzf intégration (Ctrl+T, Ctrl+R, Alt+C)
    zinit light unixorn/fzf-zsh-plugin
    
    # zoxide intégration (z pour naviguer intelligemment)
    zinit light ptavares/zsh-zoxide
fi

# ── Complétion ────────────────────────────────────────────────────────────────
autoload -Uz compinit
if [[ -n \${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' # insensible casse
zstyle ':completion:*' list-colors "\${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- Aucun résultat --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' special-dirs true
zstyle ':completion::complete:*' gain-privileges 1
bindkey '^[[Z' reverse-menu-complete     # Shift+Tab pour reculer dans le menu

# ── Configuration de zsh-autosuggestions ─────────────────────────────────────
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6c6c6c,underline"
bindkey '^ ' autosuggest-accept           # Ctrl+Espace pour accepter
bindkey '^[[C' autosuggest-accept         # → pour accepter

# ── Configuration de bat ──────────────────────────────────────────────────────
export BAT_THEME="$THEME"
export BAT_STYLE="$BAT_STYLE"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"  # man avec bat
export MANROFFOPT="-c"

# ── Configuration de fzf ──────────────────────────────────────────────────────
export FZF_DEFAULT_OPTS="
    --height=$FZF_HEIGHT
    --layout=$FZF_LAYOUT
    --border=$FZF_BORDER
    --prompt='❯ '
    --pointer='▶'
    --marker='✓'
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
    --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
    --color=selected-bg:#45475a
    --preview-window=$FZF_PREVIEW_WINDOW"

# Utilise fd si disponible, sinon find
if command -v fd &>/dev/null; then
    local fd_cmd='fd --type f'
    [[ "$RIPGREP_HIDDEN" == "true" ]] && fd_cmd+=' --hidden'
    [[ "$RIPGREP_FOLLOW" == "true" ]] && fd_cmd+=' --follow'
    fd_cmd+=' --exclude .git'
    
    export FZF_DEFAULT_COMMAND="$fd_cmd"
    export FZF_CTRL_T_COMMAND="$fd_cmd"
    
    local fd_dirs='fd --type d'
    [[ "$RIPGREP_HIDDEN" == "true" ]] && fd_dirs+=' --hidden'
    [[ "$RIPGREP_FOLLOW" == "true" ]] && fd_dirs+=' --follow'
    fd_dirs+=' --exclude .git'
    
    export FZF_ALT_C_COMMAND="$fd_dirs"
fi

# Preview pour Ctrl+T (fichiers) avec bat
export FZF_CTRL_T_OPTS="
    --preview 'bat --color=always --style=numbers --line-range=:100 {}'
    --bind 'ctrl-/:change-preview-window(down|hidden|)'"

# Preview pour Alt+C (répertoires) avec eza ou ls
if command -v eza &>/dev/null; then
    local eza_cmd='eza --tree --level=2'
    [[ "$EZA_ICONS" == "true" ]] && eza_cmd+=' --icons'
    [[ "$EZA_GIT" == "true" ]] && eza_cmd+=' --git'
    export FZF_ALT_C_OPTS="--preview '$eza_cmd {}'"
else
    export FZF_ALT_C_OPTS="--preview 'ls -la --color=always {}'"
fi

# Ctrl+R avec aperçu de la commande
export FZF_CTRL_R_OPTS="
    --preview 'echo {}'
    --preview-window=up:3:hidden:wrap
    --bind 'ctrl-/:toggle-preview'"

# ── Configuration de zoxide ────────────────────────────────────────────────────
export _ZO_ECHO=1             # Afficher le dossier cible
export _ZO_RESOLVE_SYMLINKS=1
eval "\$(zoxide init zsh --cmd $ZOXIDE_CMD)"

# ── Prompt ────────────────────────────────────────────────────────────────────
$prompt_config

# ── Raccourcis clavier ────────────────────────────────────────────────────────
bindkey -e                              # Mode Emacs (par défaut)
bindkey '^[[A' history-search-backward  # ↑ Recherche dans l'historique
bindkey '^[[B' history-search-forward   # ↓ Recherche dans l'historique
bindkey '^[[H' beginning-of-line        # Home
bindkey '^[[F' end-of-line              # End
bindkey '^[[3~' delete-char             # Suppr
bindkey '^H' backward-kill-word         # Ctrl+Backspace supprime un mot
bindkey '^[[1;5C' forward-word          # Ctrl+→ mot suivant
bindkey '^[[1;5D' backward-word         # Ctrl+← mot précédent

# ── Alias — Navigation ────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ~='cd ~'
alias -- -='cd -'
alias d='dirs -v'               # Pile des répertoires visités

# ── Alias — Listage de fichiers (eza si disponible) ───────────────────────────
if command -v eza &>/dev/null; then
    local eza_base='eza'
    [[ "$EZA_ICONS" == "true" ]] && eza_base+=' --icons'
    [[ "$EZA_GIT" == "true" ]] && eza_base+=' --git'
    
    alias ls="$eza_base --color=auto --group-directories-first"
    alias ll="$eza_base -alFh --git"
    alias la="$eza_base -A"
    alias l="$eza_base -CF"
    alias lt="$eza_base -lth --git"   # Triés par date (récent en premier)
    alias lS="$eza_base -lSh --git"   # Triés par taille
    alias tree="$eza_base --tree --level=3"
else
    alias ls='ls --color=auto --group-directories-first'
    alias ll='ls -alFh'
    alias la='ls -A'
    alias l='ls -CF'
    alias lt='ls -lth'
    alias lS='ls -lSh'
fi

# ── Alias — cat → bat ─────────────────────────────────────────────────────────
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
    alias catp='bat'                # bat avec pagination
    alias less='bat'                # bat remplace less
fi

# ── Alias — Système ───────────────────────────────────────────────────────────
alias c='clear'
alias q='exit'
alias reload='source ~/.zshrc && echo "✓ ~/.zshrc rechargé"'
alias zshrc='\${EDITOR:-nano} ~/.zshrc'
alias h='history | tail -50'
alias hg='history | grep'       # Recherche dans l'historique : hg <terme>

# Réseau
alias myip='curl -s ifconfig.me && echo'
alias myipv6='curl -s ifconfig.me/ip && echo'
alias ports='ss -tulanp 2>/dev/null || netstat -tuln'
alias ping='ping -c 5'
alias wget='wget -c'            # Reprendre les téléchargements interrompus

# Ressources système
alias df='df -hT --exclude-type=tmpfs --exclude-type=devtmpfs'
alias du='du -h --max-depth=1'
alias free='free -h'
alias top='htop 2>/dev/null || top'
alias psa='ps aux | grep'

# ── Alias — Gestionnaire de paquets ───────────────────────────────────────────
if command -v apt &>/dev/null; then
    alias update='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y'
    alias install='sudo apt install'
    alias remove='sudo apt remove'
    alias purge='sudo apt purge'
    alias search='apt search'
    alias show='apt show'
    alias autoremove='sudo apt autoremove -y'
elif command -v dnf &>/dev/null; then
    alias update='sudo dnf update -y && sudo dnf autoremove -y'
    alias install='sudo dnf install'
    alias remove='sudo dnf remove'
    alias search='dnf search'
    alias show='dnf info'
elif command -v pacman &>/dev/null; then
    alias update='sudo pacman -Syu --noconfirm'
    alias install='sudo pacman -S --noconfirm'
    alias remove='sudo pacman -R --noconfirm'
    alias search='pacman -Ss'
    alias show='pacman -Si'
elif command -v brew &>/dev/null; then
    alias update='brew update && brew upgrade'
    alias install='brew install'
    alias remove='brew uninstall'
    alias search='brew search'
    alias show='brew info'
fi

# ── Alias — Git ───────────────────────────────────────────────────────────────
alias gs='git status'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit -m'
alias gca='git commit --amend'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gl='git pull'
alias gf='git fetch --all --prune'
alias gco='git checkout'
alias gcb='git checkout -b'
alias glog='git log --oneline --graph --decorate --all'
alias glogs='git log --oneline --graph --decorate -20'
alias gdiff='git diff | bat 2>/dev/null || git diff'
alias gstash='git stash'
alias gpop='git stash pop'
alias greset='git reset --hard HEAD'
alias gclean='git clean -fd'

# ── Alias — Outils ───────────────────────────────────────────────────────────
alias fzf-history='fc -l 1 | fzf --tac | awk "{print \$2}" | xargs -I{} zsh -c {}'
alias groot='cd \$(git rev-parse --show-toplevel)'   # Racine du dépôt git
alias mkd='mkdir -pv'                                # Créer un dossier avec les parents
alias cpv='cp -v'
alias rmv='rm -v'
alias mvv='mv -v'
alias path='echo \$PATH | tr ":" "\n"'               # Afficher le PATH lisiblement

# Ripgrep aliases
if command -v rg &>/dev/null; then
    local rg_base='rg --color=auto'
    [[ "$RIPGREP_TYPE" != "" ]] && rg_base+=" --type $RIPGREP_TYPE"
    [[ "$RIPGREP_FOLLOW" == "true" ]] && rg_base+=' --follow'
    [[ "$RIPGREP_HIDDEN" == "true" ]] && rg_base+=' --hidden'
    [[ "$RIPGREP_IGNORE" == "false" ]] && rg_base+=' --no-ignore'
    
    alias grep="$rg_base"
    alias grepi="$rg_base -i"
    alias rgf="$rg_base --files-with-matches"  # Fichiers qui correspondent
    alias rgl="$rg_base --files-with-matches | wc -l"  # Nombre de fichiers
    alias rgt="$rg_base --type-add 'web:*.{html,css,js,ts,jsx,tsx,vue,svelte}' --type web"  # Fichiers web
fi

# Chercher un fichier avec fzf et l'ouvrir dans l'éditeur
alias fzf-edit='\${EDITOR:-nano} "\$(fzf --preview '"'"'bat --color=always {}'"'"')"'

# Chercher dans les fichiers avec ripgrep et fzf
if command -v rg &>/dev/null; then
    alias fzf-grep='rg --line-number --no-heading --color=always "" . | fzf --delimiter=: --preview '"'"'bat --color=always {1} --highlight-line {2}'"'"''
else
    alias fzf-grep='grep -rn "" . | fzf --delimiter=: --preview '"'"'bat --color=always {1} --highlight-line {2}'"'"''
fi

# Raccourci pour naviguer avec zoxide + fzf
alias zf='$ZOXIDE_CMD "\$(zoxide query --list | fzf)"'
alias zl='zoxide query --list'                    # Liste des dossiers zoxide
alias zr='zoxide remove'                          # Supprimer un dossier de zoxide
alias zi='zoxide add'                             # Ajouter un dossier à zoxide

# ── Fonctions utiles ──────────────────────────────────────────────────────────

# Créer un dossier et s'y déplacer
mkcd() { mkdir -p "\$1" && cd "\$1"; }

# Extraire n'importe quelle archive
extract() {
    if [ -f "\$1" ]; then
        case "\$1" in
            *.tar.bz2)   tar xjf "\$1"   ;;
            *.tar.gz)    tar xzf "\$1"   ;;
            *.tar.xz)    tar xJf "\$1"   ;;
            *.bz2)       bunzip2 "\$1"   ;;
            *.rar)       unrar x "\$1"   ;;
            *.gz)        gunzip "\$1"    ;;
            *.tar)       tar xf "\$1"    ;;
            *.tbz2)      tar xjf "\$1"   ;;
            *.tgz)       tar xzf "\$1"   ;;
            *.zip)       unzip "\$1"     ;;
            *.Z)         uncompress "\$1";;
            *.7z)        7z x "\$1"      ;;
            *)           echo "'\$1' : format non reconnu" ;;
        esac
    else
        echo "'\$1' : fichier introuvable"
    fi
}

# Afficher la météo
meteo() { curl -s "wttr.in/\${1:-}?lang=fr"; }

# Chercher dans l'historique avec fzf
fh() {
    local cmd
    cmd=\$(fc -l 1 | awk '{\$1=""; print \$0}' | fzf --tac --no-sort --preview 'echo {}' --preview-window up:3:hidden:wrap --bind 'ctrl-/:toggle-preview' +m)
    echo "\$cmd"
    eval "\$cmd"
}

# Recherche de fichier avec fzf et cd dans son dossier
fcd() {
    local file dir
    file=\$(fzf --query="\$1" --select-1 --exit-0 \\
        --preview 'bat --color=always --style=numbers {}')
    [ -n "\$file" ] && dir=\$(dirname "\$file") && z "\$dir"
}

# Backup rapide d'un fichier
bak() { cp "\$1" "\$1.bak.\$(date +%Y%m%d_%H%M%S)"; echo "✓ Sauvegardé : \$1.bak.*"; }

# Taille d'un dossier
duf() { du -sh "\${1:-.}"; }

# Afficher les 10 commandes les plus utilisées
top10() { history | awk '{print \$2}' | sort | uniq -c | sort -rn | head -10; }

# Recherche rapide de fichiers avec find/fd
search_files() {
    if command -v fd &>/dev/null; then
        local fd_cmd='fd'
        [[ "$RIPGREP_HIDDEN" == "true" ]] && fd_cmd+=' --hidden'
        [[ "$RIPGREP_FOLLOW" == "true" ]] && fd_cmd+=' --follow'
        fd_cmd+=' --exclude .git'
        
        $fd_cmd "\$1"
    else
        find . -name "*\$1*" 2>/dev/null
    fi
}

# Créer un projet template
mkproject() {
    local project_name="\$1"
    if [[ -z "\$project_name" ]]; then
        echo "Usage: mkproject <nom_du_projet>"
        return 1
    fi
    
    mkdir -p "\$project_name"/{src,docs,tests,scripts}
    echo "# \$project_name" > "\$project_name/README.md"
    cd "\$project_name"
    echo "✓ Projet '\$project_name' créé"
    
    # Ajouter au zoxide si disponible
    if command -v zoxide &>/dev/null; then
        zoxide add "\$project_name"
    fi
}

# Recherche intelligente avec ripgrep + fzf
rgfzf() {
    if command -v rg &>/dev/null && command -v fzf &>/dev/null; then
        local rg_cmd='rg --line-number --no-heading --color=always'
        [[ "$RIPGREP_HIDDEN" == "true" ]] && rg_cmd+=' --hidden'
        [[ "$RIPGREP_FOLLOW" == "true" ]] && rg_cmd+=' --follow'
        [[ "$RIPGREP_IGNORE" == "false" ]] && rg_cmd+=' --no-ignore'
        
        local result=$($rg_cmd "\$1" . | fzf --delimiter=: --preview 'bat --color=always {1} --highlight-line {2}' --preview-window=up:60%:wrap)
        
        if [[ -n "$result" ]]; then
            local file=$(echo "$result" | cut -d: -f1)
            local line=$(echo "$result" | cut -d: -f2)
            \${EDITOR:-nano} "+$line" "$file"
        fi
    else
        echo "rg et fzf sont requis pour cette fonction"
    fi
}

# Navigation avec fzf + zoxide
fzf_zoxide() {
    if command -v fzf &>/dev/null && command -v zoxide &>/dev/null; then
        local dir=$(zoxide query --list | fzf --height=40% --layout=reverse --preview 'eza --tree --level=2 {}')
        [[ -n "$dir" ]] && $ZOXIDE_CMD "$dir"
    else
        echo "fzf et zoxide sont requis pour cette fonction"
    fi
}

# ── Variables d'environnement ─────────────────────────────────────────────────
export EDITOR="\${EDITOR:-nano}"
export VISUAL="\$EDITOR"
export PAGER="\${PAGER:-bat}"
export LESS="-R"
export LANG="fr_FR.UTF-8"
export LC_ALL="fr_FR.UTF-8"

# ── Message de bienvenue ──────────────────────────────────────────────────────
if [[ \$- == *i* ]]; then
    echo -e "\033[1;36m\$(hostname)\033[0m — \033[1;32m\$(uname -sr)\033[0m — \033[1;33m\$(date '+%A %d %B %Y, %H:%M')\033[0m"
fi
ZSHRC_EOF

    success "Fichier ~/.zshrc généré"
}

# ── Configuration du shell par défaut ─────────────────────────────────────────
set_default_shell() {
    section "Configuration du shell par défaut"
    
    local zsh_path=$(which zsh)
    local current_shell=$(getent passwd "$USER" | cut -d: -f7)
    
    if [[ "$current_shell" == "$zsh_path" ]]; then
        success "ZSH est déjà le shell par défaut"
        return
    fi
    
    # Sur macOS, ZSH est déjà le défaut depuis Catalina, ne rien faire
    if [[ "$OS" == "macos" ]]; then
        info "Sur macOS, ZSH est déjà le shell par défaut depuis Catalina"
        return
    fi
    
    # Ajouter zsh aux shells autorisés si nécessaire
    if ! grep -q "$zsh_path" /etc/shells; then
        if [[ "$DRY_RUN" == false ]]; then
            echo "$zsh_path" | sudo tee -a /etc/shells > /dev/null
        fi
    fi
    
    if [[ "$DRY_RUN" == false ]]; then
        chsh -s "$zsh_path"
    fi
    
    success "Shell par défaut défini sur ZSH ($zsh_path)"
}

# ── Pré-chargement des plugins ───────────────────────────────────────────────
preload_plugins() {
    if [[ "$INSTALL_PLUGINS" == false ]]; then
        return
    fi
    
    section "Pré-chargement des plugins Zinit"
    
    info "Initialisation des plugins (première exécution, peut prendre un moment)..."
    
    if [[ "$DRY_RUN" == false ]]; then
        zsh -ic "zinit load zsh-users/zsh-autosuggestions; \
                  zinit load zsh-users/zsh-syntax-highlighting; \
                  zinit load zsh-users/zsh-completions; \
                  zinit load fdellwing/zsh-bat; \
                  zinit load unixorn/fzf-zsh-plugin; \
                  zinit load ptavares/zsh-zoxide; \
                  exit" 2>/dev/null || true
    fi
    
    success "Plugins pré-chargés"
}

# ── Mode désinstallation ─────────────────────────────────────────────────────
uninstall_zsh() {
    section "Désinstallation de ZSH et composants"
    
    warn "Cette action va supprimer ZSH, Zinit et tous les plugins"
    read -p "Continuer? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Désinstallation annulée"
        return
    fi
    
    # Restaurer le shell par défaut
    local bash_path=$(which bash)
    chsh -s "$bash_path"
    
    # Supprimer les fichiers
    rm -rf "$HOME/.zshrc"*
    rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/zinit"
    rm -rf "$HOME/.zcompdump"*
    
    # Supprimer les outils Homebrew installés
    if command -v brew &>/dev/null; then
        brew uninstall bat fzf zoxide fd eza ripgrep 2>/dev/null || true
    fi
    
    success "Désinstallation terminée. Redémarrez votre terminal."
}

# ── Fonctions de maintenance ─────────────────────────────────────────────────
update_plugins() {
    section "Mise à jour des plugins Zinit"
    
    if [[ ! -d "${XDG_DATA_HOME:-$HOME/.local/share}/zinit" ]]; then
        error "Zinit n'est pas installé"
    fi
    
    zsh -ic "zinit update --all; exit"
    success "Plugins mis à jour"
}

backup_config() {
    section "Sauvegarde de la configuration"
    
    local backup_name="zsh_backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$HOME/$backup_name"
    
    mkdir -p "$backup_path"
    
    [[ -f "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$backup_path/"
    [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/zinit" ]] && cp -r "${XDG_DATA_HOME:-$HOME/.local/share}/zinit" "$backup_path/"
    
    success "Configuration sauvegardée dans $backup_path"
}

# ── Affichage de l'aide ───────────────────────────────────────────────────────
show_help() {
    cat << EOF
Enhanced ZSH Installer v$SCRIPT_VERSION

USAGE:
    $SCRIPT_NAME [OPTIONS]

OPTIONS:
    --dry-run           Simuler l'installation sans rien faire
    --verbose           Afficher les messages de debug
    --skip-font         Ne pas installer la police JetBrainsMono
    --skip-brew         Ne pas installer Homebrew ni les paquets associés
    --no-plugins        Ne pas installer les plugins Zinit
    --theme THEME       Thème pour bat (dracula, github, monokai) [défaut: dracula]
    --prompt STYLE      Style du prompt (simple, enhanced, powerline) [défaut: enhanced]
    --fzf-height        Hauteur de fzf (50%, 70%, 100%) [défaut: 50%]
    --fzf-layout        Layout fzf (reverse, default) [défaut: reverse]
    --fzf-border        Style de bordure fzf (rounded, sharp, bold) [défaut: rounded]
    --bat-style         Style bat (numbers,changes,header,grid) [défaut: numbers,changes,header]
    --zoxide-cmd        Commande zoxide (z, zi) [défaut: z]
    --eza-icons         Activer les icônes eza (true, false) [défaut: true]
    --eza-git           Activer le support git eza (true, false) [défaut: true]
    --rg-follow         Suivre les liens symboliques avec ripgrep (true, false) [défaut: true]
    --rg-hidden         Chercher dans les fichiers cachés avec ripgrep (true, false) [défaut: false]
    --uninstall         Désinstaller ZSH et tous les composants
    --update-plugins    Mettre à jour les plugins Zinit
    --backup            Sauvegarder la configuration actuelle
    --help              Afficher cette aide

EXAMPLES:
    $SCRIPT_NAME                           # Installation standard
    $SCRIPT_NAME --dry-run --verbose       # Simulation avec debug
    $SCRIPT_NAME --skip-font --theme github # Installation sans police, thème github
    $SCRIPT_NAME --fzf-height 70% --eza-icons false # Configuration personnalisée
    $SCRIPT_NAME --rg-hidden true --bat-style grid # Ripgrep avec fichiers cachés, bat en grille
    $SCRIPT_NAME --uninstall               # Désinstallation complète

SUPPORTED SYSTEMS:
    - Linux: Ubuntu, Debian, Linux Mint, Fedora, Arch, Manjaro
    - macOS: Intel et Apple Silicon

THEMES AVAILABLE:
    - dracula, github, monokai, ansi, base16, solarized

PROMPT STYLES:
    - simple: Prompt minimaliste
    - enhanced: Prompt avec informations Git et heure
    - powerline: Style powerline avec lignes décoratives

EOF
}

# ── Parsing des arguments ─────────────────────────────────────────────────────
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --skip-font)
                SKIP_FONT=true
                shift
                ;;
            --skip-brew)
                SKIP_BREW=true
                shift
                ;;
            --no-plugins)
                INSTALL_PLUGINS=false
                shift
                ;;
            --theme)
                THEME="$2"
                shift 2
                ;;
            --prompt)
                PROMPT_STYLE="$2"
                shift 2
                ;;
            --fzf-height)
                FZF_HEIGHT="$2"
                shift 2
                ;;
            --fzf-layout)
                FZF_LAYOUT="$2"
                shift 2
                ;;
            --fzf-border)
                FZF_BORDER="$2"
                shift 2
                ;;
            --bat-style)
                BAT_STYLE="$2"
                shift 2
                ;;
            --zoxide-cmd)
                ZOXIDE_CMD="$2"
                shift 2
                ;;
            --eza-icons)
                EZA_ICONS="$2"
                shift 2
                ;;
            --eza-git)
                EZA_GIT="$2"
                shift 2
                ;;
            --rg-follow)
                RIPGREP_FOLLOW="$2"
                shift 2
                ;;
            --rg-hidden)
                RIPGREP_HIDDEN="$2"
                shift 2
                ;;
            --uninstall)
                UNINSTALL_MODE=true
                shift
                ;;
            --update-plugins)
                update_plugins
                exit 0
                ;;
            --backup)
                backup_config
                exit 0
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Option inconnue: $1. Utilisez --help pour voir les options disponibles."
                ;;
        esac
    done
}

# ── Résumé final ───────────────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║          ✓  Installation terminée avec succès          ║${NC}"
    echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Configuration installée :${NC}"
    echo ""
    echo -e "  ${CYAN}Système${NC}"
    echo    "  ├─ OS: $DISTRO_NAME"
    echo    "  ├─ ZSH: $(zsh --version | head -1)"
    echo    "  └─ Shell par défaut: ZSH"
    echo ""
    echo -e "  ${CYAN}Gestionnaire de plugins${NC}"
    echo    "  └─ Zinit: ${XDG_DATA_HOME:-$HOME/.local/share}/zinit"
    echo ""
    if [[ "$INSTALL_PLUGINS" == true ]]; then
        echo -e "  ${CYAN}Plugins ZSH${NC}"
        echo    "  ├─ zsh-autosuggestions   → suggestions (→ pour accepter)"
        echo    "  ├─ zsh-syntax-highlighting → coloration des commandes"
        echo    "  ├─ zsh-completions       → complétion enrichie"
        echo    "  ├─ zsh-bat               → bat comme pager"
        echo    "  ├─ fzf-zsh-plugin        → Ctrl+T, Ctrl+R, Alt+C"
        echo    "  └─ zsh-zoxide            → navigation intelligente"
        echo ""
    fi
    
    if [[ "$SKIP_BREW" == false ]]; then
        echo -e "  ${CYAN}Outils installés${NC}"
        echo    "  ├─ bat    → cat avec coloration (thème: $THEME)"
        echo    "  ├─ fzf    → recherche floue"
        echo    "  ├─ zoxide → cd intelligent"
        echo    "  ├─ fd     → find moderne"
        echo    "  ├─ eza    → ls moderne"
        echo    "  └─ ripgrep→ grep rapide"
        echo ""
    fi
    
    if [[ "$SKIP_FONT" == false ]]; then
        echo -e "  ${CYAN}Police${NC}"
        echo    "  └─ JetBrainsMono Nerd Font → ~/.local/share/fonts/"
        echo ""
    fi
    
    echo -e "  ${CYAN}Configuration${NC}"
    echo    "  ├─ Prompt: $PROMPT_STYLE"
    echo    "  ├─ Fichier config: ~/.zshrc"
    echo    "  └─ Backup: $BACKUP_DIR"
    echo ""
    echo -e "  ${CYAN}Alias principaux${NC}"
    echo    "  ├─ update / install / remove → gestionnaire de paquets"
    echo    "  ├─ gs / ga / gc / gp / glog   → Git rapide"
    echo    "  ├─ ll / la / lt / lS          → listage (eza si dispo)"
    echo    "  ├─ cat / less                 → bat si dispo"
    echo    "  ├─ z <dossier>                → navigation zoxide"
    echo    "  ├─ zf                         → zoxide + fzf"
    echo    "  ├─ fzf-edit                   → éditer avec fzf"
    echo    "  └─ extract <archive>          → extraire tout format"
    echo ""
    echo -e "  ${CYAN}Fonctions utiles${NC}"
    echo    "  ├─ mkcd <dossier>  → créer + aller"
    echo    "  ├─ fh              → historique avec fzf"
    echo    "  ├─ fcd             → trouver fichier et y aller"
    echo    "  ├─ bak <file>      → backup rapide"
    echo    "  ├─ top10           → commandes les plus utilisées"
    echo    "  ├─ mkproject <nom> → créer projet template"
    echo    "  └─ meteo [ville]   → météo"
    echo ""
    echo -e "${YELLOW}  ⚡ Actions requises :${NC}"
    echo -e "     1. Relancez votre terminal ou exécutez : ${BOLD}exec zsh${NC}"
    if [[ "$SKIP_FONT" == false ]]; then
        echo -e "     2. Configurez votre terminal pour utiliser ${BOLD}JetBrainsMono Nerd Font${NC}"
    fi
    echo ""
    echo -e "${CYAN}  📝 Log de l'installation :${NC} $LOG_FILE"
    echo -e "${CYAN}  🔧 Configuration :${NC} $CONFIG_FILE"
    echo ""
}

# ── Point d'entrée principal ─────────────────────────────────────────────────
main() {
    # Initialisation du log
    echo "Enhanced ZSH Installer v$SCRIPT_VERSION - Début: $(date)" > "$LOG_FILE"
    
    # Parsing des arguments
    parse_arguments "$@"
    
    # Mode désinstallation
    if [[ "$UNINSTALL_MODE" == true ]]; then
        uninstall_zsh
        exit 0
    fi
    
    # Affichage
    echo ""
    echo -e "${BOLD}${CYAN}"
    echo "  ███████╗███████╗██╗  ██╗    ███████╗███████╗████████╗██╗   ██╗██████╗ "
    echo "     ███╔╝██╔════╝██║  ██║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗"
    echo "    ███╔╝ ███████╗███████║    ███████╗█████╗     ██║   ██║   ██║██████╔╝"
    echo "   ███╔╝  ╚════██║██╔══██║    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ "
    echo "  ███████╗███████║██║  ██║    ███████║███████╗   ██║   ╚██████╔╝██║     "
    echo "  ╚══════╝╚══════╝╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     "
    echo -e "${NC}"
    echo -e "  ${BOLD}Enhanced ZSH Installer v$SCRIPT_VERSION${NC}"
    echo -e "  ${CYAN}Cross-platform • Modular • Customizable${NC}"
    echo ""
    
    if [[ "$DRY_RUN" == true ]]; then
        warn "MODE DRY-RUN: Aucune modification ne sera effectuée"
    fi
    
    # Sauvegarde de la configuration
    save_config
    
    # Vérifications préliminaires
    check_permissions
    check_internet
    
    # Détection du système
    detect_system
    
    # Installation
    install_package_manager_deps
    install_zsh
    install_homebrew
    install_brew_packages
    install_jetbrains_font
    install_zinit
    generate_zshrc
    set_default_shell
    preload_plugins
    
    # Résumé final
    if [[ "$DRY_RUN" == false ]]; then
        print_summary
    else
        echo -e "${GREEN}✓ Simulation terminée avec succès${NC}"
        echo -e "${CYAN}Exécutez sans --dry-run pour l'installation réelle${NC}"
    fi
}

# Exécution
main "$@"
