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

package aria2;

use RPC::XML;
use RPC::XML::Client;

use Configuration;
use Data::Dumper;

# Configuration
my $rpcUrl = 'http://localhost/rpc/';

sub new {
	my ($class) = @_;

	my $rpc = RPC::XML::Client->new('http://localhost:6800/rpc');
	my $self = {rpc=>$rpc, startUpComplete=>0,};

	return bless $self, $class;
}

sub startUp {
	my $this = shift;

	# Check if screen is running
	my @cmd = ($Configuration::baseDir . '/bin/isScreenRunning.sh', $Configuration::screenToAttachTo);
	system @cmd;
	if ( $? == 0 ) {
		return -1;
	}

	# Start screen with an instance of aria2 in daemon mode
	@cmd = (
	'screen', '-dmS', $Configuration::screenToAttachTo,
	'-c', "$Configuration::baseDir/etc/screenrc", 
	'aria2c',
	'--retry-wait=30',
	'-m', '0',
	'--enable-rpc',
	"--pause",
	'-l', "$Configuration::logDir/aria2c.log",
#	'--log-level=warn',
	'-d', $Configuration::downloadDir,
	'--on-download-complete', "$Configuration::baseDir/bin/complete.pl",
	'--on-download-error', "$Configuration::baseDir/bin/error.pl",
#	'--on-download-pause', "$Configuration::baseDir/bin/pause.pl",
	'-V',
	'-s', 1,
	'-j', 10,
	"--save-session=$Configuration::baseDir/etc/aria.session",
	);

	if ( -f "$Configuration::baseDir/etc/aria.session" ) {
		push @cmd, '-i', "$Configuration::baseDir/etc/aria.session";
	}

	system @cmd and die $! . "\nCommand: " . join ' ', @cmd;

	sleep(2);

	$this->{startUpComplete} = 1;

	return 0;
}

sub getSessionId {
	my ($this) = @_;

	my $response = $this->{rpc}->simple_request('aria2.getSessionInfo');

	if ( $response ) {
		return $response->{sessionId};
	} else {
		print STDERR $RPC::XML::ERROR . "\n";
		return undef;
	}
}

sub pauseDownload {
	my ($this, $gid) = @_;

	my $response = $this->{rpc}->simple_request('aria2.pause', RPC::XML::string->new($gid));

	if ( $response eq 'OK' ) {
		return $response;
	} else {
		print STDERR $RPC::XML::ERROR . "\n";
		return undef;
	}
}

sub unpauseDownload {
	my ($this, $gid) = @_;

	my $response = $this->{rpc}->simple_request('aria2.unpause', RPC::XML::string->new($gid));

	if ( $response eq 'OK' ) {
		return $response;
	} else {
		print STDERR $RPC::XML::ERROR . "\n";
		return undef;
	}
}

sub startDownload {
	my ($this, $url) = @_;

	my $response = $this->{rpc}->simple_request('aria2.addUri', [ $url ], {'pause' => 'true'});

	if ( $response ) {
		return $response;
	} else {
		print STDERR $RPC::XML::ERROR . "\n";
		return undef;
	}
}

sub pauseAllDownloads {
	my ($this) = @_;

	my $response = $this->{rpc}->simple_request('aria2.pauseAll');

	if ( $response ) {
		if ( $response eq 'OK' ) {
			return 0;
		} else {
			return 1;
		}
	}

	print STDERR $RPC::XML::ERROR . "\n";
	return -1;
}

sub resumeAllDownloads {
	my ($this) = @_;

	my $response = $this->{rpc}->simple_request('aria2.unpauseAll');

	if ( $response ) {
		if ( $response eq 'OK' ) {
			return 0;
		} else {
			return 1;
		}
	}

	print STDERR $RPC::XML::ERROR . "\n";
	return -1;
}

sub shutdown {
	my ($this) = @_;

	my $response = $this->{rpc}->simple_request('aria2.shutdown');

	if ( $response ) {
		if ( $response eq 'OK' ) {
			return 0;
		} else {
			return 1;
		}
	}

	print STDERR $RPC::XML::ERROR . "\n";
	return -1;
}

sub getGlobalOption {
	my ($this) = @_;

	my $response = $this->{rpc}->simple_request('aria2.getGlobalOption');

	if ( $response ) {
		return $response;
	}

	print STDERR $RPC::XML::ERROR . "\n";
	return -1;
}

sub getUrisFromGid {
	my ($this, $gid) = @_;

	my $response = $this->{rpc}->simple_request('aria2.getFiles', RPC::XML::string->new($gid));

	if ( $response->[0]->{uris}->[0]->{uri} ) {
		return $response->[0]->{uris}->[0]->{uri};
	}

	print STDERR $RPC::XML::ERROR . "\n";
	return undef;
}

sub setGlobalOption {
	my ($this, $url, $key, $value) = @_;

	my $response = $this->{rpc}->simple_request('aria2.changeGlobalOption', { $key, $value } );

	if ( $response ) {
		return $response;
	} else {
		print STDERR $RPC::XML::ERROR . "\n";
		return undef;
	}
}

sub isRunning {
	my ($this) = @_;

	if ( $this->{startUpComplete} ) {
		return 1;
	}

	my $response = $this->{rpc}->simple_request('aria2.getSessionInfo' );

	if ( $response ) {
		return 1;
	} else {
		return 0;
	}
}

sub stopIn {
	my ($this, $seconds) = @_;

	if ( $seconds <= 0 ) {
		print STDERR "Parameter seconds has to be greater than 0\n";
		exit 1;
	}

	if ( ! $this->isRunning() ) {
		print "Aria is not running. So call to stopIn is senseless\n";
		return;
	}

	my @cmd = (
	'screen', '-S', $Configuration::screenToAttachTo,
	'-X', 
	'screen',
	"$Configuration::baseDir/bin/stoparia2.pl", $seconds,
	);

	system @cmd and die $! . "\nCommand was: " . join ' ', @cmd;
}

sub getPausedDownloads {
	my ($this) = @_;

	my $retVal={};

	my $response = $this->{rpc}->simple_request('aria2.tellWaiting', 0, 1000);

	if ( ! $response ) {
		print STDERR $RPC::XML::ERROR . "\n";
		return undef;
	}

	foreach ( @$response ) {
		my $dl = $_;

		my $url = $dl->{files}->[0]->{uris}->[0]->{uri};
		$retVal->{$dl->{gid}} = $url;
	}

	return $retVal;
}

sub purgeDownloadResult {
	my ($this) = @_;

	my $retVal={};

	my $response = $this->{rpc}->simple_request('aria2.purgeDownloadResult');

	if ( ! $response ) {
		print STDERR $RPC::XML::ERROR . "\n";
		return undef;
	}

	return $response;
}

1;
