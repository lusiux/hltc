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
use Helper;
use hltv;
use hltvLinkList;

print "Connecting to homeloadtv account";
my $hltv = new hltv($Configuration::userId, $Configuration::username, $Configuration::password);

Helper::startupScreen($Configuration::screenToAttachTo);

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

		my @cmd = ('screen','-S', $Configuration::screenToAttachTo, '-X', 'screen', '-t', 'aria', '10', 'bin/ariaSleepWrapper.sh', '10', $Configuration::dlCmd, '-V', '-m', 0, '--retry-wait', 30, '-d', $Configuration::downloadDir, '-s', 1, $url, '--on-download-complete', $FindBin::Bin. '/bin/complete.pl');
		#print join ' ', @cmd;
		system(@cmd);

		my $ret = $hltv->finishLink($id);
		print "\n";
	}
}

print "\n";
