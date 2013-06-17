#!/usr/bin/perl -T
#
#  Author: Hari Sekhon
#  Date: 2013-06-16 23:42:48 +0100 (Sun, 16 Jun 2013)
#
#  http://github.com/harisekhon
#
#  License: see accompanying LICENSE file
#

$DESCRIPTION = "Command line interface to Spotify on Mac that leverages AppleScript

Useful for automation that you can't use your Mac HotKeys for";

$VERSION = "0.1";

use strict;
use warnings;
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/lib";
}
use HariSekhonUtils;

$usage_line = "$progname <cmd>

cmds:

play            Play
pause / stop    Pause
playpause       Toggle Play/Pause
next            Next
previous        Previous

status          Show current track details

vol up          Turn volume up
vol down        Turn volume down
vol <1-100>     Set volume to number <1-100>

start           Start Spotify
exit / quit     Exit Spotify";

get_options();

my $cmd = $ARGV[0] || usage;
my $arg = $ARGV[1] if $ARGV[1];

$cmd = lc $cmd;
$arg = lc $arg if $arg;

if($cmd eq "vol"){
    defined($arg) or usage;
}

mac_only();

$cmd = isAlNum($cmd) || usage "invalid cmd";
if(defined($arg)){
    $arg = isAlNum($arg) || usage "invalid arg";
}

my %cmds = (
    "play"      => "play",
    "pause"     => "pause",
    "stop"      => "pause",
    "playpause" => "playpause",
    "next"      => "next track",
    "prev"      => "previous track",
    "quit"      => "quit",
    "exit"      => "quit",
);

vlog2;
set_timeout();

my $osascript = which("osascript");
my $spotify_app = "Spotify";
my $cmdline = "$osascript -e 'tell applications \"$spotify_app\" to ";
my @output;

if($cmd eq "status"){
    my %state;
    $state{"status"} = `$cmdline player state as string'`  || die "failed to get Spotify status\n";
    $state{"artist"} = `$cmdline artist of current track as string'` || die "failed to get current artist\n";
    $state{"album"}  = `$cmdline album of current track as string'`  || die "failed to get current album\n";
    $state{"starred"}  = `$cmdline starred of current track as string'` || die "failed to get current starred status\n";
    $state{"track"}  = `$cmdline name of current track as string'`  || die "failed to get current track\n";
    foreach(qw/status starred artist album track/){
        $state{$_} = "Unknown (external track?)\n" unless $state{$_};
        printf "%-8s %s", ucfirst "$_:", $state{$_};
    }
} elsif($cmd eq "vol"){
    my $new_vol;
    if($arg eq "up" or $arg eq "down"){
        my $current_vol = `$cmdline sound volume as integer'`;
        $current_vol =~ /^(\d+)$/ || die "failed to determine current volume\n";
        $current_vol = $1;
        if($arg eq "up"){
            $new_vol = $current_vol + 10;
        } elsif($arg eq "down"){
            $new_vol = $current_vol - 10;
        }
    } elsif(isInt($arg)){
        ($arg < 0 or $arg > 100) and usage "volume must be between 0 and 100";
        $new_vol = $arg;
    } else {
        usage "vol arg must be one of up/down/<num>";
    }
    system($cmdline . "set sound volume to $new_vol'");
} else {
    if(grep $cmd, keys %cmds){
        $cmdline .= "$cmds{$cmd}'";
        system($cmdline);
    } else {
        usage "unknown command given";
    }
}
