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
use Slim::Utils::Prefs;
use Slim::Utils::Strings qw(string);
use Slim::Web::HTTP;
use Slim::Web::Pages;

use constant MENU_PATH => 'plugins/RehearsalPlayer/index.html';
use constant SLUG_PATH => 'jazzartplayer';
use constant API_PATH  => 'plugins/RehearsalPlayer/api';

my $serverprefs = preferences('server');

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
	Slim::Web::Pages->addRawFunction(API_PATH, \&handleApi);
}

sub handleWebIndex {
	my ($client, $params) = @_;

	$params->{rehearsalPlayerApiUrl}  = API_PATH;
	$params->{rehearsalPlayerSlugUrl} = SLUG_PATH;

	return Slim::Web::HTTP::filltemplatefile(MENU_PATH, $params);
}

sub handleApi {
	my ($httpClient, $response, $func) = @_;
	my $request = $response->request;
	my $client  = _getClientFromRequest($request);
	my $action  = $request->uri->query_param('action') || 'state';

	my $result;
	my $status = 200;

	eval {
		if ($action eq 'state') {
			$result = _buildState($client, scalar $request->uri->query_param('playlist'));
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

	my $content = to_json($result);

	$response->header('Content-Length' => length($content));
	$response->header('Connection'     => 'close');
	$response->content_type('application/json');
	$response->code($status);

	Slim::Web::HTTP::addHTTPResponse($httpClient, $response, \$content);
}

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

	my $composer = $row->{composer} || '';
	$composer =~ s/,/, /g if $composer;

	my $comment = $row->{comment} || '';
	$comment =~ s/,/, /g if $comment;

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
