#!/usr/bin/env bash
set -euo pipefail

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

# chmod +x install_zsh.sh
# ./install_zsh.sh

# -----------------------------------------------------------------------------

# ------------------------- Recommandations -----------------------------------
# - Avant d'exécuter ce scripr, il est recommandé de faire l'installation du script "install_fonts.sh" pour installer les fonts
#   nécessaires à l'affichage des icônes dans le thème Oh My Posh.
# -----------------------------------------------------------------------------
 

log() { printf "\n\033[1;32m[+] %s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33m[!] %s\033[0m\n" "$*"; }
err() { printf "\n\033[1;31m[✖] %s\033[0m\n" "$*"; }
exists() { command -v "$1" >/dev/null 2>&1; }

# ---------- Vérif distribution ----------
if [ -r /etc/os-release ]; then
  . /etc/os-release
else
  err "Impossible d'identifier la distribution (pas de /etc/os-release)."
  exit 1
fi

# ---------- Pré-requis ----------
log "Mise à jour de l'index APT et installation des prérequis…"
sudo apt update -y
sudo apt install -y --no-install-recommends \
  zsh git curl wget ca-certificates unzip || true

# Assure ~/.local/bin dans PATH (pour oh-my-posh, zoxide fallback, alias bat)
ensure_local_bin_path() {
  if ! grep -q 'export PATH="$HOME/.local/bin' "$HOME/.profile" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
  fi
  if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    export PATH="$HOME/.local/bin:$PATH"
  fi
}

ensure_local_bin_path

# ---------- Installer fzf, bat/batcat, zoxide AVANT les plugins ----------
# fzf
if ! exists fzf; then
  log "Installation de fzf…"
  sudo apt-get install -y fzf || warn "Impossible d'installer fzf via APT."
else
  log "fzf déjà installé."
fi

# bat / batcat
if ! exists bat && ! exists batcat; then
  log "Installation de bat (ou batcat selon la distribution)…"
  sudo apt-get install -y bat || sudo apt-get install -y batcat || warn "Impossible d'installer bat/batcat."
fi

# si batcat est présent mais pas bat, créer un alias 'bat' (~/.local/bin/bat)
if ! exists bat && exists batcat; then
  log "Création d'un alias 'bat' vers 'batcat' dans ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  ensure_local_bin_path
fi

# zoxide (APT si possible, sinon script officiel)
if ! exists zoxide; then
  log "Installation de zoxide…"
  if ! sudo apt-get install -y zoxide; then
    warn "zoxide indisponible via APT, installation via script officiel…"
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash -s -- -b "$HOME/.local/bin"
    ensure_local_bin_path
  fi
else
  log "zoxide déjà installé."
fi

# ---------- Installer Oh My Zsh ----------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  log "Installation de Oh My Zsh (mode non interactif)…"
  export RUNZSH=no
  export CHSH=no
  export KEEP_ZSHRC=yes
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  log "Oh My Zsh déjà installé."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM/plugins" "$ZSH_CUSTOM/themes"

# ---------- Installer Oh My Posh + thème Catppuccin Macchiato ----------
if ! exists oh-my-posh; then
  log "Installation de Oh My Posh dans ~/.local/bin…"
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
  ensure_local_bin_path
else
  log "Oh My Posh déjà installé."
fi

THEME_NAME="catppuccin_macchiato"  # orthographe officielle (Catppuccin)
POSH_DIR="$HOME/.poshthemes"
POSH_THEME="$POSH_DIR/${THEME_NAME}.omp.json"
if [ ! -f "$POSH_THEME" ]; then
  log "Téléchargement du thème Oh My Posh: ${THEME_NAME}…"
  mkdir -p "$POSH_DIR"
  curl -fsSL "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/${THEME_NAME}.omp.json" -o "$POSH_THEME"
  chmod 644 "$POSH_THEME"
else
  log "Thème ${THEME_NAME} déjà présent."
fi

# ---------- Plugins Zsh (installation via git) ----------
declare -A PLUG_URLS=(
  ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
  ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
  ["zsh-autocomplete"]="https://github.com/marlonrichert/zsh-autocomplete.git"
  ["zsh-completions"]="https://github.com/zsh-users/zsh-completions.git"
  ["fzf-zsh-plugin"]="https://github.com/unixorn/fzf-zsh-plugin.git"
)
for name in "${!PLUG_URLS[@]}"; do
  target="$ZSH_CUSTOM/plugins/$name"
  if [ -d "$target/.git" ]; then
    log "Mise à jour du plugin $name…"
    git -C "$target" pull --ff-only || true
  elif [ -d "$target" ]; then
    log "Plugin $name déjà présent."
  else
    log "Installation du plugin $name…"
    git clone --depth 1 "${PLUG_URLS[$name]}" "$target"
  fi
