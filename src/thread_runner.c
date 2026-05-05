/*
 * ============================================================
 * thread_runner.c — Mode Threads POSIX (pthreads)
 * FraudDetect | ENSET Mohammedia 2026
 *
 * Ce programme reproduit la même logique que fork_runner.c
 * mais utilise des THREADS au lieu de processus fils.
 *
 * Différences clés vs fork() :
 *   fork()    → crée un PROCESSUS fils (espace mémoire séparé)
 *   pthread   → crée un THREAD (partage la mémoire du parent)
 *
 * Appels système / fonctions POSIX utilisés :
 *   pthread_create() → crée un thread
 *   pthread_join()   → attend la fin d'un thread (≈ waitpid)
 *   pthread_t        → type identifiant un thread
 *   pthread_mutex_*  → protection des accès concurrents au log
 *
 * Compilation :
 *   gcc thread_runner.c -o thread_runner -lpthread
 *
 * Utilisation :
 *   ./thread_runner fraud_detector.sh data.csv 10000 results.log
 *
 * Architecture :
 *   Thread principal
 *   ├── Thread 1 : detect_high_amount
 *   ├── Thread 2 : detect_frequency_anomaly
 *   ├── Thread 3 : detect_behavior_change
 *   ├── Thread 4 : detect_structuring
 *   └── Thread 5 : detect_account_switching
 *   Thread principal : pthread_join() sur les cinq threads
 * ============================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>  /* pthread_create(), pthread_join(), mutex */
#include <sys/wait.h> /* WEXITSTATUS */
#include <time.h>

/* Couleurs ANSI */
#define BLUE "\033[0;34m"
#define CYAN "\033[0;36m"
#define GREEN "\033[0;32m"
#define YELLOW "\033[0;33m"
#define BOLD "\033[1m"
#define RESET "\033[0m"

/*
 * Mutex global pour protéger les printf() concurrents.
 * Sans mutex, les affichages de plusieurs threads se mélangent.
 */
pthread_mutex_t print_mutex = PTHREAD_MUTEX_INITIALIZER;

/*
 * Structure passée à chaque thread comme argument.
 * Contrairement à fork(), les threads ne peuvent pas recevoir
 * plusieurs paramètres directement — on passe un pointeur void*.
 */
typedef struct
{
    int thread_num;          /* numéro du thread (1 à 5) */
    const char *script_path; /* chemin vers fraud_detector.sh */
    const char *mode_flag;   /* ex: "--internal-high" */
    const char *csv_file;    /* fichier CSV à analyser */
    const char *threshold;   /* seuil en MAD */
    const char *log_file;    /* fichier log partagé */
    int exit_code;           /* code retour du script (résultat) */
} ThreadArgs;

/*
 * Fonction exécutée par chaque thread.
 * Signature imposée par pthreads : void* func(void* arg)
 *
 * Equivalent du bloc if (pid == 0) { ... } dans fork_runner.c
 */
void *thread_task(void *arg)
{
    ThreadArgs *targs = (ThreadArgs *)arg;

    /* Affichage thread-safe via mutex */
    pthread_mutex_lock(&print_mutex);
    printf(CYAN "[THREAD %d] TID=%lu | Tâche: %s\n" RESET,
           targs->thread_num,
           (unsigned long)pthread_self(), /* identifiant du thread courant */
           targs->mode_flag);
    fflush(stdout);
    pthread_mutex_unlock(&print_mutex);

    /* Construction de la commande Bash (identique à fork_runner.c) */
    char cmd[1024];
    snprintf(cmd, sizeof(cmd),
             "bash %s %s --threshold %s --log-file %s %s",
             targs->script_path,
             targs->mode_flag,
             targs->threshold,
             targs->log_file,
             targs->csv_file);

    /* Exécution du script */
    int ret = system(cmd);
    targs->exit_code = WEXITSTATUS(ret);

    /* Affichage de fin thread-safe */
    pthread_mutex_lock(&print_mutex);
    printf(GREEN "[THREAD %d] Terminé — code: %d\n" RESET,
           targs->thread_num, targs->exit_code);
    fflush(stdout);
    pthread_mutex_unlock(&print_mutex);

    /*
     * pthread_exit() ou return NULL — les deux terminent le thread.
     * On retourne NULL car la valeur de retour n'est pas utilisée ici.
     */
    return NULL;
}

