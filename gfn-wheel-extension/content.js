// Injection de bridge.js dans le contexte de la page pour intercepter navigator.getGamepads
(function() {
  const script = document.createElement('script');
  script.src = chrome.runtime.getURL('bridge.js');
  script.onload = function() {
    this.remove();
  };
  (document.head || document.documentElement).appendChild(script);
})();
