# Rapport Technique : TS-PC Racer sur macOS & GeForce NOW (Projet Inachevé)

> **Statut du projet :** Arrêté / Inachevé  
> **Date de clôture :** Octobre 2026  
> **Licence :** Open Source  
> **Cible matérielle :** Apple Silicon (MacBook / Mac mini / iMac) & Intel macOS  
> **Périphérique testé :** Volant Thrustmaster TS-PC Racer (Base FFB USB)

---

## 1. Objectif Initial

Permettre l'utilisation complète d'un volant de simulation de course **Thrustmaster TS-PC Racer** sur **macOS (Apple Silicon)**, avec pour but final de jouer à **Forza Horizon** en streaming via l'application native **GeForce NOW** (`/Applications/GeForceNOW.app`).

### Les 3 défis majeurs à surmonter :
1. **Le verrouillage matériel Thrustmaster (Mode Bootloader) :** À chaque branchement USB sur un système non-Windows, le volant s'initialise dans un mode bridé générique (`0x044f:0xb65d`). Sans pilote constructeur officiel sur macOS, il refuse de calibrer sa rotation à 1080° et n'envoie pas ses données haute résolution.
2. **Le verrouillage logiciel d'Apple (`GameController.framework`) :** macOS ne reconnaît nativement que les manettes de jeu standard (Xbox, PlayStation DualSense/DualShock, Switch Pro, MFi). Les volants et pédaliers USB génériques sont ignorés par les API modernes de jeu d'Apple.
3. **Le verrouillage de streaming GeForce NOW :** L'application native GeForce NOW ne transfère pas les périphériques USB bruts (pas d'USB passthrough vers la machine distante). Elle capture uniquement les manettes reconnues par macOS (`GCExtendedGamepad`) pour les ré-encoder sous forme de manette Xbox virtuelle sur le serveur cloud.

---

## 2. Ce qui a été développé et qui fonctionne

Ce dépôt contient une suite logicielle complète et autonome écrite en **C / Objective-C (IOKit)** et **Swift / SwiftUI** :

### A. Pilote Espace Utilisateur IOKit (`src/TSPCBridge.m`, `src/TSPCBridge.h`)
* **Déblocage USB automatique sans droit root ni extension noyau (No Kext / No Dext) :**  
  Envoi de la requête de contrôle USB constructeur (`bmRequestType: 0x41, bRequest: 83, wValue: 0x0009`) via IOKit pour faire basculer le volant du mode bootloader (`0xb65d`) vers son mode actif pleine résolution (`0xb689`).
* **Décodage des entrées 120 Hz :**  
  * Axe de direction 16-bit (0 à 65535, centré à 32768).
  * 3 pédales 10-bit (Accélérateur, Frein, Embrayage) avec inversion logicielle configurable.
  * Croix multidirectionnelle (Hat Switch / D-Pad).
  * 13 boutons physiques et palettes de vitesses séquentielles.
* **Contrôle matériel du retour de force (FFB) :**  
  * Configuration de l'angle de braquage physique de 140° à 1080° par commande USB.
  * Réglage du gain global de puissance.
  * Activation et dosage du ressort de rappel matériel (autocentrage actif alimenté par le moteur brushless de la base).

### B. Application macOS Native SwiftUI (`TS-PC Control.app`)
* **Tableau de bord visuel en temps réel :** Volant rotatif animé, jauges de pédales en direct, indicateurs de boutons.
* **Panneau de réglages FFB :** Sélecteurs de presets (Kart 360°, Rallye 540°, GT3 900°, Maxi 1080°), curseurs de force et d'autocentrage.
* **Serveur de télémétrie HTTP intégré (Port 8765) :** Expose l'état instantané du volant au format JSON (`http://127.0.0.1:8765/telemetry`) à 120 Hz sans impact CPU.

### C. Utilitaire en Ligne de Commande (`tspc-cli`)
* Contrôle du volant en ligne de commande : déblocage, réglage de l'angle, force, surveillance temps réel, mode démon.

### D. Extension Web Chrome (`gfn-wheel-extension/`)
* Extension Manifest V3 qui intercepte l'API Gamepad du navigateur sur `play.geforcenow.com` et injecte les données du serveur HTTP local sous forme d'une manette Xbox 360 standard.

---

## 3. Pourquoi le projet s'arrête : Les Blocages Techniques sur GeForce NOW Natif

L'objectif spécifique d'utiliser le volant dans **l'application native de bureau GeForce NOW** (`GeForceNOW.app`) s'est heurté à des limitations architecturales profondes de macOS et de NVIDIA :

### 1. Le pipeline d'entrée fermé de `GeForceNOWStreamer`
L'analyse par rétro-ingénierie du binaire `libGeronimo.dylib` (le moteur interne de streaming de GeForce NOW) a révélé la logique suivante :
```text
libGeronimo.dylib :
  1. Tente d'initialiser GameController.framework (ForgeGameController)
  2. Si un périphérique HID arrive :
     "found device 0x044f:0xb689 but not handling since there is no valid mapping"
     -> Rejet pur et simple de tout périphérique non explicitement listé dans le code de NVIDIA.
```
Contrairement à des jeux locaux comme *GRID Legends* ou *Dirt Rally* qui acceptent les périphériques HID génériques, le streamer de GeForce NOW rejette tout ce qui n'est pas une manette reconnue par Apple.

