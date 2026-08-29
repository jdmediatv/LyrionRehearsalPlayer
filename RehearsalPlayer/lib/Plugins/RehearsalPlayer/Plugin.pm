package Plugins::RehearsalPlayer::Plugin;

use strict;
use warnings;

use base qw(Slim::Plugin::Base);

use CGI::Cookie;
use File::Basename qw(basename dirname fileparse);
use File::Next;
use File::Spec::Functions qw(catfile);
use JSON::XS::VersionOneAndTwo;
use URI::Escape qw(uri_escape_utf8 uri_unescape);
use URI::QueryParam;

use Slim::Schema;
use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::PluginManager;
use Slim::Utils::Prefs;
use Slim::Utils::Strings qw(string);
use Slim::Web::HTTP;
use Slim::Web::Pages;

use Plugins::RehearsalPlayer::Spotify;

use constant MENU_PATH => 'plugins/RehearsalPlayer/index.html';
use constant SLUG_PATH => 'jazzartplayer';
use constant TABLET_SLUG_PATH => 'jazzartplayertablet';
use constant API_PATH  => 'plugins/RehearsalPlayer/api';
use constant SETTINGS_PATH => 'plugins/RehearsalPlayer/settings.html';

my $serverprefs = preferences('server');
my $pluginprefs = preferences('plugin.rehearsalplayer');

# Spotify sign-in is admin-only: one shared connection (managed from the
# plugin's Settings page) is used for every kiosk screen, rather than a
# separate per-browser/per-teacher OAuth session. "spotifySessions" (the old
# per-browser map) is no longer written, but is left out of init() deliberately
# so any leftover data from before this change just stops being read, not
# migrated.
$pluginprefs->init({
	teacherPlaylists     => [],
	spotifyAdminSession  => undef,
	spotifyPendingStates => {},
	spotifyClientId      => '',
	spotifyClientSecret  => '',
	spotifyBridgeUrl     => '',
});

my $log = Slim::Utils::Log->addLogCategory({
	category     => 'plugin.rehearsalplayer',
	defaultLevel => 'ERROR',
	description  => 'PLUGIN_REHEARSAL_PLAYER',
});

sub initPlugin {
	my $class = shift;

	if (main::WEBUI) {
		require Plugins::RehearsalPlayer::Settings;
		Plugins::RehearsalPlayer::Settings->new();
	}

	$class->SUPER::initPlugin(@_);
}

sub getDisplayName {
	return 'PLUGIN_REHEARSAL_PLAYER';
}

sub webPages {
	my $class = shift;

	Slim::Web::Pages->addPageLinks('plugins', { $class->getDisplayName() => SLUG_PATH });
	Slim::Web::Pages->addPageFunction(MENU_PATH, \&handleWebIndex);
	Slim::Web::Pages->addPageFunction(qr{^jazzartplayer/?$}, \&handleWebIndex);
	Slim::Web::Pages->addPageFunction(qr{^jazzartplayertablet/?$}, \&handleTabletIndex);
	Slim::Web::Pages->addRawFunction(API_PATH, \&handleApi);
}

sub handleWebIndex {
	my ($client, $params) = @_;

	return _renderIndex($client, $params, 'desktop', SLUG_PATH);
}

sub handleTabletIndex {
	my ($client, $params) = @_;

	return _renderIndex($client, $params, 'tablet', TABLET_SLUG_PATH);
}

sub _renderIndex {
	my ($client, $params, $layout, $slugPath) = @_;

	$params->{rehearsalPlayerLayout}    = $layout || 'desktop';
	$params->{rehearsalPlayerApiUrl}  = API_PATH;
	$params->{rehearsalPlayerSlugUrl} = $slugPath || SLUG_PATH;

	return Slim::Web::HTTP::filltemplatefile(MENU_PATH, $params);
}

# ---------------------------------------------------------------------------
# API dispatch
# ---------------------------------------------------------------------------
#
# Most actions are handled synchronously (they only touch the local Slim
# database / prefs). Everything under the "spotify_*" actions talks to the
# Spotify Web API over HTTPS, which is asynchronous - those handlers take
# ownership of $httpClient/$response and call Slim::Web::HTTP::addHTTPResponse
# themselves once the outbound request(s) complete, instead of returning a
# value for this function to send.

