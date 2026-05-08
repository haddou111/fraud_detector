#!/bin/bash

# Chargement des codes d'erreur si disponibles
if [[ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/error_codes.sh" ]]; then
    source "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/error_codes.sh"
fi

# ── Couleurs ANSI (définies aussi dans logger.sh, mais nécessaires ici) ──
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
RESET="\033[0m"

# Vérifie qu'une commande est disponible
require_cmd() {
    command -v "$1" &>/dev/null || { 
        log_error "Commande requise introuvable: $1"
        exit "$E_FILE_NOT_FOUND"
    }
}

# Vérifie qu'un fichier existe et est lisible
require_file() {
    [[ -r "$1" ]] || { 
        log_error "Fichier introuvable ou illisible: $1"
        exit "$E_PERMISSION_DENIED"
    }
}

# Affiche l'usage
usage() {
    echo "Usage: $0 [--mode léger|moyen|lourd] [--input fichier.csv]"
    exit 0
}

# reccourci d'arret 
die() {
    local code="$1"
    local message="$2"
    log_error "$message"
    exit "$code"
}


# Vérifie si l'utilisateur courant est root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Cette opération nécessite les droits root (administrateur)"
        echo -e "${BLUE}[INFO]${RESET} Relancez avec : sudo $0 $*" >&2
        exit "$E_INSUFFICIENT_PRIVILEGE"
    fi
}

# Affiche l'aide complète
show_help() {
    cat <<EOF
Usage: ./fraud_detector.sh [OPTIONS] <fichier.csv>

Modes d'exécution (obligatoire) :
  -s              Mode subshell
  -f              Mode fork
  -t              Mode threads

Options :
  --threshold N   Seuil de montant suspect (défaut: 8000)
  --window N      Fenêtre temporelle en minutes (défaut: 5)
  --user NOM      Filtrer par utilisateur
  --algo ALGO     Exécuter un seul algorithme (high|frequency|behavior|structuring|switching)
  --report        Générer un rapport texte
  --stats         Afficher les statistiques du CSV
  --export FILE   Exporter les alertes dans reports/FILE
  -l DIR          Répertoire de logs personnalisé
  -h, --help      Afficher cette aide

Exemples :
  ./fraud_detector.sh -s data/transactions_light.csv
  ./fraud_detector.sh -f --threshold 5000 data/transactions_medium.csv
  ./fraud_detector.sh -t --report data/transactions_heavy.csv
  ./fraud_detector.sh -s --algo high data/transactions_heavy.csv
  ./fraud_detector.sh -f --algo behavior --user Ali data/transactions_heavy.csv
EOF
}