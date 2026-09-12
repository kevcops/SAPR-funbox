(() => {
  const setPlaying = (playing) => {
    document.body.classList.toggle('sapr-playing', playing);
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
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bind, { once: true });
  } else {
    bind();
  }
})();
