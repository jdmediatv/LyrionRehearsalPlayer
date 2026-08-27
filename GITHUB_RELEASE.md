# Rehearsal Player v1.1.4

Tag: `v1.1.4`

Release title:

`Rehearsal Player v1.1.4`

Assets to upload:

- `RehearsalPlayer-1.1.4.zip`
- `RehearsalPlayer-1.1.4.sha1`

Suggested release body:

```md
Rehearsal Player is a native Lyrion Music Server plugin built for rehearsal spaces.

New in v1.1.4 (Spotify API compatibility fix):

- Spotify's February 2026 Web API migration for Development Mode apps broke
  two things this plugin relies on: it renamed the playlist tracks endpoint
  from /playlists/{id}/tracks to /playlists/{id}/items (this plugin was
  hitting the old, now-403-Forbidden path), and it lowered the search
  endpoint's maximum results per request from 50 to 10 (this plugin was
  asking for 15, which now returns 400 Bad Request). Both are fixed.
- The "Add" search box was also silently swallowing backend errors and
  always showing "No matching tracks found" regardless of the real cause -
  it now surfaces the actual error message.
- The settings page now logs a clear warning if a teacher playlist's
  Spotify ID doesn't look like a full 22-character playlist ID, which
  usually means a shortened spotify.link share link was pasted in instead
  of the full playlist link.

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

- Manual install: download `RehearsalPlayer-1.1.4.zip` and extract the `RehearsalPlayer` folder into your LMS plugins directory
- Repository install: add the hosted `repo.xml` URL to LMS plugin repositories (existing installs using this method will offer the update automatically)
```

Publish checklist:

1. Commit `repo.xml`, `release-assets/RehearsalPlayer-1.1.4.zip`, and `release-assets/RehearsalPlayer-1.1.4.sha1` to `jdmediatv/LyrionRehearsalPlayer` main.
2. Create release tag `v1.1.4`.
3. Upload `RehearsalPlayer-1.1.4.zip` and `RehearsalPlayer-1.1.4.sha1` as release assets (optional - the raw `release-assets/` copy in the repo is what `repo.xml` actually points to and is sufficient for installs to update).
4. Test the final asset URL from `repo.xml`.
5. Confirm existing installs pick up the update: Settings -> Plugins in LMS will offer it if "Update plugins automatically" is off, or install it automatically on next restart if that option is on.

   `https://raw.githubusercontent.com/jdmediatv/LyrionRehearsalPlayer/main/repo.xml`
