# Rehearsal Player v1.1.5

Tag: `v1.1.5`

Release title:

`Rehearsal Player v1.1.5`

Assets to upload:

- `RehearsalPlayer-1.1.5.zip`
- `RehearsalPlayer-1.1.5.sha1`

Suggested release body:

```md
Rehearsal Player is a native Lyrion Music Server plugin built for rehearsal spaces.

New in v1.1.5 (encoding fix):

- A couple of UI symbols in the settings page and the teacher playlist
  section (the remove-row "X" and the default music-note icon) were
  embedded in the plugin's HTML as raw UTF-8 characters. On a Lyrion
  install that doesn't declare a UTF-8 charset for plugin pages, browsers
  could misinterpret those bytes and render them as garbled mojibake
  instead of the intended symbol. They're now written as JavaScript
  unicode escapes (\uXXXX), which render correctly regardless of how the
  page's byte encoding gets interpreted.

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

- Manual install: download `RehearsalPlayer-1.1.5.zip` and extract the `RehearsalPlayer` folder into your LMS plugins directory
- Repository install: add the hosted `repo.xml` URL to LMS plugin repositories (existing installs using this method will offer the update automatically)
```

Publish checklist:

1. Commit `repo.xml`, `release-assets/RehearsalPlayer-1.1.5.zip`, and `release-assets/RehearsalPlayer-1.1.5.sha1` to `jdmediatv/LyrionRehearsalPlayer` main.
2. Create release tag `v1.1.5`.
3. Upload `RehearsalPlayer-1.1.5.zip` and `RehearsalPlayer-1.1.5.sha1` as release assets (optional - the raw `release-assets/` copy in the repo is what `repo.xml` actually points to and is sufficient for installs to update).
4. Test the final asset URL from `repo.xml`.
5. Confirm existing installs pick up the update: Settings -> Plugins in LMS will offer it if "Update plugins automatically" is off, or install it automatically on next restart if that option is on.

   `https://raw.githubusercontent.com/jdmediatv/LyrionRehearsalPlayer/main/repo.xml`
