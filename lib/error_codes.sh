#!/bin/bash

# =============================================================
# error_codes.sh — Codes d'erreur standardisés
# FraudDetect | ENSET Mohammedia 2026
#
# Pattern de codes d'erreur respectant la spécification :
# 100-106 : Erreurs de validation et configuration
# =============================================================

# ── Codes d'erreur standardisés ──────────────────────────────
E_INVALID_OPTION=100        # Option non reconnue dans la liste des options
E_MISSING_PARAM=101         # Le fichier CSV obligatoire n'est pas fourni
E_FILE_NOT_FOUND=102        # Le fichier CSV spécifié n'existe pas
E_PERMISSION_DENIED=103     # Lecture impossible sur le fichier CSV
E_INVALID_CSV=104           # Structure du CSV incorrecte ou corrompue
E_INSUFFICIENT_PRIVILEGE=105 # Option -r exécutée sans droits root/admin
E_INVALID_LOG_DIR=106       # Le chemin spécifié avec -l n'est pas accessible

# ── Documentation des codes d'erreur ─────────────────────────
# Code 100 : Option invalide
#   Exemple : fraud_detector.sh -z data.csv
#   Message : Option inconnue : '-z'
#
# Code 101 : Paramètre manquant
#   Exemple : fraud_detector.sh -f
#   Message : Aucun fichier CSV spécifié.
#
# Code 102 : Fichier introuvable
#   Exemple : fraud_detector.sh -s ghost.csv
#   Message : Fichier CSV introuvable: ghost.csv
#
# Code 103 : Permission refusée
#   Exemple : chmod 000 data.csv
#   Message : Lecture impossible sur le fichier CSV
#
# Code 104 : Format CSV invalide
#   Exemple : Fichier avec < 6 colonnes
#   Message : Structure du CSV incorrecte ou corrompue
#
# Code 105 : Privilège insuffisant
#   Exemple : sudo requis pour -r
#   Message : Option -r exécutée sans droits root/admin
#
# Code 106 : Répertoire log invalide
#   Exemple : -l /root/logs (sans sudo)
#   Message : Le chemin spécifié avec -l n'est pas accessible

# ── Export des variables ─────────────────────────────────────
export E_INVALID_OPTION E_MISSING_PARAM E_FILE_NOT_FOUND
export E_PERMISSION_DENIED E_INVALID_CSV E_INSUFFICIENT_PRIVILEGE
export E_INVALID_LOG_DIR