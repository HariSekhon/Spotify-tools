#!/usr/bin/perl -T
#  vim:ts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2012-04-06 21:01:42 +0100 (Fri, 06 Apr 2012)
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

# Copied from private repo for posterity

$VERSION = "0.7";

use strict;
use warnings;
use FindBin;
use utf8;
use Cwd "abs_path";
use Data::Dumper;
#use File::Basename;
#use Getopt::Long qw(:config bundling);
use LWP::Simple qw($ua get);
use Text::Unidecode; # For changing unicode to ascii
use Time::HiRes qw/time sleep/;
use URI::Escape;
use XML::Simple qw(:strict);
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/lib";
}
use HariSekhonUtils;

go_flock_yourself(1);

# Make %ENV safer (taken from PerlSec)
delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
$ENV{'PATH'} = '/bin:/usr/bin';

select(STDERR);
$| = 1;
select(STDOUT);
$| = 1;

$ua->timeout(30);

my $default_retries = 3;
my $default_separator = " - ";
my $file;
my $write_dir;
my $retries = $default_retries;
my $speed_up = 1;
my $separator;

%options = (
    "f|file=s"      => [ \$file, "File name containing the spotify URLs" ],
    "r|retries=i"   => [ \$retries, "Number of retires (defaults to $default_retries)" ],
    "w|write-dir=s" => [ \$write_dir, "Write to file of same name in path given as argument" ],
    "s|speed-up=i"  => [ \$speed_up, "Speeds up by reducing default sleep between lookups (0.1 secs) by this factor, recommend to speed up by the number of DIPs you're behind ;)" ],
    "separator=s"   => [ \$separator, "Artist - Track separator (defaults to '$default_separator')" ],
);

get_options();
$speed_up = 1 unless $speed_up;

my @files;
if($file){
    if($file =~ /,/){
        @files = split(/\s*,\s*/, $file);
    } else {
        $files[0] = $file;
    }
}
foreach(@files){
    ( $_ and not -f $_ ) and die "Error: couldn't find file '$_'\n";
}
( $retries >= 1 and $retries <= 20 ) or usage "Must specify retries between 1 and 20\n";
if($write_dir){
    $write_dir = abs_path($write_dir);
    ( -d $write_dir ) or die "Error: '$write_dir' is not a directory\n";
    ( -w $write_dir ) or die "Error: '$write_dir' is not writable\n";
    $write_dir = validate_dir($write_dir);
    $write_dir .= "/" unless $write_dir =~ /\/$/;
}

#vlog("verbose mode on");
vlog("files:        @files") if @files;
vlog("write dir:    $write_dir") if $write_dir;
vlog("speed up:     x$speed_up") if($speed_up != 0);
vlog("retries:      $retries\n");

# Example uri
#my $uri = "spotify:track:6fzDcpb550hoKmDdMlrWkH";
#my $url = "http://ws.spotify.com/lookup/1/?uri=$uri";

# Spotify says it only allows 10 requests a sec, in reality it allows more but I don't wanna get banned
# Let's see how long I get away with this for
#my $sleep          = "0.05"; # secs
# Now we find out how long we took and sleep for enough time to make this up
# so this is now the MAX sleep time
my $sleep          = 0.1 / $speed_up; # secs
my $total_start    = time;
my %stats;
my $local_tracks   = 0;
my $spotify_tracks = 0;
my $total_tracks   = 0;
my $grand_total_tracks = 0;

my $line_total = 0;

sub get_writefile_name {
    my $file = shift;
    my $filename = basename $file;
    $filename =~ /^([\w_\!\$\&\+-]+)$/ or die "file '$file' basename did not match expected regex";
    $filename = $1;
    return $write_dir . $filename;
}

