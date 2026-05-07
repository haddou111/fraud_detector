#!/bin/bash

# =============================================================
# fraud_detector.sh — Point d'entrée principal
# FraudDetect | ENSET Mohammedia 2026
#
# UTILISATION :
#   ./fraud_detector.sh -s data/transactions_light.csv
#   ./fraud_detector.sh -f --threshold 8000 data/transactions_medium.csv
#   ./fraud_detector.sh -t --report data/transactions_heavy.csv
#
# MODE DEBUG :
#export DEBUG=  # avant d'exécuter pour activer les messages de debug
# =============================================================

# Activer le mode debug si la variable DEBUG est définie
[[ -n "$DEBUG" ]] && set -x

#Resolution de chemin de projet et ou se trouve le script principal :fraud_detector.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"    

# ── Chargement des bibliothèques ─────────────────────────────
source "${SCRIPT_DIR}/lib/error_codes.sh" || { echo "ERREUR: lib/error_codes.sh manquant"; exit 1; }
source "${SCRIPT_DIR}/lib/logger.sh"   || { echo "ERREUR: lib/logger.sh manquant"; exit 1; }  
source "${SCRIPT_DIR}/lib/utils.sh"    || { echo "ERREUR: lib/utils.sh manquant"; exit 1; }
source "${SCRIPT_DIR}/lib/parser.sh"   || { echo "ERREUR: lib/parser.sh manquant"; exit 1; }
source "${SCRIPT_DIR}/lib/detector.sh" || { echo "ERREUR: lib/detector.sh manquant"; exit 1; }
source "${SCRIPT_DIR}/lib/executor.sh" || { echo "ERREUR: lib/executor.sh manquant"; exit 1; }

# ── Valeurs par défaut ───────────────────────────────────────
MODE=""
CSV_FILE=""
LOG_CUSTOM_DIR=""
THRESHOLD=8000
WINDOW_MINUTES=5
FILTER_USER=""
DO_REPORT=false
DO_STATS=false
EXPORT_FILE=""
SINGLE_ALGO=""
INTERNAL_MODE=""    # Utilisé par les programmes C pour rappeler ce script


export THRESHOLD WINDOW_MINUTES FILTER_USER EXPORT_FILE
export CURRENT_USER="${USER:-$(whoami)}"

# ── Initialisation temporaire du logger (sera réinitialisé après parsing si -l est utilisé) ──
init_logger ""

# ── Parsing des arguments ────────────────────────────────────
[[ $# -eq 0 ]] && { show_help; exit 0; } 

 # ./fraud_detector.sh -t
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)   show_help; exit 0 ;;
        -s)          MODE="subshell"; shift ;;
        -f)          MODE="fork";     shift ;;
        -t)          MODE="threads";  shift ;;
        -r)          check_root; init_logger "$LOG_CUSTOM_DIR"; export LOG_DIR LOG_FILE; restore_logs; exit 0 ;;

        -l)
            [[ -z "$2" ]] && die "$E_MISSING_PARAM" "-l requiert un chemin de répertoire"    
            LOG_CUSTOM_DIR="$2"
            # Réinitialiser le logger avec le nouveau répertoire
            init_logger "$LOG_CUSTOM_DIR"
            export LOG_DIR LOG_FILE
            shift 2 ;;     

        --threshold)
            [[ -z "$2" || ! "$2" =~ ^[0-9]+$ ]] && die "$E_MISSING_PARAM" "--threshold requiert un nombre"
            THRESHOLD="$2"; export THRESHOLD; shift 2 ;;

        --window)
            [[ -z "$2" || ! "$2" =~ ^[0-9]+$ ]] && die "$E_MISSING_PARAM" "--window requiert un nombre (minutes)"
            WINDOW_MINUTES="$2"; export WINDOW_MINUTES; shift 2 ;;

        --user)
            [[ -z "$2" ]] && die "$E_MISSING_PARAM" "--user requiert un nom d'utilisateur"
            FILTER_USER="$2"; export FILTER_USER; shift 2 ;;

        --report)  DO_REPORT=true; shift ;;
        --stats)   DO_STATS=true;  shift ;;

        --export)
            [[ -z "$2" ]] && die "$E_MISSING_PARAM" "--export requiert un nom de fichier"
            EXPORT_FILE="${SCRIPT_DIR}/reports/$2"; export EXPORT_FILE; shift 2 ;;

        --algo)
            [[ -z "$2" ]] && die "$E_MISSING_PARAM" "--algo requiert un nom d'algorithme (high|frequency|behavior|structuring|switching)"
            case "$2" in
                high|frequency|behavior|structuring|switching)
                    SINGLE_ALGO="$2"; export SINGLE_ALGO; shift 2 ;;
                *)
                    die "$E_INVALID_OPTION" "Algorithme invalide: '$2'. Utilisez: high, frequency, behavior, structuring, switching" ;;
            esac ;;

        --log-file)
            # Utilisé par les binaires C pour spécifier le fichier log
            [[ -z "$2" ]] && die "$E_MISSING_PARAM" "--log-file requiert un chemin"
            LOG_FILE="$2"; export LOG_FILE; shift 2 ;;

        # ── Flags internes : appelés par fork_runner.c et thread_runner.c ──
        # Chaque flag exécute UN SEUL algorithme de détection puis quitte.
        --internal-high)
            INTERNAL_MODE="high"; shift ;;
        --internal-frequency)
            INTERNAL_MODE="frequency"; shift ;;
        --internal-behavior)
            INTERNAL_MODE="behavior"; shift ;;
        --internal-structuring)
            INTERNAL_MODE="structuring"; shift ;;
        --internal-switching)
            INTERNAL_MODE="switching"; shift ;;

        -*)
            die "$E_INVALID_OPTION" "Option inconnue : '$1'" ;;

        *)
            [[ -z "$CSV_FILE" ]] && CSV_FILE="$1" || die "$E_INVALID_OPTION" "Argument inattendu : '$1'"
            shift ;;
    esac
