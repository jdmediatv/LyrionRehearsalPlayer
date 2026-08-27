# Rehearsal Player v1.1.0

Tag: `v1.1.0`

Release title:

`Rehearsal Player v1.1.0`

Assets to upload:

- `RehearsalPlayer-1.1.0.zip`
- `RehearsalPlayer-1.1.0.sha1`

Suggested release body:

```md
Rehearsal Player is a native Lyrion Music Server plugin built for rehearsal spaces.

New in v1.1.0:

- Static "Teacher Playlists" sidebar to the left of the existing local playlist view
- Backed by the official Spotify Web API end-to-end
- Browse a teacher's Spotify playlist and play its tracks (playback needs a Spotify
  source plugin such as Spotty installed and configured; browsing/search/add work
  without it)
- Any teacher can connect their own Spotify account and add tracks to a playlist
  they've been made a collaborator on, no shared account credentials required
- Admin settings page to configure Spotify app credentials and manage each teacher
  playlist's label, icon, and linked Spotify playlist
- See SPOTIFY_SETUP.md for the one-time setup walkthrough

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

- Manual install: download `RehearsalPlayer-1.1.0.zip` and extract the `RehearsalPlayer` folder into your LMS plugins directory
- Repository install: add the hosted `repo.xml` URL to LMS plugin repositories (existing installs using this method will offer the update automatically)
```

Publish checklist:

1. Commit `repo.xml`, `release-assets/RehearsalPlayer-1.1.0.zip`, and `release-assets/RehearsalPlayer-1.1.0.sha1` to `jdmediatv/LyrionRehearsalPlayer` main.
2. Create release tag `v1.1.0`.
3. Upload `RehearsalPlayer-1.1.0.zip` and `RehearsalPlayer-1.1.0.sha1` as release assets (optional - the raw `release-assets/` copy in the repo is what `repo.xml` actually points to and is sufficient for installs to update).
4. Test the final asset URL from `repo.xml`.
5. Confirm existing installs pick up the update: Settings -> Plugins in LMS will offer it if "Update plugins automatically" is off, or install it automatically on next restart if that option is on.

   `https://raw.githubusercontent.com/jdmediatv/LyrionRehearsalPlayer/main/repo.xml`
