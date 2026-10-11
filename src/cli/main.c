#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <CoreFoundation/CoreFoundation.h>
#include "../TSPCBridge.h"

static volatile int s_running = 1;
static void sig_handler(int sig) {
    (void)sig;
    s_running = 0;
}

static void on_telemetry(const TSPCTelemetry *t, void *ctx) {
    (void)ctx;
    printf("\r[TS-PC] Angle: %+6.1f° (%5u) | Gaz: %3.0f%% | Frein: %3.0f%% | Embrayage: %3.0f%% | D-Pad: %2d | Btn: 0x%04x  ",
           t->wheelAngleDeg, t->wheelRaw, t->gasPercent, t->brakePercent, t->clutchPercent, t->hat, t->buttons);
    fflush(stdout);
}

static void on_conn(TSPCConnectionStatus st, const char *msg, void *ctx) {
    (void)ctx;
    printf("\n[Statut USB] %s (%s)\n",
           st == TSPC_STATUS_ACTIVE ? "ACTIF (0xb689)" :
           st == TSPC_STATUS_BOOT_MODE ? "BOOTLOADER (0xb65d)" : "DÉCONNECTÉ",
           msg ? msg : "");
}

static void print_usage(const char *prog) {
    printf("Thrustmaster TS-PC Racer macOS CLI Tool\n");
    printf("Usage:\n");
    printf("  %s status                    Afficher l'état de détection du volant\n", prog);
    printf("  %s unlock                    Débloquer le volant vers le mode haute précision 1080°\n", prog);
    printf("  %s range <140-1080>          Régler l'angle de braquage (degrés)\n", prog);
    printf("  %s autocenter <0-100> [off]  Régler la force du ressort de rappel\n", prog);
    printf("  %s gain <0-100>              Régler le gain matériel FFB\n", prog);
    printf("  %s test <left|right|rumble>  Tester un effet de retour de force\n", prog);
    printf("  %s monitor                   Moniteur interactif en direct des axes et boutons\n", prog);
    printf("  %s gfn [port]                Démarrer le serveur pont HTTP pour GeForce NOW (défaut: 8765)\n", prog);
    printf("  %s daemon                    Démon d'arrière-plan pour auto-débloquer le volant\n", prog);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }

    const char *cmd = argv[1];
    tspc_init();

    if (strcmp(cmd, "status") == 0) {
        char desc[256];
        TSPCConnectionStatus st = tspc_get_connection_status(desc, sizeof(desc));
        printf("Statut du matériel : %s\n", desc);
        if (st == TSPC_STATUS_BOOT_MODE) {
            printf("Action suggérée : lancez '%s unlock' pour activer le mode haute précision.\n", argv[0]);
        } else if (st == TSPC_STATUS_ACTIVE) {
            printf("Le volant est prêt pour les jeux natifs, Wine et CrossOver.\n");
        }
        return (st == TSPC_STATUS_DISCONNECTED) ? 1 : 0;
    }

    if (strcmp(cmd, "unlock") == 0) {
        printf("Tentative de déblocage du TS-PC Racer (0x%04x -> 0x%04x)...\n", TSPC_VID, TSPC_PID_ACTIVE);
        int ret = tspc_unlock_device();
        if (ret == 0) {
            printf("Commande de déblocage envoyée avec succès !\n");
            printf("Attente de la ré-énumération du volant (3s)...\n");
            sleep(3);
            char desc[256];
            TSPCConnectionStatus st = tspc_get_connection_status(desc, sizeof(desc));
            printf("Nouvel état : %s\n", desc);
            return (st == TSPC_STATUS_ACTIVE) ? 0 : 1;
        } else {
            printf("Échec de l'envoi de la commande de déblocage (code %d).\n", ret);
            return 1;
        }
    }

    if (strcmp(cmd, "range") == 0) {
        if (argc < 3) {
            printf("Veuillez spécifier l'angle en degrés (ex: %s range 900)\n", argv[0]);
            return 1;
        }
        int deg = atoi(argv[2]);
        if (deg < 140 || deg > 1080) {
            printf("L'angle doit être compris entre 140 et 1080 degrés.\n");
            return 1;
        }
        tspc_start_listening(NULL, NULL, NULL);
        int r = tspc_set_rotation_range((uint16_t)deg);
        tspc_stop_listening();
        if (r == 0) {
            printf("Plage de rotation réglée à %d° avec succès.\n", deg);
            return 0;
        } else {
            printf("Erreur lors de l'application de la plage (volant connecté ?)\n");
            return 1;
        }
    }

    if (strcmp(cmd, "autocenter") == 0) {
        if (argc < 3) {
            printf("Veuillez spécifier la force (0-100) (ex: %s autocenter 70)\n", argv[0]);
            return 1;
        }
        int force = atoi(argv[2]);
        bool enabled = true;
        if (argc > 3 && strcmp(argv[3], "off") == 0) {
            enabled = false;
        }
        tspc_start_listening(NULL, NULL, NULL);
        int r = tspc_set_autocenter(force, enabled);
        tspc_stop_listening();
        if (r == 0) {
            printf("Rappel au centre réglé à %d%% (%s).\n", force, enabled ? "activé" : "désactivé");
            return 0;
        } else {
            printf("Erreur lors de l'application de l'autocentrage.\n");
            return 1;
        }
    }

    if (strcmp(cmd, "gain") == 0) {
        if (argc < 3) {
            printf("Veuillez spécifier le gain (0-100) (ex: %s gain 80)\n", argv[0]);
            return 1;
        }
        int gain = atoi(argv[2]);
        tspc_start_listening(NULL, NULL, NULL);
        int r = tspc_set_gain(gain);
        tspc_stop_listening();
        if (r == 0) {
            printf("Gain FFB réglé à %d%%.\n", gain);
            return 0;
        } else {
            printf("Erreur lors de l'application du gain.\n");
            return 1;
        }
    }

    if (strcmp(cmd, "test") == 0) {
        if (argc < 3) {
            printf("Options de test: left, right, rumble\n");
            return 1;
        }
        int dir = 0;
        if (strcmp(argv[2], "left") == 0) dir = -1;
        else if (strcmp(argv[2], "right") == 0) dir = 1;
        else dir = 0;

        tspc_start_listening(NULL, NULL, NULL);
        printf("Exécution du test FFB (%s)...\n", argv[2]);
        tspc_test_pulse(dir);
        tspc_stop_listening();
        printf("Test terminé.\n");
        return 0;
    }

    if (strcmp(cmd, "monitor") == 0) {
        signal(SIGINT, sig_handler);
        signal(SIGTERM, sig_handler);
        printf("--- Moniteur télémétrie TS-PC Racer (Appuyez sur Ctrl+C pour quitter) ---\n");
        tspc_start_listening(on_telemetry, on_conn, NULL);

        while (s_running) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
        }

        printf("\nArrêt du moniteur.\n");
        tspc_stop_listening();
        return 0;
    }

    if (strcmp(cmd, "gfn") == 0 || strcmp(cmd, "bridge") == 0) {
        signal(SIGINT, sig_handler);
        signal(SIGTERM, sig_handler);
        uint16_t port = 8765;
        if (argc > 2) port = (uint16_t)atoi(argv[2]);

        printf("=== Pont GeForce NOW & Forza Horizon pour TS-PC Racer ===\n");
        printf("Démarrage du serveur télémétrie HTTP sur http://127.0.0.1:%u ...\n", port);
        if (tspc_start_http_server(port) != 0) {
            printf("Erreur lors du démarrage du serveur HTTP (port %u déjà utilisé ?)\n", port);
            return 1;
        }

        printf("Serveur ACTIF. Écoute des entrées du volant (Appuyez sur Ctrl+C pour quitter)...\n");
        printf("Astuce : Ouvrez https://play.geforcenow.com dans Chrome avec l'extension activée.\n");
        tspc_start_listening(on_telemetry, on_conn, NULL);

        while (s_running) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
        }

        printf("\nArrêt du pont GeForce NOW.\n");
        tspc_stop_http_server();
        tspc_stop_listening();
        return 0;
    }

    if (strcmp(cmd, "daemon") == 0) {
        signal(SIGINT, sig_handler);
        signal(SIGTERM, sig_handler);
        printf("TS-PC Racer Daemon en cours d'exécution... (Surveillance continue)\n");
        while (s_running) {
            char desc[128];
            TSPCConnectionStatus st = tspc_get_connection_status(desc, sizeof(desc));
            if (st == TSPC_STATUS_BOOT_MODE) {
                printf("[DAEMON] Détection du volant en mode démarrage. Déblocage...\n");
                tspc_unlock_device();
                sleep(3);
            }
            sleep(2);
        }
        printf("[DAEMON] Arrêt.\n");
        return 0;
    }

    print_usage(argv[0]);
    return 1;
}
