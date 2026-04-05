# Rehearsal Player v1.0.0

Tag: `v1.0.0`

Release title:

`Rehearsal Player v1.0.0`

Assets to upload:

- `RehearsalPlayer-1.0.0.zip`
- `RehearsalPlayer-1.0.0.sha1`

Suggested release body:

```md
Rehearsal Player is a native Lyrion Music Server plugin built for rehearsal spaces.

Features in v1.0.0:

- Direct web app at `/jazzartplayer`
- Playlist-driven loading from saved LMS playlists
- Compact dark UI with purple accents
- Tutor and Class filter buttons from track metadata
- Tile-based track launcher with title, tutor, and class
- Large play and pause controls
- Jump presets for relative seek and percentage-based starts
- Volume slider for the selected player

Install options:

- Manual install: download `RehearsalPlayer-1.0.0.zip` and extract the `RehearsalPlayer` folder into your LMS plugins directory
- Repository install: add the hosted `repo.xml` URL to LMS plugin repositories
```

Publish checklist:

1. Create a GitHub repo for the plugin or release assets.
2. Commit `repo.xml` to the repo root in `jdmediatv/LyrionRehearsalPlayer`.
3. Create release tag `v1.0.0`.
4. Upload `RehearsalPlayer-1.0.0.zip` and `RehearsalPlayer-1.0.0.sha1` as release assets.
5. Test the final asset URL from `repo.xml`.
6. Share this raw `repo.xml` URL with users, or submit it to the LMS community repository aggregator:

   `https://raw.githubusercontent.com/jdmediatv/LyrionRehearsalPlayer/main/repo.xml`
