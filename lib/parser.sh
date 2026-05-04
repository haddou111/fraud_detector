#!/bin/bash
# ============================================
# Script  : parser.sh
# Auteur  : Djelika
# Date    : 2026-05-03
# Version : 1.1
# Usage   : ./parser.sh <fichier.csv> [utilisateur]
# Exemple : ./parser.sh data.csv Alice
# ============================================

# --- Configuration ---
LOG_DIR="/var/log/FRAUD_DETECTOR"
mkdir -p "$LOG_DIR"
HISTORY_LOG="$LOG_DIR/history.log"

# Redirige stdout et stderr vers le terminal ET le fichier log
exec > >(tee -a "$HISTORY_LOG") 2> >(tee -a "$HISTORY_LOG" >&2)

# ============================================
# Fonction : log_error
# But      : Affiche et enregistre un message d'erreur
# Arguments: $1 = message d'erreur
# ============================================
log_error() {
    echo "ERROR: $1" >&2
}


# ============================================
# Fonction : validate_csv
# But      : Vérifie l'existence, la lisibilité et le contenu du fichier CSV
# Arguments: $1 = chemin du fichier CSV
# Retour   : 0 si valide, 1 sinon
# ============================================
validate_csv() {
    local file_CSV="$1"

    # Vérifie si le fichier existe
    if ! [[ -f "$file_CSV" ]]; then
        log_error "Fichier CSV introuvable: $file_CSV"
        return 1
    fi

    # Vérifie si le fichier est lisible
    if ! [[ -r "$file_CSV" ]]; then
        log_error "Impossible de lire le fichier CSV: $file_CSV"
        return 1
    fi

    # Vérifie si le fichier n'est pas vide
    if ! [[ -s "$file_CSV" ]]; then
        log_error "Le fichier CSV est vide: $file_CSV"
        return 1
    fi

    return 0
}

# ============================================
# Fonction : validate_header
# But      : Vérifie que l'en-tête du CSV correspond au format attendu
# Arguments: $1 = chemin du fichier CSV
# Retour   : 0 si valide, 1 sinon
# ============================================
validate_header() {
    local file="$1"
    local expected="transaction_id|amount|timestamp|users|card_number"
    local header
    header=$(head -1 "$file")

    if [[ "$header" != "$expected" ]]; then
        log_error "En-tête CSV invalide: $header"
        return 1
    fi

    return 0
}

# ============================================
# Fonction : validate_columns
# But      : Valide les champs d'une ligne de transaction
# Arguments:
#   $1 = transaction_id
  #  $2 = user
#   $3 = amount
#   $4 = timestamp
#   $5 = card_number
# Retour   : 0 si valide, 1 si erreur(s) détectée(s)
# ============================================
validate_columns() {
    local transaction_id="$1"
    local user="$2"
    local amount="$3"
    local timestamp="$4"
    local card_number="$5"
    local valid=0   # 0 = pas d'erreur

    # Validation du transaction_id
    if [[ -z "$transaction_id" ]]; then
        log_error "transaction_id manquant"
        valid=1
    elif ! [[ "$transaction_id" =~ ^[A-Za-z0-9_-]+$ ]]; then
        log_error "transaction_id invalide: $transaction_id"
        valid=1
    fi

    # Validation du user
    if [[ -z "$user" ]]; then
        log_error "Utilisateur manquant"
        valid=1
    elif ! [[ "$user" =~ ^[A-Za-z]+$ ]]; then
        log_error "Utilisateur invalide: $user"
        valid=1
    fi

    # Validation du montant (nombre positif, max 2 décimales)
    if [[ -z "$amount" ]]; then
        log_error "Amount manquant"
        valid=1
    elif ! [[ "$amount" =~ ^[0-9]+([.][0-9]{1,2})?$ ]]; then
        log_error "Amount invalide: $amount"
        valid=1
    elif [[ "$amount" =~ ^0+([.][0-9]+)?$ ]]; then
        log_error "Amount doit être supérieur à 0: $amount"
        valid=1
    fi

    # Validation du timestamp (format ISO 8601)
    if [[ -z "$timestamp" ]]; then
        log_error "Timestamp manquant"
        valid=1
    elif ! [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] \
        || ! date -d "$timestamp" >/dev/null 2>&1; then
        log_error "Timestamp invalide: $timestamp"
        valid=1
    fi

    # Validation du numéro de carte (format ****XXXX)
    if [[ -z "$card_number" ]]; then
        log_error "card_number manquant"
        valid=1
    elif ! [[ "$card_number" =~ ^\*{4}[0-9]{4}$ ]]; then
        log_error "card_number invalide: $card_number"
        valid=1
    fi

    return "$valid"
}

# ============================================
# Fonction : parse_line
# But      : Parse une ligne CSV et valide ses champs
# Arguments: $1 = ligne CSV brute
# Retour   : 0 si valide, 1 sinon
# Note     : Ordre des colonnes : transaction_id|amount|timestamp|users|card_number
# ============================================
parse_line() {
    local line="$1"

    # Lecture des champs selon l'ordre de l'en-tête
    IFS='|' read -r TRANSACTION_ID AMOUNT TIMESTAMP USERS CARD_NUMBER <<< "$line"

    if ! validate_columns "$TRANSACTION_ID" "$AMOUNT" "$TIMESTAMP" "$USERS" "$CARD_NUMBER"; then
        return 1
    fi

    return 0
}

# ============================================
# Fonction : filter_by_user
# But      : Filtre les transactions selon un utilisateur donné
# Arguments:
#   $1 = chemin du fichier CSV
#   $2 = nom d'utilisateur (vide = afficher tout)
# Retour   : 0 si succès
# ============================================
filter_by_user() {
    local file="$1"
    local user_filter="$2"

    # Si aucun utilisateur donné, afficher tout le fichier
    if [[ -z "$user_filter" ]]; then
        cat "$file" | tee -a "$HISTORY_LOG"
        return 0
    fi

    # Afficher l'en-tête
    head -n 1 "$file" | tee -a "$HISTORY_LOG"

    # Filtrer selon la colonne USERS (colonne 4) en ignorant l'en-tête
    # tee permet d'afficher ET d'enregistrer dans le log en même temps
    awk -v user="$user_filter" 'NR>1 && $4==user' "$file" | tee -a "$HISTORY_LOG"

    return 0
}

# ============================================
# Fonction : show_stats
# But      : Affiche le min, max et la moyenne de la colonne amount (col 2)
# Arguments: $1 = chemin du fichier CSV
# Note     : Ignore l'en-tête (NR>1 / tail -n +2)
# ============================================
show_stats() {
    local file="$1"

    # Tri sur la colonne 2 (amount) en ignorant l'en-tête
    local max
    local min
    max=$(tail -n +2 "$file" | sort -t'|' -k2 -n | tail -1)
    min=$(tail -n +2 "$file" | sort -t'|' -k2 -n | head -1)

    echo "Le maximum des montants : $max" | tee -a "$HISTORY_LOG"
    echo "Le minimum des montants : $min" | tee -a "$HISTORY_LOG"

    # Calcul de la moyenne de la colonne 2 en ignorant l'en-tête
    awk -F'|' 'NR>1 { sum += $2 } END { print "Moyenne des montants:", sum/(NR-1) }' "$file" 
        | tee -a "$HISTORY_LOG"
}