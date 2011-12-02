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
# along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

package aria2;

use RPC::XML;
use RPC::XML::Client;

use Configuration;
use Helper;

# Configuration
my $rpcUrl = 'http://localhost/rpc/';

sub new {
	my ($class) = @_;

	Helper::startupScreen($Configuration::screenToAttachTo);

	my $rpc = RPC::XML::Client->new('http://localhost:6800/rpc');
	my $self = {rpc=>$rpc};

	return bless $self, $class;
}

sub startDownload {
	my ($this, $url) = @_;

	my $response = $this->{rpc}->simple_request('aria2.addUri', [ $url ]);

	if ( $response ) {
		return $response;
	} else {
		print STDERR $RPC::XML::ERROR . "\n";
		return undef;
	}
}

1;
