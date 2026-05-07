#!/bin/bash

# Répertoire par défaut des logs système (à utiliser uniquement si le script est exécuté avec les droits root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Répertoire des logs
LOG_DIR="${SCRIPT_DIR:-$(pwd)}/logs"
# Fichier principal de log
LOG_FILE="$LOG_DIR/history.log"
# Couleurs ANSI
RED="\033[0;31m" # Rouge pour les erreurs
GREEN="\033[0;32m" # Vert pour les succès
BLUE="\033[0;34m" # Bleu pour les informations
PURPLE="\033[0;35m" # violet pour warn
RESET="\033[0m" # reset couleur 
BOLD="\033[1m" # gras 

init_logger() {
    local custom_dir="$1"

    if [ -n "$custom_dir" ]; then
        LOG_DIR="$custom_dir"
        LOG_FILE="$LOG_DIR/history.log"
        # Exporter les variables pour les processus enfants
        export LOG_DIR LOG_FILE
    fi
    # Vérification des droits root si dossier système utilisé
    if [[ "$LOG_DIR" == /var/log/* ]]; then
        check_root 
    fi
    # Création du dossier de logs si inexistant
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR" || {
            echo -e "${RED}[ERROR] Impossible de créer le dossier log: $LOG_DIR${RESET}"
            exit 106
        }
    fi

    # Création du fichier log si inexistant
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" || {
            echo -e "${RED}[ERROR] Impossible de créer le fichier log: $LOG_FILE${RESET}"
            exit 106
        }
    fi
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
    # Gestion interruption CTRL+C
    trap 'log_error "Interruption du programme (SIGINT)"; exit 130' INT
}

# Archivage des logs
restore_logs() {
    # Vérification des permissions (root)
    check_root 

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