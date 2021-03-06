#!/usr/bin/perl

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

use strict;
use warnings;

use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../inc";

use Configuration;
use aria2;
use storage;

my $aria2 = new aria2();
my $db = new storage();

$aria2->startUp();
my $sessionId = $aria2->getSessionId();
$db->updateGids($sessionId, $aria2->getPausedDownloads());
my $gids = $db->getOnePausedOtrUrlPerHost();
foreach ( keys %$gids ) {
	my $dl = $gids->{$_};
	my $gid = $dl->{gid};
	print "Unpausing gid $gid\n";
	$db->updateState($dl->{id}, 2);
	$aria2->unpauseDownload($gid);
}
