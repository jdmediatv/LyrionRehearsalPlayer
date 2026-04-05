package Plugins::RehearsalPlayer::Settings;

use strict;
use warnings;

use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

my $serverprefs = preferences('server');

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_REHEARSAL_PLAYER_SHORT');
}

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/RehearsalPlayer/settings.html');
}

sub beforeRender {
	my ($class, $params) = @_;
	$params->{playlistdir} = $serverprefs->get('playlistdir') || '';
}

1;
