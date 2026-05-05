/*
 * ============================================================
 * subshell_runner.c — Mode Léger : Subshells Bash
 * FraudDetect | ENSET Mohammedia 2026
 *
 * Ce programme démontre les subshells bash :
 *   bash -c "commande &"  → lance un subshell en arrière-plan
 *   wait                  → attend la fin de tous les subshells
 *   getpid()              → identifiant du processus parent
 *
 * Architecture :
 *   Parent (subshell_runner)
 *   ├── Subshell 1 : exécute detect_high_amount
 *   ├── Subshell 2 : exécute detect_frequency_anomaly
 *   ├── Subshell 3 : exécute detect_behavior_change
 *   ├── Subshell 4 : exécute detect_structuring
 *   └── Subshell 5 : exécute detect_account_switching
 *   Parent : attend tous les subshells puis affiche les résultats
 * ============================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>      /* getpid() pour obtenir l'ID du processus actuel */
#include <sys/wait.h>    /* wait() pour la synchronisation des processus */
#include <time.h>        /* clock(), CLOCKS_PER_SEC pour le profilage temporel */

/* Couleurs ANSI pour le terminal */
#define BLUE    "\033[0;34m"
#define CYAN    "\033[0;36m"
#define GREEN   "\033[0;32m"
#define YELLOW  "\033[1;33m"
#define BOLD    "\033[1m"
#define RESET   "\033[0m"

/**
 * launch_subshell - Exécute une commande Bash dans un environnement de subshell.
 * 
 * Cette fonction construit une chaîne de commande complexe qui invoque 'bash'
 * avec les paramètres appropriés, puis utilise system() pour l'exécuter.
 * L'utilisation de '&' à la fin de la commande bash force son exécution 
 * en arrière-plan par rapport au shell invoqué, simulant un comportement de subshell.
 *
 * cript_path: Chemin absolu ou relatif vers le script fraud_detector.sh.
 * mode_flag: Le flag spécifique à l'algorithme de détection (ex: --internal-high).
 * csv_file: Le chemin vers le fichier de données transactions.
 * threshold: Le seuil de détection (MAD) passé en argument.
 * log_file: Le fichier où les logs seront centralisés.
 * subshell_num: Identifiant logique du subshell pour le suivi utilisateur.
 * 
 * Retourne: 0 en cas de succès du lancement, -1 si system() échoue.
 */
int launch_subshell(const char *script_path,
                    const char *mode_flag,
                    const char *csv_file,
                    const char *threshold,
                    const char *log_file,
                    int subshell_num)
{
    /* 
     * Buffer pour la commande interne : on prépare l'appel au script principal 
     * avec tous ses arguments de configuration.
     */
    char cmd[1024];
    snprintf(cmd, sizeof(cmd),
             "bash %s %s --threshold %s --log-file %s %s",
             script_path, mode_flag, threshold, log_file, csv_file);

    /* 
     * Buffer pour la commande complète : on encapsule la commande dans des parenthèses
     * (pour créer un subshell bash explicite) et on ajoute un message de debug.
     * Le '&' final est CRUCIAL car il permet au parent de ne pas bloquer.
     */
    char full_cmd[1200];
    snprintf(full_cmd, sizeof(full_cmd),
             "( echo '%s[SUBSHELL %d] Démarrage avec PID parent: %d%s'; %s ) &",
             CYAN, subshell_num, getpid(), RESET, cmd);

    /* Information visuelle pour l'utilisateur sur le lancement imminent */
    printf(BLUE "[SUBSHELL] Subshell %d lancé en arrière-plan (mode: %s)\n" RESET,
           subshell_num, mode_flag);
    
    /* On vide le buffer de sortie pour assurer l'ordre chronologique des messages */
    fflush(stdout);

    /* Exécution via l'interpréteur de commande du système */
    int ret = system(full_cmd);
    
    if (ret == -1) {
        perror("system() a échoué");
        return -1;
    }

    return 0;
}

/**
 * main - Point d'entrée du programme de runner subshell.
 * 
 * Le programme attend 4 arguments en ligne de commande :
 * 1. Le chemin du script bash
 * 2. Le fichier CSV de données
 * 3. Le seuil de détection
 * 4. Le fichier de log
 */
int main(int argc, char *argv[])
{
    /* Vérification de la présence des arguments requis */
    if (argc < 5) {
        fprintf(stderr, "Usage: subshell_runner <script> <csv> <threshold> <logfile>\n");
        return EXIT_FAILURE;
    }

    /* Extraction des arguments pour une meilleure lisibilité */
    const char *script_path = argv[1];
    const char *csv_file    = argv[2];
    const char *threshold   = argv[3];
    const char *log_file    = argv[4];

    printf(BOLD "\n[SUBSHELL MODE] Parent PID=%d — Lancement de 5 subshells...\n\n" RESET, 
           getpid());

    /* Capturer le temps au début de l'exécution pour calculer la performance */
    clock_t start = clock();

    /* 
     * Lancement séquentiel des 5 types de détection.
     * Chaque appel est non-bloquant grâce à la logique de subshell (&).
     */

    /* ── ANALYSE 1 : Montants élevés ──────────────────────────── */
    if (launch_subshell(script_path, "--internal-high",
                        csv_file, threshold, log_file, 1) == -1) {
        fprintf(stderr, "Erreur lors du lancement du subshell 1\n");
        return EXIT_FAILURE;
    }

    /* ── ANALYSE 2 : Anomalies de fréquence ───────────────────── */
    if (launch_subshell(script_path, "--internal-frequency",
                        csv_file, threshold, log_file, 2) == -1) {
        fprintf(stderr, "Erreur lors du lancement du subshell 2\n");
        return EXIT_FAILURE;
    }

    /* ── ANALYSE 3 : Changement de comportement ───────────────── */
    if (launch_subshell(script_path, "--internal-behavior",
                        csv_file, threshold, log_file, 3) == -1) {
        fprintf(stderr, "Erreur lors du lancement du subshell 3\n");
        return EXIT_FAILURE;
    }

    /* ── ANALYSE 4 : Structuration de transactions ────────────── */
    if (launch_subshell(script_path, "--internal-structuring",
                        csv_file, threshold, log_file, 4) == -1) {
        fprintf(stderr, "Erreur lors du lancement du subshell 4\n");
        return EXIT_FAILURE;
    }

    /* ── ANALYSE 5 : Changement rapide de compte ──────────────── */
    if (launch_subshell(script_path, "--internal-switching",
                        csv_file, threshold, log_file, 5) == -1) {
        fprintf(stderr, "Erreur lors du lancement du subshell 5\n");
        return EXIT_FAILURE;
    }

    /*
     * ── SYNCHRONISATION : Attente des processus fils ───────────
     * La fonction wait(NULL) bloque le parent tant qu'il y a des processus 
     * fils en cours d'exécution. La boucle while assure d'attendre TOUS les fils.
     */
    printf(YELLOW "\n[SUBSHELL] Parent en attente de tous les subshells (wait)...\n" RESET);
    fflush(stdout);

    /* Attendre tous les processus fils */
    while (wait(NULL) > 0);

    /* Calcul et affichage du temps total d'exécution CPU */
    clock_t end = clock();
    double duration = (double)(end - start) / CLOCKS_PER_SEC;

    printf(CYAN "\n[PERF] Mode: subshell | Durée: %.3fs | PID parent: %d | 5 subshells terminés\n" RESET,
           duration, getpid());

    printf(GREEN "\n[SUCCESS] Tous les subshells ont terminé leur exécution.\n" RESET);

    return EXIT_SUCCESS;
}
