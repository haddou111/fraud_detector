#!/bin/bash
DATA_DIR="${SCRIPT_DIR:-$(pwd)}/data"

declare -A SCENARIO_FILES=(
    [léger]="$DATA_DIR/transactions_light.csv"
    [moyen]="$DATA_DIR/transactions_medium.csv"
    [lourd]="$DATA_DIR/transactions_heavy.csv"
)

# Lance les 5 algorithmes en parallèle via le runner C (subshells)
# $1 : contenu CSV  $2 : chemin du fichier CSV
run_subshell() {
    local csv_file="$2"
    local threshold="${THRESHOLD:-8000}"
    
    local sub_bin="${SCRIPT_DIR}/subshell_runner"
    local sub_src="${SCRIPT_DIR}/src/subshell_runner.c"
    
    # Vérifier si subshell_runner existe, sinon le compiler
    if [ ! -f "$sub_bin" ]; then
        log_info "[SUBSHELL] Compilation de subshell_runner.c..."
        gcc -o "$sub_bin" "$sub_src" 2>&1 | while read line; do log_info "[GCC] $line"; done
        
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            log_error "[SUBSHELL] Échec compilation subshell_runner"
            return 1
        fi
        log_info "[SUBSHELL] Compilation réussie"
    fi
    
    # Exécuter subshell_runner avec les paramètres requis
    log_info "[SUBSHELL] Lancement subshell_runner (mode parallèle avec subshells)"
    
    "$sub_bin" "${SCRIPT_DIR}/fraud_detector.sh" "$csv_file" "$threshold" "$LOG_FILE"
    
    # Le binaire retourne le nombre total d'alertes via son code de sortie ($?)
    local ret=$?
    
    if [ $ret -ge 100 ]; then
        log_error "[SUBSHELL] Échec critique du runner (code: $ret)"
        return 1
    fi

    log_info "[SUBSHELL] Terminé - $ret algorithme(s) ont détecté des fraudes"
    return "$ret"
}


# Lance les 5 algorithmes via fork_runner.c (appels système fork/wait)
# $1 : contenu CSV  $2 : chemin du fichier CSV
run_fork() {
    local csv_content="$1"
    local csv_file="$2"
    local threshold="${THRESHOLD:-8000}"
    
    local fork_bin="${SCRIPT_DIR}/fork_runner"
    local fork_src="${SCRIPT_DIR}/src/fork_runner.c"
    
    # Vérifier si fork_runner existe, sinon le compiler
    if [ ! -f "$fork_bin" ]; then
        log_info "[FORK] Compilation de fork_runner.c..."
        gcc -o "$fork_bin" "$fork_src" 2>&1 | while read line; do log_info "[GCC] $line"; done
        
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            log_error "[FORK] Échec compilation fork_runner"
            return 1
        fi
        log_info "[FORK] Compilation réussie"
    fi
    
    # Exécuter fork_runner avec les paramètres requis
    log_info "[FORK] Lancement fork_runner (mode parallèle avec fork())"
    log_info "[FORK] Commande: $fork_bin ${SCRIPT_DIR}/fraud_detector.sh $csv_file $threshold $LOG_FILE"
    
    "$fork_bin" "${SCRIPT_DIR}/fraud_detector.sh" "$csv_file" "$threshold" "$LOG_FILE"
    
    local ret=$?
    if [ $ret -eq 0 ]; then
        log_info "[FORK] fork_runner terminé avec succès"
    else
        log_error "[FORK] fork_runner échec (code: $ret)"
    fi
    
    return $ret
}

# Lance les 5 algorithmes via thread_runner.c (pthreads POSIX)
# $1 : contenu CSV  $2 : chemin du fichier CSV
run_threads() {
    local csv_content="$1"
    local csv_file="$2"
    local threshold="${THRESHOLD:-8000}"
    
    local thread_bin="${SCRIPT_DIR}/thread_runner"
    local thread_src="${SCRIPT_DIR}/src/thread_runner.c"
    
    # Vérifier si thread_runner existe, sinon le compiler
    if [ ! -f "$thread_bin" ]; then
        log_info "[THREADS] Compilation de thread_runner.c..."
        gcc -o "$thread_bin" "$thread_src" -lpthread 2>&1 | while read line; do log_info "[GCC] $line"; done
        
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            log_error "[THREADS] Échec compilation thread_runner"
            return 1
        fi
        log_info "[THREADS] Compilation réussie"
    fi
    
    # Exécuter thread_runner avec les paramètres requis
    log_info "[THREADS] Lancement thread_runner (mode parallèle avec pthreads)"
    log_info "[THREADS] Commande: $thread_bin ${SCRIPT_DIR}/fraud_detector.sh $csv_file $threshold $LOG_FILE"
    
    "$thread_bin" "${SCRIPT_DIR}/fraud_detector.sh" "$csv_file" "$threshold" "$LOG_FILE"
    
    local ret=$?
    if [ $ret -eq 0 ]; then
        log_info "[THREADS] thread_runner terminé avec succès"
    else
        log_error "[THREADS] thread_runner échec (code: $ret)"
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
