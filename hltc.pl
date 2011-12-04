#!/usr/bin/perl -w

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
use DateTime;
use FindBin;
use lib "$FindBin::Bin/inc";

use Configuration;
use aria2;
use storage;
use hltv;
use hltvLinkList;

sub getTimeTillHHEnd {
	my $start = shift;
	my $end = shift;

	$start = $start*60*60;
	$end = $end*60*60;

	my $nowDt = DateTime->now();
	$nowDt->set_time_zone( 'Europe/Berlin' );

	my $now = $nowDt->hour*60*60+$nowDt->minute*60+$nowDt->second;

	return $end - $now - 5*60;
}

print "Connecting to homeloadtv account\n";
my $hltv = new hltv($Configuration::userId, $Configuration::username, $Configuration::password);
my $aria2 = new aria2();

$aria2->startUp();
$aria2->pauseAllDownloads(); # Just to make sure, no download is unpaused outside the happy hour.

my $db = new storage();

# Only get otr links in happy hour
my $linkList = $hltv->getNewLinks(1);
my $delta = 0;

if ( $linkList->error() ) {
	warn $linkList->error();
} else {
	$delta = getTimeTillHHEnd($linkList->getHHStart(), $linkList->getHHStart());

	if ( $delta > 0 ) {
		printf STDERR "We have %d seconds till the end of the happy hour.\n", $delta;
		$aria2->stopIn($delta);
	} else {
		print STDERR "We are not in happy hour.\n";
	}

	print $hltv->ackList($linkList);
	my $linkListRef = $linkList->getLinks();

	my $count = scalar keys %{$linkListRef};
	my $counter = 0;

	print "\nFound $count link(s)\n";

	foreach my $id ( keys %{$linkListRef} ) {
		my $url = $linkListRef->{$id};
		$counter++;

		print "\n\tStarting download of ($counter/$count): $url";
		my $gid = $aria2->startDownload($url);
		$db->addDownload($gid, $aria2->getSessionId(), $id, $url);
		print "\n";
	}
}

print "\n";

if ( $delta > 0 ) {
	print "Resuming old downloads\n";
	$aria2->resumeAllDownloads();
}