done

# ── Exportation finale des variables de log pour les processus enfants ──
export LOG_DIR LOG_FILE

# =============================================================
# MODE INTERNE — appelé par les programmes C
# Exécute un seul algorithme et retourne le nb d'alertes
# =============================================================
if [[ -n "$INTERNAL_MODE" ]]; then
    # Le logger est déjà initialisé via --log-file
    log_info "[MODE INTERNE] Démarrage algo: $INTERNAL_MODE"
    
    # Valider et charger le CSV
    validate_csv "$CSV_FILE" || {
        log_error "[MODE INTERNE] Validation CSV échouée"
        exit 1
    }
    
    CSV_DATA=$(filter_by_user "$CSV_FILE" "$FILTER_USER")
    
    if [[ -z "$CSV_DATA" ]]; then
        log_error "[MODE INTERNE] Aucune donnée CSV chargée"
        exit 1
    fi
    
    NB_LINES=$(echo "$CSV_DATA" | wc -l | tr -d ' ')
    log_info "[MODE INTERNE] $NB_LINES lignes chargées"

    ALERT_COUNT=0
    case "$INTERNAL_MODE" in
        high)        detect_high_amount "$CSV_DATA" && ALERT_COUNT=1 ;;
        frequency)   detect_frequency_anomaly "$CSV_DATA" && ALERT_COUNT=1 ;;
        behavior)    detect_behavior_change "$CSV_DATA" && ALERT_COUNT=1 ;;
        structuring) detect_structuring "$CSV_DATA" && ALERT_COUNT=1 ;;
        switching)   detect_account_switching "$CSV_DATA" && ALERT_COUNT=1 ;;
    esac
    
    log_info "[MODE INTERNE] Terminé avec $ALERT_COUNT alerte(s)"
    exit "$ALERT_COUNT"
fi

# =============================================================
# MODE NORMAL — vérifications et exécution complète
# =============================================================

[[ -z "$MODE" ]]     && die "$E_MISSING_PARAM" "Aucun mode spécifié. Utilisez -s, -f ou -t."
[[ -z "$CSV_FILE" ]] && die "$E_MISSING_PARAM" "Aucun fichier CSV spécifié."

# ── Validation CSV ───────────────────────────────────────────
log_info "[INIT] Validation du fichier CSV: $CSV_FILE"
validate_csv "$CSV_FILE" || die "$E_INVALID_CSV" "Validation CSV échouée"

log_info "[INIT] Chargement du fichier CSV..."
CSV_DATA=$(filter_by_user "$CSV_FILE" "$FILTER_USER")

if [[ -z "$CSV_DATA" ]]; then
    if [[ -n "$FILTER_USER" ]]; then
        die "$E_INVALID_CSV" "Aucune transaction pour l'utilisateur '$FILTER_USER'"
    else
        die "$E_INVALID_CSV" "Aucune donnée valide dans le fichier CSV"
    fi
fi

NB_LINES=$(echo "$CSV_DATA" | wc -l | tr -d ' ')

