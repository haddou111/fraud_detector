#!/bin/bash

LOG_DIR="${SCRIPT_DIR:-$(pwd)}/logs"
LOG_FILE="$LOG_DIR/fraud_detector_$(date +%Y%m%d).log"

log_info()  { _log "INFO"  "$*"; }
log_warn()  { _log "WARN"  "$*"; }
log_error() { _log "ERROR" "$*"; }

_log() {
    local level="$1"; shift
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}
