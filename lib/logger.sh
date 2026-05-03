#!/bin/bash

LOG_DIR="${SCRIPT_DIR:-$(pwd)}/logs"
LOG_FILE="$LOG_DIR/fraud_detector_$(date +%Y%m%d).log"

# Couleurs ANSI
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
PURPLE="\033[0;35m"
BOLD="\033[1m"
RESET="\033[0m"

# Initialise le répertoire de logs et le fichier LOG_FILE
# $1 : répertoire personnalisé (optionnel)
init_logger() {
    : # TODO: implémenter
}

# Archive ou restaure les anciens fichiers de logs (option -r)
restore_logs() {
    : # TODO: implémenter
}

log_info()  { _log "INFO"  "$*"; }
log_warn()  { _log "WARN"  "$*"; }
log_error() { _log "ERROR" "$*"; }

_log() {
    local level="$1"; shift
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}
