#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: scripts/tags.sh [--sha SHA7] [--date DATE] [--tag TAG] [--help]

Print the image tags for a release, one per line:
  <version>_<sha7>_<date>   the tag that sites pin
  <version>
  edge
<version> is the Ghost version of ARG GHOST_VERSION in the Dockerfile.

Options:
  --sha SHA7   commit to name (default: git rev-parse --short=7 HEAD)
  --date DATE  build time in UTC, such as 2026-10-28_12H00 (default: now)
  --tag TAG    git tag of the release. Exit 1 unless TAG is <version> or
               <version>-N, the rebuild N of that version with new base images
  --help       print this help and exit
EOF
}

sha=
date=
tag=
while (($#)); do
	case $1 in
	--sha)
		sha=${2:?--sha needs a value}
		shift
		;;
	--date)
		date=${2:?--date needs a value}
		shift
		;;
	--tag)
		tag=${2:?--tag needs a value}
		shift
		;;
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

dockerfile=$(dirname "$0")/../Dockerfile
version=$(sed -n 's/^ARG GHOST_VERSION=\([0-9][0-9.]*\)$/\1/p' "$dockerfile")
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
	echo "tags: no ARG GHOST_VERSION=<x.y.z> in $dockerfile" >&2
	exit 1
}

if [[ -n $tag && ! $tag =~ ^${version//./\\.}(-[1-9][0-9]*)?$ ]]; then
	echo "tags: git tag $tag is neither $version nor $version-N" >&2
	exit 1
fi

sha=${sha:-$(git rev-parse --short=7 HEAD)}
date=${date:-$(date -u +%Y-%m-%d_%HH%M)}
[[ $sha =~ ^[0-9a-f]{7}$ ]] || {
	echo "tags: --sha $sha is not 7 hex digits" >&2
	exit 1
}
[[ $date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}H[0-9]{2}$ ]] || {
	echo "tags: --date $date is not like 2026-10-28_12H00" >&2
	exit 1
}

printf '%s\n' "${version}_${sha}_${date}" "$version" edge
