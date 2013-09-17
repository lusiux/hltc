# This file is part of hltc, a client for homeload.com written in Perl
# 
# hltc is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# hltc is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with hltc.  If not, see <http://www.gnu.org/licenses/>.

package otr;

use XML::Simple;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Cookies;
use Text::Iconv;
use URI::Escape;

use Configuration;

# Configuration
my $baseUrl = 'http://www.onlinetvrecorder.com/downloader/api/';
my $minWaitSeconds = 7;

sub new {
	my ($class, $userId, $email, $password) = @_;

	my $self = {
		loggedIn => 0,
		checksum => 0,
		email => $email,
		password => $password,
		userId => $userId,
		lastRequest => 0,
	};

	$self->{ua} = new LWP::UserAgent();

	return bless $self, $class;
}

sub waitGet {
	my ($self, $url) = @_;

	my $timeDiff = int ($minWaitSeconds * (0.5 + rand(1))) - (time() - $self->{lastRequest});

	if ( $timeDiff > 0 ) {
		while ( $timeDiff-- ) {
			print '.';
			$|=1;
			sleep 1;
		}
	}
	$self->{lastRequest} = time();
	return $self->{ua}->get($url);
}

sub retry {
	my $routine = shift;
	my $retries = shift;
	my $sleep = shift;
	my @params = @_;

	for ( my $i=1; $i<=$retries; $i++ ) {
		if ( &{$routine}(@params) ) {
			return 1;
		}
		print "Retry $i/$retries of $routine()\n";
		sleep $sleep;
	}
	return 0;
}

sub fetchChecksum {
	my $self = shift;
	my $response = $self->waitGet($baseUrl . 'getcode.php');

	return 0 unless $response->is_success;

	my $code = $response->content;

	$self->{checksum} = Configuration::getChecksum($code);
	return 1;
}

sub getChecksum {
	my $self = shift;
	return if $self->{checksum};

	if ( ! retry('fetchChecksum', 5, 30, $self) ) {
		die 'Could not get current code';
	}
}

sub realLogin {
	my $self = shift;

	$self->{ua}->cookie_jar({});

	my $loginUrl = sprintf('%s/login.php?email=%s&pass=%s&did=%s&checksum=%s', $baseUrl, $self->{email}, $self->{password}, $Configuration::clientId, $self->{checksum});

	my $response = $self->waitGet($loginUrl);

	return 0 unless $response->is_success;

	my $cookies = HTTP::Cookies->new();
	$cookies->extract_cookies( $response );
	$self->{ua}->cookie_jar($cookies);
	$self->{loggedIn} = 1;
	return 1;
}

sub login {
	my $self = shift;
	return if $self->{loggedIn};

	$self->getChecksum();

	if ( ! retry('realLogin', 5, 30, $self) ) {
		die 'Could not login';
	}
}

sub getScheduled {
	my $self = shift;
	$self->login();

	my $listString = $baseUrl . 'request_list2.php?showonly=scheduled&orderby=time&status_downloaded=false&status_decoded=false&status_bad=false&status_removed=false&status_pending=false&status_expected=false&did=' . $Configuration::clientId. "&checksum=" . $self->{checksum};

	my $res = $self->waitGet($listString);

	die 'Count not get recordings' unless $res->is_success;

	die $res->content if substr($res->content,0,1) ne "<";

	my $downloads = [];

	my $converter = Text::Iconv->new('latin1', 'utf8');

	my $xml = XMLin($converter->convert($res->content));
	for ( @{$xml->{FILE}} ) {
		push @$downloads, $_;
	}

	return $downloads;
}

sub getRecordings {
	my $self = shift;
	$self->login();

	my $listString = $baseUrl . 'request_list2.php?showonly=recordings&orderby=time&status_bad=false&status_removed=false&status_downloaded=false&status_decoded=false&did=' . $Configuration::clientId. "&checksum=" . $self->{checksum};

	my $res = $self->waitGet($listString);

	die 'Count not get recordings' unless $res->is_success;

	die $res->content if substr($res->content,0,1) ne "<";

	my $downloads = [];

	my $converter = Text::Iconv->new('latin1', 'utf8');

	my $xml = XMLin($converter->convert($res->content));
	for ( @{$xml->{FILE}} ) {
		push @$downloads, $_;
	}

	return $downloads;
}

sub getFileInfo {
	my ($self, $file, $end) = @_;
	$self->login();

	my $res = $self->waitGet($file->{FILEREQUEST} . "&did=$Configuration::clientId&checksum=" . $self->{checksum} . "\n");

	die 'Could not get fileinfos for ' . $file->{TITLE} . 'with status line: ' . $res->status_line . "\n" unless $res->is_success;

	die 'No XML found' if substr($res->content,0,1) ne "<";

	my $xml = XMLin($res->content);

	print "\n";

	print "\t\tAvailable Formats: ";
	foreach ( sort keys %$xml ) {
		if ( ref $xml->{$_} eq 'ARRAY' ) {
			print $_ . '(' . scalar @{$xml->{$_}} . '), ';
		} else {
			print $_ .', ';
		}
	}
	print "\n\t\tChoosing ";

	if ( defined $xml->{HQAVI_unkodiert} ) {
		print '[HQAVI]';
		return $xml->{HQAVI_unkodiert};
	}
	if ( defined $xml->{HQMP4_geschnitten} ) {
		print '[HQMP4-cut]';
		return $xml->{HQMP4_geschnitten};
	}
	if ( defined $xml->{AVI_unkodiert} ) {
		if ( ref $xml->{AVI_unkodiert} eq 'ARRAY' ) {
			foreach ( @{$xml->{AVI_unkodiert}} ) {
				if ( $_->{FILENAME} =~ /\.HQ\./ ) {
					print '[AVI-HQ]';
					return $_;
				}
			}
		}
	}
	if ( defined $xml->{HQ} ) {
		print '[HQ]';
		return $xml->{HQ};
	}

	if ( 0 ) { ## FIXME: implement low quality whitelist
		print 'File in low quality whitelist';
	} elsif ( ($end/3600) < 24 ) {
		print 'Waiting for HQ file';
		return undef;
	}

	if ( defined $xml->{AVI_unkodiert} ) {
		print '[LQAVI]';
		return $xml->{AVI_unkodiert};
	}

	if ( defined $xml->{AVI} ) {
		print '[AVI]';
		return $xml->{AVI};
	}

	return undef;
}

1;
