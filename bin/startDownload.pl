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

use FindBin;
use lib "$FindBin::Bin/../inc";

use aria2;
use storage;

if ( scalar @ARGV != 1 ) {
	print STDERR "Usage: $0 <url>\n";
	exit 1;
}

my $url = $ARGV[0];

my $aria2 = new aria2();
my $db = new storage();

if ( $db->isUrlKnown($url) ) {
	print "\nAlready downloading URL\n";
	$db->disconnect() or warn "Disconnection failed: $DBI::errstr\n";
	exit 1;
}

$url =~ /https?:\/\/([^\/]*)\//;
my $host = $1;

my $otrUrl = 0;
if ( $url =~ /http:\/\/81\.95\.11\./ ) {
	$otrUrl = 1;
}

my $gid = $aria2->startDownload($url);
my $url_id = $db->addDownload($url, $host, $otrUrl, 1);
$db->setGidForUrl($url_id, $gid, $aria2->getSessionId());

if ( $otrUrl ) {
	# Check for active download with same host
	if ( $db->getActiveUrlsForHost($host) == 0) {
		$db->updateState($url_id, 2);
		$aria2->unpauseDownload($gid);
	}
} else {
	$db->updateState($url_id, 2);
	$aria2->unpauseDownload($gid);
}

$db->disconnect() or warn "Disconnection failed: $DBI::errstr\n";
