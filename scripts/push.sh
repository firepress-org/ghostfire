#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: scripts/push.sh [--help]

Push ghostfire:local, the image that `just check` tested, to REPO under each
tag that scripts/tags.sh prints. Write the pushed digest to
.cache/push/digest. Exit 1 when ghostfire:local was not built from HEAD, or
when two tags get different digests.

Environment:
  REPO  target repository, such as docker.io/devmtl/ghostfire (required;
        `just push` sets it)
  TAG   git tag of the release; scripts/tags.sh checks it against the
        Ghost version

Options:
  --help  print this help and exit
EOF
}

case ${1:-} in
"") ;;
-h | --help)
	usage
	exit 0
	;;
*)
	usage >&2
	exit 2
	;;
esac

repo=${REPO:?set REPO, or run through just push}
image=ghostfire:local
out=.cache/push

revision=$(podman image inspect -f '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$image")
head=$(git rev-parse --short HEAD)
[[ $revision == "$head" ]] || {
	echo "push: $image was built from $revision, not HEAD $head; run just check" >&2
	exit 1
}

tags=$("$(dirname "$0")/tags.sh" ${TAG:+--tag "$TAG"})
mkdir -p "$out"
digest=
while read -r tag; do
	podman tag "$image" "$repo:$tag"
	podman push --digestfile "$out/digest-$tag" "$repo:$tag"
	pushed=$(<"$out/digest-$tag")
	[[ -z $digest || $pushed == "$digest" ]] || {
		echo "push: $repo:$tag got $pushed, not $digest" >&2
		exit 1
	}
	digest=$pushed
	echo "push: $repo:$tag $digest"
done <<<"$tags"
printf '%s\n' "$digest" >"$out/digest"
echo "push: digest $digest written to $out/digest"
