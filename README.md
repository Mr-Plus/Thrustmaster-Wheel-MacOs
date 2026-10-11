# TS-PC Racer Control pour macOS (Apple Silicon & Intel)

> [!CAUTION]
> **Statut du projet : Inachevé / Abandonné pour l'application native GeForce NOW.**  
> Pour comprendre l'architecture, ce qui fonctionne (déblocage USB IOKit, panneau de contrôle SwiftUI, télémétrie HTTP, jeux natifs/Wine), et les verrous techniques d'Apple et de GeForce NOW ayant motivé l'arrêt, consultez le rapport complet :  
> 👉 **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)**

Pilote et panneau de contrôle complet en espace utilisateur (IOKit / User-space) pour le volant **Thrustmaster TS-PC Racer** sur macOS.

Ce logiciel résout le problème historique des volants Thrustmaster sous macOS :
1. **Sortie du mode bootloader** : À la connexion USB, le volant s'énumère en mode générique restreint (`0x044f:0xb65d`). Ce pilote lui envoie la commande USB de bascule haute résolution pour l'activer en tant que vrai **Thrustmaster TS-PC Racer** (`0x044f:0xb689`).
2. **Lecture des axes et boutons 16-bit** : Direction haute précision 65536 pas (16-bit), 3 pédales (Accélérateur, Frein, Embrayage en 10-bit), croix directionnelle D-Pad et 13 boutons d'action.
3. **Contrôle du retour de force (FFB)** : Réglage matériel de l'angle de braquage (140° à 1080°), du gain global et du ressort de rappel (autocentrage matériel).
4. **Sans extension noyau (No kext / No Dext)** : Fonctionne à 100% en espace utilisateur, sans droit root requis, sans désactiver SIP (System Integrity Protection).

---

## Contenu du projet

* **`TS-PC Control.app`** : Application graphique macOS native (SwiftUI) avec tableau de bord en temps réel.
* **`tspc-cli`** : Utilitaire en ligne de commande pour les scripts et l'automatisation.
* **`com.thrustmaster.tspc.plist`** : Service optionnel en arrière-plan pour auto-débloquer le volant à chaque branchement.

---

## 1. Lancer l'application graphique (GUI)

Vous pouvez lancer l'application directement depuis le Terminal :
```bash
open "TS-PC Control.app"
```
Ou en double-cliquant sur `TS-PC Control.app` dans le Finder.

### Fonctionnalités de l'application :
* **Visualiseur en temps réel** :
  * Volant rotatif vectoriel qui tourne en direct selon votre angle physique (avec affichage précis des degrés).
  * Jauges verticales colorées pour l'accélérateur, le frein et l'embrayage.
  * Témoins lumineux pour les 13 boutons et la croix D-Pad.
* **Réglages du volant** :
  * Angle de rotation (140° à 1080°) avec boutons rapides (Kart 360°, Rallye 540°, GT3 900°, Route 1080°).
  * Gain général du retour de force (0% à 100%).
  * Force du ressort de rappel (Autocentrage matériel) et interrupteur marche/arrêt.
* **Tests de diagnostic FFB** :
  * Impulsion de centrage, traction gauche, traction droite et vibreur.
* **Guide de compatibilité jeux** :
  * Profils recommandés et explications pour les jeux natifs Mac et Windows sous Wine/Whisky/CrossOver.

---

## 2. Utilitaire en ligne de commande (`tspc-cli`)

Pour afficher l'état du volant :
```bash
./tspc-cli status
```

Pour débloquer le volant s'il est en mode démarrage (`0xb65d`) :
```bash
./tspc-cli unlock
```

Pour régler l'angle de braquage (ex: 900°) :
```bash
./tspc-cli range 900
```

Pour régler le ressort de rappel au centre (ex: 60%) :
```bash
./tspc-cli autocenter 60
```
Pour désactiver le rappel au centre :
```bash
./tspc-cli autocenter 0 off
```

Pour régler le gain FFB global :
```bash
./tspc-cli gain 80
```

Pour lancer le moniteur de télémétrie en direct dans le terminal :
```bash
./tspc-cli monitor
```

Pour exécuter le démon de surveillance continue (auto-déblocage automatique) :
```bash
./tspc-cli daemon
```

---

## 3. Utilisation avec GeForce NOW & Forza Horizon

GeForce NOW ne supporte pas nativement les volants Thrustmaster bruts et ne redirige pas les périphériques USB vers ses serveurs distants. Ce projet intègre une **passerelle d'émulation manette Xbox 360 standard 120Hz** :

### Méthode 1 : Via Google Chrome (Recommandé - 100% Plug & Play)
1. **Lancer le pilote** :
   * Ouvrez `TS-PC Control.app` (le serveur local HTTP démarre automatiquement sur le port `8765`), ou lancez `./tspc-cli gfn`.
   * Dans l'onglet **"GeForce NOW (Forza)"**, sélectionnez le profil **Forza Équilibré (540°)** avec l'autocentrage matériel réglé à **55%**.
2. **Charger l'extension Chrome (en 30 secondes)** :
   * Ouvrez Google Chrome à l'adresse `chrome://extensions`.
   * Activez le **Mode développeur** (en haut à droite).
   * Cliquez sur **Charger l'extension non empaquetée** et sélectionnez le sous-dossier `gfn-wheel-extension` de ce projet.
3. **Jouer sur GeForce NOW** :
   * Rendez-vous sur [https://play.geforcenow.com](https://play.geforcenow.com).
   * Le badge vert **TS-PC Racer Xbox Bridge** s'affiche en haut à droite.
   * Lancez **Forza Horizon 5 (ou 6)** : le jeu détecte une manette Xbox officielle.
   * La direction (axe stick gauche), les pédales (gâchettes LT/RT analogiques) et les palettes (LB/RB) répondent immédiatement !

### Méthode 2 : Via l'application native `GeForceNOW.app`
Pour l'application Mac native `GeForceNOW.app`, macOS exige une manette enregistrée dans DriverKit (via `OpenJoystickDriver`) ou un adaptateur matériel USB (type Raspberry Pi Pico avec firmware TinyUSB XInput).

---

## 4. Compatibilité Jeux Locaux & Émulation

### Jeux natifs macOS (GRID Legends, Dirt Rally, F1 2017...)
Le TS-PC Racer une fois débloqué en `0xb689` est reconnu nativement par macOS comme un joystick HID standard. Rendez-vous dans les options de commandes du jeu pour calibrer la direction, les pédales et assigner vos boutons.

### Jeux Windows via Wine / CrossOver / Whisky / GPTK
(Assetto Corsa, BeamNG.drive, iRacing, F1 24, Automobilista 2...)
* Les jeux reçoivent tous les axes et boutons.
* L'application TS-PC Control maintient le ressort de rappel matériel et la résistance souhaitée, offrant une excellente sensation de pilotage même sous émulation.

---

## 5. Recompiler le projet

Pour recompiler le CLI et l'application :
```bash
make clean
make all
```
Pour installer l'application dans `/Applications` :
```bash
make install
```