done

# ---------- Construire dynamiquement la liste des plugins ----------
# Toujours utiles :
PLUGIN_LIST=(git)

# Ajouts indépendants
PLUGIN_LIST+=(zsh-autosuggestions zsh-autocomplete zsh-completions)

# history-substring-search (plugin natif Oh My Zsh)
PLUGIN_LIST+=(history-substring-search)

# fzf: n'ajouter le plugin que si la commande existe
if exists fzf; then
  PLUGIN_LIST+=(fzf-zsh-plugin)
else
  warn "fzf non détecté : plugin fzf-zsh-plugin non ajouté."
fi

# bat: utiliser le plugin 'bat' d'Oh My Zsh seulement si bat/batcat est disponible
if exists bat || exists batcat; then
  PLUGIN_LIST+=(bat)
else
  warn "bat/batcat non détecté : plugin 'bat' non ajouté."
fi

# NOTE: zoxide n'a pas de plugin Oh My Zsh officiel; on ajoute un bloc d'init séparé (si la commande existe)

# zsh-syntax-highlighting doit être LE DERNIER
PLUGIN_LIST+=(zsh-syntax-highlighting)

# ---------- Sauvegarde et mise à jour de ~/.zshrc ----------
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
  cp "$ZSHRC" "${ZSHRC}.bak.$(date +%Y%m%d-%H%M%S)"
  log "Sauvegarde de .zshrc -> ${ZSHRC}.bak.*"
fi
touch "$ZSHRC"

# Assurer PATH local/bin
if ! grep -q 'export PATH="$HOME/.local/bin' "$ZSHRC"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZSHRC"
fi

# Injecter Oh My Zsh + plugins (liste dynamique)
if grep -q 'oh-my-zsh.sh' "$ZSHRC"; then
  warn "Mise à jour de la liste des plugins dans .zshrc…"
  awk -v newlist="$(printf "%s " "${PLUGIN_LIST[@]}")" '
    BEGIN {inside=0}
    /plugins *= *\(/ {
      print "plugins=(";
      n=split(newlist, a, " ");
      for (i=1; i<=n; i++) if (a[i]!="") print "  " a[i];
      print ")";
      inside=1; next
    }
    inside && /\)/ {inside=0; next}
    !inside {print}
  ' "$ZSHRC" > "${ZSHRC}.tmp" && mv "${ZSHRC}.tmp" "$ZSHRC"
else
  cat >> "$ZSHRC" <<EOF

# --- Oh My Zsh ---
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"  # sera masqué par Oh My Posh ci-dessous
plugins=(
$(for p in "${PLUGIN_LIST[@]}"; do echo "  $p"; done)
)
source "\$ZSH/oh-my-zsh.sh"
EOF
fi

# Keybindings pour history-substring-search
if ! grep -q 'history-substring-search-up' "$ZSHRC"; then
  cat >> "$ZSHRC" <<'EOF'

# --- Keybindings pour history-substring-search ---
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OA' history-substring-search-up
bindkey '^[OB' history-substring-search-down
EOF
fi

# zoxide init (uniquement si présent)
if exists zoxide && ! grep -q 'zoxide init zsh' "$ZSHRC"; then
  cat >> "$ZSHRC" <<'EOF'

# --- zoxide ---
eval "$(zoxide init zsh)"
EOF
fi

# Oh My Posh (uniquement si présent)
if exists oh-my-posh && ! grep -q 'oh-my-posh init zsh' "$ZSHRC"; then
  cat >> "$ZSHRC" <<EOF

# --- Oh My Posh (thème: ${THEME_NAME}) ---
eval "\$(oh-my-posh init zsh --config '$POSH_THEME')"
EOF
fi

# ---------- Définir Zsh comme shell par défaut ----------
if [ "$SHELL" != "$(command -v zsh)" ]; then
  log "Définition de Zsh comme shell par défaut…"
  chsh -s "$(command -v zsh)"
else
  log "Zsh est déjà le shell par défaut."
fi

# ---------- Fin ----------
log "Installation et configuration terminées 🎉"
echo
echo "• Ouvrez un nouveau terminal (ou exécutez: exec zsh) pour appliquer la configuration."
echo "• Pour les icônes Oh My Posh, installez une Nerd Font (ex.: Caskaydia Cove Nerd Font)."
``