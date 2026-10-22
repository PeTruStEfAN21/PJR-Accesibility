// System-level side of the sound alerts in the browser (laptop or phone).
window.echoAlerts = (() => {
  let current = null;
  let flash = null;
  const title = document.title;

  function onScreen() {
    return document.visibilityState === 'visible' && document.hasFocus();
  }

  async function permission() {
    if ('Notification' in window && Notification.permission === 'default') {
      await Notification.requestPermission();
    }
  }

  function vibrate(pattern) {
    if (navigator.vibrate) navigator.vibrate(pattern);
  }

  function notify(text, body, critical) {
    if (critical) {
      // The tab title alternates (once a second, well under the 3 flashes/s limit) until acknowledged.
      clearInterval(flash);
      let on = false;
      flash = setInterval(() => {
        on = !on;
        document.title = on ? '⚠ ' + text : title;
      }, 1000);
    }
    // The page itself shows the alert; a notification is added when the user may not be looking.
    if (!critical && onScreen()) return;
    if (!('Notification' in window) || Notification.permission !== 'granted') return;
    if (current) current.close();
    current = new Notification(text, { body, tag: 'echo-alert', requireInteraction: critical, renotify: true });
    current.onclick = () => {
      window.focus();
      current && current.close();
    };
  }

  function clear() {
    clearInterval(flash);
    flash = null;
    document.title = title;
    if (current) current.close();
    current = null;
    vibrate(0);
  }

  return { permission, vibrate, notify, clear };
})();
