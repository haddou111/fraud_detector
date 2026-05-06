# Corrections Finales - Problèmes de Détection

## Problèmes Identifiés et Corrigés

### 1. **Caractères de retour chariot Windows (`\r`)**

**Symptôme :** 
```
WARNING : [DETECTOR] Format de montant invalide pour transaction 1: 340
```

**Cause :** Les fichiers CSV contiennent des retours chariot Windows (`\r\n`) au lieu de Unix (`\n`). Quand on lit `amount`, il contient `"340\r"` qui ne match pas la regex `^[0-9]+(\.[0-9]+)?$`.

**Solution :** Ajouter `\r` dans tous les `tr -d` :
```bash
# Avant
amount=$(echo "$amount" | tr -d ' ')

# Après
amount=$(echo "$amount" | tr -d ' \r')
```

**Fichiers modifiés :**
- `lib/detector.sh` : 8 occurrences corrigées dans tous les algos

---

### 2. **Codes de retour inversés**

**Symptôme :**
```
[MODE INTERNE] Terminé avec 1 alerte(s)
...
Terminé — 9 transactions — 0 alertes  ← PROBLÈME : devrait être > 0
```

**Cause :** Les fonctions `detect_*()` retournaient :
```bash
return $((1 - found))  # found=1 → retourne 0, found=0 → retourne 1
```

Mais en bash :
- `return 0` = **succès** (pas d'erreur)
- `return 1` = **échec** (erreur)

Donc quand une fraude était détectée (`found=1`), la fonction retournait `0` (succès), ce qui était interprété comme "pas de fraude".

**Solution :** Inverser la logique :
```bash
if [ $found -eq 1 ]; then
    _detector_warn "HIGH_AMOUNT: Détection(s) trouvée(s)"
    return 0  # Succès : fraude détectée
else
    _detector_info "HIGH_AMOUNT: Aucune détection"
    return 1  # Pas de fraude
fi
```

**Fichiers modifiés :**
- `lib/detector.sh` : 5 fonctions corrigées
  - `detect_high_amount()`
  - `detect_frequency_anomaly()`
  - `detect_behavior_change()`
  - `detect_structuring()`
  - `detect_account_switching()`

---

## Test de Validation

Après corrections, relance le test :

```bash
bash fraud_detector.sh -t data/transactions_heavy.csv
```

**Résultat attendu :**
```
Terminé — 9 transactions — X alertes  (X > 0 si fraudes détectées)
```

Au lieu de :
```
Terminé — 9 transactions — 0 alertes  (incorrect)
```

---

## Vérification des Logs

Les logs doivent maintenant montrer :
1. ✅ Pas de warnings "Format de montant invalide"
2. ✅ Les alertes `[ALERT]` s'affichent dans le terminal
3. ✅ Le compteur final d'alertes est correct

---

## Commandes de Test Recommandées

```bash
# Test avec seuil bas pour forcer des détections
bash fraud_detector.sh -s --threshold 3000 data/transactions_heavy.csv

# Test mode fork
bash fraud_detector.sh -f --threshold 5000 data/transactions_medium.csv

# Test mode threads avec rapport
bash fraud_detector.sh -t --report --threshold 6000 data/transactions_heavy.csv

# Vérifier le rapport généré
cat reports/rapport_*.txt
```

---

## Résumé des Changements

| Fichier | Lignes Modifiées | Type de Correction |
|---------|------------------|-------------------|
| lib/detector.sh | ~60-70 | Ajout `\r` dans `tr -d` |
| lib/detector.sh | ~90 | Inversion return HIGH_AMOUNT |
| lib/detector.sh | ~160 | Inversion return FREQUENCY |
| lib/detector.sh | ~220 | Inversion return BEHAVIOR |
| lib/detector.sh | ~280 | Inversion return STRUCTURING |
| lib/detector.sh | ~340 | Inversion return ACCOUNT_SWITCHING |

---

## Notes Techniques

### Pourquoi `\r` pose problème ?

Quand bash lit une ligne avec `read`, il garde le `\r` :
```bash
# Fichier contient : "340\r\n"
read amount  # amount="340\r"
echo "$amount" | grep -qE '^[0-9]+$'  # ÉCHOUE car \r n'est pas un chiffre
```

### Convention des codes de retour

En bash/Unix :
- `0` = succès, tout va bien
- `1-255` = erreur, problème détecté

Pour notre cas :
- Fraude détectée = événement **réussi** → `return 0`
- Pas de fraude = rien à signaler → `return 1`

C'est contre-intuitif mais c'est la convention Unix.
