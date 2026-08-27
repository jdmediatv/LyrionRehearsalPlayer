package Plugins::RehearsalPlayer::Spotify;

# Thin wrapper around the official Spotify Web API + Accounts service.
#
# Everything here is asynchronous (Slim::Networking::SimpleAsyncHTTP) because
# LMS web request handlers must not block the server's event loop while
# waiting on an external HTTPS call. Every public function below takes a
# success callback ($cbOk->(\%data)) and an error callback
# ($cbErr->($message)) instead of returning a value directly.
#
# Token / session storage lives in this plugin's own preference namespace
# (see Plugin.pm), not in Slim's global "server" prefs, since none of this
# is core LMS configuration.

use strict;
use warnings;

use MIME::Base64 qw(encode_base64 decode_base64);
use JSON::XS::VersionOneAndTwo;
use URI::Escape qw(uri_escape_utf8);

use Slim::Networking::SimpleAsyncHTTP;
use Slim::Utils::Log;
use Slim::Utils::Prefs;

my $log   = logger('plugin.rehearsalplayer');
my $prefs = preferences('plugin.rehearsalplayer');

use constant ACCOUNTS_BASE => 'https://accounts.spotify.com';
use constant API_BASE      => 'https://api.spotify.com/v1';
use constant AUTH_SCOPES   => 'playlist-modify-public playlist-modify-private playlist-read-private playlist-read-collaborative';

# ---------------------------------------------------------------------------
# base64url helpers (MIME::Base64's encode_base64url/decode_base64url are not
# guaranteed to exist on every Perl bundled with LMS, so we roll our own on
# top of the always-available encode_base64/decode_base64).
# ---------------------------------------------------------------------------

sub b64urlEncode {
	my ($data) = @_;
	return '' unless defined $data;

	my $encoded = encode_base64($data, '');
	$encoded =~ tr{+/}{-_};
	$encoded =~ s/=+$//;

	return $encoded;
}

sub b64urlDecode {
	my ($data) = @_;
	return '' unless defined $data && length $data;

	my $padded = $data;
	$padded =~ tr{-_}{+/};
	$padded .= '=' x ((4 - length($padded) % 4) % 4);

	return decode_base64($padded);
}

# ---------------------------------------------------------------------------
# App credentials (set on the plugin settings page)
# ---------------------------------------------------------------------------

sub clientId {
	return $prefs->get('spotifyClientId') || '';
}

sub clientSecret {
	return $prefs->get('spotifyClientSecret') || '';
}

sub bridgeUrl {
	return $prefs->get('spotifyBridgeUrl') || '';
}

sub isConfigured {
	return clientId() && clientSecret() && bridgeUrl() ? 1 : 0;
}

sub _basicAuthHeader {
	return 'Basic ' . encode_base64(clientId() . ':' . clientSecret(), '');
}

# ---------------------------------------------------------------------------
# Authorization Code flow
# ---------------------------------------------------------------------------

# Builds the URL the *teacher's own browser* should be sent to. The
# redirect_uri is always our fixed, publicly-hosted HTTPS bridge page - see
# /spotify-oauth-bridge.html in the repo root and SPOTIFY_SETUP.md. Spotify
# will not accept a plain LAN redirect URI (it requires HTTPS, or the exact
# loopback address 127.0.0.1), so the bridge page's only job is to bounce
# the browser straight back to this LMS server on the LAN, carrying the
# "code" and "state" query params with it.
#
# The LAN callback address the bridge should bounce back to is embedded
# inside "state" itself (base64url JSON), so the same bridge URL works for
# any LMS instance / any teacher's browser without extra configuration.
sub authorizeUrl {
	my ($callbackBaseUrl) = @_;

	my $nonce = _newNonce();

	my $pending = $prefs->get('spotifyPendingStates') || {};
	$pending->{$nonce} = { expires => time() + 600 };
	_prunePendingStates($pending);
	$prefs->set('spotifyPendingStates', $pending);

	my $statePayload = to_json({
		nonce => $nonce,
		cb    => $callbackBaseUrl,
	});
	my $state = b64urlEncode($statePayload);

	my %params = (
		client_id     => clientId(),
		response_type => 'code',
		redirect_uri  => bridgeUrl(),
		scope         => AUTH_SCOPES,
		state         => $state,
		show_dialog   => 'false',
	);

	return ACCOUNTS_BASE . '/authorize?' . _buildQuery(\%params);
}

