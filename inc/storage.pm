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

package storage;

use DBI;

use Configuration;

# Configuration
sub new {
	my ($class) = @_;

	my $dbargs = {AutoCommit => 0, PrintError => 1};
	my $dbh = DBI->connect("dbi:SQLite:dbname=$Configuration::baseDir/etc/downloads.sqlite", "", "", $dbargs);

	my $self = {dbh=>$dbh};

	return bless $self, $class;
}

sub addDownload {
	my ($this, $gid, $session, $hltv, $url) = @_;

	my $dbh = $this->{dbh};

	my $sql = "insert into downloads (gid, session, hltv, url) values (?, ?, ?, ?)";

	my $query = $dbh->prepare($sql);
	$query->execute($gid, $session, $hltv, $url);
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	$dbh->commit();
}

sub isUrlKnown {
	my ($this, $url) = @_;

	my $dbh = $this->{dbh};

	my $sql = "select * from downloads where url=?";

	my $query = $dbh->prepare($sql);
	$query->execute($url);
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	my $ref = $query->fetchrow_hashref();

	if ( ! defined $ref ) {
		return undef;
	} else {
		return $ref;
	}
}

sub getHltvIdFromGid {
	my ($this, $gid, $session) = @_;

	my $dbh = $this->{dbh};

	my $sql = "select * from downloads where gid=? and session=?";

	my $query = $dbh->prepare($sql);
	$query->execute($gid, $session);
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	my $ref = $query->fetchrow_hashref();

	if ( ! defined $ref ) {
		return undef;
	}

	my $hltv = $ref->{hltv};

	if ( ! $hltv ) {
		return undef;
	}

	$sql = "delete from downloads where gid=? and session=?";

	$query = $dbh->prepare($sql);
	$query->execute($gid, $session);
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	$dbh->commit();

	return $hltv;
}

sub getHltvIdFromUri{
	my ($this, $url) = @_;

	my $dbh = $this->{dbh};

	my $sql = "select * from downloads where url=?";

	my $query = $dbh->prepare($sql);
	$query->execute($url);
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	my $ref = $query->fetchrow_hashref();

	if ( ! defined $ref ) {
		return undef;
	}

	my $hltv = $ref->{hltv};

	if ( ! $hltv ) {
		return undef;
	}

	$sql = "delete from downloads where url=?";

	$query = $dbh->prepare($sql);
	$query->execute($url);
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	$dbh->commit();

	return $hltv;
}

1;
