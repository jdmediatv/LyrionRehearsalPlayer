# Rehearsal Player

Native Lyrion Music Server plugin for rehearsal spaces, with playlist artwork selection, tile-based track launching, metadata filters, large transport controls, player volume control, and (as of 1.1.9) a Spotify-backed teacher playlist section.

## Features

- Direct web app at `/jazzartplayer`
- Loads from saved Lyrion playlists
- Playlist artwork buttons for quick selection
- Track tiles showing title, Tutor, and Class metadata
- Dynamic Tutor and Class filter buttons
- Large Play and Pause controls
- Relative seek presets from `-30` to `+30`
- Percentage jump presets from `0%` to `85%`
- Volume slider for the selected player
- Dark UI with purple-accent styling
- A dedicated section of admin-configured teacher playlists, backed by the
  official Spotify Web API, so any teacher can browse a playlist and add
  tracks to it from their own Spotify account (see below)

## Spotify integration

A new panel to the left of the existing playlist view lists whichever
teacher playlists an administrator has configured. Selecting one browses
its tracks the same way a local playlist does; any teacher who connects
their own Spotify account can search Spotify's catalog and add tracks to
a playlist they've been made a collaborator on - no shared account
credentials required. This uses Spotify's official Web API end-to-end.

Setting this up takes about 10 minutes and is entirely optional - the
existing local-library view is unchanged and works exactly as before with
or without it. See [`SPOTIFY_SETUP.md`](SPOTIFY_SETUP.md) for the full
walkthrough (creating a Spotify app, hosting the small OAuth "bridge"
page, and configuring the plugin), and
[`spotify-oauth-bridge.html`](spotify-oauth-bridge.html) for the bridge
page itself.

Administer which playlists appear, their icon, and which Spotify playlist
each one links to from **Settings &rarr; Plugins &rarr; Rehearsal Player**
in Lyrion.

Playing a Spotify track's audio (rather than just browsing/searching/
adding) additionally needs a Spotify playback plugin such as the
community **Spotty** plugin installed and configured with a Spotify
Premium account - see `SPOTIFY_SETUP.md` for details.

## Install

### Manual install

1. Download `RehearsalPlayer-1.1.9.zip`.
2. Extract it into your LMS plugins directory so the final path is:

   `Plugins/RehearsalPlayer/`

3. Restart Lyrion Music Server.
4. Open:

   `http://YOUR-LMS-HOST:9000/jazzartplayer`

### Install from a repository URL

1. Add this plugin repository XML URL in Lyrion's plugin repository settings:

   `https://raw.githubusercontent.com/jdmediatv/LyrionRehearsalPlayer/main/repo.xml`

2. Refresh the plugin list in Lyrion.
3. Install `Rehearsal Player`.
4. Restart Lyrion if required.

## Repository Contents

- `RehearsalPlayer-1.1.9.zip`: installable plugin package
- `RehearsalPlayer-1.1.9.sha1`: SHA1 checksum for LMS repository installs
- `repo.xml`: Lyrion repository definition
- `GITHUB_RELEASE.md`: release text and publish checklist
- `SPOTIFY_SETUP.md`: step-by-step Spotify integration setup guide
- `spotify-oauth-bridge.html`: the static HTTPS page teachers' browsers pass through when connecting Spotify (host this yourself; see `SPOTIFY_SETUP.md`)

## Release Publishing

1. Commit `repo.xml` to the repository root.
2. Confirm the raw repository URL is live:

   `https://raw.githubusercontent.com/jdmediatv/LyrionRehearsalPlayer/main/repo.xml`

3. Create GitHub release tag `v1.1.9`.
4. Upload:

   - `RehearsalPlayer-1.1.9.zip`
   - `RehearsalPlayer-1.1.9.sha1`

5. Test the release asset URL in `repo.xml`.
6. Test the raw `repo.xml` URL from a Lyrion install.

## Community Listing

After the repository XML is publicly hosted and working, you can ask for it to be included in the LMS community repository list:

- https://github.com/LMS-Community/lms-plugin-repository

Lyrion repository documentation:

- https://lyrion.org/reference/repository-dev/

## Notes

- Use a new version number and a new zip filename for every release.
- LMS can cache release archives, so versioned filenames matter.
- Keep the plugin id in `install.xml` stable across releases.
- Spotify Client ID/Secret and per-teacher session tokens are stored in
  this plugin's own Lyrion preferences file, not in `repo.xml` or the
  zip - nothing Spotify-specific needs to be packaged into a release.
