Spotify Tools [![Build Status](https://travis-ci.org/harisekhon/spotify.svg?branch=master)](https://travis-ci.org/harisekhon/spotify)
==============

Spotify Lookup - converts Spotify URIs to 'Artist - Track' form by querying the Spotify Metadata API. Works against lists of files or standard input as a unix filter program. Useful for keeping readable backups of your Spotify playlists.

Spotify Cmd - command line control of Spotify on Mac via AppleScript calls. Useful for automation that Mac HotKeys don't help with such as skipping tracks every N seconds if you want to flick through a playlist while working.

### Setup ###
This fetches my library submodule and a few cpan modules. Type:

```
git clone https://github.com/harisekhon/spotify
cd spotify
make
```

Alternatively to run the setup manually if you don't have GNU Make installed, it's quite simple


#### Manual Setup ####

Enter the directory and run git submodule init and git submodule update to fetch my library repo:

```
git clone https://github.com/harisekhon/spotify
cd spotify
git submodule init
git submodule update
```

Then you will also need to fetch the following CPAN modules:

LWP::Simple  
Text::Unidecode  
URI::Escape  
XML::Simple  

Running the cpan command followed by the list of modules (as root) will fetch them for you:

```
cpan LWP::Simple Text::Unidecode URI::Escape XML::Simple
```


### Spotify Lookup - Usage ###

You can copy and paste the tracks from Spotify directly into text files, which puts them in Spotify URI format such as 
```
http://open.spotify.com/track/61oGXsKgJOI0e3uS2wg1BV
http://open.spotify.com/track/1j6API7GnhE8MRRedK4bda
http://open.spotify.com/track/0RxFoUhB3mAI3qpgLSf7eM
```

Then convert this to readable Artist - Track form for saving independently of Spotify but running spotify-lookup.pl against the file

```
./spotify-lookup.pl Pendulum.txt
Pendulum - Watercolour
Pendulum - Witchcraft
Pendulum - The Island - Pt. I
...
```

You can also pipe the file through standard input or even feed one or more Spotify URIs as standard input in either format that Spotify uses

```
echo http://open.spotify.com/track/5TOYgNohZAFEPOtnchPhZS | ./spotify-lookup.pl 
Foo Fighters - Arlandria

echo spotify:track:5TOYgNohZAFEPOtnchPhZS | ./spotify-lookup.pl 
Foo Fighters - Arlandria
```

Use verbose mode to print the the URIs to STDERR, so you can send the tracks to a file while still seeing the progress in your terminal

```
./spotify-lookup.pl -v Pendulum_Spotify.txt > Pendulum_Tracks.txt
verbose mode on
verbose level: 1
files:         spotify/Pendulum
speed up:      x1
retries:       3

1/42 http://ws.spotify.com/lookup/1/?uri=spotify:track:61oGXsKgJOI0e3uS2wg1BV => 0.1262 secs
2/42 http://ws.spotify.com/lookup/1/?uri=spotify:track:1j6API7GnhE8MRRedK4bda => 0.0547 secs
3/42 http://ws.spotify.com/lookup/1/?uri=spotify:track:0RxFoUhB3mAI3qpgLSf7eM => 0.0566 secs
...
...
42/42 http://ws.spotify.com/lookup/1/?uri=spotify:track:6gTQubOSdry0ievEXvhzxd => 0.0457 secs

Summary:         42 tracks, 0 local tracks, 42 spotify tracks fetched in 8.6640 secs
Completion Date: Mon Dec 31 15:38:44 GMT 2012
```
The track names are then stored in Pendulum_Tracks.txt. On large playlists you'll want to see this progress. Also it looks cool when it's running :)

The mode I use the most is to translate a list of Spotify URI files I've dumped to another directory, keeping the file names the same and you get a nice total progress listing how many tracks of the current playlist file and how many overall are completed, followed by a total summary at the end.
```
spotify-lookup.pl -v -w music spotify/Pendulum spotify/Foo_Fighters
verbose mode on
verbose level: 1
files:         spotify/Pendulum spotify/Foo_Fighters
write dir:     /Users/hari/music
speed up:      x1
retries:       3

file: 'spotify/Pendulum'
write file: '/Users/hari/music/Pendulum'
1/42 1/53 spotify/Pendulum http://ws.spotify.com/lookup/1/?uri=spotify:track:61oGXsKgJOI0e3uS2wg1BV => 0.1511 secs
2/42 2/53 spotify/Pendulum http://ws.spotify.com/lookup/1/?uri=spotify:track:1j6API7GnhE8MRRedK4bda => 0.0520 secs
3/42 3/53 spotify/Pendulum http://ws.spotify.com/lookup/1/?uri=spotify:track:0RxFoUhB3mAI3qpgLSf7eM => 0.0507 secs
42/42 42/53 spotify/Pendulum http://ws.spotify.com/lookup/1/?uri=spotify:track:6gTQubOSdry0ievEXvhzxd => 0.1757 secs
Wrote: /Users/hari/music/Pendulum

file: 'spotify/Foo_Fighters'
write file: '/Users/hari/music/Foo_Fighters'
1/11 43/53 spotify/Foo_Fighters http://ws.spotify.com/lookup/1/?uri=spotify:track:042RaY48TNY9aesv8fqYTf => 0.0606 secs
2/11 44/53 spotify/Foo_Fighters http://ws.spotify.com/lookup/1/?uri=spotify:track:0mWiuXuLAJ3Brin3Or2x6v => 0.0787 secs
...
11/11 53/53 spotify/Foo_Fighters http://ws.spotify.com/lookup/1/?uri=spotify:track:7v0mtl6oInUtHOmTk2b0gC => 0.0594 secs
Wrote: /Users/hari/music/Foo_Fighters


Summary:         53 tracks, 0 local tracks, 53 spotify tracks fetched in 5.6081 secs   
Completion Date: Mon Dec 31 15:46:33 GMT 2012
```

For full list of options see --help

### Spotify Lookup --help ###

```
./spotify-lookup --help

Filter program to convert Spotify URIs to 'Artist - Track' form by querying the
Spotify Metadata API

usage: spotify-lookup.pl [ options ]

-f  --file          File name(s) containing the spotify URLs
-a  --album         Print Album name at end of track [Album:<name>]
    --territory     Give a 2 letter territory code to suffix tracks that aren't
                    available in that territory with '(Unavailable in GB)'.
                    I've found this to be unreliable information from Spotify,
                    not currently recommended
    --mark-local    Suffix local tracks with '(Local Track)'
-r  --retries       Number of retires (defaults to 5)
-w  --write-dir     Write to file of same name in directory path given as
                    argument (cannot be the same as the source directory)
-s  --speed-up      Speeds up by reducing default sleep between lookups (0.1
                    secs) by this factor, useful if you're beind a pool of DIPs
                    at work ;)
-n  --no-locking    Do not lock, allow more than 1 copy of this program to run
                    at a time. This could get you blocked by Spotify's rate
                    limiting on their metadata API. Use with caution, only if
                    you are behind a network setup that gives you multiple IP
                    addresses
    --sort          Sort the resulting file (only used with --write-dir)
    --wait          Wait to acquire spotify lock instead of exiting
-t  --timeout       Timeout in secs (default: 10000). There is also 30 second
                    timeout on each track translation request to the Spotify
                    API
-v  --verbose       Verbose mode (-v, -vv, -vvv ...)
-h  --help          Print description and usage options
-V  --version       Print version and exit
```

### Spotify Cmd --help ###

```
./spotify-cmd.pl --help

Command line interface to Spotify on Mac that leverages AppleScript

Useful for automation that Mac HotKeys don't help with, such as auto skipping
to next track every N secs to sample a playlist while working

usage: spotify-cmd.pl <command>

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

exit / quit     Exit Spotify

-q  --quiet      Quiet mode. Do not print track information or volume after
                 completing action
-t  --timeout    Timeout in secs (default: 10)
-v  --verbose    Verbose mode (-v, -vv, -vvv ...)
-h  --help       Print description and usage options
-V  --version    Print version and exit
```
