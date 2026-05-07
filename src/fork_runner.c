/*
 * ============================================================
 * fork_runner.c — Mode Moyen : fork() réel Linux
 * FraudDetect | ENSET Mohammedia 2026
 *
 * Ce programme démontre les appels système OS :
 *   fork()   → crée un processus fils (clone du parent)
 *   wait()   → le parent attend la fin du fils
 *   pipe()   → communication parent ↔ fils
 *   getpid() → identifiant du processus courant
 *   getppid()→ identifiant du parent
 *
 * Architecture :
 *   Parent (fork_runner)
 *   ├── Fils 1 : exécute detect_high_amount via script Bash
 *   ├── Fils 2 : exécute detect_frequency_anomaly via script Bash
 *   ├── Fils 3 : exécute detect_behavior_change via script Bash
 *   ├── Fils 4 : exécute detect_structuring via script Bash
 *   └── Fils 5 : exécute detect_account_switching via script Bash
 *   Parent : wait() sur les cinq fils puis affiche les résultats
 * ============================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>      /* fork(), getpid(), getppid() */
#include <sys/wait.h>    /* wait(), waitpid(), WEXITSTATUS */
#include <sys/types.h>   /* pid_t */
#include <time.h>        /* clock(), CLOCKS_PER_SEC */

/* Couleurs ANSI pour le terminal */
#define BLUE    "\033[0;34m"
#define CYAN    "\033[0;36m"
#define GREEN   "\033[0;32m"
#define BOLD    "\033[1m"
#define RESET   "\033[0m"

/*
 * Lance un script Bash dans un processus fils via fork().
 * Retourne le PID du fils créé.
 *
 * Paramètres :
 *   script_path  — chemin vers fraud_detector.sh
 *   mode_flag    — option Bash interne (ex: "--internal-high")
 *   csv_file     — fichier CSV à analyser
 *   threshold    — seuil en MAD
 *   log_file     — fichier log partagé
 */
pid_t launch_child(const char *script_path,
                   const char *mode_flag,
                   const char *csv_file,
                   const char *threshold,
                   const char *log_file,
                   int child_num)
{
    pid_t pid = fork();   /* <-- APPEL SYSTÈME fork() */

    if (pid < 0) {
        /* fork() a échoué */
        perror("fork() a échoué");
        exit(EXIT_FAILURE);
    }

    if (pid == 0) {
        /*
         * ── PROCESSUS FILS ─────────────────────────────────
         * On est dans le fils (clone du parent).
         * pid == 0 dans le fils, pid > 0 dans le parent.
         */
        printf(CYAN "[FILS %d] PID=%d | PPID=%d | Tâche: %s\n" RESET,
               child_num, getpid(), getppid(), mode_flag);
        fflush(stdout);

        /* Construire et exécuter la commande Bash */
        char cmd[1024];
        snprintf(cmd, sizeof(cmd),
                 "bash %s %s --threshold %s --log-file %s %s",
                 script_path, mode_flag, threshold, log_file, csv_file);

        int ret = system(cmd);

        /* Le fils quitte avec le code retour du script */
        exit(WEXITSTATUS(ret));
    }

    /*
     * ── PROCESSUS PARENT ───────────────────────────────────
     * On est dans le parent : pid contient le PID du fils créé.
     */
    printf(BLUE "[FORK] Fils %d créé (PID=%d) | Parent PID=%d\n" RESET,
           child_num, pid, getpid());
    fflush(stdout);

    return pid;
}

int main(int argc, char *argv[])
{
    /* Arguments : script_path csv_file threshold log_file */
    if (argc < 5) {
        fprintf(stderr, "Usage: fork_runner <script> <csv> <threshold> <logfile>\n");
        return EXIT_FAILURE;
    }

    const char *script_path = argv[1];
    const char *csv_file    = argv[2];
    const char *threshold   = argv[3];
    const char *log_file    = argv[4];

    printf(BOLD "\n[FORK MODE] Parent PID=%d — Création de 5 fils...\n\n" RESET, getpid());

    /* Mesure du temps d'exécution */
    clock_t start = clock();

    /* ── FORK 1 : HIGH_AMOUNT ──────────────────────────────── */
    pid_t fils1 = launch_child(script_path, "--internal-high",
                                csv_file, threshold, log_file, 1);

    /* ── FORK 2 : FREQUENCY_ANOMALY ───────────────────────── */
    pid_t fils2 = launch_child(script_path, "--internal-frequency",
                                csv_file, threshold, log_file, 2);

    /* ── FORK 3 : BEHAVIOR_CHANGE ─────────────────────────── */
    pid_t fils3 = launch_child(script_path, "--internal-behavior",
                                csv_file, threshold, log_file, 3);

    /* ── FORK 4 : STRUCTURING ─────────────────────────────── */
    pid_t fils4 = launch_child(script_path, "--internal-structuring",
                                csv_file, threshold, log_file, 4);

    /* ── FORK 5 : ACCOUNT_SWITCHING ───────────────────────── */
    pid_t fils5 = launch_child(script_path, "--internal-switching",
                                csv_file, threshold, log_file, 5);

    /*
     * ── SYNCHRONISATION : wait() ───────────────────────────
     * Le parent se bloque jusqu'à ce que chaque fils termine.
     */
    printf(BLUE "\n[FORK] Parent en attente des fils (wait)...\n" RESET);
    fflush(stdout);

    int status1, status2, status3, status4, status5;
    
    waitpid(fils1, &status1, 0);   /* <-- APPEL SYSTÈME wait() */
    printf(GREEN "[FORK] Fils 1 (PID=%d) terminé — code: %d\n" RESET,
           fils1, WEXITSTATUS(status1));

    waitpid(fils2, &status2, 0);   /* <-- APPEL SYSTÈME wait() */
    printf(GREEN "[FORK] Fils 2 (PID=%d) terminé — code: %d\n" RESET,
           fils2, WEXITSTATUS(status2));

    waitpid(fils3, &status3, 0);   /* <-- APPEL SYSTÈME wait() */
    printf(GREEN "[FORK] Fils 3 (PID=%d) terminé — code: %d\n" RESET,
           fils3, WEXITSTATUS(status3));

    waitpid(fils4, &status4, 0);   /* <-- APPEL SYSTÈME wait() */
    printf(GREEN "[FORK] Fils 4 (PID=%d) terminé — code: %d\n" RESET,
           fils4, WEXITSTATUS(status4));

    waitpid(fils5, &status5, 0);   /* <-- APPEL SYSTÈME wait() */
    printf(GREEN "[FORK] Fils 5 (PID=%d) terminé — code: %d\n" RESET,
           fils5, WEXITSTATUS(status5));

    /* Compter le nombre d'alertes (code 0 = fraude détectée) */
    int total_alerts = 0;
    if (WEXITSTATUS(status1) == 0) total_alerts++;
    if (WEXITSTATUS(status2) == 0) total_alerts++;
    if (WEXITSTATUS(status3) == 0) total_alerts++;
    if (WEXITSTATUS(status4) == 0) total_alerts++;
    if (WEXITSTATUS(status5) == 0) total_alerts++;

    /* Calcul de la durée totale */
    clock_t end = clock();
    double duration = (double)(end - start) / CLOCKS_PER_SEC;

    printf(CYAN "\n[PERF] Mode: fork | Durée: %.3fs | PID parent: %d | PIDs fils: %d, %d, %d, %d, %d\n" RESET,
           duration, getpid(), fils1, fils2, fils3, fils4, fils5);
    
    printf(CYAN "[FORK] Total alertes détectées: %d\n" RESET, total_alerts);

    return total_alerts;
}
