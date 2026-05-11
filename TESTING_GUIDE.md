# Guide de Test Complet — fraud_detector.sh

## Vue d'ensemble

Ce guide explique comment tester ton script `fraud_detector.sh` et vérifier que tous les modes (subshell, fork, threads) fonctionnent correctement.

---

## Prérequis

### 1. Vérifier que les fichiers existent

```bash
ls -la fraud_detector.sh
ls -la lib/
ls -la src/
ls -la data/
```

**Résultat attendu** :
```
fraud_detector.sh
lib/utils.sh
lib/logger.sh
lib/parser.sh
lib/detector.sh
lib/executor.sh
src/fork_runner.c
src/thread_runner.c
data/transactions_light.csv
data/transactions_medium.csv
data/transactions_heavy.csv
```

---

### 2. Rendre le script exécutable

```bash
chmod +x fraud_detector.sh
chmod +x lib/*.sh
```

---

### 3. Compiler les programmes C

```bash
# Compiler fork_runner.c
gcc -o src/fork_runner src/fork_runner.c

# Compiler thread_runner.c (avec support pthreads)
gcc -pthread -o src/thread_runner src/thread_runner.c
```

**Vérifier la compilation** :
```bash
ls -la src/fork_runner
ls -la src/thread_runner
```

---

## Test 1 : Affichage de l'aide

### Commande

```bash
./fraud_detector.sh --help
```

### Résultat attendu

```
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
```

---

## Test 2 : Mode Subshell (-s)

### Commande simple

```bash
./fraud_detector.sh -s data/transactions_light.csv
```

### Résultat attendu

```
[INFO] Chargement du fichier CSV...
[INFO] Démarrage fraud_detector.sh — mode: subshell — fichier: data/transactions_light.csv (100 lignes)

══════════════ ANALYSE EN COURS ══════════════
  Mode     : subshell
  Fichier  : data/transactions_light.csv (100 transactions)
  Seuil    : 8000 MAD
═══════════════════════════════════════════════

[WARN] Fraude potentielle — ID: TXN001, Montant: 15000
[WARN] Fraude potentielle — ID: TXN045, Montant: 12500
...

══════════════════ RÉSUMÉ ═════════════════════
  Transactions analysées : 100
  Alertes générées       : 5
  Log                    : logs/fraud_detector_20260503.log
═══════════════════════════════════════════════
```

### Vérifier le log

```bash
cat logs/fraud_detector_*.log
```

---

## Test 3 : Mode Fork (-f)

### Commande simple

```bash
./fraud_detector.sh -f data/transactions_light.csv
```

### Résultat attendu

```
[FORK MODE] Parent PID=1234 — Création de 5 fils...

[FORK] Fils 1 créé (PID=1235) | Parent PID=1234
[FORK] Fils 2 créé (PID=1236) | Parent PID=1234
[FORK] Fils 3 créé (PID=1237) | Parent PID=1234
[FORK] Fils 4 créé (PID=1238) | Parent PID=1234
[FORK] Fils 5 créé (PID=1239) | Parent PID=1234

[FILS 1] PID=1235 | PPID=1234 | Tâche: --internal-high
[FILS 2] PID=1236 | PPID=1234 | Tâche: --internal-frequency
[FILS 3] PID=1237 | PPID=1234 | Tâche: --internal-behavior
[FILS 4] PID=1238 | PPID=1234 | Tâche: --internal-structuring
[FILS 5] PID=1239 | PPID=1234 | Tâche: --internal-switching

[FORK] Parent en attente des fils (wait)...

[FORK] Fils 1 (PID=1235) terminé — code: 2
[FORK] Fils 2 (PID=1236) terminé — code: 1
[FORK] Fils 3 (PID=1237) terminé — code: 0
[FORK] Fils 4 (PID=1238) terminé — code: 3
[FORK] Fils 5 (PID=1239) terminé — code: 1

[PERF] Mode: fork | Durée: 0.234s | PID parent: 1234 | PIDs fils: 1235, 1236, 1237, 1238, 1239

══════════════════ RÉSUMÉ ═════════════════════
  Transactions analysées : 100
  Alertes générées       : 7
  Log                    : logs/fraud_detector_20260503.log
═══════════════════════════════════════════════
```

### Points à vérifier

✅ Les 5 fils sont créés  
✅ Chaque fils a un PID différent  
✅ Le PPID (parent PID) est le même pour tous  
✅ Les fils terminent avec des codes différents  
✅ La durée d'exécution est affichée  

---

## Test 4 : Mode Threads (-t)

### Commande simple

```bash
./fraud_detector.sh -t data/transactions_light.csv
```

### Résultat attendu

