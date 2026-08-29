# Rehearsal Player v1.1.14

Tag: `v1.1.14`

Release title:

`Rehearsal Player v1.1.14`

Assets to upload:

- `RehearsalPlayer-1.1.14.zip`
- `RehearsalPlayer-1.1.14.sha1`

Suggested release body:

```md
Rehearsal Player is a native Lyrion Music Server plugin built for rehearsal spaces.

New in v1.1.14:

- Fixed "redirect_uri: Unsafe" errors when connecting Spotify from the
  Settings page. The saved Bridge Page URL had an invisible stray
  character in it (most likely a non-breaking space picked up from a
  copy-paste), which made it not match the Redirect URI registered
  with Spotify byte-for-byte. The URL is now cleaned automatically
  wherever it's used, and cleaned more thoroughly on save going
  forward - no need to retype it in Settings.

Also included from 1.1.13:

- Fixed the Jazzart logo showing as a broken image icon on some setups.
  It's now embedded directly in the page as inline image data instead
  of loaded as a separate file, so it always displays regardless of
  how a given LMS server serves static plugin assets.

Also included from 1.1.12:

- Added the Jazzart Studio Player logo to the top of the kiosk screen.

Also included from 1.1.11:

- Fixed a bug introduced in 1.1.10: shrinking track tiles for a playlist
  with only a few tracks also centered them in their grid cell, leaving
  a dead zone around each button where the old, full-size button used to
  be - tapping there (out of habit, or because it still looked like part
  of the tile's row) did nothing. Tiles are now only ever made shorter,
  never shrunk-and-centered, so the whole visible tile stays clickable.

Also included from 1.1.10:

- Track tiles are smaller by default - a playlist with only a few tracks
  no longer stretches each one into a huge button that fills the whole
  panel.
- Track tiles for a Spotify-sourced playlist show a small album art
  thumbnail. Local Lyrion server playlists are unaffected, since they
  have no artwork to show.

Also included from prior releases:

- Added a built-in on-screen keyboard to the Spotify search popup, since
  the kiosk is a touchscreen with no physical keyboard attached. The
  search field now suppresses the device's own software keyboard so this
  one is the only keyboard that appears - QWERTY layout with shift,
  backspace, a 123/ABC toggle for numbers and punctuation, and a Done key
  (1.1.9).
- The Spotify search-and-add box is a popup styled like a proper Spotify
  search UI: dark theme, green accents, rounded search bar, and album
  art thumbnails on each result, opened via a "+ Add Tracks" button next
  to Teacher Playlists (1.1.8).
- Fixed a bug where adding a track and refreshing the open playlist could
  send Spotify the plugin's internal row id instead of the real playlist
  id (1.1.8).

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

- Manual install: download `RehearsalPlayer-1.1.14.zip` and extract the `RehearsalPlayer` folder into your LMS plugins directory
- Repository install: add the hosted `repo.xml` URL to LMS plugin repositories (existing installs using this method will offer the update automatically)
```

Publish checklist:

1. Commit `repo.xml`, `release-assets/RehearsalPlayer-1.1.14.zip`, and `release-assets/RehearsalPlayer-1.1.14.sha1` to `jdmediatv/LyrionRehearsalPlayer` main.
2. Create release tag `v1.1.14`.
3. Upload `RehearsalPlayer-1.1.14.zip` and `RehearsalPlayer-1.1.14.sha1` as release assets (optional - the raw `release-assets/` copy in the repo is what `repo.xml` actually points to and is sufficient for installs to update).
4. Test the final asset URL from `repo.xml`.
5. Confirm existing installs pick up the update: Settings -> Plugins in LMS will offer it if "Update plugins automatically" is off, or install it automatically on next restart if that option is on.

   `https://raw.githubusercontent.com/jdmediatv/LyrionRehearsalPlayer/main/repo.xml`