sub _newNonce {
	my @chars = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);
	my $nonce = '';
	$nonce .= $chars[int(rand(scalar @chars))] for 1 .. 32;
	return $nonce;
}

sub _prunePendingStates {
	my ($pending) = @_;
	my $now = time();

	for my $key (keys %$pending) {
		delete $pending->{$key} if !$pending->{$key}{expires} || $pending->{$key}{expires} < $now;
	}

	return $pending;
}

# Verifies a "state" value came from a call to authorizeUrl() within the
# last 10 minutes (basic CSRF protection for the OAuth dance) and consumes
# it (single use). Returns the decoded { nonce, cb } hashref on success,
# or undef if the state is missing/expired/unknown.
sub consumeState {
	my ($state) = @_;
	return unless $state;

	my $decoded = eval { from_json(b64urlDecode($state)) };
	return unless $decoded && ref $decoded eq 'HASH' && $decoded->{nonce};

	my $pending = $prefs->get('spotifyPendingStates') || {};
	_prunePendingStates($pending);

	my $entry = delete $pending->{$decoded->{nonce}};
	$prefs->set('spotifyPendingStates', $pending);

	return unless $entry;

	return $decoded;
}

# Exchanges an authorization code for an access/refresh token pair.
sub exchangeCode {
	my (%args) = @_;
	my $code   = $args{code};
	my $cbOk   = $args{cbOk}  || sub {};
	my $cbErr  = $args{cbErr} || sub {};

	my %body = (
		grant_type   => 'authorization_code',
		code         => $code,
		redirect_uri => bridgeUrl(),
	);

	_tokenRequest(\%body, $cbOk, $cbErr);
}

sub refreshAccessToken {
	my (%args) = @_;
	my $refreshToken = $args{refreshToken};
	my $cbOk         = $args{cbOk}  || sub {};
	my $cbErr        = $args{cbErr} || sub {};

	my %body = (
		grant_type    => 'refresh_token',
		refresh_token => $refreshToken,
	);

	_tokenRequest(\%body, $cbOk, $cbErr);
}

sub _tokenRequest {
	my ($body, $cbOk, $cbErr) = @_;

	my $http = Slim::Networking::SimpleAsyncHTTP->new(
		sub {
			my $http = shift;
			my $data = eval { from_json($http->content) };

			if (!$data || $data->{error}) {
				$cbErr->(($data && $data->{error_description}) || 'Spotify token request failed.');
				return;
			}

			$data->{obtained_at} = time();
			$cbOk->($data);
		},
		sub {
			my $http = shift;
			$log->error('Spotify token request failed: ' . $http->error);
			$cbErr->('Could not reach Spotify.');
		},
	);

	$http->post(
		ACCOUNTS_BASE . '/api/token',
		'Authorization' => _basicAuthHeader(),
		'Content-Type'  => 'application/x-www-form-urlencoded',
		_buildQuery($body),
	);
}

# App-only ("Client Credentials") token, used for read-only calls (search,
# reading public playlists) when no teacher is currently signed in. Cached
# in prefs until shortly before it expires.
sub appToken {
	my ($cbOk, $cbErr) = @_;
	$cbErr ||= sub {};

	my $cached = $prefs->get('spotifyAppToken');
	if ($cached && $cached->{access_token} && $cached->{expires_at} > time() + 30) {
		$cbOk->($cached->{access_token});
		return;
	}

	my $http = Slim::Networking::SimpleAsyncHTTP->new(
		sub {
			my $http = shift;
			my $data = eval { from_json($http->content) };

			if (!$data || $data->{error} || !$data->{access_token}) {
				$cbErr->('Could not obtain a Spotify app token.');
				return;
			}

			$prefs->set('spotifyAppToken', {
				access_token => $data->{access_token},
				expires_at   => time() + ($data->{expires_in} || 3600),
			});

			$cbOk->($data->{access_token});
		},
		sub {
			$cbErr->('Could not reach Spotify.');
		},
	);

	$http->post(
		ACCOUNTS_BASE . '/api/token',
		'Authorization' => _basicAuthHeader(),
		'Content-Type'  => 'application/x-www-form-urlencoded',
		_buildQuery({ grant_type => 'client_credentials' }),
	);
}

