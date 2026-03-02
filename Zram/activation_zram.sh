#!/bin/bash
# =============================================================================
#  Script d'installation et configuration de ZRAM
#  Compatible : Debian, Ubuntu, Linux Mint
#  Paramètres : compression=zstd | taille=50% RAM | priorité=100 | type=swap
#  Outil      : systemd-zram-generator
#
#  DÉSINSTALLATION :
#    sudo systemctl stop dev-zram0.swap
#    sudo systemctl disable dev-zram0.swap
#    sudo apt remove systemd-zram-generator
#    sudo rm /etc/systemd/zram-generator.conf.d/zram.conf
#    # Restaurer /etc/fstab depuis la sauvegarde si nécessaire
# =============================================================================

# --- Pas de set -e : gestion manuelle des erreurs pour éviter les faux positifs ---

# --- Couleurs ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERREUR]${NC} $1"; exit 1; }

# =============================================================================
# 1. Vérification des droits root
# =============================================================================
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté en tant que root (sudo $0)"
fi

# =============================================================================
# 2. Détection de la distribution
# =============================================================================
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO="${ID}"
    DISTRO_BASE="${ID_LIKE:-$ID}"
else
    log_error "Impossible de détecter la distribution Linux."
fi

log_info "Distribution détectée : ${PRETTY_NAME}"

case "$DISTRO" in
    debian|ubuntu|linuxmint|pop|elementary|zorin)
        log_success "Distribution compatible."
        ;;
    *)
        if echo "$DISTRO_BASE" | grep -qiE "debian|ubuntu"; then
            log_warn "Distribution basée sur Debian/Ubuntu — poursuite du script."
        else
            log_error "Distribution non supportée : $DISTRO"
        fi
        ;;
esac

# =============================================================================
# 3. Vérification du module noyau zram
# =============================================================================
log_info "Vérification du module noyau zram..."
if ! modinfo zram &>/dev/null; then
    log_error "Le module noyau 'zram' n'est pas disponible sur ce système."
fi
log_success "Module zram disponible."

# =============================================================================
# 4. Vérification du support zstd par le noyau
#    zstd disponible à partir du noyau 5.3 — nécessite de charger zram d'abord
# =============================================================================
log_info "Vérification du support zstd par le noyau..."

COMPRESSION_ALGO="zstd"

# Chargement temporaire du module zram pour lire comp_algorithm
modprobe zram 2>/dev/null || true

if [[ -f /sys/block/zram0/comp_algorithm ]]; then
    if grep -q "zstd" /sys/block/zram0/comp_algorithm; then
        log_success "zstd supporté par le noyau."
    else
        log_warn "zstd non supporté par ce noyau — utilisation de lzo-rle à la place."
        COMPRESSION_ALGO="lzo-rle"
    fi
else
    log_warn "Impossible de vérifier comp_algorithm — zstd supposé supporté."
fi

# =============================================================================
# 5. Désactivation et désinstallation de zram-tools si présent
# =============================================================================
if dpkg -l zram-tools &>/dev/null 2>&1; then
    log_warn "Paquet zram-tools détecté — désinstallation pour éviter les conflits..."
    systemctl stop zramswap 2>/dev/null || true
    systemctl disable zramswap 2>/dev/null || true
    apt remove -y zram-tools > /dev/null
    log_success "zram-tools désinstallé."
fi

# =============================================================================
# 6. Installation de systemd-zram-generator (si pas déjà présent)
# =============================================================================
if dpkg -l systemd-zram-generator &>/dev/null 2>&1; then
    log_info "systemd-zram-generator déjà installé — mise à jour ignorée."
else
    log_info "Mise à jour des paquets et installation de systemd-zram-generator..."
    apt update -qq
    # stderr laissé visible pour ne pas masquer les vraies erreurs d'installation
    if ! apt install -y systemd-zram-generator > /dev/null; then
        log_error "Échec de l'installation de systemd-zram-generator."
    fi
    log_success "systemd-zram-generator installé."
fi

# =============================================================================
# 7. Écriture de la configuration zram-generator
#
#    zram-size = ram / 2  → syntaxe officielle du générateur (expression dynamique
#                            évaluée au démarrage, pas de calcul manuel en Mo)
#    compression-algorithm → zstd (ou lzo-rle si noyau trop ancien)
#    swap-priority         → 100
#    fs-type               → swap (type défini explicitement)
# =============================================================================
ZRAM_CONF_DIR="/etc/systemd/zram-generator.conf.d"
ZRAM_CONF="${ZRAM_CONF_DIR}/zram.conf"