int main(int argc, char *argv[])
{
    if (argc < 5)
    {
        fprintf(stderr, "Usage: thread_runner <script> <csv> <threshold> <logfile>\n");
        return EXIT_FAILURE;
    }

    const char *script_path = argv[1];
    const char *csv_file = argv[2];
    const char *threshold = argv[3];
    const char *log_file = argv[4];

    printf(BOLD "\n[THREAD MODE] PID=%d — Création de 5 threads...\n\n" RESET,
           getpid());

    clock_t start = clock();

    /*
     * Tableaux pour stocker les identifiants et arguments des threads.
     * Tous les threads partagent le MÊME espace mémoire que le parent —
     * c'est pourquoi on passe des pointeurs vers ces structures.
     */
    pthread_t threads[5];
    ThreadArgs args[5];

    /* Définition des 5 tâches */
    const char *flags[5] = {
        "--internal-high",
        "--internal-frequency",
        "--internal-behavior",
        "--internal-structuring",
        "--internal-switching"};

    /*
     * ── CRÉATION DES THREADS ────────────────────────────────
     * pthread_create() est l'équivalent de fork() pour les threads.
     *
     * Prototype :
     *   int pthread_create(pthread_t *thread,
     *                      const pthread_attr_t *attr,
     *                      void *(*start_routine)(void *),
     *                      void *arg);
     */
    for (int i = 0; i < 5; i++)
    {
        args[i].thread_num = i + 1;
        args[i].script_path = script_path;
        args[i].mode_flag = flags[i];
        args[i].csv_file = csv_file;
        args[i].threshold = threshold;
        args[i].log_file = log_file;
        args[i].exit_code = -1;

        int rc = pthread_create(
            &threads[i], /* identifiant du thread créé (sortie) */
            NULL,        /* attributs par défaut */
            thread_task, /* fonction à exécuter */
            &args[i]     /* argument passé à la fonction */
        );

        if (rc != 0)
        {
            fprintf(stderr, "pthread_create() échoué pour thread %d : %d\n", i + 1, rc);
            return EXIT_FAILURE;
        }

        printf(BLUE "[CREATE] Thread %d créé (TID=%lu)\n" RESET,
               i + 1, (unsigned long)threads[i]);
        fflush(stdout);
    }

    /*
     * ── SYNCHRONISATION : pthread_join() ───────────────────
     * Équivalent de waitpid() pour les threads.
     * Le thread principal se bloque jusqu'à la fin de chaque thread.
     *
     * Prototype :
     *   int pthread_join(pthread_t thread, void **retval);
     */
    printf(BLUE "\n[THREAD] Thread principal en attente (pthread_join)...\n" RESET);
    fflush(stdout);

    for (int i = 0; i < 5; i++)
    {
        int rc = pthread_join(threads[i], NULL);
        if (rc != 0)
        {
            fprintf(stderr, "pthread_join() échoué pour thread %d : %d\n", i + 1, rc);
        }
        else
        {
            printf(GREEN "[JOIN] Thread %d (TID=%lu) rejoint — code script: %d\n" RESET,
                   i + 1, (unsigned long)threads[i], args[i].exit_code);
        }
    }

    /* Libération du mutex */
    pthread_mutex_destroy(&print_mutex);

    clock_t end = clock();
    double duration = (double)(end - start) / CLOCKS_PER_SEC;

    printf(CYAN "\n[PERF] Mode: threads | Durée: %.3fs | PID: %d | %d threads\n" RESET,
           duration, getpid(), 5);

    return EXIT_SUCCESS;
}