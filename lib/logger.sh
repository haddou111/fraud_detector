#!/bin/bash

# Chargement des codes d'erreur si disponibles (Version Actuelle)
if [[ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/error_codes.sh" ]]; then
    source "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/error_codes.sh"
fi

# Répertoire des logs (défini par rapport à la racine du projet)
CURRENT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR:-$(dirname "$CURRENT_LIB_DIR")}"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/history.log"

# Couleurs ANSI
RED="\033[0;31m"    # Rouge pour les erreurs
GREEN="\033[0;32m"  # Vert pour les succès
BLUE="\033[0;34m"   # Bleu pour les informations
PURPLE="\033[0;35m" # Violet pour les warnings
RESET="\033[0m"    # Reset couleur 
BOLD="\033[1m"     # Gras 

init_logger() {
    local custom_dir="$1"

    if [ -n "$custom_dir" ]; then
        LOG_DIR="$custom_dir"
        LOG_FILE="$LOG_DIR/history.log"
        export LOG_DIR LOG_FILE
    fi

    # Vérification des droits root si dossier système utilisé
    if [[ "$LOG_DIR" == /var/log/* ]] && [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[ERROR] Accès root requis pour écrire dans $LOG_DIR${RESET}"
        exit "$E_INSUFFICIENT_PRIVILEGE"
    fi

    # Création du dossier de logs si inexistant
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            echo -e "${RED}[ERROR] Impossible de créer le dossier log: $LOG_DIR${RESET}"
            exit "$E_INVALID_LOG_DIR"
        }
    fi

    # Création du fichier log si inexistant
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" 2>/dev/null || {
            echo -e "${RED}[ERROR] Impossible de créer le fichier log: $LOG_FILE${RESET}"
            exit "$E_INVALID_LOG_DIR"
        }
    fi

    # Vérification des permissions d'écriture
    if [ ! -w "$LOG_FILE" ]; then
        echo -e "${RED}[ERROR] Fichier log non accessible en écriture: $LOG_FILE${RESET}"
        exit "$E_INVALID_LOG_DIR"
    fi

    # Permissions sécurisées
    chmod u=rw,go=r "$LOG_FILE" 2>/dev/null

    # Gestion interruption CTRL+C
    trap 'log_error "Interruption du programme (SIGINT)"; exit 130' INT
}

# Archivage des logs
restore_logs() {
    # Vérification des permissions (root)

    check_root 

    if [ -f "$LOG_FILE" ]; then
        local archive="$LOG_DIR/archive_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$archive" -C "$(dirname "$LOG_FILE")" "$(basename "$LOG_FILE")" 2>/dev/null || {
             log_error "Echec archivage logs"
             exit "$E_INVALID_LOG_DIR"
        }
        :> "$LOG_FILE" || {
            log_error "Échec de la réinitialisation du log"
            exit "$E_INVALID_LOG_DIR"
        }
        echo -e "${GREEN}[INFO] Logs archivés dans $archive${RESET}"
    fi
}

log_info()  { _log "INFOS"  "$@"; }
log_warn()  { _log "WARNING"  "$@"; }
log_error() { _log "ERROR" "$@"; }

# Fonction de log interne (Version Optimisée : propre et thread-safe)
_log() {
    local level="$1"; shift 
    local timestamp=$(date '+%Y-%m-%d-%H-%M-%S')
    local user=$(whoami)
    local log_msg="$timestamp : $user : $level : $*"

    # 1. Affichage terminal en couleur
    case "$level" in
        INFOS)   echo -e "${BLUE}${log_msg}${RESET}" ;;
        WARNING) echo -e "${PURPLE}${log_msg}${RESET}" ;;
        ERROR)   echo -e "${RED}${log_msg}${RESET}" >&2 ;;
    esac

    # 2. Écriture fichier (sans couleurs ANSI, protégée par verrou)
    {
        flock -x 200
        echo "$log_msg" >&200
    } 200>>"$LOG_FILE"
}