```
[THREAD MODE] Parent PID=1234 — Création de 5 threads...

[THREAD 1] TID=1 | Tâche: --internal-high
[THREAD 2] TID=2 | Tâche: --internal-frequency
[THREAD 3] TID=3 | Tâche: --internal-behavior
[THREAD 4] TID=4 | Tâche: --internal-structuring
[THREAD 5] TID=5 | Tâche: --internal-switching

[THREAD] Parent en attente des threads (join)...

[THREAD] Thread 1 terminé — code: 2
[THREAD] Thread 2 terminé — code: 1
[THREAD] Thread 3 terminé — code: 0
[THREAD] Thread 4 terminé — code: 3
[THREAD] Thread 5 terminé — code: 1

[PERF] Mode: threads | Durée: 0.189s | PID parent: 1234 | Threads: 1, 2, 3, 4, 5

══════════════════ RÉSUMÉ ═════════════════════
  Transactions analysées : 100
  Alertes générées       : 7
  Log                    : logs/fraud_detector_20260503.log
═══════════════════════════════════════════════
```

---

## Test 5 : Algorithme spécifique (--internal-*)

### Tester chaque algorithme

```bash
# Montants élevés
./fraud_detector.sh --internal-high data/transactions_light.csv

# Anomalies de fréquence
./fraud_detector.sh --internal-frequency data/transactions_light.csv

# Changements de comportement
./fraud_detector.sh --internal-behavior data/transactions_light.csv

# Structuring
./fraud_detector.sh --internal-structuring data/transactions_light.csv

# Account switching
./fraud_detector.sh --internal-switching data/transactions_light.csv
```

### Résultat attendu

Chaque commande affiche les alertes pour cet algorithme spécifique.

---

## Test 6 : Options personnalisées

### Test avec seuil personnalisé

```bash
./fraud_detector.sh -f --threshold 5000 data/transactions_light.csv
```

**Résultat attendu** : Plus d'alertes (seuil plus bas)

---

### Test avec filtrage utilisateur

```bash
./fraud_detector.sh -f --user alice data/transactions_light.csv
```

**Résultat attendu** : Alertes seulement pour l'utilisateur "alice"

---

### Test avec rapport

```bash
./fraud_detector.sh -f --report data/transactions_light.csv
```

**Résultat attendu** : Crée un fichier `reports/rapport_*.txt`

```bash
cat reports/rapport_*.txt
```

---

### Test avec statistiques

```bash
./fraud_detector.sh -f --stats data/transactions_light.csv
```

**Résultat attendu** : Affiche les statistiques du CSV

---

### Test avec export

```bash
./fraud_detector.sh -f --export alertes.txt data/transactions_light.csv
```

**Résultat attendu** : Crée `reports/alertes.txt`

```bash
cat reports/alertes.txt
```

**Note :** Pour plus de détails sur l'option --export, consultez le fichier `EXPORT_GUIDE.md`

---

## Test 7 : Fichiers de différentes tailles

### Fichier petit (light)

```bash
./fraud_detector.sh -f data/transactions_light.csv
```

**Temps attendu** : < 0.5s

---

### Fichier moyen (medium)

```bash
./fraud_detector.sh -f data/transactions_medium.csv
```

**Temps attendu** : 0.5s - 2s

---

### Fichier gros (heavy)

```bash
./fraud_detector.sh -f data/transactions_heavy.csv
```

**Temps attendu** : 2s - 5s

---

## Test 8 : Comparaison des modes

### Mesurer les performances

```bash
# Mode subshell
time ./fraud_detector.sh -s data/transactions_medium.csv

# Mode fork
time ./fraud_detector.sh -f data/transactions_medium.csv

# Mode threads
time ./fraud_detector.sh -t data/transactions_medium.csv
```

**Résultat attendu** :
```
Mode subshell : ~2.5s
Mode fork     : ~1.2s (plus rapide)
Mode threads  : ~1.0s (le plus rapide)
```

---

## Test 9 : Vérifier les logs

### Afficher le log complet

```bash
cat logs/fraud_detector_*.log
```

### Filtrer par type d'alerte

```bash
grep "Montant élevé" logs/fraud_detector_*.log
grep "Anomalie fréquence" logs/fraud_detector_*.log
grep "Comportement anormal" logs/fraud_detector_*.log
```

### Compter les alertes

```bash
grep -c "WARN" logs/fraud_detector_*.log
```

---

## Test 10 : Vérifier les codes de retour

### Succès

```bash
./fraud_detector.sh -f data/transactions_light.csv
echo $?  # Affiche 0
```

### Erreur : pas de mode