sub handleApi {
	my ($httpClient, $response, $func) = @_;
	my $request = $response->request;
	my $action  = $request->uri->query_param('action') || 'state';

	if ($action eq 'spotify_login') {
		return _handleSpotifyLogin($httpClient, $response, $request);
	}
	if ($action eq 'spotify_callback') {
		return _handleSpotifyCallback($httpClient, $response, $request);
	}
	if ($action eq 'spotify_logout') {
		return _handleSpotifyLogout($httpClient, $response, $request);
	}
	if ($action eq 'spotify_playlist_tracks') {
		return _handleSpotifyPlaylistTracks($httpClient, $response, $request);
	}
	if ($action eq 'spotify_search') {
		return _handleSpotifySearch($httpClient, $response, $request);
	}
	if ($action eq 'spotify_add_track') {
		return _handleSpotifyAddTrack($httpClient, $response, $request);
	}
	if ($action eq 'spotify_sync_playlists') {
		return _handleSpotifySyncPlaylists($httpClient, $response, $request);
	}

	my $client = _getClientFromRequest($request);
	my $result;
	my $status = 200;

	eval {
		if ($action eq 'state') {
			$result = _buildState($client, scalar $request->uri->query_param('playlist'));
			$result->{spotify} = _buildSpotifyStateBlock($request);
		}
		else {
			$status = 400;
			$result = { error => string('PLUGIN_REHEARSAL_PLAYER_INVALID_REQUEST') };
		}
	};

	if ($@) {
		$log->error("API failure: $@");
		$status = 500;
		$result = { error => "$@" };
	}

	_sendJson($httpClient, $response, $result, $status);
}

# ---------------------------------------------------------------------------
# Spotify: OAuth handlers
# ---------------------------------------------------------------------------

sub _handleSpotifyLogin {
	my ($httpClient, $response, $request) = @_;

	if (!Plugins::RehearsalPlayer::Spotify::isConfigured()) {
		return _sendJson($httpClient, $response, { error => string('PLUGIN_REHEARSAL_PLAYER_SPOTIFY_NOT_CONFIGURED') }, 400);
	}

	# Sign-in is admin-only: only reachable from the plugin's Settings page,
	# not from the public kiosk screen. This is a soft check (a Referer
	# header can be spoofed by anyone crafting raw HTTP requests) but it's
	# enough to stop a student from stumbling onto this URL and hijacking
	# the shared Spotify connection from the kiosk browser.
	if (!_requestIsFromSettingsPage($request)) {
		return _sendJson($httpClient, $response, { error => string('PLUGIN_REHEARSAL_PLAYER_SPOTIFY_ADMIN_ONLY') }, 403);
	}

	my $callbackBase = _apiBaseUrl($request);
	my $url = Plugins::RehearsalPlayer::Spotify::authorizeUrl($callbackBase);

	$response->code(302);
	$response->header('Location' => $url);
	$response->header('Content-Length' => 0);
	$response->header('Cache-Control' => 'no-store');

	my $empty = '';
	Slim::Web::HTTP::addHTTPResponse($httpClient, $response, \$empty);
}

sub _handleSpotifyCallback {
	my ($httpClient, $response, $request) = @_;

	my $code  = $request->uri->query_param('code');
	my $state = $request->uri->query_param('state');
	my $error = $request->uri->query_param('error');

	if ($error) {
		return _sendHtml($httpClient, $response, _spotifyResultPage(0, string('PLUGIN_REHEARSAL_PLAYER_SPOTIFY_DENIED')));
	}

	my $decodedState = Plugins::RehearsalPlayer::Spotify::consumeState($state);
	if (!$decodedState || !$code) {
		return _sendHtml($httpClient, $response, _spotifyResultPage(0, string('PLUGIN_REHEARSAL_PLAYER_SPOTIFY_BAD_STATE')));
	}

	Plugins::RehearsalPlayer::Spotify::exchangeCode(
		code  => $code,
		cbOk  => sub {
			my ($tokenData) = @_;

			Plugins::RehearsalPlayer::Spotify::getMe($tokenData->{access_token}, sub {
				my ($profile) = @_;

				my $adminSession = {
					access_token    => $tokenData->{access_token},
					refresh_token   => $tokenData->{refresh_token},
					expires_at      => time() + ($tokenData->{expires_in} || 3600),
					display_name    => $profile->{display_name} || $profile->{id} || 'Spotify user',
					spotify_user_id => $profile->{id},
				};

				$pluginprefs->set('spotifyAdminSession', $adminSession);

				# Auto-sync the teacher playlist list against whatever is now
				# visible in the newly-connected account, so the admin doesn't
				# have to also remember to press "Sync Playlists Now" the
				# first time they connect.
				_syncTeacherPlaylistsFromSpotify(sub {}, sub {});

				_sendHtml($httpClient, $response, _spotifyResultPage(1, $adminSession->{display_name}));
			}, sub {
				my ($errMsg) = @_;
				_sendHtml($httpClient, $response, _spotifyResultPage(0, $errMsg));
			});
		},
		cbErr => sub {
			my ($errMsg) = @_;
			_sendHtml($httpClient, $response, _spotifyResultPage(0, $errMsg));
		},
	);
}

