#!/usr/bin/perl -T
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2013-06-16 23:42:48 +0100 (Sun, 16 Jun 2013)
#
#  https://github.com/harisekhon/spotify-tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback
#  to help improve or steer this or other code I publish
#
#  http://www.linkedin.com/in/harisekhon
#

$DESCRIPTION = "Command line interface to Spotify on Mac that leverages AppleScript

Useful for automation that Mac HotKeys don't help with, such as auto skipping
to next track every N secs to sample a playlist while working";

$VERSION = "0.2";

use strict;
use warnings;
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/lib";
}
use HariSekhonUtils qw/:DEFAULT :time/;

$usage_line = "usage: $progname <command>

commands:

play            Play
pause / stop    Pause
playpause       Toggle Play/Pause
previous        Previous Track and print previous track information
next [secs]     Next Track and print next track information.
                Specifying optional secs will skip to next track
                every [secs] seconds. Handy for skipping through a playlist
                every 60 secs automatically and grabbing the good songs. Prints
                track information every time it skips to the next track

status          Show current track details

vol up          Turn volume up
vol down        Turn volume down
vol <1-100>     Set volume to number <1-100>

exit / quit     Exit Spotify";

my $quiet;
%options = (
    "q|quiet"   => [ \$quiet, "Quiet mode. Do not print track information or volume after completing action" ],
);

get_options();

my $cmd = $ARGV[0] || usage;
my $arg = $ARGV[1] if $ARGV[1];

$cmd = lc $cmd;
$arg = lc $arg if $arg;

mac_only();

$cmd = isAlNum($cmd) || usage "invalid cmd";
if(defined($arg)){
    $arg = isAlNum($arg) || usage "invalid arg";
}

my %cmds = (
    "play"            => "play",
    "pause"           => "pause",
    "stop"            => "pause",
    "playpause"       => "playpause",
    "next"            => "next track",
    "prev"            => "previous track",
    "quit"            => "quit",
    "exit"            => "quit",
);

vlog2;
set_timeout();

my $osascript = which("osascript");
my $spotify_app = "Spotify";
my $cmdline = "$osascript -e 'tell applications \"$spotify_app\" to ";

my %state;
sub get_state(){
    # TODO: make this more efficient, return all at once if possible, check on this later
    $state{"status"}       = join("\n", cmd("$cmdline player state as string'")) || die "failed to get Spotify status (running/stopped/paused)\n";
    $state{"artist"}       = join("\n", cmd("$cmdline artist of current track as string'"));
    $state{"album"}        = join("\n", cmd("$cmdline album of current track as string'"));
    $state{"starred"}      = join("\n", cmd("$cmdline starred of current track as string'"));
    $state{"track"}        = join("\n", cmd("$cmdline name of current track as string'"));
    $state{"duration"}     = join("\n", cmd("$cmdline duration of current track as string'"));
    $state{"position"}     = join("\n", cmd("$cmdline player position as string'"));
    $state{"popularity"}   = join("\n", cmd("$cmdline popularity of current track as string'"));
    $state{"played count"} = join("\n", cmd("$cmdline played count of current track as string'"));
    $state{"duration"} = sec2min($state{"duration"}) if $state{"duration"};
    $state{"position"} = sec2min($state{"position"}) if $state{"position"};
}


sub print_state(){
    get_state();
    foreach((qw/status starred artist album track duration position popularity/, "played count")){
        $state{$_} = "Unknown (external track?)" unless defined($state{$_});
        printf "%-14s %s\n", ucfirst("$_:"), $state{$_};
    }
}

sub get_vol(){
    my $current_vol = `$cmdline sound volume as integer'`;
    $current_vol =~ /^(\d+)$/ || die "failed to determine current volume\n";
    return $1;
}

if($cmd eq "status"){
    print_state();
} elsif($cmd eq "vol"){
    my $new_vol;
    if(defined($arg)){
        if($arg eq "up" or $arg eq "down"){
            my $current_vol = get_vol();
            vlog "Old Volume: $current_vol" unless $quiet;
            if($arg eq "up"){
                $new_vol = $current_vol + 10;
            } elsif($arg eq "down"){
                $new_vol = $current_vol - 10;
            }
        } elsif(isInt($arg)){
            $new_vol = $arg;
        } else {
            usage "vol arg must be an integer";
        }
    } else {
        print "Volume: " . get_vol() . "%\n";
        exit 0;
    }
    $new_vol = 0 if $new_vol < 0;
    $new_vol = 100 if $new_vol > 100;
    print cmd($cmdline . "set sound volume to $new_vol'");
    print "Volume: " . get_vol() . "%\n" unless $quiet;
} else {
    if(grep $cmd, keys %cmds){
        my $cmdline2 = "$cmdline $cmds{$cmd}'";
        if($cmd eq "next" and $arg){
            isInt($arg) or usage "arg to next must be an integer representing seconds before skipping to the next track";
            while(1){
                # reset timeout so we can stay in infinite loop and iterate over playlist
                alarm 0;
                sleep $arg;
                print "\n";
                set_timeout();
                print cmd($cmdline2);
                print_state() unless $quiet;
            }
        } elsif($cmd eq "prev" or
                $cmd eq "next"){
            print cmd($cmdline2);
            print_state() unless $quiet;
        } else {
            print cmd($cmdline2);
        }
    } else {
        usage "unknown command given";
    }
}
