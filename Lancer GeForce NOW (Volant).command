#!/bin/bash
# ==============================================================================
# Lanceur optimisé GeForce NOW avec support Thrustmaster TS-PC Racer pour macOS
# ==============================================================================

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

echo "=========================================================="
echo "  Lancement de GeForce NOW avec support TS-PC Racer"
echo "=========================================================="

# 1. Vérifier l'état du volant
if [ -x "./tspc-cli" ]; then
    echo "• Vérification du volant TS-PC Racer..."
    ./tspc-cli unlock 2>/dev/null
fi

# 2. Configurer les variables d'environnement pour GeForce NOW
# IMPORTANT : On ne désactive SURTOUT PAS MFi car la manette virtuelle Xbox utilise GameController.framework !
launchctl unsetenv SDL_JOYSTICK_MFI
launchctl unsetenv SDL_JOYSTICK_HIDAPI
export SDL_GAMECONTROLLERCONFIG="030040694f04000089b6000000070000,Thrustmaster TS-PC Racer,platform:Mac OS X,a:b0,b:b1,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,back:b8,start:b9,leftx:a0,lefttrigger:a2~,righttrigger:a3~,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,"
launchctl setenv SDL_GAMECONTROLLERCONFIG "$SDL_GAMECONTROLLERCONFIG"

# 3. Si GeForce NOW est déjà ouvert, le fermer proprement pour appliquer le mode volant
if pgrep -x "GeForceNOW" >/dev/null; then
    echo "• Redémarrage de GeForce NOW pour appliquer le pilote de volant..."
    killall "GeForceNOW" 2>/dev/null
    sleep 1.5
fi

# 4. Lancer l'application native GeForce NOW
echo "• Démarrage de GeForceNOW.app..."
open -a "/Applications/GeForceNOW.app" \
  --env SDL_GAMECONTROLLERCONFIG="$SDL_GAMECONTROLLERCONFIG"

echo "=========================================================="
echo "  GeForce NOW est prêt !"
echo "  Votre TS-PC Racer est configuré comme manette standard."
echo "  Vous pouvez lancer Forza Horizon et piloter au volant."
echo "=========================================================="
sleep 2