log_info "[INIT] $NB_LINES transactions chargées"
log_info "[INIT] Démarrage fraud_detector.sh — mode: $MODE — fichier: $CSV_FILE"

[[ -n "$FILTER_USER" ]] && echo -e "${BLUE}[INFO]${RESET} Filtre: ${BOLD}$FILTER_USER${RESET}"
[[ -n "$EXPORT_FILE" ]] && mkdir -p "${SCRIPT_DIR}/reports"

# ── Statistiques (--stats) ───────────────────────────────────
if $DO_STATS; then
    log_info "[STATS] Génération des statistiques"
    show_stats "$CSV_FILE"
fi

# ── En-tête d'analyse ────────────────────────────────────────
echo -e "\n${BOLD}${PURPLE}══════════════ ANALYSE EN COURS ══════════════${RESET}"
echo -e "  Mode     : ${BOLD}$MODE${RESET}"
echo -e "  Fichier  : ${BOLD}$CSV_FILE${RESET} ($NB_LINES transactions)"
echo -e "  Seuil    : ${BOLD}$THRESHOLD MAD${RESET}"
echo -e "${PURPLE}═══════════════════════════════════════════════${RESET}\n"

# ── Lancement du mode choisi ─────────────────────────────────
if [[ -n "$SINGLE_ALGO" ]]; then
    # Mode algorithme unique
    log_info "[SINGLE] Exécution de l'algorithme: $SINGLE_ALGO"
    echo -e "${BOLD}${CYAN}══════════════ ALGORITHME UNIQUE ══════════════${RESET}"
    echo -e "  Algorithme : ${BOLD}$SINGLE_ALGO${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════${RESET}\n"
    
    ALERT_COUNT=0
    case "$SINGLE_ALGO" in
        high)        detect_high_amount "$CSV_DATA" && ALERT_COUNT=1 ;;
        frequency)   detect_frequency_anomaly "$CSV_DATA" && ALERT_COUNT=1 ;;
        behavior)    detect_behavior_change "$CSV_DATA" && ALERT_COUNT=1 ;;
        structuring) detect_structuring "$CSV_DATA" && ALERT_COUNT=1 ;;
        switching)   detect_account_switching "$CSV_DATA" && ALERT_COUNT=1 ;;
    esac
    
    TOTAL_ALERTS=$ALERT_COUNT
    log_info "[SINGLE] Algorithme $SINGLE_ALGO terminé avec $TOTAL_ALERTS alerte(s)"
else
    # Mode normal avec tous les algorithmes
    case "$MODE" in
        subshell) run_subshell "$CSV_DATA" "$CSV_FILE" ;;
        fork)     run_fork     "$CSV_DATA" "$CSV_FILE" ;;
        threads)  run_threads  "$CSV_DATA" "$CSV_FILE" ;;
    esac

    TOTAL_ALERTS=$?  # en recupere le code de retourn de la fonction appelée apres la fin de son execution 
fi 

# ── Rapport (--report) ───────────────────────────────────────
if $DO_REPORT; then
    mkdir -p "${SCRIPT_DIR}/reports"
    REPORT_FILE="${SCRIPT_DIR}/reports/rapport_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "=================================================="
        echo "  RAPPORT FraudDetect — $(date '+%Y-%m-%d %H:%M:%S')"
        echo "=================================================="
        echo "Fichier  : $CSV_FILE"
        echo "Mode     : $MODE"
        echo "Seuil    : $THRESHOLD MAD"
        echo "Lignes   : $NB_LINES"
        echo "Alertes  : $TOTAL_ALERTS"
        echo ""
        echo "--- JOURNAL ---"
        cat "$LOG_FILE"
    } > "$REPORT_FILE"
    echo -e "${GREEN}[INFO]${RESET} Rapport : ${BOLD}$REPORT_FILE${RESET}"
    log_info "Rapport généré : $REPORT_FILE"
fi

# ── Résumé final ─────────────────────────────────────────────
echo -e "\n${BOLD}${GREEN}══════════════════ RÉSUMÉ ═════════════════════${RESET}"
echo -e "  Transactions analysées : ${BOLD}$NB_LINES${RESET}"
echo -e "  Alertes générées       : ${BOLD}$TOTAL_ALERTS${RESET}"
echo -e "  Log                    : ${BOLD}$LOG_FILE${RESET}"
$DO_REPORT && echo -e "  Rapport                : ${BOLD}$REPORT_FILE${RESET}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════${RESET}\n"

log_info "Terminé — $NB_LINES transactions — $TOTAL_ALERTS alertes"
exit 0

