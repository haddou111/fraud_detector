#!/bin/bash
# detector.sh — Algorithmes de détection de fraude
# Utilisé par fraud_detector.sh via : source lib/detector.sh
#
# Variables globales attendues (définies dans fraud_detector.sh) :
#   THRESHOLD      : seuil montant (défaut 8000)
#   WINDOW_MINUTES : fenêtre temporelle en minutes (défaut 5)

# ============================================
# FONCTIONS DE WRAPPING POUR LES WARNINGS
# ============================================

# Vérifier si logger est disponible
if declare -f log_warn > /dev/null 2>&1; then
    # Utiliser le logger existant
    _detector_warn() {
        log_warn "[DETECTOR] $*"
    }
    _detector_info() {
        log_info "[DETECTOR] $*"
    }
    _detector_error() {
        log_error "[DETECTOR] $*"
    }
else
    # Fallback si logger non disponible
    _detector_warn() {
        echo -e "\033[0;35m[WARNING][DETECTOR] $(date '+%Y-%m-%d-%H-%M-%S') - $*\033[0m" >&2
    }
    _detector_info() {
        echo -e "\033[0;34m[INFO][DETECTOR] $(date '+%Y-%m-%d-%H-%M-%S') - $*\033[0m"
    }
    _detector_error() {
        echo -e "\033[0;31m[ERROR][DETECTOR] $(date '+%Y-%m-%d-%H-%M-%S') - $*\033[0m" >&2
    }
fi

# ============================================
# ALGORITHMES DE DÉTECTION
# ============================================

# ALGO 1 — HIGH_AMOUNT
# Détecte toute transaction dont le montant dépasse THRESHOLD
detect_high_amount() {
    local csv_data="$1"
    local threshold="${THRESHOLD:-8000}"
    local found=0

    _detector_info "Début détection HIGH_AMOUNT (seuil: ${threshold} MAD)"

    while IFS='|' read -r id timestamp user src_acc dest_acc amount; do
        # Nettoyer les espaces autour des valeurs
        amount=$(echo "$amount" | tr -d ' ')
        id=$(echo "$id" | tr -d ' ')
        user=$(echo "$user" | tr -d ' ')
        timestamp=$(echo "$timestamp" | xargs)
        src_acc=$(echo "$src_acc" | tr -d ' ')
        dest_acc=$(echo "$dest_acc" | tr -d ' ')

        # Vérifier que le montant est un nombre
        if ! echo "$amount" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
            _detector_warn "Format de montant invalide pour transaction $id: $amount"
            continue
        fi

        # Comparer avec le seuil
        if [ "$(echo "$amount > $threshold" | bc 2>/dev/null)" = "1" ]; then
            local alert_msg="HIGH_AMOUNT | User: $user | Amount: $amount MAD | $src_acc → $dest_acc"
            echo "[ALERT] $timestamp | $alert_msg"
            
            # Utiliser logger pour warning
            _detector_warn "ALERTE FRAUDE: $alert_msg"
            found=1
        fi
    done <<< "$csv_data"

    if [ $found -eq 1 ]; then
        _detector_warn "HIGH_AMOUNT: Détection(s) trouvée(s)"
    else
        _detector_info "HIGH_AMOUNT: Aucune détection"
    fi

    return $((1 - found))
}

