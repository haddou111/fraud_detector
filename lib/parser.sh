#!/bin/bash
# ============================================
# Script  : parser.sh
# Auteur  : Djelika
# Date    : 2026-05-03
# Version : 1.1
# Usage   : Sourcé par fraud_detector.sh
# ============================================

<<<<<<< HEAD
# Charge le fichier logger.sh qui contient log_error(), log_info() et FILE_LOG
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logger.sh"
=======
# Note: SCRIPT_DIR est déjà défini par fraud_detector.sh
# Ne pas le redéfinir ici pour éviter les conflits de chemins
>>>>>>> 9dba09f1841e58183f594750a04aff01067ef8dc


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
    local expected="ID|TIMESTAMP|USER|SOURCE_ACCOUNT|DEST_ACCOUNT|AMOUNT"
    local header

    header=$(head -n 1 "$file" | tr -d '\r')

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
#   $1 = id
#   $2 = timestamp
#   $3 = user
#   $4 = source_account
#   $5 = dest_account
#   $6 = amount
# Retour   : 0 si valide, 1 si erreur(s) détectée(s)
# ============================================
validate_columns() {
    local id="$1"
    local timestamp="$2"
    local user="$3"
    local source_account="$4"
    local dest_account="$5"
    local amount="$6"
    local valid=0

    if [[ -z "$id" || ! "$id" =~ ^[0-9]+$ ]]; then
        log_error "ID invalide: $id"
        valid=1
    fi

    if [[ -z "$timestamp" || ! "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || ! date -d "$timestamp" >/dev/null 2>&1; then
        log_error "TIMESTAMP invalide: $timestamp"
        valid=1
    fi

    if [[ -z "$user" || ! "$user" =~ ^[A-Za-z]+$ ]]; then
        log_error "USER invalide: $user"
        valid=1
    fi

    if [[ -z "$source_account" || ! "$source_account" =~ ^ACC[0-9]+$ ]]; then
        log_error "SOURCE_ACCOUNT invalide: $source_account"
        valid=1
    fi

    if [[ -z "$dest_account" || ! "$dest_account" =~ ^ACC[0-9]+$ ]]; then
        log_error "DEST_ACCOUNT invalide: $dest_account"
        valid=1
    fi

    if [[ -z "$amount" || ! "$amount" =~ ^[0-9]+([.][0-9]{1,2})?$ || "$amount" == "0" ]]; then
        log_error "AMOUNT invalide: $amount"
        valid=1
    fi

    return "$valid"
}

# ============================================
# Fonction : parse_line
# But      : Parse une ligne CSV et valide ses champs
# Arguments: $1 = ligne CSV brute
# Retour   : 0 si valide, 1 sinon
# Note     : Ordre des colonnes : ID|TIMESTAMP|USER|SOURCE_ACCOUNT|DEST_ACCOUNT|AMOUNT
# ============================================
parse_line() {
    local line="$1"

    IFS='|' read -r ID TIMESTAMP USER SOURCE_ACCOUNT DEST_ACCOUNT AMOUNT <<< "$line"

    if ! validate_columns "$ID" "$TIMESTAMP" "$USER" "$SOURCE_ACCOUNT" "$DEST_ACCOUNT" "$AMOUNT"; then
        return 1
    fi

    return 0
}

# ============================================
# Fonction : filter_by_user
# But      : Filtre les transactions selon un utilisateur donné
# Arguments:
#   $1 = chemin du fichier CSV
#   $2 = nom d'utilisateur (vide = retourner tout)
# Retour   : Données CSV sur stdout (sans header)
# ============================================
filter_by_user() {
    local file="$1"
    local user_filter="$2"

    # Debug
    [[ -n "$DEBUG" ]] && log_info "[DEBUG] filter_by_user: file=$file, user=$user_filter"

    # Si aucun utilisateur donné, retourner tout sauf header
    if [[ -z "$user_filter" ]]; then
<<<<<<< HEAD
        while IFS= read -r line; do
            log_info "$line"
        done < "$file"
        return 0
    fi

    # Afficher l'en-tête
    log_info "$(head -n 1 "$file")"

    # Filtrer selon la colonne USER (colonne 3) en ignorant l'en-tête
    while IFS= read -r line; do
        log_info "$line"
    done < <(awk -F'|' -v user="$user_filter" 'NR>1 && $3==user' "$file")

=======
        tail -n +2 "$file"
        return 0
    fi

    # Filtrer selon la colonne USER (colonne 3) en ignorant l'en-tête
    awk -F'|' -v user="$user_filter" 'NR>1 && $3==user' "$file"
    
>>>>>>> 9dba09f1841e58183f594750a04aff01067ef8dc
    return 0
}

# ============================================
# Fonction : show_stats
# But      : Affiche le min, max et la moyenne de la colonne amount (col 6)
# Arguments: $1 = chemin du fichier CSV
# Note     : Ignore l'en-tête (NR>1)
# ============================================
show_stats() {
    local file="$1"

<<<<<<< HEAD
=======
    [[ -n "$DEBUG" ]] && log_info "[DEBUG] show_stats: file=$file"

    echo -e "\n${BOLD}${BLUE}═══════════════ STATISTIQUES ═══════════════${RESET}"
    
>>>>>>> 9dba09f1841e58183f594750a04aff01067ef8dc
    awk -F'|' '
    NR > 1 {
        amount = $6 + 0
        if (count == 0 || amount < min) min = amount
        if (count == 0 || amount > max) max = amount
        sum += amount
        count++
    }
    END {
        if (count > 0) {
<<<<<<< HEAD
            print "Le minimum des montants : " min
            print "Le maximum des montants : " max
            print "Moyenne des montants : " sum / count
        } else {
            print "Aucune transaction trouvée"
        }
    }' "$file" | while IFS= read -r line; do
        log_info "$line"
    done
=======
            printf "  Transactions : %d\n", count
            printf "  Minimum      : %.2f MAD\n", min
            printf "  Maximum      : %.2f MAD\n", max
            printf "  Moyenne      : %.2f MAD\n", sum / count
        } else {
            print "  Aucune transaction trouvée"
        }
    }' "$file"
    
    echo -e "${BLUE}═════════════════════════════════════════════${RESET}\n"
>>>>>>> 9dba09f1841e58183f594750a04aff01067ef8dc
}