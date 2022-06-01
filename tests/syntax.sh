#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2015-05-25 01:38:24 +0100 (Mon, 25 May 2015)
#
#  https://github.com/harisekhon/tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help improve or steer this or other code I publish
#
#  https://www.linkedin.com/in/HariSekhon
#

set -eu
[ -n "${DEBUG:-}" ] && set -x
srcdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "================================================================================"
echo "                              Syntax Checks"
echo "================================================================================"

cd "$srcdir/..";

. ./tests/utils.sh

for x in *.pl */*.pl; do
    isExcluded "$x" && continue
    #printf "%-50s" "$x:"
    #$perl -TWc $I_lib ./$x
    $perl -Tc $I_lib ./$x
done
echo "================================================================================"
echo "                  All Perl programs passed syntax check"
echo "================================================================================"
echo
echo
