#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
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

typedef struct {
    int shift_up;
    int shift_down;
    int btn_a;
    int btn_b;
    int btn_x;
    int btn_y;
    int btn_l2;
    int btn_r2;
    int btn_select;
    int btn_start;
    int btn_l3;
    int btn_r3;
    int btn_home;
} CliButtonMap;

static CliButtonMap s_cliMap = {
    .shift_up = 2,
    .shift_down = 1,
    .btn_a = 6,
    .btn_b = 5,
    .btn_x = 4,
    .btn_y = 3,
    .btn_l2 = 10,
    .btn_r2 = 9,
    .btn_select = 7,
    .btn_start = 8,
    .btn_l3 = 11,
    .btn_r3 = 12,
    .btn_home = 13
};

static void cli_load_button_mapping(void) {
    const char *paths[] = {
        "buttons_mapping.conf",
        "/Users/matthieu.verpillier/Documents/Thrustmaster/buttons_mapping.conf",
        "/tmp/tspc_buttons_mapping.conf"
    };
    FILE *f = NULL;
    for (int i = 0; i < 3; i++) {
        f = fopen(paths[i], "r");
        if (f) break;
    }
    if (!f) return;
    char line[128];
    while (fgets(line, sizeof(line), f)) {
        if (line[0] == '#' || line[0] == '\n') continue;
        char key[64];
        int val = 0;
        if (sscanf(line, "%63[^=]=%d", key, &val) == 2) {
            if (strcmp(key, "shift_up") == 0) s_cliMap.shift_up = val;
            else if (strcmp(key, "shift_down") == 0) s_cliMap.shift_down = val;
            else if (strcmp(key, "btn_a") == 0) s_cliMap.btn_a = val;
            else if (strcmp(key, "btn_b") == 0) s_cliMap.btn_b = val;
            else if (strcmp(key, "btn_x") == 0) s_cliMap.btn_x = val;
            else if (strcmp(key, "btn_y") == 0) s_cliMap.btn_y = val;
            else if (strcmp(key, "btn_l2") == 0) s_cliMap.btn_l2 = val;
            else if (strcmp(key, "btn_r2") == 0) s_cliMap.btn_r2 = val;
            else if (strcmp(key, "btn_select") == 0) s_cliMap.btn_select = val;
            else if (strcmp(key, "btn_start") == 0) s_cliMap.btn_start = val;
            else if (strcmp(key, "btn_l3") == 0) s_cliMap.btn_l3 = val;
            else if (strcmp(key, "btn_r3") == 0) s_cliMap.btn_r3 = val;
            else if (strcmp(key, "btn_home") == 0) s_cliMap.btn_home = val;
        }
    }
    fclose(f);
}

static const char *get_action_desc(int b) {
    if (b == s_cliMap.shift_up)   return "G29 R1 / Monter Vitesse (Shift Up / RB)";
    if (b == s_cliMap.shift_down) return "G29 L1 / Rétrograder (Shift Down / LB)";
    if (b == s_cliMap.btn_a)      return "G29 Croix (✕) / A Xbox (Valider)";
    if (b == s_cliMap.btn_b)      return "G29 Rond (○) / B Xbox (Retour / Frein à main)";
    if (b == s_cliMap.btn_x)      return "G29 Carré (□) / X Xbox (Klaxon / Activer)";
    if (b == s_cliMap.btn_y)      return "G29 Triangle (△) / Y Xbox (Rembobiner)";
    if (b == s_cliMap.btn_start)  return "G29 Options / Menu (Pause)";
    if (b == s_cliMap.btn_select) return "G29 Share / View (Changer vue)";
    if (b == s_cliMap.btn_l2)     return "G29 L2 (LT)";
    if (b == s_cliMap.btn_r2)     return "G29 R2 (RT)";
    if (b == s_cliMap.btn_l3)     return "G29 L3 (Stick Gauche Click)";
    if (b == s_cliMap.btn_r3)     return "G29 R3 (Stick Droit Click)";
    if (b == s_cliMap.btn_home)   return "G29 PS / Xbox Home";
    return "Non assigné";
}

