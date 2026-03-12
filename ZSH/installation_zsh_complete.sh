#!/bin/bash
# =============================================================================
#  ZSH Setup — Linux Mint / Ubuntu / Debian
#  Plugins : zinit + zsh-autosuggestions, zsh-syntax-highlighting,
#            zsh-completions, zsh-bat, fzf-zsh-plugin, zsh-zoxide
#  Brew    : bat, fzf, zoxide
#  Font    : JetBrainsMono Nerd Font (GitHub Nerd Fonts)
# =============================================================================

set -euo pipefail

# ── Couleurs ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Fonctions utilitaires ─────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERREUR]${NC} $*"; exit 1; }
section() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${NC}"; \
            echo -e "${BOLD}${CYAN}  $*${NC}"; \
            echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}\n"; }

# ── Vérification de la distribution ──────────────────────────────────────────
check_distro() {
    section "Vérification de la distribution"
    if [ ! -f /etc/os-release ]; then
        error "Impossible de déterminer la distribution."
    fi
    . /etc/os-release
    case "$ID" in
        ubuntu|debian|linuxmint) success "Distribution supportée : $PRETTY_NAME" ;;
        *) error "Distribution non supportée : $PRETTY_NAME. Ce script supporte Ubuntu, Debian et Linux Mint." ;;
    esac
}

# ── Mise à jour des paquets système ──────────────────────────────────────────
update_system() {
    section "Mise à jour des paquets système"
    sudo apt update -y
    sudo apt upgrade -y
    success "Système à jour."
}

# ── Installation des dépendances de base ─────────────────────────────────────
install_base_deps() {
    section "Installation des dépendances de base"
    sudo apt install -y \
        zsh \
        git \
        curl \
        wget \
        build-essential \
        procps \
        file \
        fontconfig \
        unzip
    success "Dépendances de base installées."
}

# ── Installation de Homebrew ──────────────────────────────────────────────────
install_homebrew() {
    section "Installation de Homebrew"
    if command -v brew &>/dev/null; then
        success "Homebrew déjà installé : $(brew --version | head -1)"
        return
    fi
    info "Installation de Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Détection du chemin Homebrew (Intel ou ARM)
    if [ -d "/home/linuxbrew/.linuxbrew" ]; then
        BREW_PREFIX="/home/linuxbrew/.linuxbrew"
    elif [ -d "$HOME/.linuxbrew" ]; then
        BREW_PREFIX="$HOME/.linuxbrew"
    else
        error "Homebrew installé mais chemin introuvable."
    fi

    eval "$($BREW_PREFIX/bin/brew shellenv)"
    success "Homebrew installé."
}

# ── Installation des paquets Homebrew ────────────────────────────────────────
install_brew_packages() {
    section "Installation des paquets via Homebrew"

    info "Installation de bat..."
    brew install bat
    success "bat installé."

    info "Installation de fzf..."
    brew install fzf
    success "fzf installé."

    info "Installation de zoxide..."
    brew install zoxide
    success "zoxide installé."
}

# ── Installation de la police JetBrainsMono Nerd Font (GitHub Nerd Fonts) ────
install_jetbrains_font() {
    FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    mkdir -p "$FONT_DIR"

    # Vérifier si déjà installée
    if fc-list | grep -qi "JetBrainsMono Nerd"; then
        success "JetBrainsMono Nerd Font déjà installée."
        return
    fi

    FONT_VERSION="3.3.0"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v${FONT_VERSION}/JetBrainsMono.zip"
    TMP_DIR=$(mktemp -d)

    info "Téléchargement de JetBrainsMono Nerd Font v${FONT_VERSION}..."
    curl -fsSL "$FONT_URL" -o "$TMP_DIR/JetBrainsMono.zip"
    unzip -q "$TMP_DIR/JetBrainsMono.zip" -d "$TMP_DIR/fonts"
    find "$TMP_DIR/fonts" -name "*.ttf" -exec cp {} "$FONT_DIR/" \;
    fc-cache -fv "$FONT_DIR" &>/dev/null
    rm -rf "$TMP_DIR"
    success "JetBrainsMono Nerd Font installée dans $FONT_DIR."
}

