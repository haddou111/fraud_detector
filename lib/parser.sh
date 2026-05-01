#!/bin/bash

# Valide l'existence, la lisibilité et l'en-tête du fichier CSV
# $1 : chemin du fichier CSV
validate_csv() {
    : # TODO: implémenter
}

# Valide l'en-tête du fichier CSV
validate_header() {
    local file="$1"
    local expected="transaction_id,amount,timestamp,merchant,card_number"
    local header
    header=$(head -1 "$file")
    [[ "$header" == "$expected" ]] || { log_error "En-tête CSV invalide: $header"; return 1; }
}

# Parse une ligne CSV et exporte les champs
parse_line() {
    local line="$1"
    IFS=',' read -r TRANSACTION_ID AMOUNT TIMESTAMP MERCHANT CARD_NUMBER <<< "$line"
}

# Filtre les lignes du CSV selon un utilisateur donné
# $1 : chemin du fichier CSV  $2 : nom d'utilisateur (vide = tout retourner)
filter_by_user() {
    : # TODO: implémenter
}

# Affiche les statistiques du CSV (min, max, moyenne des montants)
# $1 : contenu CSV (texte)
show_stats() {
    : # TODO: implémenter
}