my $write_fh;
if($file){
    foreach my $file (@files){
        $file or next;
        open(my $fh, $file) or die "Failed to open file '$file': $!";
        while(<$fh>){
            $grand_total_tracks++;
        }
        close $fh;
        my $write_file;
        if($write_dir){
            $write_file = get_writefile_name $file;
            open($write_fh, ">>", $write_file) or die "Failed to open write file '$write_file': $!";
            close $write_fh;
        }
    }
    foreach my $file (@files){
        $file or next;
        my $file_tracks  = 0;
        $line_total      = 0;
        my $write_file;
        if($write_dir){
            $write_file = get_writefile_name $file;
            open($write_fh, ">", $write_file) or die "Failed to open write file '$write_file': $!";
            select($write_fh);
            $| = 1;
        }
        open(my $fh, $file) or die "Failed to open file '$file': $!";
        print STDERR "file: '$file'\n" if scalar @files > 1;
        print STDERR "write file: '$write_file'\n" if ($write_file and scalar @files > 1);
        while(<$fh>){
            $line_total++;
        }
        seek $fh, 0, 0;
        while(<$fh>){
            $file_tracks++;
            print STDERR "$file_tracks/$line_total " if $verbose;
            print STDERR ($total_tracks + 1) . "/$grand_total_tracks " if ($verbose and scalar @files > 1);
            spotify_lookup($_)
        }
        select(STDOUT);
        close $fh;
        close $write_fh if $write_fh;
        print STDERR "Wrote: $write_file\n\n" if ($write_file and scalar @files > 1);
    }
} elsif (scalar(@ARGV) > 0) {
    $line_total = scalar @ARGV;
    foreach(@ARGV){
        print STDERR $total_tracks + 1 . "/" . scalar @ARGV . " " if $verbose;
        spotify_lookup($_)
    }
} else {
    while(<STDIN>){
        print STDERR $total_tracks + 1 . " " if $verbose;
        spotify_lookup($_)
    }
}

sub spotify_lookup {
    my $uri = $_[0];
    my $count = ($_[1] or 1);
    my $track;
    chomp $uri;
    $total_tracks++;
    if($uri =~ /[\/:]track[\/:](.+)$/){
        $track = "spotify:track:$1";
        $spotify_tracks++;
    } elsif($uri =~ /\/local\/(.*)\/.*\/(.*)\/\d+$/) {
        $track = $2;
        $track = "$1 - $2" if $1;
        $local_tracks++;
        $track = uri_unescape($track);
        $track =~ s/\+/ /g;
        print STDERR "local track, skipping lookup ($track)\n" if $verbose;
        #if($write_fh){
        #    print $write_fh unidecode("$track\n");
        #} else {
            print unidecode("$track\n");
        #}
        return 1;
    } else {
        die "Invalid URI given: $uri\n";
    }
    my $url = "http://ws.spotify.com/lookup/1/?uri=$track";
    print STDERR "GET $url => " if $verbose;
    my $start = time;
    my $content = get $url;
    my ($result, $msg) = ($?, $!);
    my $stop  = time;
    my $time_taken = sprintf("%.4f", $stop - $start);
    my $actual_sleep = $sleep - $time_taken;
    $actual_sleep = 0 if $actual_sleep < 0;
    #print STDERR "$time_taken secs [sleep $actual_sleep secs]\n" if $verbose;
    print STDERR "$time_taken secs\n" if $verbose;
    vlog3("result:  '$result'");
    vlog3("content: '$content'") if $content;
    #vlog3("msg: '$msg'");
    if ($result ne 0 or not $content) {
        $count++;
        if ($count > $retries){
            die "Failed $retries times to GET $url: $msg";
        }
        sleep 1;
        print STDERR "R " if $verbose;
        ($result, $content) = spotify_lookup($uri, $count);
    }
    $content or die "content is empty from look up $url\n";
    # See http://www.perlmonks.org/?node_id=218480 for an explanation on key folding, but cos I only get 1 track I don't need this
    my $data = XMLin($content, forcearray => 1, keyattr => [] ); #{ track => "id" });
    #print Dumper($data);
    #print unidecode($data->{artist}[0]{name}[0] . " - " . $data->{name}[0] . "\n");
    my $artists = "";
    foreach(@{$data->{artist}}){
        $artists .= "${$_}{name}[0],"
    }
    $artists =~ s/,$//;
    #if($write_fh){
        #print $write_fh unidecode("$artists - " . $data->{name}[0] . "\n");
    #} else {
        print unidecode("$artists - " . $data->{name}[0] . "\n");
    #}
    vlog2("fetched in $time_taken secs");
    if($actual_sleep > 0){
        vlog2("sleeping for $actual_sleep secs");
        sleep $actual_sleep;
    }
    vlog2;
    return ($result, $content);
}

my $total_stop = time;
my $total_time = sprintf("%.4f", $total_stop - $total_start);
($total_tracks eq $spotify_tracks + $local_tracks) or warn "Total Tracks does not match Spotify Tracks + Local Tracks!";
if($verbose){
    print STDERR "\nSummary:         $total_tracks tracks, $local_tracks local tracks, $spotify_tracks spotify tracks fetched in $total_time secs\n";
    print STDERR "Completion Date: " . `date`;
}
