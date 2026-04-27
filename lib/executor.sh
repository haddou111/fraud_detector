#!/bin/bash
DATA_DIR="${SCRIPT_DIR:-$(pwd)}/data"

declare -A SCENARIO_FILES=(
    [léger]="$DATA_DIR/transactions_light.csv"
    [moyen]="$DATA_DIR/transactions_medium.csv"
    [lourd]="$DATA_DIR/transactions_heavy.csv"
)

# Lance les 5 algorithmes en parallèle via des sous-shells bash ( ) &
# $1 : contenu CSV  $2 : chemin du fichier CSV
run_subshell() {
    : # TODO: implémenter
}

# Lance les 5 algorithmes via fork_runner.c (appels système fork/wait)
# $1 : contenu CSV  $2 : chemin du fichier CSV
run_fork() {
    : # TODO: implémenter
}

# Lance les 5 algorithmes via thread_runner.c (pthreads POSIX)
# $1 : contenu CSV  $2 : chemin du fichier CSV
run_threads() {
    : # TODO: implémenter
}

# Sélectionne le fichier selon le mode
resolve_input() {
    local mode="$1"
    echo "${SCENARIO_FILES[$mode]:-}"
}

# Exécute la détection sur un fichier CSV
run() {
    local input="$1"
    require_file "$input"
    validate_header "$input"
    local count=0 frauds=0
    while IFS= read -r line; do
        [[ $count -eq 0 ]] && (( count++ )) && continue  # skip header
        parse_line "$line"
        analyze_transaction "$TRANSACTION_ID" "$AMOUNT" || (( frauds++ ))
        (( count++ ))
    done < "$input"
    log_info "Traitement terminé — $((count-1)) transactions, $frauds fraude(s) détectée(s)"
}