# ── Installation de zinit ─────────────────────────────────────────────────────
install_zinit() {
    section "Installation de zinit"
    ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
    if [ -d "$ZINIT_HOME/.git" ]; then
        success "zinit déjà installé."
        return
    fi
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    success "zinit installé dans $ZINIT_HOME."
}

# ── Détection du préfixe Homebrew ────────────────────────────────────────────
get_brew_prefix() {
    if [ -d "/home/linuxbrew/.linuxbrew" ]; then
        echo "/home/linuxbrew/.linuxbrew"
    elif [ -d "$HOME/.linuxbrew" ]; then
        echo "$HOME/.linuxbrew"
    else
        echo ""
    fi
}

# ── Génération du fichier .zshrc ─────────────────────────────────────────────
write_zshrc() {
    section "Génération du fichier ~/.zshrc"

    BREW_PREFIX=$(get_brew_prefix)

    # Sauvegarde de l'ancien .zshrc
    if [ -f "$HOME/.zshrc" ]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        warn "Ancien .zshrc sauvegardé."
    fi

    cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
# =============================================================================
#  ~/.zshrc — Configuration ZSH
# =============================================================================

# ── Homebrew ──────────────────────────────────────────────────────────────────
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -d "$HOME/.linuxbrew" ]; then
    eval "$($HOME/.linuxbrew/bin/brew shellenv)"
fi

# ── PATH supplémentaires ─────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

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
HISTFILE="$HOME/.zsh_history"
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
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d $ZINIT_HOME ]]; then
    print -P "%F{33}▓▒░ %F{220}Installation de Zinit...%f"
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" && \
        print -P "%F{33}▓▒░ %F{34}Zinit installé.%f%b" || \
        print -P "%F{160}▓▒░ Échec de l'installation de zinit.%f%b"
fi
source "${ZINIT_HOME}/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# ── Plugins ───────────────────────────────────────────────────────────────────

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

# ── Complétion ────────────────────────────────────────────────────────────────
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' # insensible casse
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
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
export BAT_THEME="Dracula"
export BAT_STYLE="numbers,changes,header"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"  # man avec bat
export MANROFFOPT="-c"

# ── Configuration de fzf ──────────────────────────────────────────────────────
export FZF_DEFAULT_OPTS="
    --height=50%
    --layout=reverse
    --border=rounded
    --prompt='❯ '
    --pointer='▶'
    --marker='✓'
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
    --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
    --color=selected-bg:#45475a
    --preview-window=right:60%:wrap"

# Utilise fd si disponible, sinon find
if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

# Preview pour Ctrl+T (fichiers) avec bat
export FZF_CTRL_T_OPTS="
    --preview 'bat --color=always --style=numbers --line-range=:100 {}'
    --bind 'ctrl-/:change-preview-window(down|hidden|)'"

# Preview pour Alt+C (répertoires) avec tree ou ls
export FZF_ALT_C_OPTS="
    --preview 'ls -la --color=always {}'"

# Ctrl+R avec aperçu de la commande
export FZF_CTRL_R_OPTS="
    --preview 'echo {}'
    --preview-window=up:3:hidden:wrap
    --bind 'ctrl-/:toggle-preview'"

# ── Configuration de zoxide ────────────────────────────────────────────────────
export _ZO_ECHO=1             # Afficher le dossier cible
export _ZO_RESOLVE_SYMLINKS=1
eval "$(zoxide init zsh --cmd z)"

# ── Prompt ────────────────────────────────────────────────────────────────────
autoload -Uz vcs_info
precmd() { vcs_info }
setopt PROMPT_SUBST

