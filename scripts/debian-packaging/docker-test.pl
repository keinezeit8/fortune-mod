#! /usr/bin/env perl
#
# Short description for docker-test.pl
#
# Author Shlomi Fish <shlomif@cpan.org>
# Version 0.0.1
# Copyright (C) 2019 Shlomi Fish <shlomif@cpan.org>
#
use strict;
use warnings;
use 5.014;
use autodie;

use Path::Tiny qw/ path tempdir tempfile cwd /;
use Docker::CLI::Wrapper::Container ();

my $obj = Docker::CLI::Wrapper::Container->new( { sys => "debian:sid", } );

my @deps;    #= map { /^BuildRequires:\s*(\S+)/ ? ("'$1'") : () }

# path("freecell-solver.spec.in")->lines_utf8;
my $CONTAINER = "fortune-mod--deb--test-build";
my $USER      = "mygbp";
my $HOMEDIR   = "/home/$USER";

sub _clean_up_containers
{
    eval { $obj->docker( { cmd => [ 'stop', $CONTAINER, ] } ); };

    eval { $obj->docker( { cmd => [ 'rm', $CONTAINER, ] } ); };
}
_clean_up_containers();
$obj->docker( { cmd => [ 'pull', $obj->sys() ] } );
$obj->docker(
    { cmd => [ 'run', "-t", "-d", "--name", $CONTAINER, $obj->sys(), ] } );
my $REPO = 'fortune-mod';
my $URL  = "https://salsa.debian.org/shlomif-guest/$REPO";

if ( !-e $REPO )
{
    $obj->do_system( { cmd => [ "git", "clone", $URL, ] } );
}
my $cwd = cwd;
chdir "./$REPO";
$obj->do_system( { cmd => [ "git", "pull", "--ff-only", ] } );
chdir $cwd;

my $LOG_FN = "git-buildpackage-log.txt";

my $BASH_SAFETY = "set -e -x ; set -o pipefail ; ";

# $obj->docker( { cmd => [  'cp', "../scripts", "fcsfed:scripts", ] } );
my $script = <<"EOSCRIPTTTTTTT";
$BASH_SAFETY
apt-get -y update
apt-get -y install eatmydata sudo
sudo eatmydata apt -y install build-essential chrpath cmake git-buildpackage librecode-dev perl recode
sudo adduser --disabled-password --gecos '' "$USER"
sudo usermod -a -G sudo "$USER"
echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
EOSCRIPTTTTTTT

$obj->docker( { cmd => [ 'exec', $CONTAINER, 'bash', '-c', $script, ] } );

$obj->docker( { cmd => [ 'cp', "./$REPO", "$CONTAINER:$HOMEDIR/$REPO", ] } );
$obj->docker(
    {
        cmd => [
            'exec', $CONTAINER, 'bash', '-c',
            "$BASH_SAFETY chown -R $USER:$USER $HOMEDIR",
        ]
    }
);

$script = <<"EOSCRIPTTTTTTT";
$BASH_SAFETY
cd "$HOMEDIR/$REPO"
git clean -dxf .
gbp buildpackage 2>&1 | tee ~/"$LOG_FN"
EOSCRIPTTTTTTT

$obj->docker(
    {
        cmd => [ 'exec', '--user', $USER, $CONTAINER, 'bash', '-c', $script, ]
    }
);
$obj->docker( { cmd => [ 'cp', "$CONTAINER:$HOMEDIR/$LOG_FN", $LOG_FN, ] } );

_clean_up_containers();

__END__

=head1 COPYRIGHT & LICENSE

Copyright 2019 by Shlomi Fish

This program is distributed under the MIT / Expat License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

=cut