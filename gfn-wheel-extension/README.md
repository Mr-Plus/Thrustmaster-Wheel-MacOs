# Extension Chrome : Pont TS-PC Racer -> GeForce NOW Web (play.geforcenow.com)

> [!NOTE]
> Cette extension Chrome est une solution de secours pour la version Web de GeForce NOW.  
> Pour bénéficier de la meilleure expérience avec **vrai retour de force (FFB)**, réactivité 120 Hz et reconnaissance native de volant dans les jeux (Forza, F1, etc.), utilisez l'application native **TS2GFN** (`TS2GFN.app`) disponible à la racine de ce dépôt.

Cette extension permet d'utiliser le volant **Thrustmaster TS-PC Racer** sur **GeForce NOW Web (play.geforcenow.com)** sous macOS en convertissant les entrées en manette Xbox standard via l'API Gamepad du navigateur.

---

## Installation dans Google Chrome

1. Ouvrez **Google Chrome**.
2. Dans la barre d'adresse, tapez :
   ```text
   chrome://extensions
   ```
3. En haut à droite de la page, activez le bouton **"Mode développeur"** (Developer mode).
4. Cliquez sur le bouton **"Charger l'extension non empaquetée"** (Load unpacked) en haut à gauche.
5. Sélectionnez le dossier `gfn-wheel-extension` de ce projet.
6. L'extension est immédiatement installée et active.

---

## Utilisation

1. Démarrez le serveur local de télémétrie via le CLI :
   ```bash
   ./tspc-cli serve 8765
   ```
2. Ouvrez [https://play.geforcenow.com](https://play.geforcenow.com).
3. Le badge vert **"TS-PC Racer Xbox Bridge"** s'affiche en haut à droite.
4. Lancez votre jeu de course dans le navigateur.