zstyle ':vcs_info:git:*' formats ' %F{#bd93f9}(%b)%f'
zstyle ':vcs_info:*' enable git

PROMPT='%F{#50fa7b}%n%f%F{#6272a4}@%f%F{#8be9fd}%m%f %F{#f1fa8c}%~%f${vcs_info_msg_0_} %F{#ff79c6}❯%f '
RPROMPT='%F{#6272a4}%*%f'

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

# ── Alias — Listage de fichiers ───────────────────────────────────────────────
alias ls='ls --color=auto --group-directories-first'
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias lt='ls -lth'              # Triés par date (récent en premier)
alias lS='ls -lSh'              # Triés par taille

# ── Alias — cat → bat ─────────────────────────────────────────────────────────
alias cat='bat --paging=never'
alias catp='bat'                # bat avec pagination
alias less='bat'                # bat remplace less

# ── Alias — Système ───────────────────────────────────────────────────────────
alias c='clear'
alias q='exit'
alias reload='source ~/.zshrc && echo "✓ ~/.zshrc rechargé"'
alias zshrc='${EDITOR:-nano} ~/.zshrc'
alias h='history | tail -50'
alias hg='history | grep'       # Recherche dans l'historique : hg <terme>

# Réseau
alias myip='curl -s ifconfig.me && echo'
alias myipv6='curl -s ifconfig.me/ip && echo'
alias ports='ss -tulanp'
alias ping='ping -c 5'
alias wget='wget -c'            # Reprendre les téléchargements interrompus

# Ressources système
alias df='df -hT --exclude-type=tmpfs --exclude-type=devtmpfs'
alias du='du -h --max-depth=1'
alias free='free -h'
alias top='htop 2>/dev/null || top'
alias psa='ps aux | grep'

# ── Alias — APT ───────────────────────────────────────────────────────────────
alias update='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y'
alias install='sudo apt install'
alias remove='sudo apt remove'
alias purge='sudo apt purge'
alias search='apt search'
alias show='apt show'
alias autoremove='sudo apt autoremove -y'

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
alias gdiff='git diff | bat'
alias gstash='git stash'
alias gpop='git stash pop'
alias greset='git reset --hard HEAD'
alias gclean='git clean -fd'

# ── Alias — Outils ───────────────────────────────────────────────────────────
alias fzf-history='fc -l 1 | fzf --tac | awk "{print \$2}" | xargs -I{} zsh -c {}'
alias groot='cd $(git rev-parse --show-toplevel)'   # Racine du dépôt git
alias mkd='mkdir -pv'                                # Créer un dossier avec les parents
alias cpv='cp -v'
alias rmv='rm -v'
alias mvv='mv -v'
alias path='echo $PATH | tr ":" "\n"'               # Afficher le PATH lisiblement

# Chercher un fichier avec fzf et l'ouvrir dans l'éditeur
alias fzf-edit='${EDITOR:-nano} "$(fzf --preview '"'"'bat --color=always {}'"'"')"'

# Chercher dans les fichiers avec grep et fzf
alias fzf-grep='grep -rn "" . | fzf --delimiter=: --preview '"'"'bat --color=always {1} --highlight-line {2}'"'"''

# Raccourci pour naviguer avec zoxide + fzf
alias zf='z "$(zoxide query --list | fzf)"'

# ── Fonctions utiles ──────────────────────────────────────────────────────────

# Créer un dossier et s'y déplacer
mkcd() { mkdir -p "$1" && cd "$1"; }

# Extraire n'importe quelle archive
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"   ;;
            *.tar.gz)    tar xzf "$1"   ;;
            *.tar.xz)    tar xJf "$1"   ;;
            *.bz2)       bunzip2 "$1"   ;;
            *.rar)       unrar x "$1"   ;;
            *.gz)        gunzip "$1"    ;;
            *.tar)       tar xf "$1"    ;;
            *.tbz2)      tar xjf "$1"   ;;
            *.tgz)       tar xzf "$1"   ;;
            *.zip)       unzip "$1"     ;;
            *.Z)         uncompress "$1";;
            *.7z)        7z x "$1"      ;;
            *)           echo "'$1' : format non reconnu" ;;
        esac
    else
        echo "'$1' : fichier introuvable"
    fi
}

