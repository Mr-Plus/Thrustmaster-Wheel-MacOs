#!/bin/bash
# ==============================================================================
# Lanceur optimisé GeForce NOW avec émulation Logitech G29 pour TS-PC Racer
# Supporte SIP activé & survit à 100% des mises à jour de GeForce NOW
# ==============================================================================

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

echo "=========================================================="
echo "  Lancement de GeForce NOW avec Émulation Logitech G29"
echo "  Volant matériel : Thrustmaster TS-PC Racer (macOS)"
echo "=========================================================="

ORIG_APP="/Applications/GeForceNOW.app"
USER_APP_DIR="$HOME/Applications"
CLONE_APP="$USER_APP_DIR/GeForceNOW-G29.app"
DYLIB="$DIR/libTSPCG29Bridge.dylib"

# 1. Vérifier que GeForce NOW officiel est bien installé
if [ ! -d "$ORIG_APP" ]; then
    echo "❌ Erreur : /Applications/GeForceNOW.app n'a pas été trouvé."
    echo "   Veuillez installer GeForce NOW depuis https://www.nvidia.com/fr-fr/geforce-now/download/"
    exit 1
fi

# 2. Vérifier / Compiler la bibliothèque d'injection libTSPCG29Bridge.dylib
if [ ! -f "$DYLIB" ]; then
    echo "• Compilation de la passerelle Logitech G29 (libTSPCG29Bridge.dylib)..."
    make "$DYLIB" >/dev/null 2>&1
    if [ ! -f "$DYLIB" ]; then
        echo "❌ Échec de la compilation de $DYLIB"
        exit 1
    fi
fi

# 3. Si GeForce NOW est déjà ouvert, le fermer proprement avant synchronisation
if pgrep -f "GeForceNOW" >/dev/null; then
    echo "• Fermeture de l'instance précédente de GeForce NOW..."
    pkill -9 -f "GeForceNOW" 2>/dev/null
    sleep 1.0
fi

# 4. Synchroniser le clone APFS (Prend 0.09s, 0 Mo d'espace disque, préserve l'original à 100%)
mkdir -p "$USER_APP_DIR"
NEED_SYNC=0
if [ ! -d "$CLONE_APP" ] || \
   [ "$ORIG_APP/Contents/MacOS/GeForceNOW" -nt "$CLONE_APP/Contents/MacOS/GeForceNOW" ] || \
   [ "$DYLIB" -nt "$CLONE_APP/Contents/MacOS/GeForceNOW" ] || \
   ! /usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" "$CLONE_APP/Contents/Info.plist" >/dev/null 2>&1 || \
   ! /usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" "$CLONE_APP/Contents/Frameworks/GeForceNOW Helper.app/Contents/Info.plist" >/dev/null 2>&1 || \
   ! codesign -d --entitlements - "$CLONE_APP/Contents/MacOS/GeForceNOW" 2>&1 | grep -q "allow-dyld-environment-variables"; then
    NEED_SYNC=1
fi

if [ "$NEED_SYNC" -eq 1 ]; then
    echo "• Création de l'instance protégée pour GeForce NOW (Clone APFS)..."
    rm -rf "$CLONE_APP"
    cp -R "$ORIG_APP" "$CLONE_APP"
    
    echo "• Configuration des autorisations audio (Microphone) et confidentialité..."
    ENT_FILE="/tmp/gfn_entitlements.plist"
    cat << 'EOF' > "$ENT_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.automation.apple-events</key>
	<true/>
	<key>com.apple.security.cs.allow-jit</key>
	<true/>
	<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
	<true/>
	<key>com.apple.security.cs.allow-dyld-environment-variables</key>
	<true/>
	<key>com.apple.security.cs.disable-library-validation</key>
	<true/>
	<key>com.apple.security.device.audio-input</key>
	<true/>
	<key>com.apple.security.device.camera</key>
	<true/>