# Makes sure the given session hashref has a non-expired access token,
# refreshing it first if necessary, then calls $cbOk->($accessToken, $session).
# If the session has no usable refresh token, falls back to $cbErr->().
sub ensureUserToken {
	my ($session, $cbOk, $cbErr) = @_;
	$cbErr ||= sub {};

	if (!$session || !$session->{refresh_token}) {
		$cbErr->('Not signed in to Spotify.');
		return;
	}

	if ($session->{access_token} && $session->{expires_at} && $session->{expires_at} > time() + 30) {
		$cbOk->($session->{access_token}, $session);
		return;
	}

	refreshAccessToken(
		refreshToken => $session->{refresh_token},
		cbOk         => sub {
			my ($data) = @_;
			$session->{access_token} = $data->{access_token};
			$session->{expires_at}   = time() + ($data->{expires_in} || 3600);
			# Spotify does not always return a new refresh_token; keep the old one if absent.
			$session->{refresh_token} = $data->{refresh_token} if $data->{refresh_token};
			$cbOk->($session->{access_token}, $session);
		},
		cbErr => $cbErr,
	);
}

# ---------------------------------------------------------------------------
# Web API calls
# ---------------------------------------------------------------------------

sub getMe {
	my ($accessToken, $cbOk, $cbErr) = @_;
	_apiGet(API_BASE . '/me', $accessToken, $cbOk, $cbErr);
}

sub getPlaylistTracks {
	my (%args) = @_;
	my $playlistId  = $args{playlistId};
	my $accessToken = $args{accessToken};
	my $cbOk        = $args{cbOk}  || sub {};
	my $cbErr       = $args{cbErr} || sub {};

	return $cbErr->('No Spotify playlist selected.') unless $playlistId;

	my $fields = 'items(track(id,uri,name,duration_ms,artists(name),album(name,images))),next';
	my $url = API_BASE . '/playlists/' . uri_escape_utf8($playlistId) . '/tracks?'
		. _buildQuery({ fields => $fields, limit => 100 });

	_apiGet($url, $accessToken, sub {
		my ($data) = @_;
		my @tracks = _mapTrackItems($data->{items} || []);
		$cbOk->({ tracks => \@tracks });
	}, $cbErr);
}