# Afficher la météo
meteo() { curl -s "wttr.in/${1:-}?lang=fr"; }

# Chercher dans l'historique avec fzf
fh() {
    local cmd
    cmd=$(fc -l 1 | awk '{$1=""; print $0}' | fzf --tac --no-sort --preview 'echo {}' --preview-window up:3:hidden:wrap --bind 'ctrl-/:toggle-preview' +m)
    echo "$cmd"
    eval "$cmd"
}

# Recherche de fichier avec fzf et cd dans son dossier
fcd() {
    local file dir
    file=$(fzf --query="$1" --select-1 --exit-0 \
        --preview 'bat --color=always --style=numbers {}')
    [ -n "$file" ] && dir=$(dirname "$file") && z "$dir"
}

# Backup rapide d'un fichier
bak() { cp "$1" "$1.bak.$(date +%Y%m%d_%H%M%S)"; echo "✓ Sauvegardé : $1.bak.*"; }

# Taille d'un dossier
duf() { du -sh "${1:-.}"; }

# Afficher les 10 commandes les plus utilisées
top10() { history | awk '{print $2}' | sort | uniq -c | sort -rn | head -10; }

# ── Variables d'environnement ─────────────────────────────────────────────────
export EDITOR="${EDITOR:-nano}"
export VISUAL="$EDITOR"
export PAGER="bat"
export LESS="-R"
export LANG="fr_FR.UTF-8"
export LC_ALL="fr_FR.UTF-8"

# ── Message de bienvenue ──────────────────────────────────────────────────────
if [[ $- == *i* ]]; then
    echo -e "\033[1;36m$(hostname)\033[0m — \033[1;32m$(uname -sr)\033[0m — \033[1;33m$(date '+%A %d %B %Y, %H:%M')\033[0m"
fi
ZSHRC_EOF

    success "Fichier ~/.zshrc généré."
}

# ── Définir zsh comme shell par défaut ───────────────────────────────────────
set_default_shell() {
    section "Définir zsh comme shell par défaut"
    ZSH_PATH=$(which zsh)
    CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)

    if [ "$CURRENT_SHELL" = "$ZSH_PATH" ]; then
        success "zsh est déjà le shell par défaut."
        return
    fi

    # Ajouter zsh aux shells autorisés si nécessaire
    if ! grep -q "$ZSH_PATH" /etc/shells; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
    fi

    chsh -s "$ZSH_PATH"
    success "Shell par défaut défini sur zsh ($ZSH_PATH)."
}

# ── Pré-chargement des plugins zinit ─────────────────────────────────────────
preload_plugins() {
    section "Pré-chargement des plugins zinit"
    info "Initialisation des plugins (première exécution, peut prendre un moment)..."
    zsh -ic "zinit load zsh-users/zsh-autosuggestions; \
              zinit load zsh-users/zsh-syntax-highlighting; \
              zinit load zsh-users/zsh-completions; \
              zinit load fdellwing/zsh-bat; \
              zinit load unixorn/fzf-zsh-plugin; \
              zinit load ptavares/zsh-zoxide; \
              exit" 2>/dev/null || true
    success "Plugins pré-chargés."
}

