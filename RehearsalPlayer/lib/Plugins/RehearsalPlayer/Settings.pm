package Plugins::RehearsalPlayer::Settings;

use strict;
use warnings;

use base qw(Slim::Web::Settings);

use JSON::XS::VersionOneAndTwo;
use Slim::Utils::Log;
use Slim::Utils::Prefs;

my $serverprefs = preferences('server');
my $pluginprefs = preferences('plugin.rehearsalplayer');
my $log         = logger('plugin.rehearsalplayer');

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_REHEARSAL_PLAYER_SHORT');
}

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/RehearsalPlayer/settings.html');
}

sub prefs {
	return ($pluginprefs, qw(spotifyClientId spotifyClientSecret spotifyBridgeUrl));
}

sub handler {
	my ($class, $client, $params, $callback, @args) = @_;

	if ($params->{'saveSettings'}) {
		$pluginprefs->set('spotifyClientId', _trim($params->{'spotifyClientId'}));
		$pluginprefs->set('spotifyClientSecret', _trim($params->{'spotifyClientSecret'}));
		$pluginprefs->set('spotifyBridgeUrl', _trim($params->{'spotifyBridgeUrl'}));

		my $playlists = _parseTeacherPlaylistsJson($params->{'teacherPlaylistsJson'});
		$pluginprefs->set('teacherPlaylists', $playlists) if defined $playlists;
	}

	return $class->SUPER::handler($client, $params, $callback, @args);
}

sub beforeRender {
	my ($class, $params) = @_;

	$params->{playlistdir}         = $serverprefs->get('playlistdir') || '';
	$params->{spotifyClientId}     = $pluginprefs->get('spotifyClientId') || '';
	$params->{spotifyClientSecret} = $pluginprefs->get('spotifyClientSecret') || '';
	$params->{spotifyBridgeUrl}    = $pluginprefs->get('spotifyBridgeUrl') || '';
	$params->{teacherPlaylistsJson} = to_json($pluginprefs->get('teacherPlaylists') || []);
}

sub _trim {
	my ($value) = @_;
	return '' unless defined $value;

	$value =~ s/^\s+//;
	$value =~ s/\s+$//;

	return $value;
}

# Accepts the JSON blob posted by the admin table on settings.html:
#   [{ id, label, icon, playlistId, enabled, sortOrder }, ...]
# Validates/normalizes it and assigns a stable id to any new row.
sub _parseTeacherPlaylistsJson {
	my ($json) = @_;
	return unless defined $json;

	my $rows = eval { from_json($json) };
	if ($@ || ref $rows ne 'ARRAY') {
		$log->error("Could not parse teacher playlist settings: $@") if $@;
		return;
	}

	my @cleaned;
	my $order = 0;

	for my $row (@$rows) {
		next unless ref $row eq 'HASH';

		my $playlistId = _trim($row->{playlistId});
		my $label       = _trim($row->{label});
		next unless $label && $playlistId;

		# Accept a pasted Spotify playlist URL/URI and extract just the id.
		if ($playlistId =~ m{playlist[/:]([A-Za-z0-9]+)}) {
			$playlistId = $1;
		}

		push @cleaned, {
			id         => _trim($row->{id}) || _newId(),
			label      => $label,
			icon       => _trim($row->{icon}),
			playlistId => $playlistId,
			enabled    => $row->{enabled} ? 1 : 0,
			sortOrder  => $order++,
		};
	}

	return \@cleaned;
}

sub _newId {
	my @chars = ('a' .. 'z', 0 .. 9);
	my $id = '';
	$id .= $chars[int(rand(scalar @chars))] for 1 .. 12;
	return $id;
}

1;
