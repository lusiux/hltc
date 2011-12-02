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

package hltv;

use Configuration;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Cookies;
use Digest::MD5 qw(md5_hex);
use hltvLinkList;

# Configuration
my $baseUrl = 'http://www.homeloadtv.com/api/';
my $minWaitSeconds = 5;

sub new {
	my ($class, $userId, $email, $password) = @_;

	my $self = {
		email => $email,
		password => md5_hex($password),
		userId => $userId,
		lastRequest => 0,
	};

	$self->{ua} = new LWP::UserAgent();

	return bless $self, $class;
}

sub waitGet {
	my ($self, $url) = @_;

	my $timeDiff = $minWaitSeconds - (time() - $self->{lastRequest});

	if ( $timeDiff > 0 ) {
#		print "Sleeping " . $timeDiff . " seconds";
		while ( $timeDiff-- ) {
			print '.';
			$|=1;
			sleep 1;
		}
#		print "\n";
	}
	$self->{lastRequest} = time();
#	print "URL: $url\n";
	return $self->{ua}->get($url);
}

sub retry {
	my $routine = shift;
	my $retries = shift;
	my $sleep = shift;
	my @params = @_;

	for ( my $i=1; $i<=$retries; $i++ ) {
		if ( &{$routine}(@params) ) {
			return 1;
		}
		print "Retry $i/$retries of $routine()\n";
		sleep $sleep;
	}
	return 0;
}

sub getNewLinks {
	my $self = shift;

	my $listString = $baseUrl . '?do=getlinks&uid=' . $self->{userId} . '&password=' . $self->{password};

	my $res = $self->waitGet($listString);

	die 'Count not get new links' unless $res->is_success;

	my ($sek,$min,$std,$mtag,$mon,$jahr,$wtag,$jtag,$isdst) = localtime(time);
	$jahr += 1900;
	$mon++;

	my $filename = sprintf("hltv_new_links_at_%04d_%02d_%02d_%02d_%02d_%02d.xml", $jahr, $mon, $mtag, $std, $min, $sek);

	open(CUR, "> $Configuration::logDir/$filename") or warn $!;
	print CUR $res->content;
	close(CUR);

	return new hltvLinkList($res->content);
}

sub ackList {
	my $self = shift;
	my $list = shift;

	my $ackString = $baseUrl . '?do=setstate&uid=' . $self->{userId} . '&list=' . $list->getListId() . '&state=processing';

	my $res = $self->waitGet($ackString);

	die 'Count not ack new links' unless $res->is_success;

	my ($sek,$min,$std,$mtag,$mon,$jahr,$wtag,$jtag,$isdst) = localtime(time);
	$jahr += 1900;
	$mon++;

	my $filename = sprintf("hltv_ack_list_at_%04d_%02d_%02d_%02d_%02d_%02d.xml", $jahr, $mon, $mtag, $std, $min, $sek);

	open(CUR, "> $Configuration::logDir/$filename") or warn $!;
	print CUR $res->content;
	close(CUR);

	return $res->content;
}

sub finishLink {
	my $self = shift;
	my $linkId = shift;
#	my $url = shift;

	my $finishString = $baseUrl . '?do=setstate&uid=' . $self->{userId} . '&id=' . $linkId . '&state=finished';

	my $res = $self->waitGet($finishString);

	die 'Count not finish link' unless $res->is_success;

	my ($sek,$min,$std,$mtag,$mon,$jahr,$wtag,$jtag,$isdst) = localtime(time);
	$jahr += 1900;
	$mon++;

	my $filename = sprintf("hltv_finish_list_at_%04d_%02d_%02d_%02d_%02d_%02d.xml", $jahr, $mon, $mtag, $std, $min, $sek);

	open(CUR, "> $Configuration::logDir/$filename") or warn $!;
	print CUR $res->content;
	close(CUR);

	return $res->content;

}

1;
