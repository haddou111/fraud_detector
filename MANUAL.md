# FRAUD_DETECTOR.SH — Manuel Complet

## Vue d'ensemble

`fraud_detector.sh` est un système de détection de fraude bancaire qui analyse des fichiers CSV de transactions. Il supporte 3 modes d'exécution parallèles : **subshell**, **fork**, et **threads**.

---

## SYNTAXE GÉNÉRALE

```bash
./fraud_detector.sh [MODE] [OPTIONS] <fichier.csv>
```

---

## MODES D'EXÉCUTION (Obligatoire)

### `-s` — Mode Subshell (Sous-processus Bash)

```bash
./fraud_detector.sh -s data/transactions_light.csv
```

**Comportement** :
- Lance 5 algorithmes de détection en **parallèle via des sous-shells Bash**
- Chaque détection s'exécute dans un processus Bash indépendant
- Pas d'appel système `fork()` natif
- Plus léger que fork/threads

**Quand l'utiliser** :
- Systèmes sans support fork natif
- Petits fichiers CSV
- Tests rapides

---

### `-f` — Mode Fork (Appels système fork/wait)

```bash
./fraud_detector.sh -f data/transactions_medium.csv
```

**Comportement** :
- Compile et lance `fork_runner.c` (programme C)
- Crée **2 processus fils** via `fork()` (appel système Linux)
- Fils 1 : détecte les montants élevés (`--internal-high`)
- Fils 2 : détecte les anomalies de fréquence (`--internal-frequency`)
- Parent attend les 2 fils avec `waitpid()`
- Exécution **vraiment parallèle** sur multi-cœur

**Quand l'utiliser** :
- Fichiers CSV moyens à gros
- Besoin de vraie parallélisation
- Systèmes Linux/Unix

**Exemple avec options** :
```bash
./fraud_detector.sh -f --threshold 5000 --report data/transactions_medium.csv
```

---

### `-t` — Mode Threads (POSIX pthreads)

```bash
./fraud_detector.sh -t data/transactions_heavy.csv
```

**Comportement** :
- Compile et lance `thread_runner.c` (programme C)
- Crée **5 threads POSIX** (pthreads)
- Chaque thread exécute un algorithme de détection
- Partage la même mémoire (plus rapide que fork)
- Synchronisation via `pthread_join()`

**Quand l'utiliser** :
- Fichiers CSV très gros
- Besoin de partage mémoire efficace
- Systèmes avec support pthreads

---

## OPTIONS GLOBALES

### `--threshold N`

Définit le seuil de montant suspect (en unités monétaires).

```bash
./fraud_detector.sh -f --threshold 10000 data/transactions.csv
```

**Défaut** : 8000  
**Type** : Nombre entier positif

---

### `--window N`

Fenêtre temporelle pour détecter les anomalies de fréquence (en minutes).

```bash
./fraud_detector.sh -f --window 10 data/transactions.csv
```

**Défaut** : 5 minutes  
**Type** : Nombre entier positif

---

### `--user NOM`

Filtre l'analyse sur un utilisateur spécifique.

```bash
./fraud_detector.sh -f --user alice data/transactions.csv
```

**Défaut** : Tous les utilisateurs  
**Type** : Chaîne de caractères

---

### `--report`

Génère un rapport texte dans le répertoire `reports/`.

```bash
./fraud_detector.sh -f --report data/transactions.csv
```

**Résultat** : Crée `reports/rapport_YYYYMMDD_HHMMSS.txt`

---

### `--stats`

Affiche les statistiques du fichier CSV (nombre de transactions, utilisateurs, etc.).

```bash
./fraud_detector.sh -f --stats data/transactions.csv
```

---

### `--export FICHIER`

Exporte les alertes détectées dans `reports/FICHIER`.

```bash
./fraud_detector.sh -f --export alertes.txt data/transactions.csv
```

**Résultat** : Crée `reports/alertes.txt`

---

### `-l RÉPERTOIRE`

Spécifie un répertoire de logs personnalisé.

```bash
./fraud_detector.sh -f -l /tmp/my_logs data/transactions.csv
```

**Défaut** : `logs/`

---

### `-h, --help`

Affiche l'aide courte.

```bash
./fraud_detector.sh --help
```

---

### `-r`

Restaure les logs (mode maintenance).

```bash
./fraud_detector.sh -r
```

---

## FLAGS INTERNES (Réservés au programme C)

 **NE PAS UTILISER DIRECTEMENT** — Ces flags sont utilisés par `fork_runner.c` et `thread_runner.c`.

### `--internal-high`

Détecte les montants élevés (utilisé par Fils 1 en mode fork).

```bash
#  NE PAS FAIRE :
./fraud_detector.sh --internal-high data/transactions.csv

#  À LA PLACE :
./fraud_detector.sh -f data/transactions.csv
```

### `--internal-frequency`

Détecte les anomalies de fréquence (utilisé par Fils 2 en mode fork).

### `--internal-behavior`

Détecte les changements de comportement (réservé pour expansion).

### `--internal-structuring`