### 2. L'interdiction d'Apple de créer des périphériques virtuels
Sur macOS, une application normale **ne peut pas créer de manette virtuelle** dans le système.
Apple réserve la création de manettes virtuelles (`IOHIDVirtualDevice`) à une permission privée très stricte :  
`com.apple.developer.hid.virtual.device` (nécessite un agrément d'entreprise délivré au cas par cas par Apple).
Sans cette signature d'Apple :
* Impossible pour notre application locale `TS-PC Control.app` de déclarer directement une manette Xbox virtuelle au système d'exploitation.

### 3. Les limites des solutions intermédiaires (DriverKit / OpenJoystickDriver)
Nous avons testé l'utilisation d'OpenJoystickDriver (qui possède l'entitlement Apple et fournit un pont DriverKit / UserSpace vers `GameController.framework`) :
* **Conflits d'accès USB exclusif (`kIOReturnExclusiveAccess`) :** Deux processus concurrents essayant de lire le TS-PC Racer en USB ont provoqué des blocages matériels (axes saturés à fond, direction bloquée à gauche à `-1.00`, accélérateur et frein bloqués à 100%).
* **Variables d'environnement conflictuelles (`SDL_JOYSTICK_MFI`) :** Tenter de forcer SDL2 via IOKit désactive le sous-système MFi d'Apple, ce qui empêche GeForce NOW de voir la manette virtuelle.
* **Instabilité et complexité utilisateur inacceptable :** Cela requiert de valider des extensions système dans les Réglages de sécurité de macOS, de jongler entre plusieurs démons d'arrière-plan, et le résultat en jeu restait saccadé ou non fonctionnel.

---

## 4. Dépendances du Projet

### Dépendances de compilation (Incluses dans macOS) :
* **Système :** macOS 13+ (Ventura, Sonoma, Sequoia) sur architecture `arm64` ou `x86_64`.
* **Compilateurs :** `clang` et `swiftc` (via Xcode Command Line Tools : `xcode-select --install`).
* **Frameworks système Apple :**
  * `IOKit.framework` : Communication USB brute et IOHIDManager.
  * `CoreFoundation.framework` & `Foundation.framework` : Gestion bas niveau et multithreading.
  * `SwiftUI.framework` & `AppKit.framework` : Interface graphique réactive.
  * `GameController.framework` : Détection des manettes certifiées.

### Outils et composants tiers explorés :
* **OpenJoystickDriver (v0.5.0-beta.4) :** Application tierce dotée de l'entitlement Apple `com.apple.developer.hid.virtual.device` pour l'émulation de manette Xbox. *(Non recommandé pour un usage pérenne en raison de la complexité et des conflits d'accès USB)*.

### Pour tester :
 https://hardwaretester.com/gamepad
 https://gamepad-tester.com/

---

## 5. Pistes et Recommandations pour la Suite

Si quelqu'un souhaite reprendre ce travail ou faire fonctionner un volant sur GeForce NOW Mac, voici les approches viables :

### Option A — L'approche matérielle (La seule 100% universelle et stable)
Au lieu de lutter contre les sécurités de macOS :
* Utiliser un microcontrôleur intermédiaire (ex: **Raspberry Pi Pico** à 5€ avec firmware **TinyUSB** ou adaptateur **GIMX / DriveHub**).
* Le volant est branché sur le Pico (USB Host), et le Pico est branché sur le Mac (USB Device) en se faisant passer matériellement pour une vraie manette **Xbox 360 officielle (VID 0x045e, PID 0x028e)**.
* **Résultat :** macOS et GeForce NOW voient une authentique manette Xbox au niveau électrique, sans aucun logiciel ni pilote à installer sur le Mac.

### Option B — L'approche Web (Chrome / PWA)
* Utiliser GeForce NOW dans Google Chrome ([play.geforcenow.com](https://play.geforcenow.com)) avec l'extension locale fournie dans ce dépôt ([gfn-wheel-extension](gfn-wheel-extension/)).
* Le navigateur n'impose pas le filtre `GameController.framework` et accepte les entrées du pont WebSocket/HTTP local.

---

## 6. Structure du Dépôt

```text
├── Makefile                                # Script de compilation (make all, make install)
├── README.md                               # Présentation du projet
├── PROJECT_SUMMARY.md                      # Ce document d'analyse et de clôture
├── Lancer GeForce NOW (Volant).command     # Script d'injection d'environnement
├── com.thrustmaster.gfn-sdl.plist          # Démon LaunchAgent pour persistance SDL
├── com.thrustmaster.tspc.plist             # Démon de déblocage automatique USB
├── tspc-cli                                # Binaire CLI compilé
│
├── src/                                    # Code source du pilote et de l'interface
│   ├── TSPCBridge.h                        # Déclarations C/IOKit
│   ├── TSPCBridge.m                        # Implémentation USB, IOKit, FFB et HTTP server
│   ├── TSPCManager.swift                   # Couche logique Swift & gestionnaire d'état
│   ├── App.swift                           # Point d'entrée SwiftUI
│   ├── cli/main.c                          # Code source du CLI tspc-cli
│   └── Views/                              # Vues SwiftUI
│       ├── DashboardView.swift             # Tableau de bord principal
│       ├── WheelVisualView.swift           # Rendu vectoriel du volant
│       ├── PedalsVisualView.swift          # Rendu des pédales
│       ├── ButtonsVisualView.swift         # Affichage des boutons
│       ├── SettingsView.swift              # Réglages de rotation et FFB
│       ├── GFNForzaView.swift              # Onglet dédié GeForce NOW & Forza
│       └── GamesHelpView.swift             # Guide jeux natifs et Wine
│
└── gfn-wheel-extension/                    # Extension Google Chrome pour play.geforcenow.com
    ├── manifest.json                       # Déclaration Manifest V3
    ├── content.js                          # Script d'injection Gamepad API
    └── background.js                       # Service worker de l'extension
```