sub _mapTrackItems {
	my ($items) = @_;
	my @tracks;

	for my $item (@$items) {
		my $track = $item->{track};
		next unless $track && $track->{id};

		my @artistNames = map { $_->{name} } @{ $track->{artists} || [] };
		my $artwork = '';
		if ($track->{album} && $track->{album}{images} && @{ $track->{album}{images} }) {
			# Prefer a smallish image if one is available (last in the array is usually smallest).
			my @images = @{ $track->{album}{images} };
			$artwork = $images[$#images]->{url} || $images[0]->{url};
		}

		push @tracks, {
			id          => $track->{id},
			uri         => $track->{uri},
			title       => $track->{name},
			composer    => join(', ', @artistNames),
			comment     => $track->{album} ? $track->{album}{name} : '',
			duration_ms => $track->{duration_ms},
			artwork_url => $artwork,
			source      => 'spotify',
		};
	}

	return @tracks;
}

sub searchTracks {
	my (%args) = @_;
	my $query       = $args{query};
	my $accessToken = $args{accessToken};
	my $cbOk        = $args{cbOk}  || sub {};
	my $cbErr       = $args{cbErr} || sub {};

	return $cbOk->({ tracks => [] }) unless defined $query && length $query;

	my $url = API_BASE . '/search?' . _buildQuery({ q => $query, type => 'track', limit => 15 });

	_apiGet($url, $accessToken, sub {
		my ($data) = @_;
		my $items = ($data->{tracks} && $data->{tracks}{items}) || [];
		my @tracks = _mapSearchItems($items);
		$cbOk->({ tracks => \@tracks });
	}, $cbErr);
}

sub _mapSearchItems {
	my ($items) = @_;
	my @tracks;

	for my $track (@$items) {
		next unless $track && $track->{id};

		my @artistNames = map { $_->{name} } @{ $track->{artists} || [] };
		my $artwork = '';
		if ($track->{album} && $track->{album}{images} && @{ $track->{album}{images} }) {
			my @images = @{ $track->{album}{images} };
			$artwork = $images[$#images]->{url} || $images[0]->{url};
		}

		push @tracks, {
			id          => $track->{id},
			uri         => $track->{uri},
			title       => $track->{name},
			composer    => join(', ', @artistNames),
			comment     => $track->{album} ? $track->{album}{name} : '',
			duration_ms => $track->{duration_ms},
			artwork_url => $artwork,
			source      => 'spotify',
		};
	}

	return @tracks;
}

sub addTrackToPlaylist {
	my (%args) = @_;
	my $playlistId  = $args{playlistId};
	my $trackUri    = $args{trackUri};
	my $accessToken = $args{accessToken};
	my $cbOk        = $args{cbOk}  || sub {};
	my $cbErr       = $args{cbErr} || sub {};

	return $cbErr->('Missing playlist or track.') unless $playlistId && $trackUri;

	my $url = API_BASE . '/playlists/' . uri_escape_utf8($playlistId) . '/tracks';
	my $body = to_json({ uris => [ $trackUri ] });

	my $http = Slim::Networking::SimpleAsyncHTTP->new(
		sub {
			my $http = shift;
			my $data = eval { from_json($http->content) } || {};
			$cbOk->($data);
		},
		sub {
			my $http = shift;
			my $code = $http->code || 0;

			if ($code == 401) {
				$cbErr->('Your Spotify sign-in has expired. Please reconnect.');
			}
			elsif ($code == 403) {
				$cbErr->('Spotify refused this add. Make sure the playlist is set to "collaborative" so other teachers can add to it.');
			}
			else {
				$cbErr->('Spotify could not add that track (' . $code . ').');
			}
		},
	);

	$http->post(
		$url,
		'Authorization' => 'Bearer ' . $accessToken,
		'Content-Type'  => 'application/json',
		$body,
	);
}

sub _apiGet {
	my ($url, $accessToken, $cbOk, $cbErr) = @_;
	$cbErr ||= sub {};

	my $http = Slim::Networking::SimpleAsyncHTTP->new(
		sub {
			my $http = shift;
			my $data = eval { from_json($http->content) };

			if (!$data) {
				$cbErr->('Spotify returned an unexpected response.');
				return;
			}

			if ($data->{error}) {
				my $message = ref $data->{error} eq 'HASH' ? $data->{error}{message} : $data->{error};
				$cbErr->($message || 'Spotify request failed.');
				return;
			}

			$cbOk->($data);
		},
		sub {
			my $http = shift;
			my $code = $http->code || 0;
			$log->error("Spotify GET $url failed: " . $http->error . " ($code)");
			$cbErr->($code == 401 ? 'Your Spotify sign-in has expired. Please reconnect.' : 'Could not reach Spotify.');
		},
	);

	my @headers;
	push @headers, ('Authorization' => 'Bearer ' . $accessToken) if $accessToken;

	$http->get($url, @headers);
}

sub _buildQuery {
	my ($params) = @_;

	return join('&', map {
		uri_escape_utf8($_) . '=' . uri_escape_utf8(defined $params->{$_} ? $params->{$_} : '')
	} sort keys %$params);
}

1;
