#!/bin/bash
<<<<<<< Updated upstream

# Répertoire par défaut des logs système (à utiliser uniquement si le script est exécuté avec les droits root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Répertoire des logs
LOG_DIR="${SCRIPT_DIR:-$(pwd)}/logs"
=======
# Chargement des codes d'erreur si disponibles (Version Actuelle)
if [[ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/error_codes.sh" ]]; then
    source "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/error_codes.sh"
fi
# Répertoire par défaut des logs
CURRENT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR:-$(dirname "$CURRENT_LIB_DIR")}"
LOG_DIR="$PROJECT_ROOT/logs"
>>>>>>> Stashed changes
# Fichier principal de log
LOG_FILE="$LOG_DIR/history.log"
# Couleurs ANSI
RED="\033[0;31m"    # Rouge pour les erreurs
GREEN="\033[0;32m"  # Vert pour les succès
BLUE="\033[0;34m"   # Bleu pour les informations
PURPLE="\033[0;35m" # Violet pour les warningsS
RESET="\033[0m"    # Reset couleur 
BOLD="\033[1m"     # Gras 

init_logger() {
    local custom_dir="$1"

    if [ -n "$custom_dir" ]; then
        LOG_DIR="$custom_dir"
        LOG_FILE="$LOG_DIR/history.log"
        # Exporter les variables pour les processus enfants
        export LOG_DIR LOG_FILE
    fi
    # Vérification des droits root si dossier système utilisé
<<<<<<< Updated upstream
    if [[ "$LOG_DIR" == /var/log/* ]]; then
        check_root 
    fi
    # Création du dossier de logs si inexistant
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR" || {
            echo -e "${RED}[ERROR] Impossible de créer le dossier log: $LOG_DIR${RESET}"
            exit 106
=======
    if [[ "$LOG_DIR" == /var/log/* ]] && [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[ERROR] Accès root requis pour écrire dans $LOG_DIR${RESET}"
        exit "$E_INSUFFICIENT_PRIVILEGE"
    fi
    # Création du dossier de logs si inexistant
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            echo -e "${RED}[ERROR] Impossible de créer le dossier log: $LOG_DIR${RESET}"
            exit "$E_INVALID_LOG_DIR"
>>>>>>> Stashed changes
        }
    fi

    # Création du fichier log si inexistant
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" || {
            echo -e "${RED}[ERROR] Impossible de créer le fichier log: $LOG_FILE${RESET}"
            exit 106
        }
    fi
<<<<<<< Updated upstream
    # Vérification des permissions d'écriture sur le fichier log
    if [ ! -w "$LOG_FILE" ]; then
        echo -e "${RED}[ERROR] Fichier log non accessible en écriture: $LOG_FILE${RESET}"
        exit 106
    fi
    # Permissions sécurisées du fichier log
    chmod u=rw,go=r "$LOG_FILE" || {
        log_error "Impossible de modifier permissions"
        exit 106
    }
=======
    # Vérification des permissions d'écriture
    if [ ! -w "$LOG_FILE" ]; then
        echo -e "${RED}[ERROR] Fichier log non accessible en écriture: $LOG_FILE${RESET}"
        exit "$E_INVALID_LOG_DIR"
    fi
    # Permissions sécurisées
    chmod u=rw,go=r "$LOG_FILE" 2>/dev/null
>>>>>>> Stashed changes
    # Gestion interruption CTRL+C
    trap 'log_error "Interruption du programme (SIGINT)"; exit 130' INT
}
# Archivage des logs (Version Améliorée)
restore_logs() {
    # Vérification des permissions (root)
<<<<<<< Updated upstream
    check_root 

=======
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[ERROR] L'archivage nécessite les droits administrateur (root)${RESET}"
        exit "$E_INSUFFICIENT_PRIVILEGE"
    fi
>>>>>>> Stashed changes
    # Si log existe
    if [ -f "$LOG_FILE" ]; then
        #crée une variable archive avec un nom unique basé sur la date et l'heure actuelle
        local archive="$LOG_DIR/archive_$(date +%Y%m%d_%H%M%S).tar.gz"
        #archive le fichier de log actuel dans un fichier tar.gz et redirige les erreurs vers le fichier de log
        tar -czf "$archive" -C "$(dirname "$LOG_FILE")" "$(basename "$LOG_FILE")" 2>/dev/null || {
             log_error "Echec archivage logs"
             exit 106
      }
        #Réinitialisation du log
        :> "$LOG_FILE" || {
            log_error "Échec de la réinitialisation du log"
            exit 106
        }

        echo -e "${GREEN}[INFO] Logs archivés dans $archive${RESET}"
    fi
}

log_info()  { _log "INFOS"  "$@"; }
log_warn()  { _log "WARNING"  "$@"; }
log_error() { _log "ERROR" "$@"; }

_log() {
    local level="$1"; shift 

    local timestamp
    timestamp=$(date '+%Y-%m-%d-%H-%M-%S')
    # Utilisateur courant
    local user
    user=$(whoami)
    # Message final log 
    local log_msg="$timestamp : $user : $level : $*"

    # Affichage terminal en couleur (hors verrou)
    case "$level" in
        INFOS)   echo -e "${BLUE}${log_msg}${RESET}" ;;
        WARNING) echo -e "${PURPLE}${log_msg}${RESET}" ;;
        ERROR)   echo -e "${RED}${log_msg}${RESET}" >&2 ;;
    esac

    # Écriture fichier protégée par verrou flock
    {
        #un seul processus écrit à la fois 
        flock -x 200
        echo "$log_msg" >&200
    } 200>>"$LOG_FILE"
}