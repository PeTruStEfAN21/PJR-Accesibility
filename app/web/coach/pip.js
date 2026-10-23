// The clarity coach's alert above the meeting: a Document Picture-in-Picture window (Chrome or Edge on a
// computer, on https or localhost) that stays on top of every other window, the meeting app included.
// It only shows the text and the icon the page gives it (app/lib/features/coach/alert_window_web.dart).
window.echoPip = (() => {
  const CSS = `
    :root { color-scheme: dark; }
    html, body { margin: 0; height: 100%; background: #121212; color: #f5f5f5; }
    main {
      box-sizing: border-box; height: 100%; display: flex; align-items: center; gap: 14px;
      padding: 12px 16px; border-left: 8px solid #3a3a3a;
      font: 700 calc(20px * var(--scale)) / 1.3 Roboto, sans-serif;
    }
    main.alert { border-left-color: #ffc857; }
    .icon { font-size: calc(34px * var(--scale)); line-height: 1; }
    .text { margin: 0; overflow-wrap: anywhere; }
  `;

  let pip = null;
  let box = null;
  let icon = null;
  let text = null;

  return {
    supported() {
      return 'documentPictureInPicture' in window && window.isSecureContext;
    },

    // Needs a click on the page just before; resolves false when the browser refuses. The text follows
    // the size the colleague chose in Echo (textScale, 1 to 2).
    async open(title, language, textScale, onClosed) {
      if (pip) return true;
      const scale = Math.min(Math.max(textScale, 1), 2);
      try {
        pip = await documentPictureInPicture.requestWindow({
          width: Math.round(400 * Math.min(scale, 1.5)),
          height: Math.round(130 * scale),
        });
      } catch (error) {
        console.warn('echoPip: could not open', error);
        return false;
      }
      const doc = pip.document;
      doc.title = title;
      doc.documentElement.lang = language;
      doc.documentElement.style.setProperty('--scale', String(scale));
      const style = doc.createElement('style');
      // The app's own Roboto (bundled with the build), like every other text in Echo.
      const roboto = new URL('assets/assets/fonts/Roboto-Bold.ttf', document.baseURI).href;
      style.textContent = `@font-face { font-family: Roboto; font-weight: 700; src: url(${roboto}) format('truetype'); }` + CSS;
      doc.head.append(style);
      box = doc.createElement('main');
      box.setAttribute('role', 'status');
      box.setAttribute('aria-live', 'polite');
      icon = doc.createElement('span');
      icon.className = 'icon';
      icon.setAttribute('aria-hidden', 'true');
      text = doc.createElement('p');
      text.className = 'text';
      box.append(icon, text);
      doc.body.append(box);
      pip.addEventListener('pagehide', () => {
        pip = null;
        onClosed();
      });
      return true;
    },

    show(message, symbol, alert) {
      if (!pip) return;
      text.textContent = message;
      icon.textContent = symbol;
      box.classList.toggle('alert', alert);
    },

    close() {
      if (pip) pip.close();
    },
  };
})();