# ── Résumé final ──────────────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║          ✓  Installation terminée avec succès          ║${NC}"
    echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Ce qui a été installé et configuré :${NC}"
    echo ""
    echo -e "  ${CYAN}Shell${NC}"
    echo    "  ├─ zsh (shell par défaut)"
    echo    "  └─ zinit (gestionnaire de plugins)"
    echo ""
    echo -e "  ${CYAN}Plugins zsh${NC}"
    echo    "  ├─ zsh-autosuggestions   → suggestions en gris (→ pour accepter)"
    echo    "  ├─ zsh-syntax-highlighting → coloration des commandes"
    echo    "  ├─ zsh-completions       → complétion enrichie (Tab)"
    echo    "  ├─ zsh-bat               → bat comme pager (man, git diff...)"
    echo    "  ├─ fzf-zsh-plugin        → Ctrl+T (fichier), Ctrl+R (historique), Alt+C (dossier)"
    echo    "  └─ zsh-zoxide            → z <dossier> pour navigation intelligente"
    echo ""
    echo -e "  ${CYAN}Outils Homebrew${NC}"
    echo    "  ├─ bat    → cat avec coloration syntaxique"
    echo    "  ├─ fzf    → recherche floue interactive"
    echo    "  ├─ zoxide → cd intelligent avec apprentissage"
    echo    "  └─ JetBrainsMono Nerd Font → dans ~/.local/share/fonts/"
    echo ""
    echo -e "  ${CYAN}Alias utiles${NC}"
    echo    "  ├─ update / install / remove  → APT simplifié"
    echo    "  ├─ gs / ga / gc / gp / glog   → Git rapide"
    echo    "  ├─ ll / la / lt / lS          → listage de fichiers"
    echo    "  ├─ z <dossier>                → navigation zoxide"
    echo    "  ├─ zf                         → zoxide + fzf interactif"
    echo    "  ├─ fzf-edit                   → ouvrir un fichier avec fzf"
    echo    "  └─ extract <archive>          → extraire tout format"
    echo ""
    echo -e "  ${CYAN}Fonctions utiles${NC}"
    echo    "  ├─ mkcd <dossier>  → créer + aller dans le dossier"
    echo    "  ├─ extract <file>  → extraire n'importe quelle archive"
    echo    "  ├─ fh              → rechercher dans l'historique avec fzf"
    echo    "  ├─ fcd             → trouver un fichier et aller dans son dossier"
    echo    "  ├─ bak <file>      → sauvegarder un fichier rapidement"
    echo    "  ├─ top10           → 10 commandes les plus utilisées"
    echo    "  └─ meteo [ville]   → afficher la météo"
    echo ""
    echo -e "${YELLOW}  ⚡ Action requise :${NC} Relancez votre terminal ou exécutez :"
    echo -e "     ${BOLD}exec zsh${NC}"
    echo ""
    echo -e "${YELLOW}  🖋  Police :${NC} Configurez votre terminal pour utiliser"
    echo -e "     ${BOLD}JetBrainsMono Nerd Font${NC} afin d'afficher les icônes correctement."
    echo ""
}

# ── Point d'entrée principal ─────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${BOLD}${CYAN}"
    echo "  ███████╗███████╗██╗  ██╗    ███████╗███████╗████████╗██╗   ██╗██████╗ "
    echo "     ███╔╝██╔════╝██║  ██║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗"
    echo "    ███╔╝ ███████╗███████║    ███████╗█████╗     ██║   ██║   ██║██████╔╝"
    echo "   ███╔╝  ╚════██║██╔══██║    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ "
    echo "  ███████╗███████║██║  ██║    ███████║███████╗   ██║   ╚██████╔╝██║     "
    echo "  ╚══════╝╚══════╝╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     "
    echo -e "${NC}"
    echo -e "  ${BOLD}Installation ZSH pour Linux Mint / Ubuntu / Debian${NC}"
    echo -e "  ${CYAN}zinit · autosuggestions · syntax-highlighting · bat · fzf · zoxide${NC}"
    echo ""

    check_distro
    update_system
    install_base_deps
    install_homebrew
    install_brew_packages
    install_jetbrains_font
    install_zinit
    write_zshrc
    set_default_shell
    preload_plugins
    print_summary
}

main "$@"