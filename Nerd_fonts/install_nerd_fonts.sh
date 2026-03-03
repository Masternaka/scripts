#!/bin/bash

# --------------------------- Explication du script ---------------------------
# Script d'installation des Nerd Fonts (macOS et Linux)
# Polices: JetBrainsMono, CaskaydiaMono, FiraCode, MesloLG
# -----------------------------------------------------------------------------

# ------------------------ Instructions d'utilisation -------------------------
# Il faut rendre ce script exécutable (chmod +x) et l'exécuter depuis le répertoire où il se trouve.
# -----------------------------------------------------------------------------

# chmod +x install_nerd_fonts.sh
# ./install_nerd_fonts.sh

# -----------------------------------------------------------------------------

set -e  # Arrêter le script en cas d'erreur

# Couleurs pour l'affichage
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Détection de l'OS
OS="$(uname -s)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Installation des Nerd Fonts${NC}"
echo -e "${BLUE}========================================${NC}\n"
echo -e "${BLUE}Système détecté: ${OS}${NC}\n"

# Fonction pour installer via Homebrew (macOS et Linux)
install_via_homebrew() {
    # Vérifier si Homebrew est installé
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}⚠️  Homebrew n'est pas installé!${NC}"
        echo -e "${BLUE}Installation de Homebrew en cours...${NC}\n"
        
        # Installer Homebrew
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Ajouter Homebrew au PATH pour la session actuelle
        if [[ "$OS" == "Darwin" ]]; then
            # macOS
            if [[ $(uname -m) == 'arm64' ]]; then
                # Mac M1/M2/M3 (Apple Silicon)
                eval "$(/opt/homebrew/bin/brew shellenv)"
            else
                # Mac Intel
                eval "$(/usr/local/bin/brew shellenv)"
            fi
        else
            # Linux
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
        
        # Vérifier que l'installation a réussi
        if command -v brew &> /dev/null; then
            echo -e "${GREEN}✓ Homebrew installé avec succès${NC}\n"
        else
            echo -e "${RED}❌ Erreur lors de l'installation de Homebrew${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✓ Homebrew détecté${NC}\n"
    fi

    # Ajouter le tap des fonts si nécessaire
    echo -e "${BLUE}Ajout du tap homebrew/cask-fonts...${NC}"
    brew tap homebrew/cask-fonts

    # Liste des Nerd Fonts à installer
    if [[ "$OS" == "Darwin" ]]; then
        # Sur macOS, utiliser les casks
        fonts=(
            "font-jetbrains-mono-nerd-font"
            "font-caskaydia-mono-nerd-font"
            "font-fira-code-nerd-font"
            "font-meslo-lg-nerd-font"
        )
        
        for font in "${fonts[@]}"; do
            echo -e "\n${BLUE}Installation de ${font}...${NC}"
            if brew install --cask "$font"; then
                echo -e "${GREEN}✓ ${font} installé avec succès${NC}"
            else
                echo -e "${RED}❌ Erreur lors de l'installation de ${font}${NC}"
            fi
        done
    else
        # Sur Linux, utiliser les formulas
        fonts=(
            "font-jetbrains-mono-nerd-font"
            "font-caskaydia-mono-nerd-font"
            "font-fira-code-nerd-font"
            "font-meslo-lg-nerd-font"
        )
        
        for font in "${fonts[@]}"; do
            echo -e "\n${BLUE}Installation de ${font}...${NC}"
            if brew install "$font"; then
                echo -e "${GREEN}✓ ${font} installé avec succès${NC}"
            else
                echo -e "${RED}❌ Erreur lors de l'installation de ${font}${NC}"
            fi
        done
    fi
}

# Fonction pour installer manuellement sur Linux
install_manual_linux() {
    echo -e "${BLUE}Installation manuelle des Nerd Fonts sur Linux...${NC}\n"
    
    # Créer le répertoire des fonts
    FONT_DIR="$HOME/.local/share/fonts/NerdFonts"
    mkdir -p "$FONT_DIR"
    
    # URL de base GitHub
    BASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
    
    # Liste des fonts à télécharger
    fonts=(
        "JetBrainsMono"
        "CascadiaMono"
        "FiraCode"
        "Meslo"
    )
    
    # Télécharger et installer chaque font
    for font in "${fonts[@]}"; do
        echo -e "${BLUE}Téléchargement de ${font}...${NC}"
        
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        
        if curl -fLo "${font}.zip" "${BASE_URL}/${font}.zip"; then
            echo -e "${BLUE}Extraction de ${font}...${NC}"
            unzip -q "${font}.zip" -d "${font}"
            
            # Copier les fichiers .ttf et .otf
            find "${font}" -name "*.ttf" -o -name "*.otf" | while read -r file; do
                cp "$file" "$FONT_DIR/"
            done
            
            echo -e "${GREEN}✓ ${font} installé avec succès${NC}"
        else
            echo -e "${RED}❌ Erreur lors du téléchargement de ${font}${NC}"
        fi
        
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
    done
    
    # Mettre à jour le cache des fonts
    echo -e "\n${BLUE}Mise à jour du cache des polices...${NC}"
    fc-cache -fv "$FONT_DIR"
    
    echo -e "${GREEN}✓ Cache mis à jour${NC}"
}

# Installation selon l'OS
if [[ "$OS" == "Darwin" ]]; then
    # macOS - toujours utiliser Homebrew
    install_via_homebrew
elif [[ "$OS" == "Linux" ]]; then
    # Linux - proposer le choix
    if command -v brew &> /dev/null; then
        echo -e "${YELLOW}Homebrew est déjà installé.${NC}"
        echo -e "${BLUE}Utilisation de Homebrew pour l'installation...${NC}\n"
        install_via_homebrew
    else
        echo -e "${YELLOW}Choix de la méthode d'installation:${NC}"
        echo -e "1) Installer via Homebrew (recommandé, mais plus long)"
        echo -e "2) Installation manuelle (plus rapide)"
        echo -e ""
        read -p "Votre choix (1 ou 2, défaut=2): " choice
        choice=${choice:-2}
        
        if [[ "$choice" == "1" ]]; then
            install_via_homebrew
        else
            install_manual_linux
        fi
    fi
else
    echo -e "${RED}❌ Système d'exploitation non supporté: ${OS}${NC}"
    exit 1
fi

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Installation terminée!${NC}"
echo -e "${BLUE}========================================${NC}\n"

if [[ "$OS" == "Darwin" ]]; then
    echo -e "Les polices sont maintenant disponibles dans vos applications."
    echo -e "Vous devrez peut-être redémarrer certaines applications pour voir les nouvelles polices.\n"
else
    echo -e "Les polices sont installées dans: ${FONT_DIR}"
    echo -e "Vous devrez peut-être redémarrer vos applications ou votre session pour voir les nouvelles polices.\n"
fi