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
