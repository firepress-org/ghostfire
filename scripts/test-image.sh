#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: scripts/test-image.sh [--timing] [--help]

Start IMAGE with SQLite on a fresh volume, wait for HTTP 200 on the path of
GHOST_URL, then check that the page shows the default site text, and that
<path>ghost/ and <path>ghost/api/admin/site/ answer 200. On failure, print
the container logs and exit 1. The container and its volume are removed on
exit.

Environment:
  IMAGE      image to test (default ghostfire:local)
  GHOST_URL  url given to Ghost (default http://localhost:2368)
  TIMEOUT    seconds to wait for the first HTTP 200 (default 90)

Options:
  --timing   print the seconds from container start to the first HTTP 200
  --help     print this help and exit
EOF
}

timing=false
while (($#)); do
	case $1 in
	--timing) timing=true ;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		usage >&2
		exit 2
		;;
	esac
	shift
done

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

image=${IMAGE:-ghostfire:local}
url=${GHOST_URL:-http://localhost:2368}
parse_url "$url"
name=ghostfire-test-$$

cleanup() {
	podman rm -f "$name" >/dev/null 2>&1 || true
	podman volume rm -f "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "test: image $image, url $url"
podman volume create "$name" >/dev/null
start -v "$name:/var/lib/ghost/content" \
	-e url="$url" \
	-e NODE_ENV=production \
	-e database__client=sqlite3 \
	-e database__connection__filename=/var/lib/ghost/content/data/ghost.db \
	"$image"

home=$(wait_for_200 "$path" "${TIMEOUT:-90}")
if $timing; then print_timing; fi
echo "$path 200"
grep -q 'Thoughts, stories and ideas' <<<"$home" ||
	fail "$path lacks the text 'Thoughts, stories and ideas'"

check_admin "$path"
echo "test ok, Ghost $version"