# ALGO 2 — FREQUENCY_ANOMALY
# Détecte les utilisateurs qui font plus de 3 transactions en WINDOW_MINUTES
detect_frequency_anomaly() {
    local csv_data="$1"
    local window="${WINDOW_MINUTES:-5}"
    local window_sec=$((window * 60))
    local found=0

    _detector_info "Début détection FREQUENCY_ANOMALY (fenêtre: ${window} minutes)"

    # Récupérer la liste des utilisateurs uniques
    local users
    users=$(echo "$csv_data" | awk -F'|' '{gsub(/ /, "", $3); print $3}' | sort -u)

    for user in $users; do
        # Récupérer tous les timestamps de cet utilisateur, convertis en epoch
        local timestamps=()
        while IFS='|' read -r id timestamp u src_acc dest_acc amount; do
            u=$(echo "$u" | tr -d ' ')
            if [ "$u" = "$user" ]; then
                # Convertir timestamp en epoch Unix
                local epoch
                epoch=$(date -d "$(echo "$timestamp" | xargs)" +%s 2>/dev/null)
                if [ -n "$epoch" ]; then
                    timestamps+=("$epoch")
                else
                    _detector_warn "Format timestamp invalide pour $user: $timestamp"
                fi
            fi
        done <<< "$csv_data"

        # Trier les timestamps
        if [ ${#timestamps[@]} -eq 0 ]; then
            continue
        fi
        
        IFS=$'\n' sorted=($(sort -n <<< "${timestamps[*]}")); unset IFS

        # Fenêtre glissante
        local n=${#sorted[@]}
        for ((i=0; i<n; i++)); do
            local count=1
            for ((j=i+1; j<n; j++)); do
                local diff=$(( sorted[j] - sorted[i] ))
                if [ "$diff" -le "$window_sec" ]; then
                    count=$((count + 1))
                else
                    break
                fi
            done
            if [ "$count" -gt 3 ]; then
                local alert_msg="FREQUENCY_ANOMALY | User: $user | $count transactions en moins de ${window} min"
                echo "[ALERT] $alert_msg"
                _detector_warn "ALERTE FRAUDE: $alert_msg"
                found=1
                break
            fi
        done
    done

    if [ $found -eq 1 ]; then
        _detector_warn "FREQUENCY_ANOMALY: Détection(s) trouvée(s)"
    else
        _detector_info "FREQUENCY_ANOMALY: Aucune détection"
    fi

    return $((1 - found))
}

# ALGO 3 — BEHAVIOR_CHANGE
# Détecte un passage brutal de petits à grands montants (ratio > 10x)
detect_behavior_change() {
    local csv_data="$1"
    local ratio_threshold=10
    local found=0

    _detector_info "Début détection BEHAVIOR_CHANGE (ratio seuil: ${ratio_threshold}x)"

    # Récupérer la liste des utilisateurs uniques
    local users
    users=$(echo "$csv_data" | awk -F'|' '{gsub(/ /, "", $3); print $3}' | sort -u)

    for user in $users; do
        local amounts=()

        # Récupérer les montants de cet utilisateur dans l'ordre
        while IFS='|' read -r id timestamp u src_acc dest_acc amount; do
            u=$(echo "$u" | tr -d ' ')
            amount=$(echo "$amount" | tr -d ' ')
            if [ "$u" = "$user" ] && echo "$amount" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
                amounts+=("$amount")
            fi
        done <<< "$csv_data"

        local n=${#amounts[@]}
        if [ "$n" -lt 2 ]; then
            continue
        fi

        # Comparer chaque montant avec la moyenne des précédents
        local sum=$(echo "${amounts[0]}" | cut -d'.' -f1)
        for ((i=1; i<n; i++)); do
            local avg=$((sum / i))
            local current=$(echo "${amounts[$i]}" | cut -d'.' -f1)
            avg_int=${avg%.*}

            if [ "$avg_int" -gt 0 ]; then
                local ratio=$((current / avg_int))
                if [ "$ratio" -ge "$ratio_threshold" ]; then
                    local alert_msg="BEHAVIOR_CHANGE | User: $user | Montant habituel ~${avg_int} MAD → Montant actuel: ${current} MAD (ratio x${ratio})"
                    echo "[ALERT] $alert_msg"
                    _detector_warn "ALERTE FRAUDE: $alert_msg"
                    found=1
                    break
                elif [ "$ratio" -gt 5 ] && [ "$ratio" -lt 10 ]; then
                    # Warning modéré pour changement significatif mais pas seuil critique
                    _detector_warn "Changement modéré détecté pour $user: ratio x${ratio}"
                fi
            fi

            sum=$((sum + $(echo "${amounts[$i]}" | cut -d'.' -f1)))
        done
    done

    if [ $found -eq 1 ]; then
        _detector_warn "BEHAVIOR_CHANGE: Détection(s) trouvée(s)"
    else
        _detector_info "BEHAVIOR_CHANGE: Aucune détection"
    fi

    return $((1 - found))
}

# ALGO 4 — STRUCTURING (Smurfing)
# Détecte des transactions répétées entre 90% et 100% du seuil
detect_structuring() {
    local csv_data="$1"
    local threshold="${THRESHOLD:-8000}"
    # Zone suspecte : entre 90% et 100% du seuil
    local low=$(echo "$threshold * 90 / 100" | bc)
    local found=0

    _detector_info "Début détection STRUCTURING (zone: ${low}-${threshold} MAD)"

    # Compter combien de fois chaque utilisateur est dans cette zone
    declare -A user_count

    while IFS='|' read -r id timestamp user src_acc dest_acc amount; do
        user=$(echo "$user" | tr -d ' ')
        amount=$(echo "$amount" | tr -d ' ')

        if ! echo "$amount" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
            continue
        fi

        local amount_int=${amount%.*}

        # Montant entre low et threshold (exclu) ?
        if [ "$amount_int" -ge "$low" ] && [ "$amount_int" -lt "$threshold" ]; then
            user_count["$user"]=$(( ${user_count["$user"]:-0} + 1 ))
            _detector_info "$user: Transaction suspecte de $amount_int MAD (zone de smurfing)"
        fi
    done <<< "$csv_data"

    # Alerter si un utilisateur a fait ≥ 2 transactions dans cette zone
    for user in "${!user_count[@]}"; do
        if [ "${user_count[$user]}" -ge 2 ]; then
            local alert_msg="STRUCTURING | User: $user | ${user_count[$user]} transactions entre ${low} et ${threshold} MAD (zone de smurfing)"
            echo "[ALERT] $alert_msg"
            _detector_warn "ALERTE FRAUDE: $alert_msg"
            found=1
        elif [ "${user_count[$user]}" -eq 1 ]; then
            _detector_warn "$user: 1 transaction dans zone smurfing - surveillance renforcée"
        fi
    done

    if [ $found -eq 1 ]; then
        _detector_warn "STRUCTURING: Détection(s) trouvée(s)"
    else
        _detector_info "STRUCTURING: Aucune détection"
    fi

    return $((1 - found))
}

# ALGO 5 — ACCOUNT_SWITCHING
# Détecte les changements fréquents de compte destinataire (> 3 comptes différents)
detect_account_switching() {
    local csv_data="$1"
    local found=0

    _detector_info "Début détection ACCOUNT_SWITCHING"

    # Récupérer la liste des utilisateurs uniques
    local users
    users=$(echo "$csv_data" | awk -F'|' '{gsub(/ /, "", $3); print $3}' | sort -u)

    for user in $users; do
        # Récupérer tous les comptes destinataires distincts pour cet utilisateur
        local dest_accounts
        dest_accounts=$(echo "$csv_data" | awk -F'|' -v u="$user" '
            {
                gsub(/ /, "", $3)
                gsub(/ /, "", $6)
                if ($3 == u) print $6
            }
        ' | sort -u)

        local count
        count=$(echo "$dest_accounts" | grep -c '.' 2>/dev/null || echo "0")

        if [ "$count" -gt 3 ]; then
            local accounts_list
            accounts_list=$(echo "$dest_accounts" | tr '\n' ',' | sed 's/,$//')
            local alert_msg="ACCOUNT_SWITCHING | User: $user | $count comptes destinataires différents: $accounts_list"
            echo "[ALERT] $alert_msg"
            _detector_warn "ALERTE FRAUDE: $alert_msg"
            found=1
        elif [ "$count" -eq 2 ] || [ "$count" -eq 3 ]; then
            _detector_info "$user: Changement de compte modéré ($count comptes différents)"
        fi
    done

    if [ $found -eq 1 ]; then
        _detector_warn "ACCOUNT_SWITCHING: Détection(s) trouvée(s)"
    else
        _detector_info "ACCOUNT_SWITCHING: Aucune détection"
    fi

    return $((1 - found))
}

# Point d'entrée principal
# Appelé transaction par transaction depuis executor.sh
analyze_transaction() {
    local transaction_id="$1"
    local amount="$2"
    local threshold="${THRESHOLD:-8000}"

    _detector_info "Analyse transaction $transaction_id (montant: $amount MAD)"

    if [ "$(echo "$amount > $threshold" | bc 2>/dev/null)" = "1" ]; then
        _detector_warn "Fraude potentielle détectée — ID: $transaction_id, Montant: $amount MAD (dépasse seuil ${threshold})"
        return 1
    fi
    
    _detector_info "Transaction $transaction_id validée"
    return 0
}