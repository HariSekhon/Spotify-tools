#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2015-11-05 23:29:15 +0000 (Thu, 05 Nov 2015)
#
#  https://github.com/harisekhon/tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help improve or steer this or other code I publish
#
#  https://www.linkedin.com/in/HariSekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$srcdir"

# shellcheck disable=SC1090
. "$srcdir/../bash-tools/lib/utils.sh"

section "Running Spotify All Tests"

./syntax.sh

while read -r script; do
    "./$script"
done < <(find . -name 'test*.sh')

./help.sh

cd "$srcdir/.."

bash-tools/check_all.sh