```bash
./fraud_detector.sh data/transactions_light.csv
echo $?  # Affiche 1
```

### Erreur : fichier inexistant

```bash
./fraud_detector.sh -f data/nonexistent.csv
echo $?  # Affiche 1
```

---

## Test 11 : Cas limites

### Fichier vide

```bash
touch data/empty.csv
./fraud_detector.sh -f data/empty.csv
echo $?
```

**Résultat attendu** : Erreur ou 0 alertes

---

### Fichier avec en-tête seulement

```bash
echo "transaction_id,user_id,amount,timestamp,location" > data/header_only.csv
./fraud_detector.sh -f data/header_only.csv
echo $?
```

**Résultat attendu** : 0 alertes

---

### Utilisateur inexistant

```bash
./fraud_detector.sh -f --user nonexistent data/transactions_light.csv
echo $?
```

**Résultat attendu** : 0 alertes ou erreur

---

## Test 12 : Nettoyage et réinitialisation

### Nettoyer les logs

```bash
rm -f logs/fraud_detector_*.log
```

### Nettoyer les rapports

```bash
rm -f reports/rapport_*.txt
rm -f reports/alertes.txt
```

### Nettoyer les binaires compilés

```bash
rm -f src/fork_runner
rm -f src/thread_runner
```

---

## Script de test automatisé

Crée un fichier `test.sh` :

```bash
#!/bin/bash

echo "========== TEST 1 : Aide =========="
./fraud_detector.sh --help

echo -e "\n========== TEST 2 : Mode Subshell =========="
./fraud_detector.sh -s data/transactions_light.csv
echo "Code de retour: $?"

echo -e "\n========== TEST 3 : Mode Fork =========="
./fraud_detector.sh -f data/transactions_light.csv
echo "Code de retour: $?"

echo -e "\n========== TEST 4 : Mode Threads =========="
./fraud_detector.sh -t data/transactions_light.csv
echo "Code de retour: $?"

echo -e "\n========== TEST 5 : Algorithme spécifique =========="
./fraud_detector.sh --internal-high data/transactions_light.csv
echo "Code de retour: $?"

echo -e "\n========== TEST 6 : Avec rapport =========="
./fraud_detector.sh -f --report data/transactions_light.csv
echo "Code de retour: $?"

echo -e "\n========== TEST 7 : Vérifier les logs =========="
echo "Nombre d'alertes :"
grep -c "WARN" logs/fraud_detector_*.log

echo -e "\n========== TOUS LES TESTS TERMINÉS =========="
```

### Exécuter le script de test

```bash
chmod +x test.sh
./test.sh
```

---

## Checklist de test

- [ ] Aide affichée correctement
- [ ] Mode subshell fonctionne
- [ ] Mode fork crée 5 fils
- [ ] Mode threads crée 5 threads
- [ ] Algorithmes spécifiques fonctionnent
- [ ] Seuil personnalisé fonctionne
- [ ] Filtrage utilisateur fonctionne
- [ ] Rapport généré correctement
- [ ] Export fonctionne
- [ ] Logs créés correctement
- [ ] Codes de retour corrects
- [ ] Performances acceptables
- [ ] Pas d'erreurs de compilation
- [ ] Pas de corruption de données

---

## Dépannage

### Erreur : "Commande non trouvée"

```bash
chmod +x fraud_detector.sh
chmod +x lib/*.sh
```

---

### Erreur : "fork_runner.c non compilé"

```bash
gcc -o src/fork_runner src/fork_runner.c
```

---

### Erreur : "Fichier CSV manquant"

```bash
ls -la data/
```

---

### Logs vides

```bash
cat logs/fraud_detector_*.log
```

---

### Pas d'alertes détectées

Vérifier que les algorithmes sont implémentés dans `lib/detector.sh`

---

## Résumé des tests

| Test | Commande | Résultat attendu |
|------|----------|------------------|
| Aide | `./fraud_detector.sh --help` | Affiche l'aide |
| Subshell | `./fraud_detector.sh -s data/transactions_light.csv` | Alertes affichées |
| Fork | `./fraud_detector.sh -f data/transactions_light.csv` | 5 fils créés |
| Threads | `./fraud_detector.sh -t data/transactions_light.csv` | 5 threads créés |
| Algorithme | `./fraud_detector.sh --internal-high data/transactions_light.csv` | Alertes pour cet algo |
| Rapport | `./fraud_detector.sh -f --report data/transactions_light.csv` | Rapport généré |
| Export | `./fraud_detector.sh -f --export alertes.txt data/transactions_light.csv` | Fichier créé |
| Code retour | `./fraud_detector.sh -f data/transactions_light.csv; echo $?` | 0 (succès) |

