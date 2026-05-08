#!/bin/bash

# Lance les 5 algorithmes en parallèle via sous-shells bash
# $1 : contenu CSV  $2 : chemin du fichier CSV
run_subshell() {
    local csv_content="$1"
    local csv_file="$2"
    
    log_info "[SUBSHELL] Lancement de 5 sous-shells en parallèle"
    
    # Créer un fichier temporaire pour les résultats
    local tmp_dir="${SCRIPT_DIR}/tmp"
    mkdir -p "$tmp_dir"
    local result_file="$tmp_dir/subshell_results_$$.txt"
    > "$result_file"
    
    # Lancer les 5 algos en arrière-plan
    (
        log_info "[SUBSHELL-1] HIGH_AMOUNT démarré"
        detect_high_amount "$csv_content"
        echo "high:$?" >> "$result_file"
    ) &
    
    (
        log_info "[SUBSHELL-2] FREQUENCY_ANOMALY démarré"
        detect_frequency_anomaly "$csv_content"
        echo "frequency:$?" >> "$result_file"
    ) &
    
    (
        log_info "[SUBSHELL-3] BEHAVIOR_CHANGE démarré"
        detect_behavior_change "$csv_content"
        echo "behavior:$?" >> "$result_file"
    ) &
    
    (
        log_info "[SUBSHELL-4] STRUCTURING démarré"
        detect_structuring "$csv_content"
        echo "structuring:$?" >> "$result_file"
    ) &
    
    (
        log_info "[SUBSHELL-5] ACCOUNT_SWITCHING démarré"
        detect_account_switching "$csv_content"
        echo "switching:$?" >> "$result_file"
    ) &
    
    # Attendre que tous les sous-shells se terminent
    log_info "[SUBSHELL] Attente de la fin des 5 sous-shells..."
    wait
    
    # Compter le nombre total d'alertes
    local total_alerts=0
    while IFS=: read -r algo code; do
        log_info "[SUBSHELL] $algo terminé avec code $code"
        # Code 0 = fraude détectée, code 1 = pas de fraude
        if [[ "$code" == "0" ]]; then
            ((total_alerts++))
        fi
    done < "$result_file"
    rm -f "$result_file"
    log_info "[SUBSHELL] Terminé - $total_alerts algorithme(s) ont détecté des fraudes"
    
    return "$total_alerts"
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

