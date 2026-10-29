#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: scripts/lane.sh [--timing] [--hold SECONDS] [--help] <name>

Run IMAGE on a scratch copy of a real site, the way the hosting stack runs
it: user 1000:1000, 300 MB of memory, and the site's config.production.json
and /etc/localtime mounted read-only. Wait for HTTP 200 on the path of the
config's url, check <path>ghost/ and the admin site API, print the site
version, then print the container logs. The container and the scratch copy
are removed on exit, so the lane data is never changed.

The container joins the Podman network ghostfire-lane, created on first use.
That network has no route out, so the copy cannot call Stripe, Mailgun, or
its own live url, and the published port still answers.

Environment:
  IMAGE      image to run (default ghostfire:local)
  LANES_DIR  lane data, one <name>/ holding content/ and
             config.production.json (default ~/.cache/ghostfire-lanes)
  TIMEOUT    seconds to wait for the first HTTP 200 (default 180)

Options:
  --timing        print the seconds from container start to the first HTTP 200
  --hold SECONDS  keep the site running that long after the checks
  --help          print this help and exit
EOF
}

timing=false
hold=0
lane=
while (($#)); do
	case $1 in
	--timing) timing=true ;;
	--hold)
		hold=${2:?--hold needs SECONDS}
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	-*)
		usage >&2
		exit 2
		;;
	*) lane=$1 ;;
	esac
	shift
done
[[ -n $lane ]] || {
	usage >&2
	exit 2
}

# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

image=${IMAGE:-ghostfire:local}
src=${LANES_DIR:-$HOME/.cache/ghostfire-lanes}/$lane
config=$src/config.production.json
[[ -d $src/content && -f $config ]] || {
	echo "lane: $src needs content/ and config.production.json" >&2
	exit 2
}

# A lane must never reach a real database: only SQLite, on the scratch copy.
# Ghost's production default is MySQL, so the config must say sqlite3.
client=$(jq -r '.database.client // "none"' "$config")
[[ $client == sqlite3 ]] || {
	echo "lane: $config sets the database client $client; a lane needs sqlite3" >&2
	exit 2
}
url=$(jq -er .url "$config")
proto=${url%%://*}
rest=${url#*://}
host=${rest%%/*}
path=/
[[ $rest == */* ]] && path=/${rest#*/}
path=${path%/}/
name=ghostfire-lane-$lane-$$
work=$(mktemp -d "${TMPDIR:-/tmp}/ghostfire-lane.XXXXXX")

cleanup() {
	podman rm -f "$name" >/dev/null 2>&1 || true
	rm -rf -- "$work"
}
trap cleanup EXIT

# A copy of a real site keeps its keys, such as Stripe and Mailgun, and its live
# url, so a lane must not reach the outside. Without a default route, every
# outbound connection fails at once with ENETUNREACH. DNS stays on, so a lookup
# does not wait for a timeout. The last check covers a parallel lane that
# created the network first.
net=ghostfire-lane
podman network exists "$net" ||
	podman network create -o no_default_route=true "$net" >/dev/null ||
	podman network exists "$net"
[[ $(podman network inspect -f '{{index .Options "no_default_route"}}' "$net") == true ]] || {
	echo "lane: the Podman network $net has a default route; remove it and run again" >&2
	exit 2
}

echo "lane: $lane, image $image, url $url, container $name"
# Copy the contents, not the directory, so a symlinked content root cannot
# send writes back to the lane data.
mkdir "$work/content"
cp -a "$src/content/." "$work/content/"
# keep-id:uid=1000 maps the host user to UID 1000, so the container can write
# the copy whatever the host UID is.
# Ghost logs at info so the migrations show; the site config sets the rest.
start --network "$net" --userns keep-id:uid=1000,gid=1000 --user 1000:1000 --memory 300m \
	-v "$work/content:/var/lib/ghost/content" \
	-v "$config:/var/lib/ghost/config.production.json:ro" \
	-v /etc/localtime:/etc/localtime:ro \
	-e url="$url" \
	-e NODE_ENV=production \
	-e logging__level=info \
	"$image"

wait_for_200 "$path" "${TIMEOUT:-180}" >/dev/null
if $timing; then print_timing; fi
echo "$path 200"
check_admin "$path"
echo "lane ok, $lane on Ghost $version"

if ((hold > 0)); then
	echo "lane: holding $name for ${hold}s"
	sleep "$hold"
fi
echo "--- container logs ($name) ---"
podman logs "$name" 2>&1
