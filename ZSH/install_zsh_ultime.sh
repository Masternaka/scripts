#!/usr/bin/env bash

# --------------------------- Explication du script ---------------------------
# Zsh + Oh My Zsh + Oh My Posh + plugins
# - Installe fzf, bat/batcat, zoxide AVANT de configurer plugins et init
# - Ajoute dans plugins=() uniquement ce qui est présent
# - Compatible Ubuntu / Debian / Linux Mint (APT-based)
# -----------------------------------------------------------------------------

# ------------------------ Instructions d'utilisation -------------------------
# Ce script doit être exécuté dans un terminal avec les droits d'un utilisateur normal (pas root).
# Il faut rendre ce script exécutable (chmod +x) et l'exécuter depuis le répertoire où il se trouve.
# -----------------------------------------------------------------------------

# chmod +x install_zsh_ultime.sh
# ./install_zsh_ultime.sh

# -----------------------------------------------------------------------------

# ------------------------- Recommandations -----------------------------------
# - Avant d'exécuter ce scripr, il est recommandé de faire l'installation du script "install_fonts.sh" pour installer les fonts
#   nécessaires à l'affichage des icônes dans le thème Oh My Posh.
# -----------------------------------------------------------------------------

set -euo pipefail

# ── Couleurs et Helpers ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_step()  { echo -e "\n${BOLD}${BLUE}══ $1 ${NC}"; }
log_info()  { echo -e "  ${GREEN}✔${NC}  $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $1"; }
log_error() { echo -e "  ${RED}✘${NC}  $1"; exit 1; }

echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║      ULTIMATE ZSH & OH-MY-POSH INSTALLER v2.0        ║"
echo "  ║      Ubuntu · Debian · Linux Mint                    ║"
echo "  ╚══════════════════════════════════════════════════════╝${NC}"

# ── Vérifications ─────────────────────────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
  log_error "Ne pas exécuter ce script en tant que root. Utilisez un utilisateur normal."
fi

if ! sudo -v &>/dev/null; then
  log_error "Droits sudo requis pour installer les paquets (apt)."
fi

# ── Paquets Système ───────────────────────────────────────────────────────────
log_step "Installation des paquets système (APT)"
sudo apt update -qq
if ! sudo apt install -y -qq zsh git curl wget unzip fontconfig fzf bat fd-find 2>&1 | tee /tmp/apt_install.log | grep -q "^E:"; then
  log_info "Paquets système installés avec succès"
else
  log_error "Erreur lors de l'installation APT. Voir /tmp/apt_install.log"
fi

# Assurer ~/.local/bin dans le PATH
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# Symlinks pour Ubuntu/Debian (batcat -> bat, fdfind -> fd)
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  log_info "Alias créé : bat -> batcat"
fi
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  log_info "Alias créé : fd -> fdfind"
fi

# ── Outils Externes (Zoxide & Oh My Posh) ───────────────────────────────────
log_step "Installation de Zoxide et Oh My Posh"

# Zoxide
if ! command -v zoxide &>/dev/null; then
  if curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash -s -- -b "$HOME/.local/bin"; then
    log_info "Zoxide installé."
  else
    log_warn "Échec de l'installation de Zoxide (non-bloquant)."
  fi
else
  log_info "Zoxide déjà présent."
fi

# Oh My Posh
if ! command -v oh-my-posh &>/dev/null; then
  if curl -sSfL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"; then
    log_info "Oh My Posh installé."
  else
    log_warn "Échec de l'installation de Oh My Posh (non-bloquant)."
  fi
else
  log_info "Oh My Posh déjà présent."
fi

# Thème Catppuccin
POSH_DIR="$HOME/.poshthemes"
mkdir -p "$POSH_DIR"
THEME_URL="https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/catppuccin_macchiato.omp.json"
THEME_FILE="$POSH_DIR/catppuccin_macchiato.omp.json"

if curl -sSfL "$THEME_URL" -o "$THEME_FILE" && [ -s "$THEME_FILE" ]; then
  log_info "Thème Catppuccin Macchiato téléchargé."
