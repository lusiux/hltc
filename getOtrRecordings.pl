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
use utf8;

use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/inc";
use POSIX;

use Configuration;
use otr;

my $otr = new otr($Configuration::otrUserId, $Configuration::username, $Configuration::password);

print "Logging in";
$otr->login();

print "\nGet recordings";
my $allDownloads = $otr->getRecordings();

my @downloads = grep { $_->{STATUS} ne "Archiv" } @{$allDownloads};
my $count = scalar @downloads;
my $counter = 0;

for my $file ( @downloads ) {
	$counter++;
	print "\nChecking ($counter/$count): " . $file->{TITLE} . ' vom ' . $file->{BEGIN};

	if ( $file->{STATUS} ne "Bereit zum Download" ) {
		print "\tSkipping: Status " . $file->{STATUS} ."\n";
		next;
	}

	my $end;
	if ( $file->{END} =~ /(\d{1,2}).(\d{1,2}).(\d{2,4}) (\d{1,2}):(\d{1,2}):(\d{1,2})/ ) {
		my $day = $1;
		my $month = $2;
		my $year = $3;
		my $hour = $4;
		my $min = $5;
		my $sec = $6;
		$end = mktime($sec, $min, $hour, $day, $month-1, $year-1900);
	} else {
		print $file->{END};
		exit 1;
	}

	print "\n\tGetting download URLs";
	my $infos = $otr->getFileInfo($file, time()-$end);

	if ( ! defined $infos ) {
		print "\n\tNo suitable urls found\n";
		next;
	}

	if ( ! $ARGV[0] || $ARGV[0] ne '-n' ) {
		system('bin/startDownload.pl', $infos->{FREE});
	} else {
		system('bin/checkDownload.pl', $infos->{FREE});
	}
}
print "\n";
