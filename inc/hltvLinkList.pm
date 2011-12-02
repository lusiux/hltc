
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

package hltvLinkList;

sub parseList {
	my $list = shift;
	my $retVal = {};

	if ( $list =~ /^(USER_NOT_FOUND|WRONG_PASSWORD|DB_ERROR|NOT_ALLOWED|NO_NEW_LINKS)/ ) {
		$retVal->{error} = $1;
	} else {
		my @lines = split '\n', $list;

		#INTERVAL=15;NUMBER_OF_LINKS=3;LIST=23;LINKCOUNT=137;
		my $info = shift @lines;
		foreach my $pair ( split ';', $info ) {
			my ($key, $value) = split '=', $pair, 2;
			$retVal->{lc($key)} = $value;
		}

		$retVal->{links} = {};

		foreach my $line ( @lines ) {
			my ($url, $id) = split ';', $line;
			$retVal->{links}->{$id} = $url;
		}
	}

	return $retVal;
}

sub new {
	my ($class, $list) = @_;
	my $self = {};

	$self = parseList($list);

	return bless $self, $class;
}

sub getListId {
	my $self = shift;
	return $self->{list};
}

sub getNumberOfLinks {
	my $self = shift;
	return $self->{number_of_links};
}

sub getLinksOnServer {
	my $self = shift;
	return $self->{linkcount};
}

sub error {
	my $self = shift;
	if ( defined $self->{error} ) {
		return $self->{error};
	}
	return 0;
}

sub getLinks {
	my $self = shift;
	return $self->{links};
}

1;