else
  log_warn "Échec du téléchargement du thème. Oh My Posh utilisera le thème par défaut."
  rm -f "$THEME_FILE"
fi

# ── Oh My Zsh & Plugins ─────────────────────────────────────────────────────
log_step "Installation de Oh My Zsh et des plugins"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  if RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" 2>&1; then
    log_info "Oh My Zsh installé."
  else
    log_error "Échec de l'installation de Oh My Zsh."
  fi
else
  log_info "Oh My Zsh déjà présent."
fi

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
mkdir -p "$ZSH_CUSTOM/plugins"

# Plugins essentiels (zsh-autocomplete RETIRÉ pour éviter les conflits)
declare -A PLUGINS=(
  ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
  ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
  ["zsh-completions"]="https://github.com/zsh-users/zsh-completions.git"
  ["zsh-bat"]="https://github.com/fdellwing/zsh-bat.git"
  ["zsh-history-substring-search"]="https://github.com/zsh-users/zsh-history-substring-search.git"
  ["fzf-zsh-plugin"]="https://github.com/unixorn/fzf-zsh-plugin.git"
)

for name in "${!PLUGINS[@]}"; do
  dest="$ZSH_CUSTOM/plugins/$name"
  if [ ! -d "$dest" ]; then
    if git clone --depth 1 -q "${PLUGINS[$name]}" "$dest" 2>&1; then
      log_info "Plugin installé : $name"
    else
      log_warn "Échec de l'installation du plugin : $name"
    fi
  else
    log_info "Plugin déjà présent : $name (mise à jour avec 'git pull' si nécessaire)"
  fi
done

# ── Configuration ~/.zshrc ──────────────────────────────────────────────────
log_step "Génération du fichier ~/.zshrc"

if [ -f "$HOME/.zshrc" ]; then
  BACKUP="$HOME/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
  mv "$HOME/.zshrc" "$BACKUP"
  log_warn "Ancien .zshrc sauvegardé : $BACKUP"
fi

cat > "$HOME/.zshrc" << 'EOF'
# =============================================================================
#  Configuration ZSH (Générée automatiquement - Version améliorée)
# =============================================================================

export PATH="$HOME/.local/bin:$PATH"
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="" # Désactivé car géré par Oh-My-Posh

# ── OPTIMISATION : Lazy Loading ─────────────────────────────────────────────
# Chargement différé pour améliorer les performances de démarrage
skip_global_compinit=1

# ── PRÉ-CHARGEMENT (Completions personnalisées) ─────────────────────────────
fpath+="${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-completions/src"

# ── PLUGINS OH-MY-ZSH ────────────────────────────────────────────────────────
# IMPORTANT : zsh-syntax-highlighting DOIT TOUJOURS ÊTRE LE DERNIER
plugins=(
  git
  zsh-autosuggestions
  zsh-completions
  zsh-bat
  zsh-history-substring-search
  fzf-zsh-plugin
  zsh-syntax-highlighting  # TOUJOURS EN DERNIER !
)

source $ZSH/oh-my-zsh.sh

# ── OUTILS EXTERNES (Init conditionnelle) ────────────────────────────────────
# Oh My Posh
if command -v oh-my-posh &>/dev/null; then
  POSH_THEME="$HOME/.poshthemes/catppuccin_macchiato.omp.json"
  if [ -f "$POSH_THEME" ]; then
    eval "$(oh-my-posh init zsh --config "$POSH_THEME")"
  else
    eval "$(oh-my-posh init zsh)"
  fi
fi

# Zoxide (CD intelligent basé sur l'historique)
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh --cmd cd)"
fi

# ── RACCOURCIS CLAVIER (History Substring Search) ────────────────────────────
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down

# ── FZF: THÈME CATPPUCCIN MACCHIATO ──────────────────────────────────────────
export FZF_DEFAULT_OPTS=" \
--color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 \
--color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 \
--color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796 \
--height=40% --layout=reverse --border"

# Commande FZF avec fallback
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
else
  export FZF_DEFAULT_COMMAND='find . -type f'
fi

