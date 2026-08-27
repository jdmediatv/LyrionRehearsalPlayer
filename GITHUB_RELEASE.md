# Rehearsal Player v1.1.7

Tag: `v1.1.7`

Release title:

`Rehearsal Player v1.1.7`

Assets to upload:

- `RehearsalPlayer-1.1.7.zip`
- `RehearsalPlayer-1.1.7.sha1`

Suggested release body:

```md
Rehearsal Player is a native Lyrion Music Server plugin built for rehearsal spaces.

New in v1.1.7:

- Spotify Connect/Disconnect has moved off the main kiosk screen and into
  the plugin's Settings page, and sign-in is now admin-only: one shared
  connection is managed by an administrator, and students/teachers at the
  kiosk can no longer sign in, sign out, or otherwise touch the Spotify
  connection. Browsing, searching, and adding tracks at the kiosk still
  work as before, using that shared connection.
- Press and hold a teacher playlist button to pop up a QR code for that
  playlist. If you paste a "Share > Invite collaborators" link into the
  new Invite Link column in Settings, the QR code uses that; otherwise it
  falls back to the playlist's normal Spotify share link (the official
  Spotify Web API has no endpoint that hands back the special invite
  link, so getting the exact one into the QR code needs that one manual
  copy-paste per playlist).
- Settings can now sync the Teacher Playlists table against whatever
  playlists are actually visible in the connected Spotify account -
  newly visible playlists are added automatically (unchecked, so you can
  review before they appear on the kiosk) and playlists no longer visible
  are removed. This runs automatically right after you connect Spotify,
  and on demand via the new "Sync Playlists Now" button.

Also included from prior releases:

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

- Manual install: download `RehearsalPlayer-1.1.7.zip` and extract the `RehearsalPlayer` folder into your LMS plugins directory
- Repository install: add the hosted `repo.xml` URL to LMS plugin repositories (existing installs using this method will offer the update automatically)
```

Publish checklist:

1. Commit `repo.xml`, `release-assets/RehearsalPlayer-1.1.7.zip`, and `release-assets/RehearsalPlayer-1.1.7.sha1` to `jdmediatv/LyrionRehearsalPlayer` main.
2. Create release tag `v1.1.7`.
3. Upload `RehearsalPlayer-1.1.7.zip` and `RehearsalPlayer-1.1.7.sha1` as release assets (optional - the raw `release-assets/` copy in the repo is what `repo.xml` actually points to and is sufficient for installs to update).
4. Test the final asset URL from `repo.xml`.
5. Confirm existing installs pick up the update: Settings -> Plugins in LMS will offer it if "Update plugins automatically" is off, or install it automatically on next restart if that option is on.

   `https://raw.githubusercontent.com/jdmediatv/LyrionRehearsalPlayer/main/repo.xml`
