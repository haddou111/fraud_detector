#!/bin/bash

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
