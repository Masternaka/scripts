#!/bin/bash
# =============================================================================
#  Script d'installation et configuration de ZSH
#  Compatible : Ubuntu, Debian, Linux Mint
#  Auteur     : Claude (Anthropic)
# =============================================================================

set -e

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Variables ─────────────────────────────────────────────────────────────────
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PLUGINS_DIR="$ZSH_CUSTOM/plugins"
OMP_THEME="catppuccin_macchiato"
OMP_THEMES_DIR="$HOME/.cache/oh-my-posh/themes"
OMP_CONFIG="$OMP_THEMES_DIR/${OMP_THEME}.omp.json"

# ── Helpers ───────────────────────────────────────────────────────────────────
log_step()  { echo -e "\n${BOLD}${BLUE}══ $1 ${NC}"; }
log_info()  { echo -e "  ${GREEN}✔${NC}  $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC}  $1"; }
log_error() { echo -e "  ${RED}✘${NC}  $1"; }
log_title() {
  echo -e "${BOLD}${CYAN}"
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║       ZSH + Oh My Zsh + Oh My Posh Installer        ║"
  echo "  ║       Ubuntu · Debian · Linux Mint                   ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

# ── Vérifications préliminaires ───────────────────────────────────────────────
check_not_root() {
  if [ "$EUID" -eq 0 ]; then
    log_error "Ne pas exécuter ce script en tant que root (sudo)."
    log_error "Lancez-le en tant qu'utilisateur normal : bash install_zsh.sh"
    exit 1
  fi
}

check_os() {
  if [ ! -f /etc/os-release ]; then
    log_error "Système d'exploitation non reconnu."
    exit 1
  fi
  source /etc/os-release
  case "$ID" in
    ubuntu|debian|linuxmint|pop) ;;
    *)
      log_warn "OS '$ID' non officiellement supporté. Tentative quand même..."
      ;;
  esac
  log_info "OS détecté : ${PRETTY_NAME}"
}

check_sudo() {
  if ! sudo -v &>/dev/null; then
    log_error "Droits sudo requis pour installer les paquets système."
    exit 1
  fi
}

# ── Paquets système ───────────────────────────────────────────────────────────
install_packages() {
  log_step "Installation des paquets système"
  sudo apt update -qq
  sudo apt install -y \
    zsh \
    git \
    curl \
    wget \
    unzip \
    bat \
    fzf \
    fd-find \
    fontconfig \
    2>/dev/null || true

  # Sur Ubuntu/Debian, bat s'installe sous le nom 'batcat'
  # Création d'un lien symbolique vers ~/.local/bin/bat
  mkdir -p "$HOME/.local/bin"
  if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    log_info "Lien symbolique bat → batcat créé dans ~/.local/bin"
  fi

  # Idem pour fd (fd-find → fd)
  if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    log_info "Lien symbolique fd → fdfind créé dans ~/.local/bin"
  fi

  log_info "Paquets système installés avec succès"
}

# ── Zoxide ────────────────────────────────────────────────────────────────────
install_zoxide() {
  log_step "Installation de Zoxide"
  if command -v zoxide &>/dev/null; then
    log_warn "Zoxide déjà installé ($(zoxide --version)). Mise à jour..."
  fi
  curl -sSf https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
  log_info "Zoxide installé dans ~/.local/bin"
}

# ── Oh My Zsh ─────────────────────────────────────────────────────────────────
install_oh_my_zsh() {
  log_step "Installation de Oh My Zsh"
  if [ -d "$HOME/.oh-my-zsh" ]; then
    log_warn "Oh My Zsh déjà installé. Mise à jour..."
    git -C "$HOME/.oh-my-zsh" pull --quiet
    return
  fi
  RUNZSH=no CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  log_info "Oh My Zsh installé"
}

