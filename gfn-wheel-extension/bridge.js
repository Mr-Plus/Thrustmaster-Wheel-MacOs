// Bridge TS-PC Racer -> Manette Xbox Standard pour GeForce NOW & Forza Horizon
(function() {
  'use strict';

  console.log('[TS-PC GFN Bridge] Initialisation du pont Xbox 360...');

  const origGetGamepads = navigator.getGamepads.bind(navigator);

  // Configuration par défaut optimisée pour Forza Horizon
  const config = {
    linearity: 1.2,     // 1.0 = direct, 1.2+ = plus de stabilité au centre
    deadzone: 0.02,     // 2% de zone morte
    targetRange: 540    // Degrés physiques recommandés
  };

  const state = {
    connected: false,
    steer: 0.0,
    gas: 0.0,
    brake: 0.0,
    clutch: 0.0,
    buttons: 0,
    hat: -1,
    wheelAngleDeg: 0.0,
    lastUpdate: 0,
    source: 'none'
  };

  // 1. Polling du pilote local macOS via http://127.0.0.1:8765/telemetry
  async function pollLocalDriver() {
    try {
      const res = await fetch('http://127.0.0.1:8765/telemetry', { cache: 'no-store' });
      if (res.ok) {
        const data = await res.json();
        
        // Calcul de la direction avec courbe de sensibilité
        const norm = (data.wheelRaw - 32768) / 32768.0;
        let steerVal = 0.0;
        if (Math.abs(norm) > config.deadzone) {
          const sign = norm >= 0 ? 1 : -1;
          steerVal = sign * Math.pow(Math.abs(norm), config.linearity);
        }
        
        state.steer = Math.max(-1.0, Math.min(1.0, steerVal));
        state.gas = Math.max(0.0, Math.min(1.0, data.gasPercent / 100.0));
        state.brake = Math.max(0.0, Math.min(1.0, data.brakePercent / 100.0));
        state.clutch = Math.max(0.0, Math.min(1.0, data.clutchPercent / 100.0));
        state.buttons = data.buttons || 0;
        state.hat = data.hat;
        state.wheelAngleDeg = data.wheelAngleDeg || 0.0;
        state.connected = data.connected;
        state.lastUpdate = performance.now();
        state.source = 'TS-PC Control (Local HTTP 120Hz)';
        
        updateHUD();
      }
    } catch (e) {
      // Pilote local fermé, le fallback sur Gamepad physique prendra le relais si disponible
    }
    setTimeout(pollLocalDriver, 8); // ~120 Hz
  }

  pollLocalDriver();

  // 2. Fallback de secours : lecture directe si le pilote HTTP n'est pas ouvert
  function checkDirectGamepadFallback() {
    const now = performance.now();
    if (now - state.lastUpdate > 500) {
      const rawGps = origGetGamepads();
      for (let i = 0; i < rawGps.length; i++) {
        const gp = rawGps[i];
        if (gp && (gp.id.includes('044f') || gp.id.toLowerCase().includes('thrustmaster') || gp.id.includes('b689'))) {
          if (gp.axes.length > 0) {
            const rawSteer = gp.axes[0];
            const sign = rawSteer >= 0 ? 1 : -1;
            state.steer = sign * Math.pow(Math.abs(rawSteer), config.linearity);
          }
          state.connected = true;
          state.source = 'Chrome Gamepad Direct';
          updateHUD();
          break;
        }
      }
    }
  }

  function makeBtn(pressed, val) {
    return {
      pressed: Boolean(pressed),
      touched: Boolean(pressed),
      value: typeof val === 'number' ? val : (pressed ? 1.0 : 0.0)
    };
  }

  // 3. Synthèse de la manette Xbox 360 standard
  function synthesizeXboxController() {
    checkDirectGamepadFallback();

    const now = performance.now();
    const b = state.buttons;

    // Mapping des boutons :
    // Bouton 1 -> A, Bouton 2 -> B, Bouton 3 -> X, Bouton 4 -> Y
    // Bouton 5 (Palette Gauche) -> LB (Rapport inférieur)
    // Bouton 6 (Palette Droite) -> RB (Rapport supérieur)
    const btnA = (b & 1) !== 0;
    const btnB = (b & 2) !== 0;
    const btnX = (b & 4) !== 0;
    const btnY = (b & 8) !== 0;
    const btnLB = (b & 16) !== 0;
    const btnRB = (b & 32) !== 0;
    const btnBack = (b & 256) !== 0;
    const btnStart = (b & 512) !== 0;

    // Croix D-Pad (Hat switch)
    const dpadUp = state.hat === 0 || state.hat === 1 || state.hat === 7;
    const dpadDown = state.hat === 3 || state.hat === 4 || state.hat === 5;
    const dpadLeft = state.hat === 5 || state.hat === 6 || state.hat === 7;
    const dpadRight = state.hat === 1 || state.hat === 2 || state.hat === 3;

    const standardButtons = [
      makeBtn(btnA),                                  // 0: A
      makeBtn(btnB),                                  // 1: B
      makeBtn(btnX),                                  // 2: X
      makeBtn(btnY),                                  // 3: Y
      makeBtn(btnLB),                                 // 4: LB (Palette -)
      makeBtn(btnRB),                                 // 5: RB (Palette +)
      makeBtn(state.brake > 0.02, state.brake),       // 6: LT (Frein progressif)
      makeBtn(state.gas > 0.02, state.gas),           // 7: RT (Accélérateur progressif)
      makeBtn(btnBack),                               // 8: Back / View
      makeBtn(btnStart),                              // 9: Start / Menu
      makeBtn(false),                                 // 10: LS Click
      makeBtn(false),                                 // 11: RS Click
      makeBtn(dpadUp),                                // 12: Dpad Up
      makeBtn(dpadDown),                              // 13: Dpad Down
      makeBtn(dpadLeft),                              // 14: Dpad Left
      makeBtn(dpadRight),                             // 15: Dpad Right
      makeBtn(false)                                  // 16: Guide
    ];

    return {
      id: 'Xbox 360 Controller (STANDARD GAMEPAD Vendor: 045e Product: 028e)',
      index: 0,
      connected: state.connected,
      timestamp: now,
      mapping: 'standard',
      axes: [
        state.steer, // Left Stick X: Direction du volant
        0.0,         // Left Stick Y
        0.0,         // Right Stick X
        0.0          // Right Stick Y
      ],
      buttons: standardButtons,
      vibrationActuator: null
    };
  }

  // 4. Surcharge de l'API W3C navigator.getGamepads
  navigator.getGamepads = function() {
    const real = origGetGamepads();
    const xbox = synthesizeXboxController();

    const result = [xbox];
    for (let i = 0; i < real.length; i++) {
      if (real[i]) {
        // Filtrer le TS-PC brut pour éviter les doublons dans GFN
        const isRawTSPC = real[i].id.includes('044f') || real[i].id.toLowerCase().includes('thrustmaster');
        if (!isRawTSPC) {
          result.push(real[i]);
        }
      }
    }
    return result;
  };

  // 5. Mini HUD discret en haut à droite sur play.geforcenow.com
  let hudEl = null;
  function updateHUD() {
    if (!hudEl) {
      if (!document.body) return;
      hudEl = document.createElement('div');
      hudEl.style.position = 'fixed';
      hudEl.style.top = '12px';
      hudEl.style.right = '12px';
      hudEl.style.zIndex = '999999';
      hudEl.style.backgroundColor = 'rgba(15, 18, 24, 0.9)';
      hudEl.style.color = '#fff';
      hudEl.style.fontFamily = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
      hudEl.style.fontSize = '11px';
      hudEl.style.padding = '8px 12px';
      hudEl.style.borderRadius = '8px';
      hudEl.style.border = '1px solid rgba(0, 255, 128, 0.3)';
      hudEl.style.boxShadow = '0 4px 12px rgba(0,0,0,0.5)';
      hudEl.style.pointerEvents = 'none';
      hudEl.style.transition = 'opacity 0.3s ease';
      document.body.appendChild(hudEl);
    }

    const steerPct = Math.round(state.steer * 100);
    const gasPct = Math.round(state.gas * 100);
    const brakePct = Math.round(state.brake * 100);

    hudEl.innerHTML = `
      <div style="display:flex; align-items:center; gap:6px; margin-bottom:4px;">
        <span style="display:inline-block; width:8px; height:8px; border-radius:50%; background:${state.connected ? '#00e676' : '#ff5252'};"></span>
        <strong style="color:#00e676;">TS-PC Racer Xbox Bridge</strong>
        <span style="color:#888; font-size:9px;">(Forza)</span>
      </div>
      <div style="font-size:10px; color:#aaa; font-family:monospace;">
        Dir: <span style="color:#00e5ff;">${steerPct > 0 ? '+' : ''}${steerPct}%</span> | 
        Gaz: <span style="color:#00e676;">${gasPct}%</span> | 
        Frein: <span style="color:#ff5252;">${brakePct}%</span>
      </div>
    `;
  }

  console.log('[TS-PC GFN Bridge] Prêt pour GeForce NOW et Forza Horizon !');
})();
