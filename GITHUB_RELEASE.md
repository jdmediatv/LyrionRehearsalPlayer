# Rehearsal Player v1.1.1

Tag: `v1.1.1`

Release title:

`Rehearsal Player v1.1.1`

Assets to upload:

- `RehearsalPlayer-1.1.1.zip`
- `RehearsalPlayer-1.1.1.sha1`

Suggested release body:

```md
Rehearsal Player is a native Lyrion Music Server plugin built for rehearsal spaces.

New in v1.1.1 (UI update):

- The playlist panel is now labelled "Show Playlists"
- "Teacher Playlists" has moved out of the left sidebar into its own full-width
  section directly below Show Playlists, styled to match the existing playlist strip
- No functional changes to Spotify connect/browse/search/add behaviour from v1.1.0

Also included from prior releases:

- Direct web app at `/jazzartplayer`
- Playlist-driven loading from saved LMS playlists
- Compact dark UI with purple accents
- Tutor and Class filter buttons from track metadata
- Tile-based track launcher with title, tutor, and class
- Large play and pause controls
- Jump presets for relative seek and percentage-based starts
- Volume slider for the selected player
- Portrait tablet page at `/jazzartplayertablet`, optimized for iPad Air 4 style use

Install options:

- Manual install: download `RehearsalPlayer-1.1.1.zip` and extract the `RehearsalPlayer` folder into your LMS plugins directory
- Repository install: add the hosted `repo.xml` URL to LMS plugin repositories (existing installs using this method will offer the update automatically)
```

Publish checklist:

1. Commit `repo.xml`, `release-assets/RehearsalPlayer-1.1.1.zip`, and `release-assets/RehearsalPlayer-1.1.1.sha1` to `jdmediatv/LyrionRehearsalPlayer` main.
2. Create release tag `v1.1.1`.
3. Upload `RehearsalPlayer-1.1.1.zip` and `RehearsalPlayer-1.1.1.sha1` as release assets (optional - the raw `release-assets/` copy in the repo is what `repo.xml` actually points to and is sufficient for installs to update).
4. Test the final asset URL from `repo.xml`.
5. Confirm existing installs pick up the update: Settings -> Plugins in LMS will offer it if "Update plugins automatically" is off, or install it automatically on next restart if that option is on.

   `https://raw.githubusercontent.com/jdmediatv/LyrionRehearsalPlayer/main/repo.xml`
