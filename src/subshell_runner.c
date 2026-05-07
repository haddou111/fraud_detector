/*
 * ============================================================
 * subshell_runner.c — Mode Léger : Subshells Bash 
 * FraudDetect | ENSET Mohammedia 2026
 *
 * Architecture :
 *   Parent (subshell_runner)
 *   ├── Subshell 1 (PID_1) : exécute detect_high_amount
 *   ├── ...
 *   └── Subshell 5 (PID_5) : exécute detect_account_switching
 * ============================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>      /* fork(), exec() */
#include <sys/wait.h>    /* waitpid() */
#include <sys/time.h>    /* Pour une mesure précise du temps réel */

/* Couleurs ANSI */
#define BLUE    "\033[0;34m"
#define CYAN    "\033[0;36m"
#define GREEN   "\033[0;32m"
#define YELLOW  "\033[1;33m"
#define RED     "\033[0;31m"
#define BOLD    "\033[1m"
#define RESET   "\033[0m"

/**
 * launch_subshell - Crée un processus fils pour exécuter un algorithme.
 */
pid_t launch_subshell(const char *script_path,
                      const char *mode_flag,
                      const char *csv_file,
                      const char *threshold,
                      const char *log_file,
                      int subshell_num)
{
    pid_t pid = fork();

    if (pid < 0) {
        perror("fork() a échoué");
        exit(100);
    }

    if (pid == 0) {
        /* ── PROCESSUS FILS ── */
        char cmd[2048]; /* Augmenté pour la sécurité */
        
        /* On encapsule dans un subshell bash ( ... ) pour respecter le concept */
        snprintf(cmd, sizeof(cmd),
                 "bash %s %s --threshold %s --log-file %s %s",
                 script_path, mode_flag, threshold, log_file, csv_file);

        /* On garde la notion de subshell via les parenthèses Bash ( ... ) */
        char full_cmd[1200];
        snprintf(full_cmd, sizeof(full_cmd),
                 "( echo '%s[SUBSHELL %d] Démarrage (PID parent: %d)%s'; %s )",
                 CYAN, subshell_num, (int)getppid(), RESET, cmd);

        /* Exécution synchrone à l'intérieur du fils */
        int ret = system(full_cmd);
        
        /* Vérification que system() n'a pas échoué avant d'extraire le code */
        if (ret == -1) {
            perror("system() a échoué dans le subshell");
            exit(100);
        }

        /* On quitte avec le code de retour du script (0 = alerte, 1 = ok) */
        exit(WEXITSTATUS(ret));
    }

    /* ── PROCESSUS PARENT ── */
    printf(BLUE "[SUBSHELL] Subshell %d lancé (PID=%d)\n" RESET, subshell_num, pid);
    fflush(stdout);

    return pid;
}

int main(int argc, char *argv[])
{
    if (argc < 5) {
        fprintf(stderr, "Usage: subshell_runner <script> <csv> <threshold> <logfile>\n");
        return 100; 
    }

    const char *script_path = argv[1];
    const char *csv_file    = argv[2];
    const char *threshold   = argv[3];
    const char *log_file    = argv[4];

    printf(BOLD "\n[SUBSHELL MODE] Parent PID=%d — Lancement de 5 subshells...\n\n" RESET, getpid());

    clock_t start = clock();
    pid_t pids[5];

    /* Lancement des 5 algorithmes en parallèle */
    const char *flags[5] = {
        "--internal-high",
        "--internal-frequency",
        "--internal-behavior",
        "--internal-structuring",
        "--internal-switching"
    };

    for (int i = 0; i < 5; i++) {
        pids[i] = launch_subshell(script_path, flags[i], csv_file, threshold, log_file, i + 1);
    }

    printf(YELLOW "\n[SUBSHELL] Parent en attente de synchronisation...\n" RESET);
    fflush(stdout);

    /* Attente des résultats et comptage des alertes */
    int total_alerts = 0;
    int status;

    for (int i = 0; i < 5; i++) {
        int ret = waitpid(pids[i], &status, 0);
        if (ret == -1) {
            perror("waitpid() a échoué");
            continue;
        }
        /* WIFEXITED vérifie que le processus s'est terminé normalement */
        if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
            total_alerts++;
        }
    }

    clock_t end = clock();
    double duration = (double)(end - start) / CLOCKS_PER_SEC;

    printf(CYAN "\n[PERF] Mode: subshell | Durée: %.3fs | PID parent: %d | 5 subshells terminés\n" RESET,
           duration, getpid());

    printf(BOLD GREEN "[SUCCESS] Analyse terminée. Total alertes détectées: %d\n" RESET, total_alerts);

    /* On retourne le nombre d'alertes pour executor.sh */
    return total_alerts;
}
