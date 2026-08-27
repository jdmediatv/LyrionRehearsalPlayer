# Spotify Setup

Rehearsal Player can show each teacher's Spotify playlist in a static
section, let any teacher browse it, and let any teacher add tracks to it
from their own Spotify account (their account just needs to be a member of
a *collaborative* Spotify playlist - no shared password required).

This uses Spotify's official Web API, which needs a one-time setup. It
takes about 10 minutes.

## Why an extra "bridge" page is needed

Spotify requires the redirect address it sends people back to after they
sign in (the "Redirect URI") to be HTTPS - the only exception is the exact
address `http://127.0.0.1:<port>/...`. Most Lyrion servers running in a
school or rehearsal space only have a local network address like
`http://192.168.1.50:9000`, which Spotify will not accept.

The plugin works around this with a tiny static page -
[`spotify-oauth-bridge.html`](spotify-oauth-bridge.html) in this
repository - that you host once, anywhere with HTTPS. Spotify redirects to
that page; the page immediately bounces the teacher's browser on to your
actual Lyrion server on your local network. The bridge page never talks to
Spotify's API and stores nothing - it only reads its own URL and
redirects. You can read the whole thing; it's about 60 lines.

## 1. Host the bridge page

Any static HTTPS host works. Two free options:

**GitHub Pages**
1. Create a new public GitHub repository (or use a folder in an existing one).
2. Add `spotify-oauth-bridge.html` to it.
3. In the repository's Settings &rarr; Pages, enable Pages for that branch/folder.
4. Your bridge URL will be something like:
   `https://your-username.github.io/your-repo/spotify-oauth-bridge.html`

**Cloudflare Pages / Netlify Drop**
1. Drag-and-drop a folder containing just `spotify-oauth-bridge.html` onto
   Cloudflare Pages or Netlify Drop.
2. You'll get a URL like `https://your-project.pages.dev/spotify-oauth-bridge.html`.

Either way, write down the exact final URL - you'll need it twice below,
and it must match **exactly** (including `https://` and the filename) in
both places.

## 2. Create a Spotify app

1. Go to <https://developer.spotify.com/dashboard> and log in with any
   Spotify account (a free account is fine for this step - it's the
   *app*, not a playlist owner, that needs registering here).
2. Click **Create app**.
3. Fill in a name/description (e.g. "Jazzart Rehearsal Player").
4. Under **Redirect URIs**, add the bridge URL from step 1 exactly as
   written, then click **Add**.
5. Under APIs used, tick **Web API**.
6. Save. Open the app's **Settings** and copy the **Client ID** and
   **Client Secret** (click "View client secret").

## 3. Configure the plugin

In Lyrion, go to **Settings &rarr; Plugins &rarr; Rehearsal Player** and
fill in:

- **Client ID** / **Client Secret** - from step 2.
- **Bridge Page URL** - the exact URL from step 1. This must be
  byte-for-byte identical to the Redirect URI registered in step 2.

## 4. Set up each teacher's playlist

For every playlist that should appear in the Teacher Playlists section:

1. In Spotify, open the playlist and turn on **Collaborative** in its
   settings (the playlist's three-dot menu). This is what allows other
   teachers - once they've connected their own account - to add tracks to
   it, without needing the owning account's password.
2. Copy the playlist's share link (Share &rarr; Copy link to playlist).
3. In the Rehearsal Player settings page, add a row under **Teacher
   Playlists**: paste the link (or just the playlist ID) in, give it a
   label (e.g. the teacher's name) and an icon - either an emoji or a
   direct image URL.
4. Save.

The playlist will now appear in the Teacher Playlists section for every teacher using
the app. Anyone who clicks **Connect Spotify** there and signs
in with their own Spotify account can then search for and add tracks to
any playlist shown there that they've been given collaborative access to.

## 5. Playback (optional but recommended)

Browsing, searching and adding tracks all work as soon as the steps above
are done. To actually *play* a Spotify playlist's tracks through a
Squeezebox player from inside Rehearsal Player, this Lyrion server also
needs a Spotify-capable playback plugin installed and configured with a
Spotify Premium account - the community **Spotty** plugin
(<https://github.com/michaelherger/lms-spotty>) is the standard choice.

Without it, the Teacher Playlists section and add-to-playlist features still work fully;
Rehearsal Player will simply show a message instead of trying to play a
Spotify track, and local library playlists are completely unaffected
either way.

## Notes

- Each teacher only needs to connect their own Spotify account once per
  browser/device (a small cookie remembers the connection for about 6
  months).
- No Spotify passwords are ever seen or stored by this plugin - only an
  access/refresh token issued by Spotify for the scopes it explicitly
  grants (`playlist-modify-public`, `playlist-modify-private`,
  `playlist-read-private`, `playlist-read-collaborative`).
- If you ever move the Lyrion server to a new IP/hostname, nothing here
  needs to change - the bridge page is told where to send people back to
  on every single sign-in, not configured with a fixed address.
