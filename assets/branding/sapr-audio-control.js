(() => {
  const MODES = [
    ['auto', 'Auto'],
    ['hdmi', 'TV / HDMI'],
    ['analog', 'Speaker / PA'],
    ['bluetooth', 'Bluetooth'],
  ];

  const apiBase = () => `${window.location.protocol}//${window.location.hostname}:5556`;

  const showStatus = (el, text, isError = false) => {
    el.textContent = text || '';
    el.classList.toggle('is-error', isError);
  };

  const bind = async () => {
    // Only the phone/controller UI receives the SAPR brand header. The splash
    // page intentionally does not, so this control will not appear on the TV.
    const header = document.querySelector('.sapr-brand-header');
    if (!header || document.getElementById('sapr-audio-control')) return;

    const wrap = document.createElement('div');
    wrap.id = 'sapr-audio-control';
    wrap.innerHTML = `
      <label for="sapr-audio-select">Audio</label>
      <select id="sapr-audio-select" aria-label="Audio output">
        ${MODES.map(([value, label]) => `<option value="${value}">${label}</option>`).join('')}
      </select>
      <span id="sapr-audio-status" role="status" aria-live="polite"></span>
    `;
    header.appendChild(wrap);

    const select = document.getElementById('sapr-audio-select');
    const status = document.getElementById('sapr-audio-status');

    try {
      const response = await fetch(`${apiBase()}/audio`, { cache: 'no-store' });
      if (response.ok) {
        const data = await response.json();
        if (MODES.some(([value]) => value === data.mode)) select.value = data.mode;
      }
    } catch (_) {
      showStatus(status, 'Audio control unavailable', true);
    }

    select.addEventListener('change', async () => {
      const requested = select.value;
      select.disabled = true;
      showStatus(status, 'Switching…');
      try {
        const response = await fetch(`${apiBase()}/audio/${encodeURIComponent(requested)}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
        });
        const data = await response.json().catch(() => ({}));
        if (!response.ok) throw new Error(data.error || 'Could not switch audio output');
        showStatus(status, 'Connected');
        window.setTimeout(() => showStatus(status, ''), 1800);
      } catch (err) {
        showStatus(status, err.message || 'Audio switch failed', true);
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
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bind, { once: true });
  } else {
    bind();
  }
})();
