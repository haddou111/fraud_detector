#!/bin/bash
LOG_DIR="/var/log/FRAUD_DETECTOR"
mkdir -p "$LOG_DIR"
HISTORY_LOG="$LOG_DIR/history.log"
exec >>(tee -a "$HISTORY_LOG") 2>>(tee -a "$HISTORY_LOG">2&)
#tee -a sert a ecrire dans un fichier sans écraser le contenu du fichier et a ecrire dans le terminal en mm temps

# Enregistre les erreurs dans stderr
log_error(){
echo "Error:$1" >&2 # le >&2 sert a envoyer le message vers la sortie d'erreur 2

}
#Validez l'existence du fichier csv
validate_csv(){
local file_CSV="$1"

if ! [[ -f "$file_CSV" ]];then
log_error "Fichier CSV introuvable: $file_CSV"
return 1
fi

if ! [[ -r "$file_CSV" ]]; then
log_error "Impossible de lire le fichier csv"
return 1
fi

if ! [[ -s "$file_CSV" ]]; then
log_error "le fichier csv est vide: $file_CSV"
return 1
fi

return 0
}

# Valide l'en-tête du fichier CSV

validate_header() {
    local file="$1"
    local expected="transaction_id|amount|timestamp|users|card_number"
    local header
    header=$(head -1 "$file")
    if [[ "$header" != "$expected" ]]; then
  log_error "En-tête CSV invalide: $header"
  return 1
fi
}

# Valide la validité des champs d'une transaction
validate_columns() {
    local transaction_id="$1"
    local amount="$2"
    local timestamp="$3"
    local merchant="$4"
    local card_number="$5"
    local valid=0 #il n'y a pas d'erreur

    if [[ -z "$transaction_id" ]]; then
        log_error "transaction_id manquant" #sert à enregistrer l’erreur proprement, souvent dans un fichier errors_logs
        valid=1 #signifie qu'il y'a une erreur
    elif  ![[ "$transaction_id" =~ ^[A-Za-z0-9_-]+$ ]]; then
        log_error "transaction_id invalide: $transaction_id"
        valid=1
    fi
if [[ -z "$user" ]]; then
        log_error "utilisateur manquant" #sert à enregistrer l’erreur proprement, souvent dans un fichier errors_logs
        valid=1 #signifie qu'il y'a une erreur
    elif  ![[ "$user" =~ ^[A-Za-z]+$ ]]; then
        log_error "transaction_id invalide: $user"
        valid=1
    fi

    if [[ -z "$amount" ]]; then
        log_error "amount manquant"
        valid=1
    elif ! [[ "$amount" =~ ^[0-9]+([.][0-9]{1,2})?$ ]]; then
        log_error "amount invalide: $amount"
        valid=1
    elif [[ "$amount" =~ ^0+([.][0-9]+)?$ ]]; then
        log_error "amount doit être supérieur à 0: $amount"
        valid=1
    fi

    if [[ -z "$timestamp" ]]; then
        log_error "timestamp manquant"
        valid=1
    elif ! [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || ! date -d "$timestamp" >/dev/null 2>&1; then
        log_error "timestamp invalide: $timestamp"
        valid=1
    fi


    if [[ -z "$card_number" ]]; then
        log_error "card_number manquant"
        valid=1
    elif ! [[ "$card_number" =~ ^\*{4}[0-9]{4}$ ]]; then
        log_error "card_number invalide: $card_number"
        valid=1
    fi

    return "$valid"
}

# Parse une ligne CSV et exporte les champs
parse_line() {
    local line="$1"
    IFS='|' read -r TRANSACTION_ID USERS AMOUNT TIMESTAMP  CARD_NUMBER <<< "$line"

   if ! validate_columns "$TRANSACTION_ID" "$USERS" "$AMOUNT" "$TIMESTAMP" "$CARD_NUMBER"; then
  return 1
fi
}
# Filtre les lignes du CSV selon un utilisateur donné
# $1 : chemin du fichier CSV
# $2 : nom d'utilisateur (vide = tout retourner)
filter_by_user() {
    local file="$1"
    local user_filter="$2"

  # Si aucun utilisateur n'est donné, on affiche tout le fichier
    if [[ -z "$user_filter" ]]; then
        cat "$file"
        return 0
    fi

    # Afficher l'en-tête
    head -n 1 "$file"

    # Filtrer selon la colonne USER, ici colonne 2
    -v user="$user_filter" 'NR > 1 && $2 == user' "$file"

    return 0
} 











#parse_csv() {
 # local file_CSV="$1"
  #local lineawk -F'|' 

  #validate_csv "$file_CSV" || return 1
  #validate_header "$file_CSV" || return 1

  #tail -n +2 "$file_CSV" | while IFS= read -r line; do
   # parse_line "$line" || log_error "Ligne invalide: $line"
  #done

  #return 0
#}

#parse_csv "$1"




