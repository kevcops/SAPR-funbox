(() => {
  const MODES = [
    ['auto', 'Auto'],
    ['hdmi', 'TV / HDMI'],
    ['analog', 'Speaker / PA'],
    // Bluetooth is intentionally hidden from the renter-facing phone UI for
    // now. The backend support remains in place so it can be re-enabled later.
    // ['bluetooth', 'Bluetooth'],
  ];

  const apiBase = () => `${window.location.protocol}//${window.location.hostname}:5556`;
  const pikaBase = () => (window.pikaraokeConfig && window.pikaraokeConfig.basePath) || '';

  const showStatus = (el, text, isError = false) => {
    el.textContent = text || '';
    el.classList.toggle('is-error', isError);
  };

  const postPikaraoke = async (path, options = {}) => {
    const response = await fetch(`${pikaBase()}${path}`, {
      method: 'POST',
      cache: 'no-store',
      ...options,
    });
    if (!response.ok) {
      let message = 'Control request failed';
      try {
        const data = await response.json();
        if (data && data.error) message = data.error;
      } catch (_) {}
      throw new Error(message);
    }
    return response;
  };

  const bind = async () => {
    // Only the phone/controller UI receives the SAPR brand header. The splash
    // page intentionally does not, so these controls will not appear on the TV.
    const header = document.querySelector('.sapr-brand-header');
    if (!header || document.getElementById('sapr-audio-control')) return;

    const wrap = document.createElement('div');
    wrap.id = 'sapr-audio-control';
    wrap.innerHTML = `
      <div class="sapr-audio-row">
        <label for="sapr-audio-select">Audio</label>
        <select id="sapr-audio-select" aria-label="Audio output">
          ${MODES.map(([value, label]) => `<option value="${value}">${label}</option>`).join('')}
        </select>
        <span id="sapr-audio-status" role="status" aria-live="polite"></span>
      </div>
      <div id="sapr-player-controls" aria-label="Karaoke playback controls">
        <button type="button" id="sapr-pause" class="sapr-control-button">Pause / Resume</button>
        <button type="button" id="sapr-next" class="sapr-control-button">Next Song</button>
        <button type="button" id="sapr-end-session" class="sapr-control-button sapr-control-danger">End Session</button>
      </div>
      <span id="sapr-player-status" role="status" aria-live="polite"></span>
    `;
    header.appendChild(wrap);

    const select = document.getElementById('sapr-audio-select');
    const audioStatus = document.getElementById('sapr-audio-status');
    const playerStatus = document.getElementById('sapr-player-status');
    const pauseButton = document.getElementById('sapr-pause');
    const nextButton = document.getElementById('sapr-next');
    const endButton = document.getElementById('sapr-end-session');
    const playerButtons = [pauseButton, nextButton, endButton];

    try {
      const response = await fetch(`${apiBase()}/audio`, { cache: 'no-store' });
      if (response.ok) {
        const data = await response.json();
        if (MODES.some(([value]) => value === data.mode)) select.value = data.mode;
      }
    } catch (_) {
      showStatus(audioStatus, 'Audio control unavailable', true);
    }

    select.addEventListener('change', async () => {
      const requested = select.value;
      select.disabled = true;
      showStatus(audioStatus, 'Switching…');
      try {
        const response = await fetch(`${apiBase()}/audio/${encodeURIComponent(requested)}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
        });
        const data = await response.json().catch(() => ({}));
        if (!response.ok) throw new Error(data.error || 'Could not switch audio output');
        showStatus(audioStatus, 'Connected');
        window.setTimeout(() => showStatus(audioStatus, ''), 1800);
      } catch (err) {
        showStatus(audioStatus, err.message || 'Audio switch failed', true);
        try {
          const current = await fetch(`${apiBase()}/audio`, { cache: 'no-store' });
          if (current.ok) {
            const data = await current.json();
            if (data.mode) select.value = data.mode;
          }
        } catch (_) {}
      } finally {
        select.disabled = false;
      }
    });

    const runPlayerAction = async (button, message, action) => {
      playerButtons.forEach((btn) => { btn.disabled = true; });
      showStatus(playerStatus, message);
      try {
        await action();
        showStatus(playerStatus, 'Done');
        window.setTimeout(() => showStatus(playerStatus, ''), 1500);
      } catch (err) {
        showStatus(playerStatus, err.message || 'Playback control failed', true);
      } finally {
        playerButtons.forEach((btn) => { btn.disabled = false; });
      }
    };

    pauseButton.addEventListener('click', () => {
      runPlayerAction(pauseButton, 'Updating playback…', () => postPikaraoke('/pause'));
    });

    nextButton.addEventListener('click', () => {
      runPlayerAction(nextButton, 'Skipping…', () => postPikaraoke('/skip'));
    });

    endButton.addEventListener('click', () => {
      const confirmed = window.confirm(
        'End this karaoke session? This stops the current song and clears the entire queue.'
      );
      if (!confirmed) return;

      runPlayerAction(endButton, 'Ending session…', () =>
        postPikaraoke('/queue/edit?action=clear', {
          headers: { 'X-Requested-With': 'XMLHttpRequest' },
        })
      );
    });
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bind, { once: true });
  } else {
    bind();
  }
})();
