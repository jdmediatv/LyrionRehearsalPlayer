# Rehearsal Player

Native Lyrion Music Server plugin for rehearsal spaces, with playlist artwork selection, tile-based track launching, metadata filters, large transport controls, and player volume control.

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

## Install

### Manual install

1. Download `RehearsalPlayer-1.0.0.zip`.
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

- `RehearsalPlayer-1.0.0.zip`: installable plugin package
- `RehearsalPlayer-1.0.0.sha1`: SHA1 checksum for LMS repository installs
- `repo.xml`: Lyrion repository definition
- `GITHUB_RELEASE.md`: release text and publish checklist

## Release Publishing

1. Commit `repo.xml` to the repository root.
2. Confirm the raw repository URL is live:

   `https://raw.githubusercontent.com/jdmediatv/LyrionRehearsalPlayer/main/repo.xml`

3. Create GitHub release tag `v1.0.0`.
4. Upload:

   - `RehearsalPlayer-1.0.0.zip`
   - `RehearsalPlayer-1.0.0.sha1`

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
