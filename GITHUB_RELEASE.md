# Rehearsal Player v1.1.6

Tag: `v1.1.6`

Release title:

`Rehearsal Player v1.1.6`

Assets to upload:

- `RehearsalPlayer-1.1.6.zip`
- `RehearsalPlayer-1.1.6.sha1`

Suggested release body:

```md
Rehearsal Player is a native Lyrion Music Server plugin built for rehearsal spaces.

New in v1.1.6 (important bug fix):

- Clicking a teacher playlist was sending the plugin's own internal row
  identifier to Spotify's Web API instead of the actual Spotify playlist
  id. This meant a teacher playlist could fail to load with a 400 or 403
  error even when its Spotify Playlist field in Settings was filled in
  correctly - the two ids just happened to look similar (both short
  alphanumeric strings), which made it easy to mistake for a bad link when
  it was actually this bug. Root-caused after multiple rounds of log
  analysis with a real Lyrion install; fixed by using the row's real
  Spotify playlist id when fetching its tracks.

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

- Manual install: download `RehearsalPlayer-1.1.6.zip` and extract the `RehearsalPlayer` folder into your LMS plugins directory
- Repository install: add the hosted `repo.xml` URL to LMS plugin repositories (existing installs using this method will offer the update automatically)
```

Publish checklist:

1. Commit `repo.xml`, `release-assets/RehearsalPlayer-1.1.6.zip`, and `release-assets/RehearsalPlayer-1.1.6.sha1` to `jdmediatv/LyrionRehearsalPlayer` main.
2. Create release tag `v1.1.6`.
3. Upload `RehearsalPlayer-1.1.6.zip` and `RehearsalPlayer-1.1.6.sha1` as release assets (optional - the raw `release-assets/` copy in the repo is what `repo.xml` actually points to and is sufficient for installs to update).
4. Test the final asset URL from `repo.xml`.
5. Confirm existing installs pick up the update: Settings -> Plugins in LMS will offer it if "Update plugins automatically" is off, or install it automatically on next restart if that option is on.

   `https://raw.githubusercontent.com/jdmediatv/LyrionRehearsalPlayer/main/repo.xml`
