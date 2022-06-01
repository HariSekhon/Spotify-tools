#!/usr/bin/perl -T
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2012-04-06 21:01:42 +0100 (Fri, 06 Apr 2012)
#
#  https://github.com/HariSekhon/Spotify-tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback
#  to help improve or steer this or other code I publish
#
#  https://www.linkedin.com/in/HariSekhon
#

# Spotify changed early 2016 so this program has been superceded by a whole suite of Spotify tools in this
# and the DevOps Bash tools repo (a submodule of this repo as bash-tools as the top level)

$DESCRIPTION = "Filter program to convert Spotify URIs to 'Artist - Track' form by querying the Spotify Metadata API";

$VERSION = "0.10.0";

use strict;
use warnings;
use utf8;
use Cwd "abs_path";
use File::Basename;
use LWP::Simple qw/get $ua/;
use Text::Unidecode; # For changing unicode to ascii
use Time::HiRes qw/time sleep/;
use URI::Escape;
# yay Spotify changed from horrible XML to JSON API
use JSON;
#use XML::Simple qw(:strict);
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/lib";
}
use HariSekhonUtils;

autoflush();

$ua->agent("Hari Sekhon $progname version $main::VERSION");
$ua->timeout(30);

set_timeout_max(86400);
set_timeout_default(10000);
my $album = 0;
my $default_retries = 5;
my $no_locking;
my $file;
my $write_dir;
my $retries = $default_retries;
my $speed_up = 1;
my $sort = 0;
my $wait = 0;
my $territory = "";
my $local_track = 0;

%options = (
    "f|file=s"      => [ \$file,      "File name(s) containing the spotify URLs" ],
    "a|album"       => [ \$album,     "Print Album name at end of track [Album:<name>]" ],
    "territory=s"   => [ \$territory, "Give a 2 letter territory code to suffix tracks that aren't available in that territory with '(Unavailable in GB)'. I've found this to be unreliable information from Spotify, not currently recommended" ],
    "mark-local"    => [ \$local_track, "Suffix local tracks with '(Local Track)'" ],
    "r|retries=i"   => [ \$retries,   "Number of retires (defaults to $default_retries)" ],
    "w|write-dir=s" => [ \$write_dir, "Write to file of same name in directory path given as argument (cannot be the same as the source directory)" ],
    "s|speed-up=i"  => [ \$speed_up,  "Speeds up by reducing default sleep between lookups (0.1 secs) by this factor, useful if you're beind a pool of DIPs at work ;)" ],
    "n|no-locking"  => [ \$no_locking, "Do not lock, allow more than 1 copy of this program to run at a time. This could get you blocked by Spotify's rate limiting on their metadata API. Use with caution, only if you are behind a network setup that gives you multiple IP addresses" ],
    #"timeout-per-request=i" => [ \$timeout_per_request, "Timeout per request to the spotify API" ],
    "sort"          => [ \$sort,      "Sort the resulting file (only used with --write-dir)" ],
    "wait"          => [ \$wait,      "Wait to acquire spotify lock instead of exiting" ],
);
@usage_order = qw/file album territory mark-local retries write-dir speed-up no-locking sort wait/;

#$HariSekhonUtils::default_options{"t|timeout=i"} = [ \$timeout, "Unutilized. There is 30 second timeout on each track translation request to the Spotify API" ];
$HariSekhonUtils::default_options{"t|timeout=i"} = [ \$timeout, $HariSekhonUtils::default_options{"t|timeout=i"}[1] . ". There is also 30 second timeout on each track translation request to the Spotify API" ];

get_options();

if($territory){
    $territory =~ /^[A-Za-z]{2}$/ or usage "territory must be a two letter country code";
    $territory = uc $territory;
}

go_flock_yourself(undef, $wait) unless $no_locking;

set_timeout();

$speed_up = 1 unless $speed_up;