sub _handleSpotifyLogout {
	my ($httpClient, $response, $request) = @_;

	if (!_requestIsFromSettingsPage($request)) {
		return _sendJson($httpClient, $response, { error => string('PLUGIN_REHEARSAL_PLAYER_SPOTIFY_ADMIN_ONLY') }, 403);
	}

	$pluginprefs->set('spotifyAdminSession', undef);

	_sendJson($httpClient, $response, { ok => 1 });
}

# ---------------------------------------------------------------------------
# Spotify: data handlers
# ---------------------------------------------------------------------------

sub _handleSpotifyPlaylistTracks {
	my ($httpClient, $response, $request) = @_;

	my $playlistId = $request->uri->query_param('playlistId');

	if (!$playlistId) {
		return _sendJson($httpClient, $response, { error => string('PLUGIN_REHEARSAL_PLAYER_INVALID_REQUEST') }, 400);
	}

	_withBestToken($request, sub {
		my ($token) = @_;

		Plugins::RehearsalPlayer::Spotify::getPlaylistTracks(
			playlistId  => $playlistId,
			accessToken => $token,
			cbOk        => sub {
				my ($data) = @_;
				_sendJson($httpClient, $response, {
					tracks   => $data->{tracks},
					playable => _spotifyPlaybackAvailable(),
				});
			},
			cbErr       => sub {
				my ($errMsg) = @_;
				_sendJson($httpClient, $response, { error => $errMsg }, 502);
			},
		);
	});
}

sub _handleSpotifySearch {
	my ($httpClient, $response, $request) = @_;

	my $query = $request->uri->query_param('q');

	_withBestToken($request, sub {
		my ($token) = @_;

		Plugins::RehearsalPlayer::Spotify::searchTracks(
			query       => $query,
			accessToken => $token,
			cbOk        => sub {
				my ($data) = @_;
				_sendJson($httpClient, $response, { tracks => $data->{tracks} });
			},
			cbErr       => sub {
				my ($errMsg) = @_;
				_sendJson($httpClient, $response, { error => $errMsg }, 502);
			},
		);
	});
}

sub _handleSpotifyAddTrack {
	my ($httpClient, $response, $request) = @_;

	my $body = eval { from_json($request->content || '{}') } || {};
	my $playlistId = $body->{playlistId};
	my $trackUri   = $body->{trackUri};

	if (!$playlistId || !$trackUri) {
		return _sendJson($httpClient, $response, { error => string('PLUGIN_REHEARSAL_PLAYER_INVALID_REQUEST') }, 400);
	}

	my $session = _adminSession();

	if (!$session) {
		return _sendJson($httpClient, $response, { error => string('PLUGIN_REHEARSAL_PLAYER_SPOTIFY_NOT_CONNECTED_ADMIN') }, 401);
	}

	Plugins::RehearsalPlayer::Spotify::ensureUserToken($session, sub {
		my ($token, $updatedSession) = @_;

		$pluginprefs->set('spotifyAdminSession', $updatedSession);

		Plugins::RehearsalPlayer::Spotify::addTrackToPlaylist(
			playlistId  => $playlistId,
			trackUri    => $trackUri,
			accessToken => $token,
			cbOk        => sub {
				_sendJson($httpClient, $response, { ok => 1 });
			},
			cbErr       => sub {
				my ($errMsg) = @_;
				_sendJson($httpClient, $response, { error => $errMsg }, 502);
			},
		);
	}, sub {
		my ($errMsg) = @_;
		_sendJson($httpClient, $response, { error => $errMsg }, 401);
	});
}

sub _handleSpotifySyncPlaylists {
	my ($httpClient, $response, $request) = @_;

	if (!_requestIsFromSettingsPage($request)) {
		return _sendJson($httpClient, $response, { error => string('PLUGIN_REHEARSAL_PLAYER_SPOTIFY_ADMIN_ONLY') }, 403);
	}

	if (!_adminSession()) {
		return _sendJson($httpClient, $response, { error => string('PLUGIN_REHEARSAL_PLAYER_SPOTIFY_NOT_CONNECTED_ADMIN') }, 401);
	}

	_syncTeacherPlaylistsFromSpotify(sub {
		my ($summary) = @_;
		_sendJson($httpClient, $response, {
			ok        => 1,
			added     => $summary->{added},
			removed   => $summary->{removed},
			playlists => $pluginprefs->get('teacherPlaylists') || [],
		});
	}, sub {
		my ($errMsg) = @_;
		_sendJson($httpClient, $response, { error => $errMsg }, 502);
	});
}

