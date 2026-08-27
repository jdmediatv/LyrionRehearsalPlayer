# Rehearsal Player v1.1.8

Tag: `v1.1.8`

Release title:

`Rehearsal Player v1.1.8`

Assets to upload:

- `RehearsalPlayer-1.1.8.zip`
- `RehearsalPlayer-1.1.8.sha1`

Suggested release body:

```md
Rehearsal Player is a native Lyrion Music Server plugin built for rehearsal spaces.

New in v1.1.8:

- The Spotify search-and-add box is now a popup instead of an inline
  panel, styled to look like a proper Spotify search UI: dark theme,
  green accents, rounded search bar, and album art thumbnails on each
  result. It opens from a new "+ Add Tracks" button that appears next to
  Teacher Playlists whenever you're browsing one.
- Fixed a bug where adding a track and then refreshing the playlist you
  were browsing could send Spotify the plugin's internal row id instead
  of the real playlist id - the same class of bug fixed for playlist
  loading in 1.1.6, just in the add-track refresh path this time.

Also included from prior releases:

- Spotify Connect/Disconnect moved off the main kiosk screen and into the
  plugin's Settings page, and sign-in is now admin-only: one shared
  connection is managed by an administrator, and students/teachers at the
  kiosk can no longer sign in, sign out, or otherwise touch the Spotify
  connection (1.1.7).
- Press and hold a teacher playlist button to pop up a QR code for that
  playlist, using an admin-pasted "Invite collaborators" link when set,
  otherwise the plain playlist share link (1.1.7).
- Settings can sync the Teacher Playlists table against whatever
  playlists are actually visible in the connected Spotify account,
  adding new ones and removing ones that vanish, on connect and via a
  "Sync Playlists Now" button (1.1.7).

- Clicking a teacher playlist was sending the plugin's own internal row
  identifier to Spotify's Web API instead of the actual Spotify playlist
  id, which could make a correctly-configured playlist fail to load with
  a 400 or 403 error (fixed in 1.1.6).

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

- Manual install: download `RehearsalPlayer-1.1.8.zip` and extract the `RehearsalPlayer` folder into your LMS plugins directory
- Repository install: add the hosted `repo.xml` URL to LMS plugin repositories (existing installs using this method will offer the update automatically)
```

Publish checklist:

1. Commit `repo.xml`, `release-assets/RehearsalPlayer-1.1.8.zip`, and `release-assets/RehearsalPlayer-1.1.8.sha1` to `jdmediatv/LyrionRehearsalPlayer` main.
2. Create release tag `v1.1.8`.
3. Upload `RehearsalPlayer-1.1.8.zip` and `RehearsalPlayer-1.1.8.sha1` as release assets (optional - the raw `release-assets/` copy in the repo is what `repo.xml` actually points to and is sufficient for installs to update).
4. Test the final asset URL from `repo.xml`.
5. Confirm existing installs pick up the update: Settings -> Plugins in LMS will offer it if "Update plugins automatically" is off, or install it automatically on next restart if that option is on.

   `https://raw.githubusercontent.com/jdmediatv/LyrionRehearsalPlayer/main/repo.xml`
