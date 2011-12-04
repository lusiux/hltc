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

my $aria2 = new aria2();

if ( scalar @ARGV == 1 ) {
	print "Waiting $ARGV[0] seconds\n";
	sleep $ARGV[0];
}

my $retVal = $aria2->pauseAllDownloads();

if ( $retVal != 0 ) {
	print STDERR "An error occured\n";
}

$retVal = $aria2->shutdown();

if ( $retVal != 0 ) {
	print STDERR "An error occured\n";
}
