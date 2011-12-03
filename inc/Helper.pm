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

package Helper;

use Configuration;

sub startupScreen {
	my $screenName = shift;

	# Check if screen is running
	my @cmd = ($Configuration::baseDir . '/bin/isScreenRunning.sh', $screenName);
	system @cmd;
	if ( $? == 0 ) {
		return;
	}

	# Start screen with an instance of aria2 in daemon mode
	@cmd = ('screen', '-dmS', $screenName, '-c', "$Configuration::baseDir/etc/screenrc", 'aria2c', '--retry-wait=30', '-m', '0', '--enable-rpc', '-l', "$Configuration::logDir/aria2c.log", '-d', $Configuration::downloadDir, '--on-download-complete', "$Configuration::baseDir/bin/complete.pl", '-V', '-s', 1);
	system @cmd or die $!;
}

1;