# The single admin-connected Spotify session, if there is one and it hasn't
# been explicitly cleared. There is only ever one of these now - see the
# comment above spotifyAdminSession in initPlugin().
sub _adminSession {
	return $pluginprefs->get('spotifyAdminSession');
}

# Resolves the best access token to use for a *read* call: the admin's own
# token if Spotify is connected (refreshing it first if it's stale),
# otherwise the plugin's app-level (Client Credentials) token, which can read
# public playlists and the search catalog but cannot see private /
# collaborative playlists it hasn't been shared with.
sub _withBestToken {
	my ($request, $cb) = @_;

	my $session = _adminSession();

	if ($session && $session->{refresh_token}) {
		Plugins::RehearsalPlayer::Spotify::ensureUserToken($session, sub {
			my ($token, $updatedSession) = @_;
			$pluginprefs->set('spotifyAdminSession', $updatedSession);
			$cb->($token);
		}, sub {
			Plugins::RehearsalPlayer::Spotify::appToken($cb, sub { $cb->(undef) });
		});
		return;
	}

	Plugins::RehearsalPlayer::Spotify::appToken($cb, sub { $cb->(undef) });
}

sub _buildSpotifyStateBlock {
	my ($request) = @_;

	my $session = _adminSession();

	return {
		configured   => Plugins::RehearsalPlayer::Spotify::isConfigured(),
		playable     => _spotifyPlaybackAvailable(),
		playlists    => _visibleTeacherPlaylists(),
		connected    => $session ? 1 : 0,
		display_name => $session ? ($session->{display_name} || '') : '',
	};
}

sub _visibleTeacherPlaylists {
	my $playlists = $pluginprefs->get('teacherPlaylists') || [];
	my @visible = grep { !defined $_->{enabled} || $_->{enabled} } @$playlists;

	@visible = sort {
		($a->{sortOrder} || 0) <=> ($b->{sortOrder} || 0) || lc($a->{label} || '') cmp lc($b->{label} || '')
	} @visible;

	return [ map {
		{
			id         => $_->{id},
			label      => $_->{label},
			icon       => $_->{icon},
			playlistId => $_->{playlistId},
			inviteUrl  => $_->{inviteUrl},
		}
	} @visible ];
}

# ---------------------------------------------------------------------------
# Spotify: keep the Teacher Playlists list in sync with what's actually
# visible in the admin-connected account - add anything new (disabled by
# default so the admin can review it before it shows up on the kiosk), and
# drop any row whose playlist the account can no longer see (removed,
# unshared, or the account was switched).
# ---------------------------------------------------------------------------

sub _syncTeacherPlaylistsFromSpotify {
	my ($cbOk, $cbErr) = @_;
	$cbErr ||= sub {};

	my $session = _adminSession();
	if (!$session) {
		return $cbErr->(string('PLUGIN_REHEARSAL_PLAYER_SPOTIFY_NOT_CONNECTED_ADMIN'));
	}

	Plugins::RehearsalPlayer::Spotify::ensureUserToken($session, sub {
		my ($token, $updatedSession) = @_;
		$pluginprefs->set('spotifyAdminSession', $updatedSession);

		Plugins::RehearsalPlayer::Spotify::getUserPlaylists(
			accessToken => $token,
			cbOk        => sub {
				my ($data) = @_;
				my $remote = $data->{playlists} || [];
				my %remoteById = map { $_->{id} => $_ } @$remote;

				my $existing = $pluginprefs->get('teacherPlaylists') || [];
				my %seenIds  = map { ($_->{playlistId} || '') => 1 } @$existing;

				# Keep every existing row whose playlist is still visible in
				# the account; anything else is gone from Spotify's side.
				my @kept    = grep { $remoteById{ $_->{playlistId} || '' } } @$existing;
				my $removed = scalar(@$existing) - scalar(@kept);

				my @added;
				for my $remotePlaylist (@$remote) {
					next if $seenIds{ $remotePlaylist->{id} };

					push @added, {
						id         => _newPlaylistRowId(),
						label      => $remotePlaylist->{name} || $remotePlaylist->{id},
						icon       => '',
						playlistId => $remotePlaylist->{id},
						inviteUrl  => '',
						enabled    => 0,
					};
				}

				my @merged = (@kept, @added);
				my $order  = 0;
				$_->{sortOrder} = $order++ for @merged;

				$pluginprefs->set('teacherPlaylists', \@merged);

				$cbOk->({ added => scalar(@added), removed => $removed });
			},
			cbErr => $cbErr,
		);
	}, $cbErr);
}

