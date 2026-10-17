# Rapport Technique d'Ingénierie : TS2GFN (Thrustmaster TS-PC Racer vers GeForce NOW)

> **Statut du projet :** Succès Technique Complet & Déployé  
> **Dernière mise à jour :** Octobre 2026  
> **Cible matérielle :** macOS Apple Silicon (M1/M2/M3/M4) & Intel  
> **Périphérique :** Thrustmaster TS-PC Racer (Base FFB USB 1080°, Roue GT / Open Wheel)  
> **Application Cible :** NVIDIA GeForce NOW Desktop (`GeForceNOW.app`) & Jeux Cloud (Forza Horizon 5, F1 24, etc.)  

---

## 1. Vue d'Ensemble & Objectif

L'objectif de ce projet était de surmonter le verrouillage historique des volants de simulation de course sous macOS, afin d'utiliser un volant haut de gamme **Thrustmaster TS-PC Racer** avec toutes ses fonctionnalités (direction 16-bit, pédales analogiques, palettes, boutons GT et **retour de force dynamique FFB**) directement dans l'application native **GeForce NOW**.

Le projet a abouti à la création de **TS2GFN** : une suite logicielle native en espace utilisateur (User-Space) sans aucune extension noyau, sans désactivation de SIP, et sans adaptateur matériel externe.

---

## 2. Les Défis Techniques & Limitations Initiales

### A. Le mode démarrage bridé (Bootloader 0xb65d)
À la mise sous tension ou lors du branchement USB sur un système sans pilote officiel Windows, le TS-PC Racer s'énumère sous l'identifiant générique `0x044f:0xb65d`. Dans cet état :
* Le moteur brushless est inactif (pas de centrage, pas de FFB).
* L'angle de rotation est bridé et les rapports HID haute résolution ne sont pas envoyés.
* **Solution :** Une requête de contrôle USB IOKit spécifique (`bmRequestType: 0x41, bRequest: 83, wValue: 0x0009`) transmise directement à l'interface de contrôle du périphérique provoque sa ré-énumération instantanée en véritable TS-PC Racer (`0x044f:0xb689`).

### B. Le verrouillage Apple & GeForce NOW
* **Sous macOS :** `GameController.framework` ne reconnaît que les manettes grand public (Xbox, DualSense, Switch). Apple interdit à une application standard de créer une manette virtuelle (`com.apple.developer.hid.virtual.device` étant un droit privé refusé au public).
* **Dans GeForce NOW (`libGeronimo.dylib`) :** L'analyse du streamer NVIDIA a révélé un filtrage strict des périphériques HID :
  ```text
  "found device 0x044f:0xb689 but not handling since there is no valid mapping"
  ```
  Le streamer rejette nativement tout volant Thrustmaster car NVIDIA n'embarque de profils volant officiels que pour quelques références (notamment les volants Logitech G29).

---

## 3. L'Architecture Gagnante : Émulation User-Space Logitech G29

Plutôt que d'essayer de créer une manette virtuelle au niveau du noyau ou d'utiliser des kexts obsolètes, la solution retenue a consisté en une **passerelle d'interposition dynamique en espace utilisateur** (`libTSPCG29Bridge.dylib`).

### 1. Interposition Dynamique Mach-O (`DYLD_INSERT_LIBRARIES`)
La bibliothèque s'interpose sur les fonctions IOKit de bas niveau appelées par `GeForceNOWStreamer` :
* `IOHIDManagerOpen`
* `IOHIDDeviceGetProperty` (VendorID, ProductID, SerialNumber, ProductString)
* `IOHIDDeviceOpen` & `IOHIDDeviceClose`
* `IOHIDDeviceRegisterInputReportCallback`
* `IOHIDDeviceSetReport` & `IOHIDDeviceSetReportWithCallback`

### 2. Usurpation d'Identité Logitech G29 (Device Spoofing)
Lorsque GeForce NOW interroge les périphériques HID connectés :
* Le Vendor ID `0x044f` (Thrustmaster) est maquillé en `0x046d` (Logitech).
* Le Product ID `0x0489` (TS-PC Racer) est maquillé en `0x0294` (Logitech G29 Driving Force Racing Wheel).
* La chaîne d'identification renvoie `"Logitech G29 Driving Force Racing Wheel"`.
* Le descripteur de rapport HID (`ReportDescriptor`) est adapté à la volée pour correspondre exactement à la disposition mémoire attendue pour un G29.

### 3. Traduction Bidirectionnelle des Données & FFB en Temps Réel
* **Entrées (Volant -> Jeu) :** Les rapports HID 120 Hz du TS-PC Racer sont convertis en paquets G29 :
  * Angle de rotation 16-bit et axe directionnel.
  * Pédalier 3 axes (Accélérateur, Frein, Embrayage) avec inversion logicielle configurable.
  * Mappage personnalisé des 13 boutons du volant GT et de la croix directionnelle D-Pad.
* **Sorties (Jeu -> Retour de Force Moteur) :**
  * GeForce NOW transmet des paquets FFB DirectInput standard pour G29 via `IOHIDDeviceSetReport`.
  * La passerelle intercepte ces paquets en temps réel, extrait les composantes de force (ressort, frottement, périodique, chocs), leur applique un multiplicateur de gain configurable (`ffb_gain`), et les ré-injecte sous forme de commandes USB brutes au moteur du TS-PC Racer.

