#!/bin/bash
set -euo pipefail

###############################################################################
# Script d'installation automatisée des applications Flatpak
# Compatible : Debian / Ubuntu / Linux Mint
# Bureaux    : GNOME / KDE Plasma / Cinnamon / XFCE / MATE
#
# Utilisation:
#   sudo ./installation_flatpak_debian_base.sh [--help] [--dry-run] [--list]
#
# Options:
#   --help    : Affiche l'aide et quitte
#   --dry-run : Simule les installations sans effectuer de modifications
#   --list    : Affiche la liste des applications qui seraient installées
###############################################################################

# Couleurs
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"

# Options
DRY_RUN=false
SHOW_LIST=false
INTERRUPTED=false
FLATHUB_NEWLY_ADDED=false

# Fichier de log
LOG_FILE="${LOG_FILE:-/var/log/flatpak_install_$(date +%Y%m%d_%H%M%S).log}"

# Variables détectées automatiquement
DISTRO_ID=""
DISTRO_NAME=""
DESKTOP_ENV=""

###############################################################################
# Fonctions utilitaires
###############################################################################

log() {
    echo -e "$@" | tee -a "$LOG_FILE"
}

show_help() {
    echo -e "${GREEN}=== Aide du script d'installation Flatpak ===${RESET}"
    echo ""
    echo "Installe automatiquement des applications Flatpak."
    echo "Compatible : Debian, Ubuntu, Linux Mint"
    echo "Bureaux    : GNOME, KDE Plasma, Cinnamon, XFCE, MATE"
    echo ""
    echo "UTILISATION:"
    echo "  sudo ./installation_flatpak_debian_base.sh [options]"
    echo ""
    echo "OPTIONS:"
    echo "  --help      Affiche cette aide"
    echo "  --dry-run   Simule sans effectuer de modifications"
    echo "  --list      Affiche les applications qui seraient installées"
    echo ""
    echo "APPLICATIONS INSTALLÉES:"
    echo "  - Bottles   : Gestionnaire de bouteilles Wine"
    echo "  - Warehouse : Gestionnaire d'applications Flatpak"
    echo "  - Flatseal  : Gestionnaire de permissions Flatpak"
    echo "  - FlatSweep : Nettoyeur de données Flatpak"
    echo "  - Bazaar    : Gestionnaire de paquets Flatpak"
}

cleanup_on_exit() {
    local exit_code=$?
    if [ "$INTERRUPTED" = true ]; then
        log "${RED}Installation interrompue par l'utilisateur.${RESET}"
    elif [ $exit_code -ne 0 ]; then
        log "${RED}Le script s'est terminé avec une erreur (code: $exit_code).${RESET}"
    fi
}

handle_interrupt() {
    INTERRUPTED=true
    log ""
    log "${RED}Signal d'interruption reçu.${RESET}"
    exit 130
}

confirm_installation() {
    if [ "$DRY_RUN" = false ]; then
        log "${YELLOW}Continuer avec l'installation des applications Flatpak ? (y/N)${RESET}"
        read -r -s -n 1 -p "> " response
        echo
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log "${YELLOW}Installation annulée par l'utilisateur.${RESET}"
            exit 0
        fi
    fi
}

###############################################################################
# Détection de la distribution et du bureau
###############################################################################

detect_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_NAME="${NAME:-Unknown}"
    else
        DISTRO_ID="unknown"
        DISTRO_NAME="Unknown"
    fi

    log "${BLUE}🐧 Distribution détectée : ${DISTRO_NAME} (${DISTRO_ID})${RESET}"

    case "$DISTRO_ID" in
        debian|ubuntu|linuxmint|pop|elementary|zorin)
            ;;
        *)
            log "${YELLOW}⚠ Distribution '${DISTRO_NAME}' non testée. Le script peut fonctionner mais n'est pas garanti.${RESET}"
            ;;
    esac
}