# ── OPTIONS ZSH ──────────────────────────────────────────────────────────────
setopt AUTO_CD              # Taper un nom de dossier = cd automatique
setopt CORRECT              # Correction orthographique des commandes
setopt HIST_IGNORE_DUPS     # Pas de doublons dans l'historique
setopt HIST_FIND_NO_DUPS    # Ignore les doublons lors de la recherche
setopt SHARE_HISTORY        # Partage l'historique entre sessions
setopt APPEND_HISTORY       # Ajoute à l'historique au lieu d'écraser

# Historique plus large
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

# ── ALIAS ────────────────────────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# Bat comme pager par défaut (si disponible)
if command -v bat &>/dev/null; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  alias cat='bat --paging=never'
fi

# ── FONCTIONS UTILES ─────────────────────────────────────────────────────────
# Extraction intelligente d'archives
extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2) tar xjf "$1" ;;
      *.tar.gz)  tar xzf "$1" ;;
      *.bz2)     bunzip2 "$1" ;;
      *.rar)     unrar x "$1" ;;
      *.gz)      gunzip "$1" ;;
      *.tar)     tar xf "$1" ;;
      *.tbz2)    tar xjf "$1" ;;
      *.tgz)     tar xzf "$1" ;;
      *.zip)     unzip "$1" ;;
      *.Z)       uncompress "$1" ;;
      *.7z)      7z x "$1" ;;
      *)         echo "'$1' ne peut pas être extrait via extract()" ;;
    esac
  else
    echo "'$1' n'est pas un fichier valide"
  fi
}

# Recherche rapide de processus
psgrep() {
  ps aux | grep -v grep | grep -i -e VSZ -e "$@"
}

# ── MESSAGE D'ACCUEIL ────────────────────────────────────────────────────────
# Affichage d'un message personnalisé (optionnel, peut être commenté)
# echo -e "${BLUE}Bienvenue dans votre shell optimisé ! 🚀${NC}"
EOF

log_info "Fichier .zshrc configuré de manière optimale."

# ── Shell par défaut ────────────────────────────────────────────────────────
log_step "Définition de ZSH comme shell par défaut"
ZSH_PATH="$(command -v zsh)"
if [ "$SHELL" != "$ZSH_PATH" ]; then
  if sudo chsh -s "$ZSH_PATH" "$(whoami)"; then
    log_info "Shell par défaut changé vers ZSH. Reconnexion requise."
  else
    log_warn "Impossible de changer le shell par défaut. Faites-le manuellement avec : chsh -s $(command -v zsh)"
  fi
else
  log_info "ZSH est déjà votre shell par défaut."
fi

# ── Vérifications post-installation ─────────────────────────────────────────
log_step "Vérifications finales"
MISSING_TOOLS=()
for tool in zsh git curl oh-my-posh zoxide bat fd fzf; do
  if ! command -v "$tool" &>/dev/null; then
    MISSING_TOOLS+=("$tool")
  fi
done

if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
  log_info "Tous les outils sont correctement installés ✓"
else
  log_warn "Outils manquants (non-bloquant) : ${MISSING_TOOLS[*]}"
fi

# ── FINALISATION ────────────────────────────────────────────────────────────
echo -e "\n${BOLD}${GREEN}╔════════════════════════════════════════════════════════╗"
echo -e "║  🎉 INSTALLATION TERMINÉE AVEC SUCCÈS !                ║"
echo -e "╚════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${BOLD}${CYAN}📋 Prochaines étapes :${NC}"
echo -e "  1️⃣  Installez une Nerd Font (ex: MesloLGS NF, Fira Code NF)"
echo -e "     👉 https://www.nerdfonts.com/font-downloads"
echo -e "  2️⃣  Activez-la dans les paramètres de votre terminal"
echo -e "  3️⃣  Lancez votre nouveau shell : ${GREEN}exec zsh${NC}"
echo -e "\n${YELLOW}⚠️  Note : Le premier démarrage peut être lent (compilation des completions).${NC}"
echo -e "${YELLOW}    Les démarrages suivants seront beaucoup plus rapides.${NC}\n"