### 4. Calibration de la Géométrie de Braquage (1:1)
Dans des jeux comme *Forza Horizon 5*, un décalage était initialement constaté (45° de rotation physique produisait 90° de rotation virtuelle en jeu).
* **Résolution :** Introduction d'un ratio de compensation géométrique configurable dans la passerelle (`steering_ratio = 0.50`).
* Avec ce paramètre, la synchronisation est rigoureusement 1:1 entre le volant physique et le cockpit virtuel du véhicule.

---

## 4. Conformité macOS & Sécurité (SIP Actif)

Pour permettre l'injection de `libTSPCG29Bridge.dylib` via `DYLD_INSERT_LIBRARIES` sans désactiver le System Integrity Protection (SIP) de macOS :
1. **Clone APFS Instantané :** Le lanceur crée un clone de `GeForceNOW.app` dans `~/Applications/GeForceNOW-G29.app`. Grâce au système de fichiers APFS (Copy-on-Write), cette opération est instantanée (0.09s) et n'occupe aucun espace disque supplémentaire.
2. **Entitlements Dédiés :** L'instance dupliquée reçoit les droits `com.apple.security.cs.allow-dyld-environment-variables` et `disable-library-validation`, avec une signature ad-hoc (`codesign -s - -f`).
3. **Pérennité :** L'application originale située dans `/Applications/GeForceNOW.app` n'est jamais modifiée, préservant ainsi les mises à jour automatiques de NVIDIA.

---

## 5. Interface & Expérience Utilisateur (`TS2GFN.app`)

L'application graphique a été entièrement repensée selon un design épuré, moderne et ergonomique :

* **Mise en page 2 colonnes en une seule page :**
  * **Colonne de gauche :** Badge de statut en temps réel et grand bouton de lancement direct pour GeForce NOW.
  * **Colonne de droite :** Réglages matériels aérés (Angle matériel 140° à 1080° avec presets rapides, Sensibilité braquage 1:1, Puissance FFB Cloud, Ressort de centrage, Inversion des pédales).
* **Accès contextuel :**
  * Bouton `[ ⏱ ]` : Ouvre la modale de télémétrie complète (volant rotatif vectoriel, barres de niveau des pédales, matrice de diagnostic des boutons).
  * Bouton `[ ? ]` : Ouvre le guide d'utilisation, la documentation et les informations système (*« Passerelle locale IOKit User-Space — Sans kext ni désactivation SIP »* - `TS2GFN v1.0.0`).
* **Optimisations logicielles :**
  * Remplacement des boucles de polling externes (`pgrep`) par la surveillance native en mémoire `NSWorkspace.shared.runningApplications` (0% CPU au repos).
  * Mise en cache des ressources graphiques et suppression de tout code mort.

---

## 6. Structure du Dépôt

```text
├── Makefile                                # Compilation (make all, make install, make clean)
├── README.md                               # Documentation utilisateur principale
├── PROJECT_SUMMARY.md                      # Rapport technique et d'ingénierie
├── buttons_mapping.conf                    # Mappage boutons GT, ratio braquage et gain FFB
├── Lancer GeForce NOW (Volant).command     # Script de démarrage automatisé
├── AppIcon.icns                            # Icône macOS haute résolution
├── AppIcon_1024.png                        # Fichier source 1024x1024 de l'icône
│
├── src/                                    # Code source
│   ├── Info.plist                          # Métadonnées du bundle TS2GFN.app
│   ├── logo_transparent.png                # Asset graphique transparent pour l'UI
│   ├── TSPCBridge.h                        # Déclarations C/IOKit & Structures de télémétrie
│   ├── TSPCBridge.m                        # Pilote IOKit, déblocage USB et contrôle matériel
│   ├── TSPCG29Bridge.m                     # Passerelle d'interposition dyld & émulation Logitech G29
│   ├── TSPCManager.swift                   # Gestionnaire d'état réactif et coordination Cocoa
│   ├── App.swift                           # Interface graphique principale SwiftUI
│   │
│   ├── Views/                              # Composants visuels SwiftUI
│   │   ├── WheelVisualView.swift           # Rendu vectoriel dynamique du volant
│   │   ├── PedalsVisualView.swift          # Rendu graphique des pédales
│   │   └── ButtonsVisualView.swift         # Matrice de test des boutons et D-Pad
│   │
│   └── cli/                                # Outils en ligne de commande
│       └── main.c                          # Code source de tspc-cli
│
└── gfn-wheel-extension/                    # Extension Google Chrome de secours (Web)
    ├── manifest.json                       # Manifest V3
    ├── content.js                          # Script d'injection Gamepad API
    ├── background.js                       # Worker de l'extension
    └── README.md                           # Notice de l'extension web
```

---

## 7. Conclusion

Le projet démontre qu'il est parfaitement possible de faire fonctionner un équipement simracing haut de gamme réputé incompatible sous macOS, tout en respectant l'ensemble des contraintes de sécurité modernes du système d'exploitation (Apple Silicon, Sandboxing, System Integrity Protection).