# ── Oh My Posh ────────────────────────────────────────────────────────────────
install_oh_my_posh() {
  log_step "Installation de Oh My Posh"
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
  log_info "Oh My Posh installé dans ~/.local/bin"

  log_step "Téléchargement du thème $OMP_THEME"
  mkdir -p "$OMP_THEMES_DIR"
  curl -fsSL \
    "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/${OMP_THEME}.omp.json" \
    -o "$OMP_CONFIG"
  log_info "Thème $OMP_THEME téléchargé dans $OMP_THEMES_DIR"
}

# ── Plugins ZSH ───────────────────────────────────────────────────────────────
clone_or_update_plugin() {
  local name="$1"
  local repo="$2"
  local dest="$PLUGINS_DIR/$name"

  if [ -d "$dest/.git" ]; then
    log_warn "Plugin '$name' déjà présent. Mise à jour..."
    git -C "$dest" pull --quiet
  else
    git clone --depth=1 "https://github.com/$repo" "$dest"
    log_info "Plugin '$name' installé"
  fi
}

install_plugins() {
  log_step "Installation des plugins ZSH"
  mkdir -p "$PLUGINS_DIR"

  clone_or_update_plugin "zsh-autosuggestions"        "zsh-users/zsh-autosuggestions"
  clone_or_update_plugin "zsh-syntax-highlighting"    "zsh-users/zsh-syntax-highlighting"
  clone_or_update_plugin "zsh-autocomplete"           "marlonrichert/zsh-autocomplete"
  clone_or_update_plugin "zsh-completions"            "zsh-users/zsh-completions"
  clone_or_update_plugin "zsh-bat"                    "fdellwing/zsh-bat"
  clone_or_update_plugin "zsh-history-substring-search" "zsh-users/zsh-history-substring-search"
  clone_or_update_plugin "fzf-zsh-plugin"             "unixorn/fzf-zsh-plugin"

  log_info "Tous les plugins installés"
}

# ── Configuration .zshrc ──────────────────────────────────────────────────────
configure_zshrc() {
  log_step "Génération du fichier .zshrc"

  # Sauvegarde de l'ancien .zshrc
  if [ -f "$HOME/.zshrc" ]; then
    local backup="$HOME/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$HOME/.zshrc" "$backup"
    log_warn "Ancien .zshrc sauvegardé → $backup"
  fi

  cat > "$HOME/.zshrc" << 'EOF'
# =============================================================================
#  ~/.zshrc — Configuration ZSH
#  Généré par install_zsh.sh
# =============================================================================

# ── Oh My Zsh ─────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"

# Désactivation du thème Oh My Zsh (Oh My Posh gère le prompt)
ZSH_THEME=""

# ── fpath : zsh-completions doit être ajouté avant compinit ──────────────────
fpath+="${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-completions/src"

# ── Configuration zsh-autocomplete ───────────────────────────────────────────
# Doit être chargé AVANT oh-my-zsh
source "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"

# ── Plugins Oh My Zsh ─────────────────────────────────────────────────────────
plugins=(
  git
  sudo
  copypath
  dirhistory
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  zsh-bat
  zsh-history-substring-search
  fzf-zsh-plugin
)

source "$ZSH/oh-my-zsh.sh"

# ── PATH ─────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── Oh My Posh ───────────────────────────────────────────────────────────────
if command -v oh-my-posh &>/dev/null; then
  eval "$(oh-my-posh init zsh --config "$HOME/.cache/oh-my-posh/themes/catppuccin_macchiato.omp.json")"
fi

# ── Zoxide ───────────────────────────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh --cmd cd)"
fi

# ── FZF ──────────────────────────────────────────────────────────────────────
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS="
  --height=40%
  --layout=reverse
  --border=rounded
  --color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796
  --color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6
  --color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git 2>/dev/null || find . -type f'

# ── Autosuggestions ───────────────────────────────────────────────────────────
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6e738d,bold"
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# ── History substring search — Raccourcis clavier ────────────────────────────
bindkey '^[[A' history-substring-search-up   # Flèche haut
bindkey '^[[B' history-substring-search-down # Flèche bas
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND="fg=green,bold"
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND="fg=red,bold"

# ── Historique ────────────────────────────────────────────────────────────────
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt HIST_VERIFY

# ── Options ZSH ───────────────────────────────────────────────────────────────
setopt AUTO_CD           # cd sans 'cd'
setopt AUTO_PUSHD        # cd pousse vers la pile
setopt PUSHD_IGNORE_DUPS
setopt CORRECT           # Correction orthographique
setopt COMPLETE_ALIASES

# ── Alias utiles ─────────────────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip --color=auto'

# Utilise bat pour la coloration de man
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFF_OPT="-c"

# ── Variables d'environnement ─────────────────────────────────────────────────
export EDITOR='nano'
export LANG='fr_FR.UTF-8'
export LC_ALL='fr_FR.UTF-8'
EOF

  log_info "Fichier .zshrc généré"
}