Détecte le structuring (réservé pour expansion).

### `--internal-switching`

Détecte le account switching (réservé pour expansion).

### `--log-file FICHIER`

Spécifie le fichier log (utilisé par les programmes C).

```bash
#  NE PAS FAIRE :
./fraud_detector.sh --log-file logs/custom.log data/transactions.csv

#  À LA PLACE :
./fraud_detector.sh -f -l logs/ data/transactions.csv
```

---

## EXEMPLES D'UTILISATION

### Exemple 1 : Analyse simple en mode fork

```bash
./fraud_detector.sh -f data/transactions_light.csv
```

**Résultat** :
- Lance 2 fils en parallèle
- Affiche les alertes détectées
- Crée un log dans `logs/fraud_detector_YYYYMMDD.log`

---

### Exemple 2 : Analyse avec seuil personnalisé et rapport

```bash
./fraud_detector.sh -f --threshold 5000 --report data/transactions_medium.csv
```

**Résultat** :
- Seuil abaissé à 5000
- Génère un rapport dans `reports/rapport_*.txt`
- Affiche le résumé final

---

### Exemple 3 : Analyse d'un utilisateur spécifique en mode threads

```bash
./fraud_detector.sh -t --user bob --stats data/transactions_heavy.csv
```

**Résultat** :
- Filtre sur l'utilisateur "bob"
- Affiche les statistiques du CSV
- Lance 5 threads pour l'analyse complète

---

### Exemple 4 : Analyse en mode subshell avec export

```bash
./fraud_detector.sh -s --export alertes_export.txt data/transactions_light.csv
```

**Résultat** :
- Lance 5 sous-shells Bash
- Exporte les alertes dans `reports/alertes_export.txt`

---

### Exemple 5 : Fenêtre temporelle personnalisée

```bash
./fraud_detector.sh -f --window 15 data/transactions_medium.csv
```

**Résultat** :
- Détecte les anomalies de fréquence sur une fenêtre de 15 minutes (au lieu de 5)

---

## FICHIERS DE DONNÉES

### Fichiers CSV disponibles

| Fichier | Taille | Utilisation |
|---------|--------|-------------|
| `data/transactions_light.csv` | Petit | Tests rapides, développement |
| `data/transactions_medium.csv` | Moyen | Tests normaux, fork recommandé |
| `data/transactions_heavy.csv` | Gros | Tests de performance, threads recommandé |

---

## FICHIERS DE SORTIE

### Logs

```
logs/
├── fraud_detector_20260503.log    # Log principal
└── .gitkeep
```

### Rapports

```
reports/
├── rapport_20260503_143022.txt    # Rapport généré avec --report
└── alertes_export.txt             # Alertes exportées avec --export
```

---

## CODES DE RETOUR

| Code | Signification |
|------|---------------|
| 0 | Succès |
| 1 | Erreur générale |
| 2 | Fichier CSV invalide |
| 3 | Mode non spécifié |
| 4 | Paramètre manquant |

---

## COMPARAISON DES MODES

| Aspect | Subshell (-s) | Fork (-f) | Threads (-t) |
|--------|---------------|-----------|-------------|
| **Processus créés** | 5 sous-shells | 2 processus | 5 threads |
| **Parallélisme** | Pseudo-parallèle | Vrai parallèle | Vrai parallèle |
| **Partage mémoire** | Non | Non | Oui |
| **Overhead** | Faible | Moyen | Faible |
| **Fichiers petits** |  Bon |  Overkill |  Overkill |
| **Fichiers moyens** | Lent |  Optimal |  Bon |
| **Fichiers gros** |  Très lent |  Bon |  Optimal |

---

## DÉPANNAGE

### Erreur : "Aucun mode spécifié"

```bash
#  MAUVAIS :
./fraud_detector.sh data/transactions.csv

#  BON :
./fraud_detector.sh -f data/transactions.csv
```

### Erreur : "Fichier CSV manquant"

```bash
#  MAUVAIS :
./fraud_detector.sh -f

#  BON :
./fraud_detector.sh -f data/transactions.csv
```

### Erreur : "fork_runner.c non compilé"

```bash
# Compile manuellement :
gcc -o fork_runner src/fork_runner.c
```

### Logs vides ou manquants

```bash
# Vérifier les permissions :
ls -la logs/

# Restaurer les logs :
./fraud_detector.sh -r
```

---

## NOTES IMPORTANTES

1. **Toujours spécifier un mode** (`-s`, `-f`, ou `-t`)
2. **Ne pas mélanger les modes** : `./fraud_detector.sh -f -t` est invalide
3. **Les flags `--internal-*` sont réservés** au programme C
4. **Le fichier CSV doit exister** et être lisible
5. **Les rapports sont créés dans `reports/`** (créé automatiquement)
6. **Les logs sont créés dans `logs/`** (créé automatiquement)

## VOIR AUSSI

- `fraud_detector.sh --help` — Aide courte
- `lib/detector.sh` — Algorithmes de détection
- `src/fork_runner.c` — Implémentation fork
- `src/thread_runner.c` — Implémentation threads

