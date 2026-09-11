# Top Karaoke Catalog

The permanent catalog is intended to be a curated house library (target: ~100 songs).

## Manifest

Edit `config/top-karaoke.csv` with:

- rank
- artist
- title
- source type
- source

Do not commit copyrighted audio/video files to Git.

The project deliberately does not bulk-download copyrighted karaoke tracks from YouTube. Populate the runtime library from media you own/license or from sources that explicitly authorize downloading and commercial playback.

Runtime destination:

```text
/srv/funbox/karaoke/top-karaoke/
```

Event-specific media belongs in:

```text
/srv/funbox/karaoke/events/current/
```

## Initial v1 reference list

The included 100-title manifest is seeded from Singa's 2026 United States most-sung karaoke ranking. It is a *selection manifest*, not a media bundle. Source fields are intentionally blank.

Before production use, consider whether SA Party Rental wants separate **standard** and **family-friendly** house catalogs; several popular karaoke songs contain explicit lyrics, and seasonal titles may be better swapped out for evergreen party songs.