my @files;
if($file){
    if($file =~ /,/){
        @files = split(/\s*,\s*/, $file);
    } else {
        $files[0] = $file;
    }
}
foreach(@ARGV){
    push(@files, $_);
}
foreach(@files){
    ( $_ and not -f $_ ) and die "Error: couldn't find file '$_'\n";
}
( $retries >= 1 and $retries <= 100 ) or usage "Must specify retries between 1 and 100\n";
if($write_dir){
    $write_dir = abs_path($write_dir);
    if(@files){
        foreach my $file (@files){
            if(abs_path(dirname($file)) eq $write_dir){
                die "Error: cannot specify write dir as '$write_dir' as this is the same directory containing source file '$file'. This would result in overwriting your own file!\n";
            }
        }
    }
    ( -d $write_dir ) or die "Error: '$write_dir' is not a directory\n";
    ( -w $write_dir ) or die "Error: '$write_dir' is not writable\n";
    $write_dir =~ /^([\w_\/\.-]+)$/ or die "Write dir did not match expected regex\n";
    $write_dir = $1;
}

vlog "verbose mode on" if $verbose == 1;
vlog "verbose level: $verbose";
vlog "files:         @files" if @files;
vlog "write dir:     $write_dir" if $write_dir;
vlog "speed up:      x$speed_up" if($speed_up != 0);
vlog "retries:       $retries\n";

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

sub spotify_lookup($;$$);

sub get_writefile_name {
    my $file = shift;
    my $filename = basename $file;
    $filename =~ /^([\w_\!\$\&\+-]+)$/ or die "file '$file' basename did not match expected regex\n";
    $filename = $1;
    return $write_dir . "/" . $filename;
}

my $write_fh;
if(@files){
    foreach my $file (@files){
        $file or next;
        open(my $fh, $file) or die "Failed to open file '$file': $!\n";
        while(<$fh>){
            $grand_total_tracks++;
        }
        close $fh;
        my $write_file;
        if($write_dir){
            $write_file = get_writefile_name $file;
            open($write_fh, ">>", $write_file) or die "Failed to open write file '$write_file': $!\n";
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
            open($write_fh, ">", $write_file) or die "Failed to open write file '$write_file': $!\n";
            select($write_fh);
            $| = 1;
        }
        open(my $fh, $file) or die "Failed to open file '$file': $!\n";
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
            print STDERR "$file " if ($verbose and scalar @files > 1);
            spotify_lookup($_)
        }
        select(STDOUT);
        # TODO: add file sort algorithm here to allow dump_playlists to not have to do this
        close $fh;
        close $write_fh if $write_fh;
        print STDERR "Wrote: $write_file\n\n" if ($write_file and scalar @files > 1);
    }
# Originally used to take a URI on the cli but decided to make it work like a unix filter program such that an arg is a file and stdin is for passing things in like this
#} elsif (scalar(@ARGV) > 0) {
#    $line_total = scalar @ARGV;
#    foreach(@ARGV){
#        print STDERR $total_tracks + 1 . "/" . scalar @ARGV . " " if $verbose;
#        spotify_lookup($_)
#    }
} else {
    #print STDERR "reading from standard input\n";
    while(<STDIN>){
        print STDERR $total_tracks + 1 . " " if $verbose;
        print STDERR "- " if $verbose;
        spotify_lookup($_)
    }
}

