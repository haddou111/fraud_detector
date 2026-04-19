#!/usr/bin/env bash
# fraud_detector.sh — Point d'entrée principal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/logger.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/parser.sh"
source "$SCRIPT_DIR/lib/detector.sh"
source "$SCRIPT_DIR/lib/executor.sh"

main() {
    log_info "Démarrage du détecteur de fraude"
    # TODO: implémenter la logique principale
}

main "$@"