# True when a Spotify-capable audio source plugin is installed and enabled,
# so a Squeezebox player can actually stream a spotify:track:... URI the same
# way it streams a local file:// URL. Without one, browsing/search/add-to-
# playlist still work (those only need the Spotify Web API), but in-app
# playback cannot. Checks each known community plugin that registers a
# "spotify:" protocol handler - the original "Spotty" plugin, and "SpotOn",
# a newer alternative that (unlike recent Spotty releases) still supports
# Spotify Connect.
my @SPOTIFY_PLAYBACK_PLUGINS = (
	'Plugins::Spotty::Plugin',
	'Plugins::SpotOn::Plugin',
);

sub _spotifyPlaybackAvailable {
	for my $plugin (@SPOTIFY_PLAYBACK_PLUGINS) {
		my $enabled = eval {
			Slim::Utils::PluginManager->isEnabled($plugin);
		};
		return 1 if $enabled;
	}
	return 0;
}

# ---------------------------------------------------------------------------
# Small HTTP helpers shared by the sync + async handlers
# ---------------------------------------------------------------------------

sub _sendJson {
	my ($httpClient, $response, $data, $status) = @_;

	my $content = to_json($data);

	$response->header('Content-Length' => length($content));
	$response->header('Connection'     => 'close');
	$response->header('Cache-Control'  => 'no-store');
	$response->content_type('application/json');
	$response->code($status || 200);

	Slim::Web::HTTP::addHTTPResponse($httpClient, $response, \$content);
}

sub _sendHtml {
	my ($httpClient, $response, $html) = @_;

	$response->header('Content-Length' => length($html));
	$response->header('Connection'     => 'close');
	$response->content_type('text/html; charset=utf-8');
	$response->code(200);

	Slim::Web::HTTP::addHTTPResponse($httpClient, $response, \$html);
}

