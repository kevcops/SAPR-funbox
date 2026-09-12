(() => {
  const setPlaying = (playing) => {
    document.body.classList.toggle('sapr-playing', playing);
  };

  const withBasePath = (path) => {
    const basePath = (window.pikaraokeConfig && window.pikaraokeConfig.basePath) || '';
    return `${basePath}${path}`;
  };

  const syncServerPlaybackState = async () => {
    try {
      const response = await fetch(withBasePath('/now_playing'), {
        cache: 'no-store',
      });
      if (!response.ok) return;
      const text = await response.text();
      if (!text) return;
      const state = JSON.parse(text);

      // The video element does not always emit ended/emptied when PiKaraoke
      // receives a remote skip or queue-clear command. The server is the
      // authoritative source for whether a karaoke song still exists. This
      // also preserves the playback layout while a real song is paused.
      if (!state.now_playing) setPlaying(false);
    } catch (_) {
      // A transient status failure should never disturb active playback.
    }
  };

  const bind = () => {
    const video = document.getElementById('video');
    if (!video) return;

    setPlaying(false);
    video.addEventListener('play', () => setPlaying(true));
    video.addEventListener('ended', () => setPlaying(false));
    video.addEventListener('emptied', () => setPlaying(false));
    video.addEventListener('abort', () => setPlaying(false));
    video.addEventListener('error', () => setPlaying(false));

    // Remote phone controls can change PiKaraoke state without producing a
    // reliable media-element event on the splash browser. Reconcile once per
    // second so End Session always restores the full idle-screen QR layout.
    syncServerPlaybackState();
    window.setInterval(syncServerPlaybackState, 1000);
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bind, { once: true });
  } else {
    bind();
  }
})();
