#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2020-11-17 11:34:22 +0000 (Tue, 17 Nov 2020)
#
#  https://github.com/HariSekhon/spotify-tools
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

# shellcheck disable=SC2034,SC2154
usage_description="
Uses Shpotify to skim through current Spotify playlist

spotify is assumed to be in \$PATH

Useful for quickly going through Discover Backlog

Optional argument: seconds interval - how long to listen before skipping to the next 30 second boundary in the track (default: 3 seconds)
"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args="[<seconds_interval>]"

interval="${1:-3}"

if ! is_int "$interval"; then
    usage "interval must be an integer"
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
    for track_position in 30 60 90 120 150; do
        # osascript from install_spotifycontrol.sh
        # this doesn't work and actually jumps to this position N, not current+N
        #spotify forward 30
        #spotify jump "$track_position"
        # Shpotify
        spotify pos "$track_position"
        sleep "$interval"
    done
    if ! is_paused; then
        # this ends up unpausing Spotify so don't call it if paused
        spotify next
        echo
    fi
done
