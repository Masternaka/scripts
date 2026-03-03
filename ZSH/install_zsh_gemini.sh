#!/bin/bash

# Arrêter le script en cas d'erreur
set -e

# Vérifier que le script n'est pas lancé en root
if [ "$EUID" -eq 0 ]; then
  echo "❌ Veuillez ne pas exécuter ce script en tant que root. Lancez-le avec votre utilisateur normal."
  exit 1
fi

echo "🔄 Mise à jour des paquets et installation des dépendances..."
sudo apt update
sudo apt install -y curl git wget unzip fontconfig zsh fzf bat

# Création des dossiers locaux si nécessaires
mkdir -p ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"

# Configuration de bat (Debian/Ubuntu installe bat sous le nom 'batcat')
if command -v batcat &> /dev/null; then
    ln -sf /usr/bin/batcat ~/.local/bin/bat
fi

echo "📦 Installation de Zoxide..."
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

echo "📦 Installation de Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "✅ Oh My Zsh est déjà installé."
fi

echo "📦 Installation de Oh My Posh..."
sudo curl -s https://ohmyposh.dev/install.sh | bash -s

echo "🎨 Téléchargement du thème Catppuccin Macchiato..."
mkdir -p ~/.poshthemes
wget -qO ~/.poshthemes/catppuccin_macchiato.omp.json https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/catppuccin_macchiato.omp.json

echo "🔌 Installation des plugins Zsh..."
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# Fonction pour cloner ou mettre à jour un plugin
install_plugin() {
    if [ ! -d "${ZSH_CUSTOM}/plugins/$2" ]; then
        git clone --depth=1 "$1" "${ZSH_CUSTOM}/plugins/$2"
    else
        echo "✅ Le plugin $2 est déjà présent."
    fi
}

install_plugin "https://github.com/zsh-users/zsh-autosuggestions" "zsh-autosuggestions"
install_plugin "https://github.com/zsh-users/zsh-syntax-highlighting.git" "zsh-syntax-highlighting"
install_plugin "https://github.com/marlonrichert/zsh-autocomplete.git" "zsh-autocomplete"
install_plugin "https://github.com/zsh-users/zsh-completions" "zsh-completions"
install_plugin "https://github.com/fdellwing/zsh-bat.git" "zsh-bat"
install_plugin "https://github.com/zsh-users/zsh-history-substring-search" "zsh-history-substring-search"
install_plugin "https://github.com/unixorn/fzf-zsh-plugin.git" "fzf-zsh-plugin"
# Zoxide est géré nativement via un plugin intégré à Oh My Zsh ou via init directement.

echo "⚙️ Configuration du fichier ~/.zshrc..."
# Sauvegarde de l'ancien .zshrc
[ -f ~/.zshrc ] && mv ~/.zshrc ~/.zshrc.bak

cat > ~/.zshrc << 'EOF'
# Chemin vers Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"

# Oh My Posh gère le thème, on désactive celui de OMZ
ZSH_THEME=""

# Définition des plugins
plugins=(
    git
    zsh-completions
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-autocomplete
    zsh-bat
    zsh-history-substring-search
    fzf-zsh-plugin
    zoxide
)

# Chargement de Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Ajout du chemin pour les binaires locaux
export PATH="$HOME/.local/bin:$PATH"

# Configuration des touches pour history-substring-search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Initialisation de Oh My Posh avec le thème
eval "$(oh-my-posh init zsh --config ~/.poshthemes/catppuccin_macchiato.omp.json)"

# Optionnel : réduire l'agressivité de zsh-autocomplete si besoin
# zstyle ':autocomplete:*' delay 0.1
EOF

echo "🔑 Définition de Zsh comme shell par défaut..."
sudo chsh -s $(which zsh) $(whoami)

echo ""
echo "🎉 INSTALLATION TERMINÉE ! 🎉"
echo "👉 Veuillez fermer votre terminal et le rouvrir, ou tapez 'zsh' pour commencer."
echo "⚠️ IMPORTANT : Oh My Posh nécessite une police 'Nerd Font' pour afficher correctement les icônes."
echo "Téléchargez-en une (ex: MesloLGS NF ou FiraCode Nerd Font) sur https://www.nerdfonts.com/ et définissez-la dans les préférences de votre terminal."