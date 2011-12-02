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
# along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/inc";

use Configuration;
use aria2;
use hltv;
use hltvLinkList;

print "Connecting to homeloadtv account";
my $hltv = new hltv($Configuration::userId, $Configuration::username, $Configuration::password);
my $aria2 = new aria2();

my $linkList = $hltv->getNewLinks();
if ( $linkList->error() ) {
	warn $linkList->error();
} else {
	print $hltv->ackList($linkList);
	my $linkListRef = $linkList->getLinks();

	my $count = $linkList->getNumberOfLinks();
	my $counter = 0;

	print "\nFound $count link(s)\n";

	foreach my $id ( keys %{$linkListRef} ) {
		my $url = $linkListRef->{$id};
		$counter++;

		print "\n\tStarting download of ($counter/$count): $url";

		$aria2->startDownload($url);

		my $ret = $hltv->finishLink($id);
		print "\n";
	}
}

print "\n";