detect_desktop() {
    # XDG_CURRENT_DESKTOP est la plus fiable, DESKTOP_SESSION en fallback
    local raw_de="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-unknown}}"
    DESKTOP_ENV=$(echo "$raw_de" | tr '[:upper:]' '[:lower:]')

    # Normalisation
    case "$DESKTOP_ENV" in
        *gnome*)         DESKTOP_ENV="gnome"    ;;
        *kde*|*plasma*)  DESKTOP_ENV="kde"      ;;
        *cinnamon*)      DESKTOP_ENV="cinnamon" ;;
        *xfce*)          DESKTOP_ENV="xfce"     ;;
        *mate*)          DESKTOP_ENV="mate"     ;;
        *lxqt*)          DESKTOP_ENV="lxqt"     ;;
        *budgie*)        DESKTOP_ENV="budgie"   ;;
        *)               DESKTOP_ENV="unknown"  ;;
    esac

    # Linux Mint utilise Cinnamon par défaut
    if [ "$DISTRO_ID" = "linuxmint" ] && [ "$DESKTOP_ENV" = "unknown" ]; then
        DESKTOP_ENV="cinnamon"
    fi

    log "${BLUE}🖥  Bureau détecté : ${DESKTOP_ENV}${RESET}"
}

###############################################################################
# Vérifications système
###############################################################################

check_network() {
    log "${BLUE}🌐 Vérification de la connexion réseau...${RESET}"
    if ! curl -s --max-time 5 https://flathub.org > /dev/null; then
        log "${RED}❌ Impossible de joindre flathub.org. Vérifiez votre connexion réseau.${RESET}"
        exit 1
    fi
    log "${GREEN}✓ Connexion réseau OK${RESET}"
}

check_flatpak_installed() {
    if ! command -v flatpak &> /dev/null; then
        log "${RED}❌ Flatpak n'est pas installé. Installez-le avec :${RESET}"
        log "${YELLOW}   sudo apt install flatpak${RESET}"
        exit 1
    fi
    log "${GREEN}✓ Flatpak est installé ($(flatpak --version))${RESET}"
}

###############################################################################
# Intégration bureau (plugin selon DE détecté)
###############################################################################

install_package_if_missing() {
    local pkg="$1"
    if dpkg -l "$pkg" &>/dev/null; then
        log "${GREEN}✓ $pkg déjà installé${RESET}"
    else
        log "${BLUE}➕ Installation de $pkg...${RESET}"
        if [ "$DRY_RUN" = false ]; then
            apt-get install -y "$pkg" 2>&1 | tee -a "$LOG_FILE"
            log "${GREEN}✓ $pkg installé${RESET}"
        else
            log "DRY-RUN: apt-get install -y $pkg"
        fi
    fi
}

setup_desktop_integration() {
    log ""
    log "${BLUE}🔌 Configuration de l'intégration bureau (${DESKTOP_ENV})...${RESET}"

    case "$DESKTOP_ENV" in

        gnome|budgie|unity)
            # GNOME Software nécessite un plugin dédié pour Flatpak
            install_package_if_missing "gnome-software-plugin-flatpak"
            ;;

        kde)
            # KDE Discover nécessite son backend Flatpak
            install_package_if_missing "plasma-discover-backend-flatpak"
            ;;

        cinnamon)
            if [ "$DISTRO_ID" = "linuxmint" ]; then
                # mintinstall gère Flatpak nativement sur Linux Mint
                log "${GREEN}✓ Linux Mint : le Gestionnaire de logiciels (mintinstall) supporte Flatpak nativement${RESET}"
                log "${CYAN}  → Les apps seront visibles dans Menu > Gestionnaire de logiciels${RESET}"
            else
                # Cinnamon sur Ubuntu/Debian : utiliser gnome-software
                install_package_if_missing "gnome-software-plugin-flatpak"
            fi
            ;;

        xfce|mate|lxqt)
            # Pas de plugin natif dédié, gnome-software est la meilleure option
            log "${CYAN}  → Bureau ${DESKTOP_ENV} : installation du plugin GNOME Software${RESET}"
            install_package_if_missing "gnome-software-plugin-flatpak"
            ;;

        *)
            log "${YELLOW}⚠ Bureau non reconnu ('${DESKTOP_ENV}'). Aucun plugin installé automatiquement.${RESET}"
            log "${CYAN}  → Vous pourrez gérer vos apps Flatpak via le terminal ou Warehouse.${RESET}"
            ;;
    esac
}

