#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2020-11-17 11:34:22 +0000 (Tue, 17 Nov 2020)
#
#  https://github.com/HariSekhon/Spotify-tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help steer this or other code I publish
#
#  https://www.linkedin.com/in/HariSekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash_tools="$srcdir/bash-tools"

# shellcheck disable=SC1090
. "$bash_tools/lib/utils.sh"

default_sleep_secs=3
default_track_positions="30 60 90 120 150"

# shellcheck disable=SC2034,SC2154
usage_description="
Uses Shpotify to skim through current Spotify playlist

spotify is assumed to be in \$PATH

Useful for quickly going through Discover Backlog

Optional arguments:

- seconds before skipping to next interval - how long to listen before skipping to the next position (default: $default_sleep_secs seconds)
- intervals - comma or space separated list of positions in tracks to skip to (default: $default_track_positions. For example 30 60 90 120 150 means track positions 0:30 1;00 1:30 2:00 2:30)

Examples:

Default:

    ${0##*/}

    ${0##*/} $default_sleep_secs $default_track_positions

Faster more aggressive skipping - listen for only 2 secs at the 1 and 2 minutes marks of each track (60 and 120 seconds track positions):

    ${0##*/} 2 60 120
"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args="[<seconds>] [<intervals>]"

help_usage "$@"

sleep_secs="${1:-3}"
shift || :

if ! is_int "$sleep_secs"; then
    usage "interval must be an integer"
fi

if [ $# -gt 0 ]; then
    track_positions=("$@")
    for track_position in "${track_positions[@]}"; do
        if ! is_int "$track_position"; then
            usage "Invalid track position given, must be an integer of seconds: $track_position"
        fi
    done
else
    read -r -a track_positions <<< "$default_track_positions"
fi

spotify play

# SpotifyControl
#spotify info
# Shpotify
spotify status

is_paused(){
    # spotify command sends a pipefail failure which causes the ! is_paused conditional to fail and runs the next track which unpauses
    { spotify status || : ; } | grep -Fq 'Spotify is currently paused'
}

while true; do
    if is_paused; then
        timestamp "Spotify is paused, waiting"
        sleep 30
        continue
    fi
    for track_position in "${track_positions[@]}"; do
        # osascript from install_spotifycontrol.sh
        # this doesn't work and actually jumps to this position N, not current+N
        #spotify forward 30
        #spotify jump "$track_position"
        # Shpotify
        spotify pos "$track_position"
        sleep "$sleep_secs"
    done
    # next ends up unpausing Spotify so don't call it if paused
    if ! is_paused; then
        # background it because otherwise there is a 1 second delay where the next track plays the start before skipping to the first position
        # due to the time it takes to run the next is_paused check
        {
            echo
            spotify next
            echo
        } &
    fi
done
