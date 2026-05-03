#!/bin/bash

# Vérifie qu'une commande est disponible
require_cmd() {
    command -v "$1" &>/dev/null || { log_error "Commande requise introuvable: $1"; exit 1; }
}

# Vérifie qu'un fichier existe et est lisible
require_file() {
    [[ -r "$1" ]] || { log_error "Fichier introuvable ou illisible: $1"; exit 1; }
}

# Affiche l'usage
usage() {
    echo "Usage: $0 [--mode léger|moyen|lourd] [--input fichier.csv]"
    exit 0
}

# reccourci d'arret 
die() {
    local code="$1"
    local message="$2"
    echo -e "${RED}[ERREUR]${RESET} $message" >&2
    exit "$code"
}


# Vérifie si l'utilisateur courant est root
check_root() {
    : # TODO: implémenter
}

# Affiche l'aide complète
show_help() {
    cat <<EOF
Usage: ./fraud_detector.sh [OPTIONS] <fichier.csv>

Modes d'exécution (obligatoire) :
  -s              Mode subshell
  -f              Mode fork
  -t              Mode threads

Options :
  --threshold N   Seuil de montant suspect (défaut: 8000)
  --window N      Fenêtre temporelle en minutes (défaut: 5)
  --user NOM      Filtrer par utilisateur
  --report        Générer un rapport texte
  --stats         Afficher les statistiques du CSV
  --export FILE   Exporter les alertes dans reports/FILE
  -l DIR          Répertoire de logs personnalisé
  -h, --help      Afficher cette aide

Exemples :
  ./fraud_detector.sh -s data/transactions_light.csv
  ./fraud_detector.sh -f --threshold 5000 data/transactions_medium.csv
  ./fraud_detector.sh -t --report data/transactions_heavy.csv
EOF
}
