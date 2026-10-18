# TS2GFN — Thrustmaster TS-PC Racer vers GeForce NOW pour macOS (Apple Silicon & Intel)

![TS2GFN Logo](src/logo_transparent.png)

> **Statut du projet : 100% Fonctionnel & Opérationnel.**  
> Pont local en espace utilisateur (User-Space IOKit) permettant d'utiliser le volant **Thrustmaster TS-PC Racer** avec toutes ses fonctionnalités (direction 16-bit, pédales, boutons, palettes et **Retour de Force / FFB**) dans l'application native **NVIDIA GeForce NOW** sous macOS, sans extension noyau ni désactivation du SIP.

---

## 🚀 Fonctionnalités Principales

1. **Émulation Native Logitech G29 dans GeForce NOW** :
   * Grâce à une bibliothèque d'interposition dynamique (`libTSPCG29Bridge.dylib`), GeForce NOW reconnaît directement votre TS-PC Racer comme un authentique volant **Logitech G29 Driving Force Racing Wheel**.
   * Les jeux de course cloud (**Forza Horizon 5, F1 24, Assetto Corsa, EA WRC, Dirt Rally...**) détectent un vrai volant au lieu d'une manette basique.

2. **Retour de Force Dynamique (FFB) Opérationnel** :
   * Les effets de retour de force envoyés par les serveurs distants de GeForce NOW (vibrations de vibreurs, dérapages, perte d'adhérence, résistance de direction) sont interceptés, traduits et transmis en temps réel au moteur brushless haute puissance du TS-PC Racer.
   * Multiplicateur de gain FFB ajustable en direct dans l'interface (1.5x recommandé).

3. **Synchronisation Braquage 1:1 Parfaite (Forza & Simulations)** :
   * Correction géométrique intégrée (`steering_ratio = 0.50`) : 45° de rotation physique correspondent exactement à 45° dans le cockpit virtuel. Fini l'effet de sur-braquage ou de décalage angulaire.

4. **Déblocage USB Automatique (No Kext / No Dext / SIP Actif)** :
   * À la connexion, le volant s'initialise en mode bootloader générique (`0x044f:0xb65d`). **TS2GFN** lui transmet automatiquement la séquence de contrôle USB constructeur pour l'activer en tant que vrai **TS-PC Racer** haute résolution (`0x044f:0xb689`) à 1080°.
   * Fonctionne entièrement en espace utilisateur standard, sans aucun droit root, sans kext ni extension DriverKit, et avec **SIP (System Integrity Protection) activé**.

5. **Interface Graphique Épurée & Aérée (`TS2GFN.app`)** :
   * Application SwiftUI native en une seule page claire et réactive.
   * Grand bouton de lancement direct pour GeForce NOW avec vérification automatique de l'environnement.
   * Curseurs de réglages physiques (Angle 140° à 1080°, Sensibilité 1:1, Puissance FFB, Ressort de centrage, Inversion des pédales).
   * Modale Télémétrie (`⏱`) : Volant vectoriel animé, jauges de pédalier en direct, matrice de test des boutons GT.
   * Modale Aide (`?`) : Notice d'utilisation et spécifications techniques.

---

## 📦 Contenu du Répertoire

* **`TS2GFN.app`** : Application graphique macOS (SwiftUI / Cocoa).
* **`libTSPCG29Bridge.dylib`** : Passerelle d'interposition IOKit pour l'émulation Logitech G29 et la traduction FFB.
* **`Lancer GeForce NOW (Volant).command`** : Script automatisé de lancement avec clone APFS sans perte d'espace disque.
* **`buttons_mapping.conf`** : Fichier de configuration du mappage des boutons GT, du ratio de braquage et du gain FFB.
* **`tspc-cli`** : Utilitaire en ligne de commande pour le contrôle matériel, la télémétrie et le déblocage en script.
* **`gfn-wheel-extension/`** : Extension Chrome de secours pour la version Web (play.geforcenow.com).

---

## 🛠️ Installation & Démarrage Rapide

### 1. Prérequis
* Un Mac (Apple Silicon M1/M2/M3/M4 ou processeur Intel) sous macOS 13+.
* Le volant **Thrustmaster TS-PC Racer** (avec roue GT / Open Wheel ou standard) branché en USB.
* L'application officielle **GeForce NOW** installée dans `/Applications/GeForceNOW.app`.

### 2. Compilation
Dans le Terminal, à la racine du projet :
```bash
make all
make install
```
Cette commande compile `tspc-cli`, la dylib d'émulation `libTSPCG29Bridge.dylib`, l'application `TS2GFN.app` et l'installe directement dans votre dossier `/Applications`.

### 3. Utilisation au quotidien
1. Branchez votre volant **Thrustmaster TS-PC Racer** à votre Mac.
2. Ouvrez l'application **TS2GFN** depuis votre dossier Applications ou via Spotlight.
3. Ajustez vos préférences (par exemple 900° ou 1080°, Sensibilité à 0.50, FFB à 1.50x).
4. Cliquez sur le grand bouton vert **« LANCER GEFORCE NOW »** :
   * L'application prépare un clone APFS sécurisé (`~/Applications/GeForceNOW-G29.app`) respectant le SIP.
   * GeForce NOW démarre avec la passerelle G29 injectée.
5. Lancez votre jeu de course préféré (Forza Horizon 5, F1 24, etc.) : **votre volant et son retour de force fonctionnent immédiatement !**

---

## ⚙️ Configuration Avancée (`buttons_mapping.conf`)

Le fichier `buttons_mapping.conf` permet d'ajuster les correspondances de boutons et l'étalonnage :

```ini
# Configuration du mappage des boutons Thrustmaster TS-PC Racer -> Logitech G29
# Volant GT / Open Wheel
shift_up=2        # Palette droite (Monter vitesse / R1)
shift_down=1      # Palette gauche (Rétrograder / L1)
btn_a=6           # Bouton Croix (A)
btn_b=5           # Bouton Rond (B)
btn_x=4           # Bouton Carré (X)
btn_y=3           # Bouton Triangle (Y)
btn_l2=10         # Gâchette L2
btn_r2=9          # Gâchette R2
btn_select=7      # Bouton Select / View
btn_start=8       # Bouton Start / Menu
btn_l3=11         # Bouton L3
btn_r3=12         # Bouton R3
btn_home=13       # Bouton PlayStation / Home

# Calibration Angle & FFB
steering_ratio=0.50  # 0.50 = 1:1 parfait dans Forza Horizon 5
ffb_gain=1.20        # Multiplicateur dynamique FFB Cloud (1.20x recommandé)

# Paramètres Principaux des Forces (Défauts Thrustmaster)
master_gain=75       # Ajuster l'ensemble des forces (75% défaut constructeur)
gain_constant=100    # Forces Constantes (100%)
gain_periodic=100    # Forces Périodiques (100%)
gain_spring=100      # Forces de Ressort (100%)
gain_damper=100      # Forces d'Amortisseur (100%)
boost_enabled=0      # BOOST Constant + Ressort (0=OFF, 1=ON)

# Paramètres de Retour au Centre (game = via le jeu, wheel = via le volant)
autocenter_mode=game # 'game' coupe le ressort interne matériel pour laisser la physique du jeu piloter le centrage
autocenter_wheel_force=50 # Force du ressort statique lorsque le mode 'wheel' est actif
```

---

## 💻 Utilitaire Ligne de Commande (`tspc-cli`)

Pour les utilisateurs avancés ou l'intégration dans des scripts :

* **Vérifier l'état du volant** :
  ```bash
  ./tspc-cli status
  ```
* **Débloquer le volant (si en bootloader `0xb65d`)** :
  ```bash
  ./tspc-cli unlock
  ```
* **Régler l'angle de rotation matériel (ex: 900°)** :
  ```bash
  ./tspc-cli range 900
  ```
* **Régler le rappel au centre (autocentrage matériel)** :
  ```bash
  ./tspc-cli autocenter 50
  ```
* **Lancer le moniteur de télémétrie en temps réel** :
  ```bash
  ./tspc-cli monitor
  ```
* **Lancer l'assistant interactif de calibration des boutons** :
  ```bash
  ./tspc-cli calibrate-buttons
  ```

---

## 🛡️ Sécurité & Système (SIP)

* **Aucune extension noyau (Kext)** : Contrairement aux anciens pilotes non signés, TS2GFN utilise exclusivement les API IOKit en espace utilisateur.
* **SIP Actif** : Le System Integrity Protection de macOS reste activé. Le lanceur crée un clone APFS copy-on-write de l'application GeForce NOW dans `~/Applications/GeForceNOW-G29.app` pour y injecter `libTSPCG29Bridge.dylib` en toute conformité.
* **Empreinte CPU Minimale** : L'application n'effectue aucun polling lourd de processus ; la détection est gérée en mémoire via les API Cocoa natives.

---

## 📄 Licence

Ce projet est distribué sous licence open source pour la communauté simracing sur macOS.
Thrustmaster, Logitech, GeForce NOW et Forza Horizon sont des marques déposées de leurs propriétaires respectifs.
