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
use FindBin;
use lib "$FindBin::Bin/inc";

use Configuration;
use aria2;
use storage;
use hltv;
use hltvLinkList;

print "Connecting to homeloadtv account\n";
my $hltv = new hltv($Configuration::userId, $Configuration::username, $Configuration::password);
my $aria2 = new aria2();
my $db = new storage();

$aria2->startUp();
my $sessionId = $aria2->getSessionId();
$aria2->purgeDownloadResult();
$db->updateGids($sessionId, $aria2->getPausedDownloads());

my $delta = $hltv->getTimeTillHHEnd();

if ( $delta > 0 ) {
	printf STDERR "We have %d seconds till the end of the happy hour.\n", $delta;
	$aria2->stopIn($delta);

	print "Resuming old otr downloads\n";

	my $gids = $db->getOnePausedOtrUrlPerHost();
	foreach ( keys %$gids ) {
		my $dl = $gids->{$_};
		my $gid = $dl->{gid};
		print "Unpausing gid $gid\n";
		$db->updateState($dl->{id}, 2);
		$aria2->unpauseDownload($gid);
	}
} else {
	print STDERR "We are not in happy hour.\n";
}

# Only get otr links in happy hour
my $linkList = $hltv->getNewLinks(1);

if ( $linkList->error() ) {
	warn $linkList->error();
} else {
	print $hltv->ackList($linkList);
	my $linkListRef = $linkList->getLinks();

	my $count = scalar keys %{$linkListRef};
	my $counter = 0;

	print "\nFound $count link(s)\n";

	foreach my $id ( keys %{$linkListRef} ) {
		my $url = $linkListRef->{$id};
		$counter++;

		print "\n\tStarting download of ($counter/$count): $url";
		if ( $db->isUrlKnown($url) ) {
			print "\nAlready downloading URL\n";
			print $hltv->finishLink($id) . "\n";
			next;
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
		$db->addHltvIdToUrl($url_id, $id);

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

		print "\n";
	}
}

$db->disconnect();

print "\n";