static uint32_t s_test_last_btn = 0;
static int s_test_last_hat = -1;

static void on_btn_event(const TSPCTelemetry *t, void *ctx) {
    (void)ctx;
    uint32_t diff = t->buttons ^ s_test_last_btn;
    if (diff) {
        for (int b = 1; b <= 16; b++) {
            if (diff & (1 << (b - 1))) {
                int pressed = (t->buttons & (1 << (b - 1))) != 0;
                char ts_desc[32];
                snprintf(ts_desc, sizeof(ts_desc), "Bouton matériel #%d", b);
                const char *g29_desc = get_action_desc(b);
                printf("  %-9s : %-22s  --->  %s\n",
                       pressed ? "[PRESSÉ]" : "[RELÂCHÉ]", ts_desc, g29_desc);
                fflush(stdout);
            }
        }
        s_test_last_btn = t->buttons;
    }

    if (t->hat != s_test_last_hat) {
        const char *d = "Neutre / Centré";
        switch (t->hat) {
            case 0: d = "Haut (Nord)"; break;
            case 1: d = "Haut-Droit (NE)"; break;
            case 2: d = "Droit (Est)"; break;
            case 3: d = "Bas-Droit (SE)"; break;
            case 4: d = "Bas (Sud)"; break;
            case 5: d = "Bas-Gauche (SO)"; break;
            case 6: d = "Gauche (Ouest)"; break;
            case 7: d = "Haut-Gauche (NO)"; break;
            default: break;
        }
        printf("  [D-PAD]   : Croix directionnelle  --->  %s (val=%d)\n", d, t->hat);
        fflush(stdout);
        s_test_last_hat = t->hat;
    }
}

static volatile int s_detected_btn = -1;
static volatile int s_btn_released = 1;

static void on_calib_event(const TSPCTelemetry *t, void *ctx) {
    (void)ctx;
    if (t->buttons != 0 && s_btn_released) {
        for (int b = 1; b <= 16; b++) {
            if (t->buttons & (1 << (b - 1))) {
                s_detected_btn = b;
                s_btn_released = 0;
                break;
            }
        }
    } else if (t->buttons == 0) {
        s_btn_released = 1;
    }
}

static void draw_bipolar_bar(char *out, size_t out_len, float percent, int half_width) {
    if (percent < -100.0f) percent = -100.0f;
    if (percent > 100.0f) percent = 100.0f;
    if (half_width > 30) half_width = 30;
    char left[32];
    char right[32];
    memset(left, ' ', half_width);
    left[half_width] = '\0';
    memset(right, ' ', half_width);
    right[half_width] = '\0';

    if (percent < -0.5f) {
        int fill = (int)((-percent * half_width) / 100.0f);
        if (fill > half_width) fill = half_width;
        for (int i = 0; i < fill; i++) {
            left[half_width - 1 - i] = '=';
        }
    } else if (percent > 0.5f) {
        int fill = (int)((percent * half_width) / 100.0f);
        if (fill > half_width) fill = half_width;
        for (int i = 0; i < fill; i++) {
            right[i] = '=';
        }
    }
    snprintf(out, out_len, "[%s|%s]", left, right);
}

static uint64_t cli_time_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000ULL + (uint64_t)ts.tv_nsec / 1000000ULL;
}

