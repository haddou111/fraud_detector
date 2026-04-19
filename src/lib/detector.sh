#!/bin/bash
# detector.sh — Algorithmes de détection de fraude


# Point d'entrée principal de détection pour une transaction
analyze_transaction() {
    local transaction_id="$1" amount="$2"
    if detect_high_amount "$amount"; then
        log_warn "Fraude potentielle détectée — ID: $transaction_id, Montant: $amount"
        return 1
    fi
    return 0
}
