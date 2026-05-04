#!/bin/bash
# detector.sh — Algorithmes de détection de fraude
# Utilisé par fraud_detector.sh via : source lib/detector.sh
#
# Variables globales attendues (définies dans fraud_detector.sh) :
#   THRESHOLD      : seuil montant (défaut 8000)
#   WINDOW_MINUTES : fenêtre temporelle en minutes (défaut 5)

# ─────────────────────────────────────────────
# ALGO 1 — HIGH_AMOUNT
# Détecte toute transaction dont le montant dépasse THRESHOLD
# $1 : contenu CSV complet (texte, sans header)
# ─────────────────────────────────────────────
detect_high_amount() {
    local csv_data="$1"
    local threshold="${THRESHOLD:-8000}"
    local found=0

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
            continue
        fi

        # Comparer avec le seuil (en entier pour éviter les problèmes de virgule)
        if [ "$(echo "$amount > $threshold" | bc 2>/dev/null)" = "1" ]; then
            echo "[ALERT] $timestamp | HIGH_AMOUNT | User: $user | Amount: $amount MAD | $src_acc → $dest_acc"
            found=1
        fi
    done <<< "$csv_data"

    return $((1 - found))  # retourne 0 si au moins une alerte, 1 sinon
}

# ─────────────────────────────────────────────
# ALGO 2 — FREQUENCY_ANOMALY
# Détecte les utilisateurs qui font plus de 3 transactions en WINDOW_MINUTES
# $1 : contenu CSV complet (texte, sans header)
# ─────────────────────────────────────────────
detect_frequency_anomaly() {
    local csv_data="$1"
    local window="${WINDOW_MINUTES:-5}"
    local window_sec=$((window * 60))
    local found=0

    # Récupérer la liste des utilisateurs uniques
    local users
    users=$(echo "$csv_data" | awk -F'|' '{gsub(/ /, "", $3); print $3}' | sort -u)

    for user in $users; do
        # Récupérer tous les timestamps de cet utilisateur, convertis en epoch
        local timestamps=()
        while IFS='|' read -r id timestamp u src_acc dest_acc amount; do
            u=$(echo "$u" | tr -d ' ')
            if [ "$u" = "$user" ]; then
                # Convertir timestamp "2026-04-10 10:02:00" en epoch Unix
                local epoch
                epoch=$(date -d "$(echo "$timestamp" | xargs)" +%s 2>/dev/null)
                if [ -n "$epoch" ]; then
                    timestamps+=("$epoch")
                fi
            fi
        done <<< "$csv_data"

        # Trier les timestamps
        IFS=$'\n' sorted=($(sort -n <<< "${timestamps[*]}")); unset IFS

        # Fenêtre glissante : compter combien de transactions en < window_sec
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
                echo "[ALERT] FREQUENCY_ANOMALY | User: $user | $count transactions en moins de ${window} min"
                found=1
                break  # une seule alerte par utilisateur
            fi
        done
    done

    return $((1 - found))
}

# ─────────────────────────────────────────────
# ALGO 3 — BEHAVIOR_CHANGE
# Détecte un passage brutal de petits à grands montants (ratio > 10x)
# $1 : contenu CSV complet (texte, sans header)
# ─────────────────────────────────────────────
detect_behavior_change() {
    local csv_data="$1"
    local ratio_threshold=10
    local found=0

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
        local sum=${amounts[0]}
        for ((i=1; i<n; i++)); do
            local avg=$((sum / i))
            local current=${amounts[$i]%.*}  # partie entière
            avg_int=${avg%.*}

            if [ "$avg_int" -gt 0 ]; then
                local ratio=$((current / avg_int))
                if [ "$ratio" -ge "$ratio_threshold" ]; then
                    echo "[ALERT] BEHAVIOR_CHANGE | User: $user | Montant habituel ~${avg_int} MAD → Montant actuel: ${current} MAD (ratio x${ratio})"
                    found=1
                    break
                fi
            fi

            sum=$((sum + ${amounts[$i]%.*}))
        done
    done

    return $((1 - found))
}

# ─────────────────────────────────────────────
# ALGO 4 — STRUCTURING (Smurfing)
# Détecte des transactions répétées entre 90% et 100% du seuil
# Ces montants sont juste en-dessous du seuil pour éviter la détection
# $1 : contenu CSV complet (texte, sans header)
# ─────────────────────────────────────────────
detect_structuring() {
    local csv_data="$1"
    local threshold="${THRESHOLD:-8000}"
    # Zone suspecte : entre 90% et 100% du seuil
    local low=$(echo "$threshold * 90 / 100" | bc)
    local found=0

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
        fi
    done <<< "$csv_data"

    # Alerter si un utilisateur a fait ≥ 2 transactions dans cette zone
    for user in "${!user_count[@]}"; do
        if [ "${user_count[$user]}" -ge 2 ]; then
            echo "[ALERT] STRUCTURING | User: $user | ${user_count[$user]} transactions entre ${low} et ${threshold} MAD (zone de smurfing)"
            found=1
        fi
    done

    return $((1 - found))
}

# ─────────────────────────────────────────────
# ALGO 5 — ACCOUNT_SWITCHING
# Détecte les changements fréquents de compte destinataire (> 3 comptes différents)
# $1 : contenu CSV complet (texte, sans header)
# ─────────────────────────────────────────────
detect_account_switching() {
    local csv_data="$1"
    local found=0

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
        count=$(echo "$dest_accounts" | grep -c '.')

        if [ "$count" -gt 3 ]; then
            local accounts_list
            accounts_list=$(echo "$dest_accounts" | tr '\n' ',' | sed 's/,$//')
            echo "[ALERT] ACCOUNT_SWITCHING | User: $user | $count comptes destinataires différents: $accounts_list"
            found=1
        fi
    done

    return $((1 - found))
}

# ─────────────────────────────────────────────
# Point d'entrée principal
# Appelé transaction par transaction depuis executor.sh
# $1 : transaction_id
# $2 : amount
# ─────────────────────────────────────────────
analyze_transaction() {
    local transaction_id="$1"
    local amount="$2"
    local threshold="${THRESHOLD:-8000}"

    if [ "$(echo "$amount > $threshold" | bc 2>/dev/null)" = "1" ]; then
        # log_warn doit être défini dans logger.sh (sourcé avant)
        if declare -f log_warn > /dev/null 2>&1; then
            log_warn "Fraude potentielle détectée — ID: $transaction_id, Montant: $amount"
        else
            echo "[WARN] Fraude potentielle détectée — ID: $transaction_id, Montant: $amount"
        fi
        return 1
    fi
    return 0
}