setup_flathub_remote() {
    log ""
    log "${BLUE}🔧 Vérification du remote Flathub...${RESET}"
    if flatpak remotes --columns=name | grep -qx "flathub"; then
        log "${GREEN}✓ Remote Flathub déjà configuré${RESET}"
    else
        log "${BLUE}➕ Ajout du remote Flathub...${RESET}"
        if [ "$DRY_RUN" = false ]; then
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>&1 | tee -a "$LOG_FILE"
            FLATHUB_NEWLY_ADDED=true
            log "${GREEN}✓ Remote Flathub ajouté${RESET}"
        else
            log "DRY-RUN: flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
        fi
    fi
}

###############################################################################
# Applications à installer
###############################################################################

applications=(
    "com.usebottles.bottles:Bottles - Gestionnaire de bouteilles Wine"
    #"org.dupot.easyflatpak:EasyFlatpak - Interface graphique Flatpak"
    "io.github.flattool.Warehouse:Warehouse - Gestionnaire d'applications Flatpak"
    "com.github.tchx84.Flatseal:Flatseal - Gestionnaire de permissions Flatpak"
    "io.github.giantpinkrobots.flatsweep:FlatSweep - Nettoyeur de données Flatpak"
    "io.github.kolunmi.Bazaar:Bazaar - Gestionnaire de paquets Flatpak"
    #"io.github.dvlv.boxbuddyrs:Box Buddy - Gestionnaire de paquets Flatpak"
    #"it.mijorus.gearlever:Gearlever - Gestionnaire de paquets Flatpak"
)

show_applications_list() {
    echo -e "${GREEN}=== Applications Flatpak qui seront installées ===${RESET}"
    echo ""
    for app_info in "${applications[@]}"; do
        app_id="${app_info%%:*}"
        app_desc="${app_info##*:}"
        echo -e "${BLUE}•${RESET} $app_desc"
        echo -e "  ${YELLOW}ID:${RESET} $app_id"
        echo ""
    done
}

###############################################################################
# Installation des applications
###############################################################################

install_flatpak_with_retry() {
    local app="$1"
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if [ "$DRY_RUN" = false ]; then
            if flatpak install -y flathub "$app" 2>&1 | tee -a "$LOG_FILE"; then
                return 0
            else
                attempt=$((attempt + 1))
                if [ $attempt -le $max_attempts ]; then
                    log "${YELLOW}⟳ Nouvelle tentative dans 5 secondes... ($attempt/$max_attempts)${RESET}"
                    sleep 5
                fi
            fi
        else
            log "DRY-RUN: flatpak install -y flathub $app"
            return 0
        fi
    done

    return 1
}