# ── Shell par défaut ──────────────────────────────────────────────────────────
set_default_shell() {
  log_step "Configuration de ZSH comme shell par défaut"
  local zsh_path
  zsh_path="$(command -v zsh)"

  # S'assurer que zsh est dans /etc/shells
  if ! grep -q "$zsh_path" /etc/shells; then
    echo "$zsh_path" | sudo tee -a /etc/shells > /dev/null
    log_info "$zsh_path ajouté à /etc/shells"
  fi

  if [ "$SHELL" = "$zsh_path" ]; then
    log_warn "ZSH est déjà le shell par défaut."
    return
  fi

  chsh -s "$zsh_path"
  log_info "Shell par défaut changé en $zsh_path"
}

# ── Résumé final ──────────────────────────────────────────────────────────────
print_summary() {
  echo -e "\n${BOLD}${GREEN}"
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║   ✅  Installation terminée avec succès !            ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "${BOLD}  Ce qui a été installé :${NC}"
  echo -e "  • ${CYAN}ZSH${NC}                       — Shell principal"
  echo -e "  • ${CYAN}Oh My Zsh${NC}                 — Framework ZSH"
  echo -e "  • ${CYAN}Oh My Posh${NC}                — Prompt personnalisé"
  echo -e "  • ${CYAN}Thème catppuccin_macchiato${NC} — Thème Oh My Posh"
  echo -e "  • ${CYAN}zsh-autosuggestions${NC}       — Suggestions automatiques"
  echo -e "  • ${CYAN}zsh-syntax-highlighting${NC}   — Coloration syntaxique"
  echo -e "  • ${CYAN}zsh-autocomplete${NC}          — Autocomplétion avancée"
  echo -e "  • ${CYAN}zsh-completions${NC}           — Complétions supplémentaires"
  echo -e "  • ${CYAN}zsh-bat${NC}                   — Remplacement de cat par bat"
  echo -e "  • ${CYAN}zsh-history-substring-search${NC} — Recherche dans l'historique"
  echo -e "  • ${CYAN}fzf-zsh-plugin${NC}            — Intégration FZF"
  echo -e "  • ${CYAN}Zoxide${NC}                    — Navigation cd intelligente"
  echo ""
  echo -e "${BOLD}${YELLOW}  ⚠  Action requise :${NC}"
  echo -e "  Pour que le prompt Oh My Posh s'affiche correctement,"
  echo -e "  installez une ${BOLD}Nerd Font${NC} et configurez votre terminal pour l'utiliser."
  echo -e "  Recommandation : ${CYAN}https://www.nerdfonts.com/font-downloads${NC}"
  echo -e "  (ex: JetBrainsMono Nerd Font, FiraCode Nerd Font, Meslo Nerd Font)"
  echo ""
  echo -e "${BOLD}  ▶  Prochaine étape :${NC}"
  echo -e "  Fermez et rouvrez votre terminal, ou exécutez : ${CYAN}exec zsh${NC}"
  echo ""
}

# ── Point d'entrée ────────────────────────────────────────────────────────────
main() {
  log_title

  log_step "Vérifications préliminaires"
  check_not_root
  check_os
  check_sudo

  install_packages
  install_zoxide
  install_oh_my_zsh
  install_oh_my_posh
  install_plugins
  configure_zshrc
  set_default_shell

  print_summary
}

main "$@"