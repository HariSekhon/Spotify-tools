#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2015-05-25 01:38:24 +0100 (Mon, 25 May 2015)
#
#  https://github.com/harisekhon/spotify
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help improve or steer this or other code I publish
#
#  http://www.linkedin.com/in/harisekhon
#

set -eu
[ -n "${DEBUG:-}" ] && set -x
srcdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$srcdir/..";

. ./tests/utils.sh

hr
echo "Spotify Lookup API Tests"
echo

URI='http://open.spotify.com/track/1j6API7GnhE8MRRedK4bda'
EXPECTED="Pendulum - Witchcraft [Album:Immersion]"

echo "running spotify-lookup.pl against Spotify API"
result=$(perl -T $I_lib spotify-lookup.pl --album --territory GB --mark-local <<< "$URI")
if [ "$result" = "$EXPECTED" ]; then
    echo "SUCCESSFULLY resolved '$URI' => '$result'"
else
    echo "FAILED to resolve '$URI' => '$EXPECTED', got '$result' instead"
    exit 1
fi
echo
hr
echo
echo
