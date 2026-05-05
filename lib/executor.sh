#!/bin/bash
DATA_DIR="${SCRIPT_DIR:-$(pwd)}/data"

declare -A SCENARIO_FILES=(
    [léger]="$DATA_DIR/transactions_light.csv"
    [moyen]="$DATA_DIR/transactions_medium.csv"
    [lourd]="$DATA_DIR/transactions_heavy.csv"
)

# Lance les 5 algorithmes via subshell_runner.c
# $1 : contenu CSV  $2 : chemin du fichier CSV
run_subshell() {
    local csv_content="$1"
    local csv_file="$2"
    local threshold="${THRESHOLD:-8000}"
    
    # Vérifier si subshell_runner existe, sinon le compiler
    if [ ! -f "./subshell_runner" ]; then
        log_info "Compilation de subshell_runner.c..."
        gcc -o subshell_runner subshell_runner.c 2>/dev/null
        if [ $? -ne 0 ]; then
            log_error "Échec compilation subshell_runner"
            return 1
        fi
    fi
    
    # Exécuter subshell_runner avec les paramètres requis
    log_info "Lancement subshell_runner (mode parallèle avec sous-shells)"
    ./subshell_runner "fraud_detector.sh" "$csv_file" "$threshold" "$LOG_FILE"
    
    local ret=$?
    if [ $ret -eq 0 ]; then
        log_info "subshell_runner terminé avec succès"
    else
        log_error "subshell_runner échec (code: $ret)"
    fi
    
    return $ret
}

# Lance les 5 algorithmes via fork_runner.c (appels système fork/wait)
# $1 : contenu CSV  $2 : chemin du fichier CSV
run_fork() {
    local csv_content="$1"
    local csv_file="$2"
    local threshold="${THRESHOLD:-8000}"
    
    # Vérifier si fork_runner existe, sinon le compiler
    if [ ! -f "./fork_runner" ]; then
        log_info "Compilation de fork_runner.c..."
        gcc -o fork_runner fork_runner.c 2>/dev/null
        if [ $? -ne 0 ]; then
            log_error "Échec compilation fork_runner"
            return 1
        fi
    fi
    
    # Exécuter fork_runner avec les paramètres requis
    log_info "Lancement fork_runner (mode parallèle avec fork())"
    ./fork_runner "fraud_detector.sh" "$csv_file" "$threshold" "$LOG_FILE"
    
    local ret=$?
    if [ $ret -eq 0 ]; then
        log_info "fork_runner terminé avec succès"
    else
        log_error "fork_runner échec (code: $ret)"
    fi
    
    return $ret
}

# Lance les 5 algorithmes via thread_runner.c (pthreads POSIX)
# $1 : contenu CSV  $2 : chemin du fichier CSV
# Lance les 5 algorithmes via thread_runner.c (pthreads POSIX)
# $1 : contenu CSV  $2 : chemin du fichier CSV
run_threads() {
    local csv_content="$1"
    local csv_file="$2"
    local threshold="${THRESHOLD:-8000}"
    
    # Vérifier si thread_runner existe, sinon le compiler
    if [ ! -f "./thread_runner" ]; then
        log_info "Compilation de thread_runner.c..."
        gcc -o thread_runner thread_runner.c -lpthread 2>/dev/null
        if [ $? -ne 0 ]; then
            log_error "Échec compilation thread_runner"
            return 1
        fi
    fi
    
    # Exécuter thread_runner avec les paramètres requis
    log_info "Lancement thread_runner (mode parallèle avec pthreads)"
    ./thread_runner "fraud_detector.sh" "$csv_file" "$threshold" "$LOG_FILE"
    
    local ret=$?
    if [ $ret -eq 0 ]; then
        log_info "thread_runner terminé avec succès"
    else
        log_error "thread_runner échec (code: $ret)"
    fi
    
    return $ret
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