install_applications() {
    local total_apps=${#applications[@]}
    local current_app=0
    local failed_apps=()
    local success_count=0

    log ""
    log "${GREEN}=== Installation des applications Flatpak ===${RESET}"
    log ""

    for app_info in "${applications[@]}"; do
        current_app=$((current_app + 1))
        app_id="${app_info%%:*}"
        app_desc="${app_info##*:}"

        log "${GREEN}[$current_app/$total_apps] $app_desc${RESET}"

        # Détection fiable via flatpak info (méthode officielle)
        if flatpak info "$app_id" &>/dev/null; then
            log "${YELLOW}  → Déjà installé, ignoré.${RESET}"
            success_count=$((success_count + 1))
        else
            log "  → Installation de $app_id..."
            if install_flatpak_with_retry "$app_id"; then
                log "${GREEN}  ✓ Installé avec succès${RESET}"
                success_count=$((success_count + 1))
            else
                failed_apps+=("$app_id")
                log "${RED}  ✗ Échec de l'installation${RESET}"
            fi
        fi
        log ""
    done

    # Rapport final
    log "${GREEN}=== Résumé ===${RESET}"
    log "Succès : $success_count / $total_apps"

    if [ ${#failed_apps[@]} -gt 0 ]; then
        log "${RED}Échecs : ${failed_apps[*]}${RESET}"
    fi

    if [ "$DRY_RUN" = false ]; then
        log "${GREEN}✅ Installation terminée.${RESET}"
    else
        log "${YELLOW}🔍 Mode simulation terminé (aucune modification effectuée).${RESET}"
    fi
}

cleanup_cache() {
    log ""
    if [ "$DRY_RUN" = false ]; then
        log "${BLUE}🧹 Nettoyage des paquets Flatpak inutilisés...${RESET}"
        if flatpak uninstall --unused -y 2>&1 | tee -a "$LOG_FILE"; then
            log "${GREEN}✓ Nettoyage terminé${RESET}"
        else
            log "${YELLOW}⚠ Aucun paquet inutilisé à nettoyer${RESET}"
        fi
    else
        log "DRY-RUN: flatpak uninstall --unused -y"
    fi
}

# Avertissement redémarrage adapté selon le bureau
warn_if_restart_needed() {
    if [ "$FLATHUB_NEWLY_ADDED" = true ] && [ "$DRY_RUN" = false ]; then

        local de_msg=""
        case "$DESKTOP_ENV" in
            gnome|budgie) de_msg="GNOME Logiciels" ;;
            kde)          de_msg="KDE Discover" ;;
            cinnamon)     de_msg="le Gestionnaire de logiciels" ;;
            xfce|mate)    de_msg="GNOME Logiciels" ;;
            *)            de_msg="votre gestionnaire de logiciels" ;;
        esac

        log ""
        log "${YELLOW}╔══════════════════════════════════════════════════════════╗${RESET}"
        log "${YELLOW}║  ⚠  REDÉMARRAGE DE SESSION RECOMMANDÉ                   ║${RESET}"
        log "${YELLOW}║                                                          ║${RESET}"
        log "${YELLOW}║  Flathub vient d'être ajouté pour la première fois.      ║${RESET}"
        log "${YELLOW}║  Pour que les apps apparaissent dans ${de_msg},  ║${RESET}"
        log "${YELLOW}║  veuillez :                                              ║${RESET}"
        log "${YELLOW}║                                                          ║${RESET}"
        log "${YELLOW}║    → Vous déconnecter puis reconnecter, OU               ║${RESET}"
        log "${YELLOW}║    → Redémarrer votre ordinateur                         ║${RESET}"
        log "${YELLOW}╚══════════════════════════════════════════════════════════╝${RESET}"
    fi
}

###############################################################################
# Gestion des arguments
###############################################################################

for arg in "$@"; do
    case $arg in
        --help)
            show_help
            exit 0
            ;;
        --list)
            SHOW_LIST=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        *)
            echo -e "${RED}Option inconnue: $arg${RESET}"
            echo "Utilisez --help pour voir les options disponibles."
            exit 1
            ;;
    esac
done

# --list ne nécessite pas de privilèges root
if [ "$SHOW_LIST" = true ]; then
    show_applications_list
    exit 0
fi

# Vérification root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Veuillez exécuter ce script avec sudo.${RESET}"
    exit 1
fi

if [ -z "${SUDO_USER:-}" ]; then
    echo -e "${RED}SUDO_USER n'est pas défini. Veuillez exécuter avec sudo.${RESET}"
    exit 1
fi

# Initialisation du log
mkdir -p "$(dirname "$LOG_FILE")"
log "=== Démarrage - $(date) ==="
log "Utilisateur : $SUDO_USER | Mode dry-run : $DRY_RUN"
log "Log : $LOG_FILE"

# Signaux
trap 'handle_interrupt' INT TERM
trap 'cleanup_on_exit' EXIT

###############################################################################
# Point d'entrée principal
###############################################################################

main() {
    log ""
    log "${GREEN}=== Script d'installation des applications Flatpak ===${RESET}"
    log ""

    # Détection automatique de l'environnement
    detect_distro
    detect_desktop
    log ""

    # Vérifications
    check_network
    check_flatpak_installed

    # Plugin bureau adapté à la distro + DE détectés
    setup_desktop_integration
    setup_flathub_remote

    # Confirmation et installation
    confirm_installation
    install_applications
    cleanup_cache

    # Avertissement redémarrage si Flathub nouvellement ajouté
    warn_if_restart_needed

    log ""
    log "${CYAN}📄 Log complet : $LOG_FILE${RESET}"
}

main