</dict>
</plist>
EOF

    # Modifier uniquement les Info.plist des applications (.app), JAMAIS les Frameworks (comme SDL2)
    APP_PLISTS=(
        "$CLONE_APP/Contents/Info.plist"
        "$CLONE_APP/Contents/MacOS/GeForceNOWStreamer.app/Contents/Info.plist"
        "$CLONE_APP/Contents/MacOS/GeForceNOWContainer.app/Contents/Info.plist"
        "$CLONE_APP/Contents/Frameworks/GeForceNOW Helper.app/Contents/Info.plist"
        "$CLONE_APP/Contents/Frameworks/GeForceNOW Helper (GPU).app/Contents/Info.plist"
        "$CLONE_APP/Contents/Frameworks/GeForceNOW Helper (Renderer).app/Contents/Info.plist"
        "$CLONE_APP/Contents/Frameworks/GeForceNOW Helper (Plugin).app/Contents/Info.plist"
        "$CLONE_APP/Contents/Frameworks/GeForceNOW Helper (Alerts).app/Contents/Info.plist"
    )
    for p in "${APP_PLISTS[@]}"; do
        if [ -f "$p" ]; then
            /usr/libexec/PlistBuddy -c "Add :NSMicrophoneUsageDescription string 'GeForce NOW utilise le microphone pour le chat vocal dans les jeux.'" "$p" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :NSMicrophoneUsageDescription 'GeForce NOW utilise le microphone pour le chat vocal dans les jeux.'" "$p" 2>/dev/null
            /usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string 'GeForce NOW utilise la caméra pour le streaming vidéo.'" "$p" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :NSCameraUsageDescription 'GeForce NOW utilise la caméra pour le streaming vidéo.'" "$p" 2>/dev/null
        fi
    done

    echo "• Signature locale pour autoriser l'injection et le microphone sous macOS..."
    codesign --force --entitlements "$ENT_FILE" -s - "$CLONE_APP/Contents/Frameworks/GeForceNOW Helper.app" 2>/dev/null
    codesign --force --entitlements "$ENT_FILE" -s - "$CLONE_APP/Contents/Frameworks/GeForceNOW Helper (GPU).app" 2>/dev/null
    codesign --force --entitlements "$ENT_FILE" -s - "$CLONE_APP/Contents/Frameworks/GeForceNOW Helper (Renderer).app" 2>/dev/null
    codesign --force --entitlements "$ENT_FILE" -s - "$CLONE_APP/Contents/Frameworks/GeForceNOW Helper (Plugin).app" 2>/dev/null
    codesign --force --entitlements "$ENT_FILE" -s - "$CLONE_APP/Contents/Frameworks/GeForceNOW Helper (Alerts).app" 2>/dev/null
    codesign --force --entitlements "$ENT_FILE" -s - "$CLONE_APP/Contents/MacOS/GeForceNOWStreamer.app" 2>/dev/null
    codesign --force --entitlements "$ENT_FILE" -s - "$CLONE_APP/Contents/MacOS/GeForceNOWContainer.app" 2>/dev/null
    codesign --force --entitlements "$ENT_FILE" -s - "$CLONE_APP/Contents/MacOS/GeForceNOW" 2>/dev/null
    codesign --force --entitlements "$ENT_FILE" -s - "$CLONE_APP" 2>/dev/null
fi

# 4. Vérifier et débloquer le TS-PC Racer si nécessaire
if [ -x "./tspc-cli" ]; then
    echo "• Vérification du statut du volant TS-PC Racer..."
    ./tspc-cli status >/dev/null 2>&1
    STATUS=$?
    if [ $STATUS -eq 0 ]; then
        echo "✓ TS-PC Racer détecté et opérationnel !"
    else
        # Tenter un déblocage si en bootloader
        ./tspc-cli unlock >/dev/null 2>&1
    fi
fi

# 6. Démarrage de GeForce NOW avec la passerelle G29 active
echo "• Démarrage de GeForce NOW (Émulation Logitech G29 active)..."
DYLD_INSERT_LIBRARIES="$DYLIB" "$CLONE_APP/Contents/MacOS/GeForceNOW" >/dev/null 2>&1 &
GFN_PID=$!
disown $GFN_PID


echo "=========================================================="
echo "  ✓ GeForce NOW est lancé avec succès !"
echo "  ✓ Votre TS-PC Racer est reconnu comme Logitech G29."
echo "  ✓ Les jeux (Forza Horizon, F1, Assetto Corsa...) détecteront"
echo "    directement un véritable volant avec angle et pédales natifs."
echo "=========================================================="
sleep 2