sub spotify_lookup($;$$) {
    my $uri   = $_[0];
    my $count = ($_[1] or 1);
    my $retry = ($_[2] or 0);
    my $track;
    my $album_name;
    chomp $uri;
    $uri =~ s/#.*//;
    $uri = trim($uri);
    return (0,0) unless $uri;
    $total_tracks++ unless $retry;
    if($uri =~ /([\/:])track\1(.+)$/){
        $track = "spotify:track:$2";
        $spotify_tracks++ unless $retry;
    } elsif($uri =~ /([\/:])local\1(.*)\1(.*)\1(.*)\1\d+$/) {
        $track = $4;
        $track = "$2 - $4" if $2;
        $album_name = $3 || "";
        $local_tracks++;
        $track = uri_unescape($track);
        $track =~ s/\+/ /g;
        print STDERR "*local track, skipping lookup ($track)\n" if $verbose;
        if($album){
            $track .= " [Album:" . uri_unescape($album_name) . "]";
        }
        if($local_track){
            $track .= ' (Local Track)';
        }
        print unidecode("$track\n");
        return 1;
    } else {
        die "Invalid URI given: $uri\n";
    }
    # API changed early 2016
    #my $url = "http://ws.spotify.com/lookup/1/?uri=$track";
    $track =~ s/^spotify:track://;
    my $url = "https://api.spotify.com/v1/tracks/$track";
    print STDERR "$url => " if $verbose;
    my $req = HTTP::Request->new("GET", $url);
    my $start = time;
    my $response = $ua->request($req);
    my $stop  = time;
    my $result = $response->code;
    my $content = $response->content;
    vlog3("\nreturned HTML:\n\n" . ( $content ? $content : "<blank>" ) . "\n");
    vlog2("http status code:     " . $response->code);
    vlog2("http status message:  " . $response->message . "\n");
    my $time_taken = sprintf("%.4f", $stop - $start);
    my $actual_sleep = $sleep - $time_taken;
    $actual_sleep = 0 if $actual_sleep < 0;
    #print STDERR "$time_taken secs [sleep $actual_sleep secs]\n" if $verbose;
    print STDERR "$time_taken secs\n" if $verbose;
    unless($response->code eq "200"){
        $count++;
        if($count > $retries){
            my $msg = "";
            if($json = isJson($content)){
                $msg = get_field2($json, "error.message", 1);
            }
            die "Failed $retries times to GET $url" . ( $msg ? ": $msg" : "" ) . "\n";
        }
        sleep 1;
        print STDERR "R " if $verbose;
        ($result, $content) = spotify_lookup($uri, $count, 1);
    }
    $content or die "content is empty from look up $url\n";
    # See http://www.perlmonks.org/?node_id=218480 for an explanation on key folding, but cos I only get 1 track I don't need this
    #my $data = XMLin($content, forcearray => 1, keyattr => [] ); #{ track => "id" });
    $json = isJson($content) or die "invalid json returned by Spotify API";
    #print Dumper($data);
    #print unidecode($data->{artist}[0]{name}[0] . " - " . $data->{name}[0] . "\n");
    my $artists = "";
    foreach(get_field_array("artists")){
        $artists .= get_field2($_, "name") . ","
    }
    $artists =~ s/,$//;
    unless($retry){
        my $track = "$artists - " . get_field("name");
        if($album){
            $track .= " [Album:" . get_field("album.name") . "]";
        }
        #my $available = get_field("available", 1);
        #if(defined($available) and $available =~ /^true$/i){
        #    $track .= " (Unavailable)";
        #} elsif($territory){
        if($territory){
            my @available_markets = get_field_array("available_markets");
            if(@available_markets){
                unless(grep { $_ eq $territory } @available_markets){
                    $track .= " (Unavailable in $territory)";
                }
            } else {
                print STDERR "WARNING: territories not found for $track\n";
            }
        }
        print unidecode("$track\n");
    }
    vlog3("fetched in $time_taken secs");
    if($actual_sleep > 0){
        vlog3("sleeping for $actual_sleep secs");
        sleep $actual_sleep;
    }
    vlog3;
    return ($result, $content);
}

my $total_stop = time;
my $total_time = sprintf("%.4f", $total_stop - $total_start);
($total_tracks eq $spotify_tracks + $local_tracks) or warn "Total Tracks does not match Spotify Tracks + Local Tracks!";
if($verbose){
    print STDERR "\nSummary:         $total_tracks tracks, $local_tracks local tracks, $spotify_tracks spotify tracks fetched in $total_time secs\n";
    print STDERR "Completion Date: " . `date`;
}
