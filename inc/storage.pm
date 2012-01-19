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
	my ($this, $url, $host, $otr, $state) = @_;

	my $dbh = $this->{dbh};

#CREATE TABLE urls ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "url" text NOT NULL, "host" text NOT NULL, "otr" int not NULL, "state" int not NULL);
	my $sql = "insert into urls (url, host, otr, state) values (?, ?, ?, ?)";

	my $query = $dbh->prepare($sql);
	$query->execute($url, $host, $otr, $state);
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	$dbh->commit();

	$sql = "select last_insert_rowid();";
	$query = $dbh->prepare($sql);
	$query->execute();

	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	my ($id) = $query->fetchrow_array();

	return $id;
}

sub addHltvIdToUrl {
	my ($this, $url_id, $hltv_id) = @_;

	my $dbh = $this->{dbh};

#CREATE TABLE hltv("url_id" int primary key, "hltv_id" int not null);
	my $sql = "insert into hltv (url_id, hltv_id) values (?, ?)";

	my $query = $dbh->prepare($sql);
	$query->execute($url_id, $hltv_id);
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	$dbh->commit();
}

sub updateState {
	my ($this, $url_id, $state) = @_;

	my $dbh = $this->{dbh};

#CREATE TABLE hltv("url_id" int primary key, "hltv_id" int not null);
	my $sql = "update urls set state=? where id=?;";

	my $query = $dbh->prepare($sql);
	$query->execute($state, $url_id);
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}
	$dbh->commit();
}

sub getInfoByUrl {
	my ($this, $url) = @_;

	my $dbh = $this->{dbh};

	my $sql = "select * from urls where url=?";

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

sub isUrlKnown {
	my ($this, $url) = @_;

	my $dbh = $this->{dbh};

	my $sql = "select * from urls where url=?;";

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

sub getHltvIdFromId{
	my ($this, $urlId) = @_;

	my $dbh = $this->{dbh};

	my $sql = "select * from hltv where url_id=?";

	my $query = $dbh->prepare($sql);
	$query->execute($urlId);
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	my $ref = $query->fetchrow_hashref();

	if ( ! defined $ref ) {
		return undef;
	}

	return  $ref->{hltv_id};
}

sub getActiveUrlsForHost {
	my ($this, $host) = @_;

	my $dbh = $this->{dbh};

	my $sql = "select count(url) from urls where state=2 and host=?;";

	my $query = $dbh->prepare($sql);
	$query->execute($host);
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	my ($count) = $query->fetchrow_array();

	return $count;
}

sub clearOldGids {
	my ($this, $session_id) = @_;

	my $dbh = $this->{dbh};

	my $sql = "delete from aria2 where session_id !=?;";

	my $query = $dbh->prepare($sql);
	$query->execute($session_id) or warn $dbh->errstr;
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}
	$dbh->commit();
}

sub setGidForUrl {
	my ($this, $url_id, $gid, $session_id) = @_;

	my $dbh = $this->{dbh};

	my $sql = "insert into aria2 (url_id, session_id, gid) values (?,?,?);";

	my $query = $dbh->prepare($sql);

	$query->execute($url_id, $session_id, $gid);
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}
	$dbh->commit();
}

sub updateGids {
	my ($this, $session_id, $gidUrlHashRef) = @_;

	$this->clearOldGids($session_id);

	my $dbh = $this->{dbh};

	my $sql = "insert into aria2 (url_id, session_id, gid) select (select id from urls where url=?), ?,? where not exists (select 1 from aria2 where url_id=(select id from urls where url=?));";

	my $query = $dbh->prepare($sql);

	foreach ( keys %$gidUrlHashRef ) {
		my $gid = $_;
		my $url = $gidUrlHashRef->{$gid};
		$query->execute($url, $session_id, $gid, $url);
		if ( $dbh->err() ) {
			die "$DBI::errstr\n";
		}
	}
	$dbh->commit();
}

sub getPausedOtrUrlForHost {
	my ($this,$host) = @_;

	my $dbh = $this->{dbh};

	my $sql = "select urls.id as id, aria2.gid as gid from urls join aria2 on urls.id = aria2.url_id where urls.state=1 and urls.otr=1 and host=? group by urls.host;";

	my $query = $dbh->prepare($sql);
	$query->execute($host);
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	return $query->fetchrow_hashref();
}

sub getOnePausedOtrUrlPerHost {
	my ($this) = @_;

	my $dbh = $this->{dbh};

	my $sql = "select urls.id as id, aria2.gid as gid from urls join aria2 on urls.id = aria2.url_id where urls.state=1 and urls.otr=1 group by urls.host;";

	my $query = $dbh->prepare($sql);
	$query->execute();
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	return $query->fetchall_hashref('id');
}

sub getRunningOtrUrls {
	my ($this) = @_;

	my $dbh = $this->{dbh};

	my $sql = "select urls.id as id, aria2.gid as gid from urls join aria2 on urls.id = aria2.url_id where urls.state=2 and urls.otr=1";

	my $query = $dbh->prepare($sql);
	$query->execute();
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	return $query->fetchall_hashref('id');
}

sub getPausedNonOtrUrls {
	my ($this) = @_;

	my $dbh = $this->{dbh};

	my $sql = "select aria2.gid as gid from urls join aria2 on urls.id = aria2.url_id where urls.state=1 and urls.otr=0;";

	my $query = $dbh->prepare($sql);
	$query->execute();
	if ( $dbh->err() ) {
		die "$DBI::errstr\n";
	}

	return $query->fetchall_arrayref([0]);
}

sub disconnect {
	my ($this) = @_;
	$this->{dbh}->disconnect();
}

1;
