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

use Configuration;
use storage;
use hltv;
use aria2;

if ( scalar @ARGV != 3 ) {
	print STDERR "Usage: $0 <GID> <number-of-links> <filePath>\n";
	exit 1;
}

my $gid = $ARGV[0];
my $numberOfFiles = $ARGV[1];
my $filePath = $ARGV[2];

my $fileName = $filePath;
$fileName =~ s/^.*\/([^\/]+)$/$1/;

open OUT, ">> $Configuration::baseDir/logs/error.log" or die $!;
print OUT "$fileName\n";
close OUT;

my $db = new storage();
my $aria2 = new aria2();

my $url = $aria2->getUriFromGid($gid);
my $info = $db->getInfoByUrl($url);

$db->updateState($info->{id}, 4);

$url =~ /https?:\/\/([^\/]*)\//;
my $host = $1;

if ( (my $nextDl = $db->getPausedOtrUrlForHost($host)) ) {
	$db->updateState($nextDl->{id}, 2);
	$aria2->unpauseDownload($nextDl->{gid});
}