static int run_debug_ffb(void) {
    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    // Try listening to wheel telemetry if wheel is connected
    tspc_start_listening(on_telemetry, on_conn, NULL);

    printf("\033[?25l"); // Hide cursor
    printf("\033[2J");   // Clear screen

    uint32_t last_seq = 0;
    uint64_t last_pkt_time = 0;
    int pkt_rate = 0;
    int pkt_counter = 0;
    uint64_t rate_timer = cli_time_ms();

    while (s_running) {
        TSPCFfbDebugData dbg;
        bool has_data = tspc_ffb_debug_read(&dbg);
        TSPCTelemetry telem;
        tspc_get_telemetry_snapshot(&telem);

        uint64_t now = cli_time_ms();
        if (now - rate_timer >= 1000) {
            pkt_rate = pkt_counter;
            pkt_counter = 0;
            rate_timer = now;
        }

        if (has_data && dbg.seq != last_seq) {
            last_seq = dbg.seq;
            last_pkt_time = now;
            pkt_counter++;
        }

        uint64_t elapsed_ms = (last_pkt_time > 0) ? (now - last_pkt_time) : 999999;

        // Move cursor to top-left
        printf("\033[H");

        printf("\033[1;36m================================================================================\033[0m\n");
        printf("\033[1;37m🏎️   TS2GFN FORCE FEEDBACK INSPECTOR : GeForce NOW (G29) -> TS-PC Racer\033[0m\n");
        printf("\033[1;36m================================================================================\033[0m\n");

        if (!has_data || elapsed_ms > 3000) {
            printf("État de liaison : \033[1;33m⏳ EN ATTENTE DE GEFORCE NOW\033[0m (Lancez un jeu avec volant)\n");
            printf("Fichier d'échange: %s\n", TSPC_FFB_DEBUG_FILE);
            printf("Dernière activité: %s\n\n", (last_pkt_time > 0) ? "Inactif depuis > 3s" : "Aucune trame reçue");
        } else {
            printf("État de liaison : \033[1;32m● CONNECTÉ & ACTIF\033[0m  |  Fréquence: \033[1;37m%d Hz\033[0m  |  Latence: \033[1;37m%llu ms\033[0m  |  Trame #\033[1;37m%u\033[0m\n",
                   pkt_rate, (unsigned long long)elapsed_ms, dbg.seq);
            printf("Configuration   : Gain FFB: \033[1;33m%.2fx\033[0m  |  Sens: \033[1;33m%s\033[0m  |  Centrage: \033[1;33m%s\033[0m\n\n",
                   dbg.ffb_gain, dbg.ffb_invert ? "INVERSÉ" : "Standard",
                   dbg.autocenter_mode == 0 ? "Jeu (Physique Directe)" : "Volant (Ressort Matériel)");
        }

        // Section 1: G29 Cloud Input
        printf("\033[1;34m[1] SIGNAUX ENVOYÉS PAR LE JEU DANS GEFORCE NOW (Protocole Logitech G29)\033[0m\n");
        if (has_data) {
            float g29_pct = ((float)dbg.g29_delta * 100.0f) / 127.0f;
            char g29_bar[64];
            draw_bipolar_bar(g29_bar, sizeof(g29_bar), g29_pct, 15);

            const char *dir_str = "Point Neutre (0 Couple)";
            if (dbg.g29_delta > 0) dir_str = "Couple Droite (Sens Horaire)";
            else if (dbg.g29_delta < 0) dir_str = "Couple Gauche (Sens Anti-horaire)";

            printf("  • Commande reçue : \033[1;37m%s\033[0m (Opcode: 0x%02X)\n", dbg.g29_desc, dbg.g29_cmd_type);
            printf("  • Valeur brute   : \033[1;37m0x%02X\033[0m (%u / 255)  |  Centre neutre G29 = 0x80 (128)\n",
                   dbg.g29_raw_force, dbg.g29_raw_force);
            printf("  • Delta physique : \033[1;%sm%+d\033[0m sur plage [-128..+127]  ->  %s\n",
                   dbg.g29_delta == 0 ? "32" : (dbg.g29_delta > 0 ? "33" : "35"),
                   dbg.g29_delta, dir_str);
            printf("  • Jauge Cloud    : \033[1;32m%s\033[0m  \033[1;37m%+6.1f%%\033[0m\n\n", g29_bar, g29_pct);
        } else {
            printf("  (Aucune trame reçue pour le moment)\n\n");
        }

        // Section 2: Thrustmaster TS-PC Output
        printf("\033[1;32m[2] TRADUCTION & ORDRES ENVOYÉS AU VOLANT THRUSTMASTER TS-PC RACER\033[0m\n");
        if (has_data) {
            char tspc_bar[64];
            draw_bipolar_bar(tspc_bar, sizeof(tspc_bar), dbg.tspc_percent, 15);

            printf("  • Couple Moteur  : \033[1;%sm%+d\033[0m / 16384  (Format Natif Constant Force 16-bit)\n",
                   dbg.tspc_level == 0 ? "32" : "33", dbg.tspc_level);
            printf("  • Puissance Base : \033[1;32m%s\033[0m  \033[1;37m%+6.1f%%\033[0m du moteur brushless 40W\n",
                   tspc_bar, dbg.tspc_percent);

            printf("  • Trame USB HID  : \033[1;36m");
            for (uint32_t i = 0; i < dbg.tspc_packet_len && i < 19; i++) {
                printf("%02X ", dbg.tspc_packet[i]);
            }
            if (dbg.tspc_packet_len == 0) printf("(Désactivé)");
            printf("\033[0m\n\n");
        } else {
            printf("  (En attente de commandes du moteur)\n\n");
        }

        // Section 3: Wheel physical telemetry
        printf("\033[1;35m[3] POSITION PHYSIQUE DU VOLANT TS-PC EN DIRECT\033[0m\n");
        if (telem.isConnected) {
            float angle_pct = (telem.wheelAngleDeg / (dbg.wheel_range > 0 ? (dbg.wheel_range / 2.0f) : 450.0f)) * 100.0f;
            char angle_bar[64];
            draw_bipolar_bar(angle_bar, sizeof(angle_bar), angle_pct, 15);

            printf("  • Angle Actuel   : \033[1;37m%+6.1f°\033[0m (Plage active: %u°)  %s\n",
                   telem.wheelAngleDeg, dbg.wheel_range > 0 ? dbg.wheel_range : 900, angle_bar);
            printf("  • Capteur Optique: Raw = %u (Centre neutre ~32768)\n\n", telem.wheelRaw);
        } else {
            printf("  • Volant : \033[1;31mNon détecté sur le port USB\033[0m (Vérifiez le câble ou lancez 'unlock')\n\n");
        }

        // Section 4: History Table
        printf("\033[1;33m[4] HISTORIQUE DES DERNIÈRES COMMANDES FFB REÇUES\033[0m\n");
        printf("  HEURE        | G29 RAW | DELTA | TS-PC 16B | PUISSANCE | DESCRIPTION\n");
        printf("  -------------+---------+-------+-----------+-----------+------------------------------\n");

        if (has_data && dbg.history_count > 0) {
            uint32_t count = dbg.history_count;
            if (count > 8) count = 8;
            for (uint32_t i = 0; i < count; i++) {
                int idx = (int)dbg.history_head - 1 - (int)i;
                if (idx < 0) idx += 16;
                const TSPCFfbHistoryItem *item = &dbg.history[idx];

                time_t sec = (time_t)(item->timestamp_ms / 1000ULL);
                int ms = (int)(item->timestamp_ms % 1000ULL);
                struct tm tm_buf;
                localtime_r(&sec, &tm_buf);

                float pct = ((float)item->tspc_level * 100.0f) / 16384.0f;
                printf("  %02d:%02d:%02d.%03d | 0x%02X    | %+5d | %+9d | %+8.1f%% | %-28.28s\n",
                       tm_buf.tm_hour, tm_buf.tm_min, tm_buf.tm_sec, ms,
                       item->g29_raw, item->g29_delta, item->tspc_level, pct, item->note);
            }
        } else {
            printf("  (Aucune trame dans l'historique)\n");
        }

        printf("\n\033[1;30mAppuyez sur Ctrl+C pour quitter l'inspecteur.\033[0m\n");
        fflush(stdout);

        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.04, false);
    }

    printf("\033[?25h\n"); // Restore cursor
    tspc_stop_listening();
    printf("Arrêt de l'inspecteur FFB.\n");
    return 0;
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
    printf("  %s debug-ffb                 Inspecteur FFB en direct (Flux GeForce NOW G29 -> TS-PC)\n", prog);
    printf("  %s calibrate-buttons         Assistant pas-à-pas pour calibrer chaque touche physique\n", prog);
    printf("  %s test-buttons              Tester et valider chaque bouton du volant en direct\n", prog);
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

    if (strcmp(cmd, "debug-ffb") == 0 || strcmp(cmd, "ffb") == 0 || strcmp(cmd, "inspector") == 0) {
        return run_debug_ffb();
    }

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

    if (strcmp(cmd, "calibrate-buttons") == 0) {
        signal(SIGINT, sig_handler);
        signal(SIGTERM, sig_handler);
        printf("========================================================================\n");
        printf("  ASSISTANT DE CALIBRATION DES TOUCHES DU VOLANT TS-PC RACER\n");
        printf("  Suivez les instructions et actionnez chaque commande (Ctrl+C pour annuler)\n");
        printf("========================================================================\n\n");

        struct {
            const char *key;
            const char *prompt;
            int assigned;
        } steps[] = {
            { "shift_up",   "Actionnez la Palette Droite (Monter vitesse / Shift Up)", 2 },
            { "shift_down", "Actionnez la Palette Gauche (Rétrograder / Shift Down)",  1 },
            { "btn_a",      "Appuyez sur le bouton A (Croix / Valider)",                5 },
            { "btn_b",      "Appuyez sur le bouton B (Rond / Annuler / Frein à main)",  4 },
            { "btn_x",      "Appuyez sur le bouton X (Carré / Klaxon / Activer)",       6 },
            { "btn_y",      "Appuyez sur le bouton Y (Triangle / Rembobiner)",          3 },
            { "btn_start",  "Appuyez sur le bouton Start / Menu (Pause)",               10 },
            { "btn_select", "Appuyez sur le bouton Select / View (Changer vue)",        9 }
        };
        int num_steps = sizeof(steps) / sizeof(steps[0]);

        tspc_start_listening(on_calib_event, on_conn, NULL);

        for (int i = 0; i < num_steps && s_running; i++) {
            printf("[%d/%d] 👉 %s ... ", i + 1, num_steps, steps[i].prompt);
            fflush(stdout);

            s_detected_btn = -1;
            while (s_detected_btn < 0 && s_running) {
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, false);
            }
            if (!s_running) break;

            steps[i].assigned = s_detected_btn;
            printf("✓ Détecté : Bouton matériel #%d !\n", steps[i].assigned);

            // Wait for button release
            while (!s_btn_released && s_running) {
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, false);
            }
            usleep(250000); // 250ms debounce
        }

        tspc_stop_listening();

        if (s_running) {
            FILE *f = fopen("buttons_mapping.conf", "w");
            if (f) {
                fprintf(f, "# Configuration personnalisée générée par tspc-cli calibrate-buttons\n");
                for (int i = 0; i < num_steps; i++) {
                    fprintf(f, "%s=%d\n", steps[i].key, steps[i].assigned);
                }
                fprintf(f, "btn_l2=7\nbtn_r2=8\nbtn_l3=11\nbtn_r3=12\nbtn_home=13\n");
                fclose(f);
                printf("\n========================================================================\n");
                printf("  ✓ Calibration terminée et enregistrée dans buttons_mapping.conf !\n");
                printf("  ✓ Les boutons sont immédiatement appliqués pour GeForce NOW.\n");
                printf("========================================================================\n");
            } else {
                printf("\n❌ Erreur lors de l'enregistrement de buttons_mapping.conf\n");
            }
        }
        return 0;
    }

    if (strcmp(cmd, "test-buttons") == 0) {
        signal(SIGINT, sig_handler);
        signal(SIGTERM, sig_handler);
        cli_load_button_mapping();
        printf("========================================================================\n");
        printf("  TESTEUR INTERACTIF DE BOUTONS TS-PC RACER -> G29 / FORZA HORIZON\n");
        printf("  Appuyez sur n'importe quel bouton ou palette (Ctrl+C pour quitter)\n");
        printf("========================================================================\n\n");

        tspc_start_listening(on_btn_event, on_conn, NULL);

        while (s_running) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
        }

        printf("\nArrêt du testeur de boutons.\n");
        tspc_stop_listening();
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