sub _spotifyResultPage {
	my ($ok, $message) = @_;

	my $safeMessage = defined $message ? $message : '';
	$safeMessage =~ s/&/&amp;/g;
	$safeMessage =~ s/</&lt;/g;
	$safeMessage =~ s/>/&gt;/g;

	my $heading = $ok
		? string('PLUGIN_REHEARSAL_PLAYER_SPOTIFY_CONNECTED')
		: string('PLUGIN_REHEARSAL_PLAYER_SPOTIFY_FAILED');
	my $okFlag = $ok ? 1 : 0;

	return <<"HTML";
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>$heading</title>
<style>
	body { background:#0d0a15; color:#f3eeff; font-family:-apple-system,'Segoe UI',sans-serif; display:flex; align-items:center; justify-content:center; height:100vh; margin:0; }
	.box { text-align:center; padding:24px; max-width:320px; }
	h1 { font-size:18px; margin-bottom:8px; }
	p { color:#b7a6d7; font-size:13px; }
</style>
</head>
<body>
	<div class="box">
		<h1>$heading</h1>
		<p>$safeMessage</p>
		<p>You can close this window.</p>
	</div>
	<script>
		try { if (window.opener) { window.opener.postMessage({ rehearsalPlayerSpotify: true, ok: $okFlag }, '*'); } } catch (e) {}
		setTimeout(function () { window.close(); }, 1500);
	</script>
</body>
</html>
HTML
}

# Mirrors Settings::_newId() - kept as a separate local copy rather than
# calling into Settings.pm, since that module is only require()'d when
# main::WEBUI is true (see initPlugin above) and this needs to work
# regardless.
sub _newPlaylistRowId {
	my @chars = ('a' .. 'z', 0 .. 9);
	my $id = '';
	$id .= $chars[int(rand(scalar @chars))] for 1 .. 12;
	return $id;
}

# True when $request's Referer header points at this plugin's Settings page.
# Used as a soft guard to keep Spotify sign-in/out and the playlist-sync
# button reachable only from Settings, not from the public kiosk screen -
# see the comment in _handleSpotifyLogin for the caveats of this approach.
sub _requestIsFromSettingsPage {
	my ($request) = @_;

	my $referer = $request->header('Referer') || $request->header('Referrer') || '';
	return $referer =~ m{\Q@{[ SETTINGS_PATH ]}\E}i ? 1 : 0;
}

sub _apiBaseUrl {
	my ($request) = @_;

	my $host = $request->header('Host') || 'localhost';
	my $webroot = $serverprefs->get('webroot') || '/';
	$webroot = '/' . $webroot unless $webroot =~ m{^/};
	$webroot .= '/' unless $webroot =~ m{/$};

	return 'http://' . $host . $webroot . API_PATH;
}

# ---------------------------------------------------------------------------
# Existing local-library playlist logic (unchanged)
# ---------------------------------------------------------------------------

sub _buildState {
	my ($client, $selectedPlaylistId) = @_;

	my $playlistRoot = _playlistRoot();
	my @playlists    = _discoverPlaylists($playlistRoot);
	my $selected     = _pickSelectedPlaylist(\@playlists, $selectedPlaylistId);
	my @tracks       = $selected ? _loadPlaylistTracks($selected->{path}) : ();
	my %filters      = _buildFilters(\@tracks);
	my @players      = _listPlayers();

	my $selectedPlayer = $client ? $client->id : (@players ? $players[0]->{id} : '');

	return {
		message               => '',
		error                 => '',
		playlist_root         => $playlistRoot || '',
		playlist_root_valid   => $playlistRoot && -d $playlistRoot ? 1 : 0,
		playlist_count        => scalar @playlists,
		playlists             => \@playlists,
		selected_playlist_id  => $selected ? $selected->{id} : '',
		selected_playlist     => $selected ? $selected->{title} : '',
		tracks                => \@tracks,
		track_count           => scalar @tracks,
		filters               => \%filters,
		players               => \@players,
		selected_player_id    => $selectedPlayer,
	};
}

sub _playlistRoot {
	return $serverprefs->get('playlistdir') || '';
}

sub _discoverPlaylists {
	my ($root) = @_;
	return unless $root && -d $root;

	my @playlists;
	my $iter = File::Next::files({
		file_filter => sub {
			return $_ !~ /^\./ && /\.(?:m3u|m3u8|pls)$/i;
		},
		descend_filter => sub {
			return $_ !~ /^\./;
		},
	}, $root);

	while (defined(my $file = $iter->())) {
		my $info = _summarizePlaylist($file);
		push @playlists, $info if $info;
	}

	@playlists = sort {
		lc($a->{title}) cmp lc($b->{title})
	} @playlists;

	return @playlists;
}

sub _summarizePlaylist {
	my ($file) = @_;

	my @tracks = _loadPlaylistTracks($file);
	return unless @tracks;

	my ($name) = fileparse($file, qr/\.[^.]+$/);

	return {
		id          => $file,
		path        => $file,
		title       => $name,
		track_count => scalar @tracks,
		artwork_url => $tracks[0] && $tracks[0]->{artwork_url}
			? $tracks[0]->{artwork_url}
			: '/music/0/cover_96x96_p.png',
	};
}

sub _pickSelectedPlaylist {
	my ($playlists, $selectedPlaylistId) = @_;
	return unless $playlists && @$playlists;

	if ($selectedPlaylistId) {
		for my $playlist (@$playlists) {
			return $playlist if $playlist->{id} eq $selectedPlaylistId;
		}
	}

	return $playlists->[0];
}

sub _loadPlaylistTracks {
	my ($playlistFile) = @_;

	my @entries = _parsePlaylistFile($playlistFile);
	my @tracks;
	my (%seenIds, %seenMeta);

	for my $entry (@entries) {
		my $track = _resolvePlaylistEntry($playlistFile, $entry);
		next unless $track;

		my ($idKey, $metaKey) = _trackDedupKeys($track);
		next if ($idKey && $seenIds{$idKey}) || ($metaKey && $seenMeta{$metaKey});

		$seenIds{$idKey}   = 1 if $idKey;
		$seenMeta{$metaKey} = 1 if $metaKey;

		$track->{position} = scalar(@tracks) + 1;
		push @tracks, $track;
	}

	return @tracks;
}

sub _trackDedupKeys {
	my ($track) = @_;
	return ('', '') unless $track && ref $track eq 'HASH';

	my $idKey = defined $track->{id} && $track->{id} ne ''
		? 'id:' . $track->{id}
		: '';

	my @parts = map { _normalizeDedupValue($_) } (
		$track->{title},
		$track->{composer},
		$track->{comment},
	);

	my $metaKey = join('|', grep { defined $_ && $_ ne '' } @parts);

	if (!$metaKey && $track->{url}) {
		my $path = eval { Slim::Utils::Misc::pathFromFileURL($track->{url}) };
		$metaKey = _normalizeDedupValue(_basenameWithoutExtension(basename($path || '')));
	}

	return ($idKey, $metaKey ? 'meta:' . $metaKey : '');
}

sub _normalizeDedupValue {
	my ($value) = @_;
	return '' unless defined $value && $value ne '';

	$value = uri_unescape($value);
	$value = lc $value;
	$value =~ s/\.[^.]+$//;
	$value =~ s/[^a-z0-9]+//g;

	return $value;
}

sub _parsePlaylistFile {
	my ($file) = @_;
	return unless $file && -f $file;

	open my $fh, '<:raw', $file or return;

	my @entries;
	my (%pls, $pendingTitle, $pendingUrl);

	while (my $line = <$fh>) {
		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/^\x{FEFF}//;
		next if $line eq '';

		if ($file =~ /\.(?:pls)$/i) {
			if ($line =~ /^File(\d+)=(.+)$/i) {
				$pls{$1}->{source_path} = $2;
			}
			elsif ($line =~ /^Title(\d+)=(.+)$/i) {
				$pls{$1}->{title} = $2;
			}

			next;
		}

		if ($line =~ /^#EXTURL:(.+)$/i) {
			$pendingUrl = $1;
			next;
		}

		if ($line =~ /^#EXTINF:[^,]*,(.*)$/i) {
			$pendingTitle = $1;
			next;
		}

		next if $line =~ /^\#/;

		push @entries, {
			source_path => $line,
			source_url  => $pendingUrl,
			title       => $pendingTitle,
		};

		$pendingTitle = undef;
		$pendingUrl   = undef;
	}

	close $fh;

	if (%pls) {
		@entries = map { $pls{$_} } sort { $a <=> $b } keys %pls;
	}

	return @entries;
}

sub _resolvePlaylistEntry {
	my ($playlistFile, $entry) = @_;
	return unless $playlistFile && $entry;

	my @exactUrls = _playlistEntryCandidateUrls($playlistFile, $entry);

	for my $url (@exactUrls) {
		my $match = _lookupTrackByUrl($url);
		return $match if $match;
	}

	my $basename = _playlistEntryBasename($entry);
	my $title    = $entry->{title} || _basenameWithoutExtension($basename);
	my $fuzzy    = _lookupTrackFuzzy($playlistFile, $basename, $title);

	return $fuzzy if $fuzzy;

	return unless @exactUrls;

	return {
		title       => $title || string('PLUGIN_REHEARSAL_PLAYER_UNKNOWN_TRACK'),
		composer    => '',
		comment     => '',
		url         => $exactUrls[0],
		artwork_url => '/music/0/cover_96x96_p.png',
	};
}

sub _playlistEntryCandidateUrls {
	my ($playlistFile, $entry) = @_;

	my @candidates;
	my %seen;
	my $basename = _playlistEntryBasename($entry);
	my $dir      = dirname($playlistFile);

	if ($basename) {
		my $sibling = catfile($dir, $basename);
		if (-f $sibling) {
			my $url = Slim::Utils::Misc::fileURLFromPath($sibling);
			push @candidates, $url unless $seen{$url}++;
		}
	}

	if ($entry->{source_url} && $entry->{source_url} =~ /^file:/i) {
		push @candidates, $entry->{source_url} unless $seen{$entry->{source_url}}++;
	}

	if ($entry->{source_path} && $entry->{source_path} =~ m{^/}) {
		my $url = Slim::Utils::Misc::fileURLFromPath($entry->{source_path});
		push @candidates, $url unless $seen{$url}++;
	}

	return @candidates;
}

sub _playlistEntryBasename {
	my ($entry) = @_;
	return '' unless $entry;

	if ($entry->{source_path}) {
		return basename($entry->{source_path});
	}

	if ($entry->{source_url} && $entry->{source_url} =~ /^file:/i) {
		my $path = eval { Slim::Utils::Misc::pathFromFileURL($entry->{source_url}) };
		return basename($path) if $path;
	}

	return '';
}

sub _basenameWithoutExtension {
	my ($value) = @_;
	return '' unless defined $value && $value ne '';

	my ($name) = fileparse($value, qr/\.[^.]+$/);
	return $name;
}

sub _lookupTrackByUrl {
	my ($url) = @_;
	return unless $url;

	my $dbh = Slim::Schema->dbh;
	my $sql = q{
		SELECT
			tracks.id,
			tracks.title,
			tracks.url,
			tracks.coverid,
			COALESCE((
				SELECT GROUP_CONCAT(DISTINCT contributors.name)
				FROM contributor_track
				JOIN contributors ON contributors.id = contributor_track.contributor
				WHERE contributor_track.track = tracks.id AND contributor_track.role = 2
			), '') AS composer,
			COALESCE((
				SELECT GROUP_CONCAT(DISTINCT comments.value)
				FROM comments
				WHERE comments.track = tracks.id
			), '') AS comment
		FROM tracks
		WHERE tracks.url = ?
		LIMIT 1
	};

	my $row = $dbh->selectrow_hashref($sql, undef, $url);
	return _normalizeTrackRow($row);
}

sub _lookupTrackFuzzy {
	my ($playlistFile, $basename, $title) = @_;
	return unless ($basename || $title);

	my $dbh = Slim::Schema->dbh;
	my $preferredDirLike = '%' . uri_escape_utf8(dirname($playlistFile)) . '%';
	my $basenameLike     = '%' . uri_escape_utf8($basename || '') . '%';

	my $sql = q{
		SELECT
			tracks.id,
			tracks.title,
			tracks.url,
			tracks.coverid,
			COALESCE((
				SELECT GROUP_CONCAT(DISTINCT contributors.name)
				FROM contributor_track
				JOIN contributors ON contributors.id = contributor_track.contributor
				WHERE contributor_track.track = tracks.id AND contributor_track.role = 2
			), '') AS composer,
			COALESCE((
				SELECT GROUP_CONCAT(DISTINCT comments.value)
				FROM comments
				WHERE comments.track = tracks.id
			), '') AS comment,
			CASE
				WHEN ? <> '%%' AND tracks.url LIKE ? THEN 4
				WHEN ? <> ''   AND LOWER(tracks.title) = LOWER(?) THEN 3
				WHEN ? <> '%%' AND tracks.url LIKE ? THEN 2
				WHEN ? <> ''   AND LOWER(tracks.title) LIKE LOWER(?) THEN 1
				ELSE 0
			END AS score
		FROM tracks
		WHERE
			(? <> '%%' AND tracks.url LIKE ?)
			OR (? <> '' AND LOWER(tracks.title) = LOWER(?))
			OR (? <> '%%' AND tracks.url LIKE ?)
			OR (? <> '' AND LOWER(tracks.title) LIKE LOWER(?))
		ORDER BY score DESC, LENGTH(tracks.url) ASC
		LIMIT 1
	};

	my $titleLike = $title ? '%' . $title . '%' : '';
	my $row = $dbh->selectrow_hashref(
		$sql,
		undef,
		$preferredDirLike, $preferredDirLike,
		$title || '', $title || '',
		$basenameLike, $basenameLike,
		$titleLike, $titleLike,
		$preferredDirLike, $preferredDirLike,
		$title || '', $title || '',
		$basenameLike, $basenameLike,
		$titleLike, $titleLike,
	);

	return _normalizeTrackRow($row);
}

sub _normalizeTrackRow {
	my ($row) = @_;
	return unless $row && ref $row eq 'HASH';

	my $composer = _cleanMetadataValue($row->{composer});
	my $comment  = _cleanMetadataValue($row->{comment});

	return {
		id          => $row->{id},
		title       => $row->{title} || string('PLUGIN_REHEARSAL_PLAYER_UNKNOWN_TRACK'),
		composer    => $composer,
		comment     => $comment,
		url         => $row->{url},
		artwork_url => $row->{coverid}
			? '/music/' . $row->{coverid} . '/cover_96x96_p.png'
			: '/music/0/cover_96x96_p.png',
	};
}

sub _cleanMetadataValue {
	my ($value) = @_;
	return '' unless defined $value && $value ne '';

	my @parts = split /\s*,\s*/, $value;
	my (@cleaned, %seen);

	for my $part (@parts) {
		next unless defined $part;
		$part =~ s/^\s+//;
		$part =~ s/\s+$//;
		next unless length $part;
		next if lc($part) eq 'jazzart';
		next if $seen{lc $part}++;
		push @cleaned, $part;
	}

	return join(', ', @cleaned);
}

sub _buildFilters {
	my ($tracks) = @_;
	my (%composers, %comments);

	for my $track (@{$tracks || []}) {
		$composers{$track->{composer}}++ if $track->{composer};
		$comments{$track->{comment}}++   if $track->{comment};
	}

	return (
		composers => [ sort { lc($a) cmp lc($b) } keys %composers ],
		comments  => [ sort { lc($a) cmp lc($b) } keys %comments ],
	);
}

sub _listPlayers {
	my @players = map {
		{
			id   => $_->id,
			name => $_->name,
		}
	} Slim::Player::Client::clients();

	@players = sort {
		lc($a->{name}) cmp lc($b->{name})
	} @players;

	return @players;
}

sub _getClientFromRequest {
	my ($request) = @_;

	my $client;

	if (my $id = $request->uri->query_param('player')) {
		$client = Slim::Player::Client::getClient($id);
	}

	if (!$client && (my $cookie = $request->header('Cookie'))) {
		my $cookies = { CGI::Cookie->parse($cookie) };

		if (my $player = $cookies->{'Squeezebox-player'}) {
			$client = Slim::Player::Client::getClient($player->value);
		}
	}

	return $client;
}

1;