mkdir -p "$ZRAM_CONF_DIR"
log_info "Écriture de la configuration dans ${ZRAM_CONF}..."

cat > "$ZRAM_CONF" <<EOF
# =============================================================
#  Configuration ZRAM — généré par install_zram.sh
#  Outil : systemd-zram-generator
# =============================================================

[zram0]

# Taille = 50% de la RAM (expression évaluée dynamiquement au démarrage)
zram-size = ram / 2

# Algorithme de compression
compression-algorithm = ${COMPRESSION_ALGO}

# Priorité du swap (100 = préféré par rapport au swap disque)
swap-priority = 100

# Type explicitement défini à swap
# Valeurs possibles : swap | ext2 | ext4 | btrfs | xfs | tmpfs ...
fs-type = swap
EOF

log_success "Fichier de configuration écrit (compression: ${COMPRESSION_ALGO})."

# =============================================================================
# 8. Abaissement de la priorité du swapfile Ubuntu
#    Le swapfile par défaut a une priorité de -2 dans /etc/fstab.
#    On l'abaisse à -10 pour garantir que le zram (priorité 100) soit
#    TOUJOURS utilisé en premier. Le swapfile ne sert qu'en débordement.
# =============================================================================
FSTAB="/etc/fstab"

if grep -q '/swapfile' "$FSTAB"; then
    log_info "Swapfile Ubuntu détecté — abaissement de sa priorité à -10 dans /etc/fstab..."

    if ! grep '/swapfile' "$FSTAB" | grep -q 'pri='; then
        # Sauvegarde horodatée pour ne pas écraser l'original si le script est relancé
        FSTAB_BAK="${FSTAB}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$FSTAB" "$FSTAB_BAK"
        log_info "Sauvegarde créée : ${FSTAB_BAK}"

        sed -i '/\/swapfile/s/\(sw\)/\1,pri=-10/' "$FSTAB"
        log_success "Priorité du swapfile abaissée à -10 dans /etc/fstab."
    else
        log_warn "Une priorité est déjà définie pour le swapfile — vérifiez /etc/fstab manuellement."
    fi

    # Réactivation avec priorité explicite (-p) pour application immédiate
    if swapoff /swapfile 2>/dev/null; then
        if swapon -p -10 /swapfile 2>/dev/null; then
            log_success "Swapfile réactivé avec priorité -10 (sans redémarrage)."
        else
            log_warn "Impossible de réactiver le swapfile — sera pris en compte au prochain démarrage."
        fi
    else
        log_warn "Swapfile non actif en ce moment — la nouvelle priorité sera appliquée au prochain démarrage."
    fi
else
    log_info "Aucun swapfile détecté dans /etc/fstab — aucune modification nécessaire."
fi

# =============================================================================
# 9. Rechargement de systemd et activation du zram
# =============================================================================
log_info "Rechargement de systemd..."
systemctl daemon-reload

log_info "Activation du périphérique zram0..."
if systemctl start dev-zram0.swap; then
    log_success "Périphérique zram0 activé comme swap."
else
    log_error "Échec de l'activation de zram0. Vérifiez : journalctl -xe"
fi

# =============================================================================
# 10. Récapitulatif — taille lue depuis zramctl (valeur réelle du noyau)
# =============================================================================
sleep 1

TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))

# Lecture de la taille réelle allouée par le noyau via zramctl
if command -v zramctl &>/dev/null; then
    ZRAM_REAL_SIZE=$(zramctl --noheadings --output DISKSIZE /dev/zram0 2>/dev/null || echo "N/A")
else
    ZRAM_REAL_SIZE="N/A (zramctl non disponible)"
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   ZRAM configuré avec succès !${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  ${BLUE}Compression${NC}  : ${COMPRESSION_ALGO}"
echo -e "  ${BLUE}Taille swap${NC}  : ${ZRAM_REAL_SIZE}  (50% de ${TOTAL_RAM_MB} Mo)"
echo -e "  ${BLUE}Priorité${NC}     : 100  (swapfile abaissé à -10)"
echo -e "  ${BLUE}Type${NC}         : swap  (défini via fs-type)"
echo ""

log_info "Périphériques zram actifs :"
if command -v zramctl &>/dev/null; then
    zramctl
else
    log_warn "zramctl non disponible."
fi

echo ""
log_info "Partitions swap actives (ordre d'utilisation) :"
swapon --show

echo ""
log_success "Installation terminée. Le zram swap sera actif à chaque démarrage."