#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: scripts/push.sh [--immutable | --mutable] [--help]

Push ghostfire:local, the image that `just check` tested, to REPO in two
steps. First, push it under its immutable tag, the first tag that
scripts/tags.sh prints, and write the pushed digest to .cache/push/digest.
Then point the other tags, the Ghost version and edge, at that digest. The
release workflow attests the digest between the two steps.

With TAG set, the second step moves those tags only when git lists no
release tag newer than TAG, so a rerun of an older release cannot move them
back. Exit 1 when ghostfire:local was not built from HEAD, when git lists no
release tag, or when a tag ends on another digest.

Environment:
  REPO  target repository, such as docker.io/devmtl/ghostfire (required;
        `just push` sets it)
  TAG   git tag of the release; scripts/tags.sh checks it against the
        Ghost version

Options:
  --immutable  run only the first step
  --mutable    run only the second step, on the digest in .cache/push/digest
  --help       print this help and exit
EOF
}

push_immutable=true
move_tags=true
case ${1:-} in
"") ;;
--immutable) move_tags=false ;;
--mutable) push_immutable=false ;;
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
tags=$("$(dirname "$0")/tags.sh" ${TAG:+--tag "$TAG"})

if $push_immutable; then
	revision=$(podman image inspect -f '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$image")
	head=$(git rev-parse --short HEAD)
	[[ $revision == "$head" ]] || {
		echo "push: $image was built from $revision, not HEAD $head; run just check" >&2
		exit 1
	}
	tag=$(head -n 1 <<<"$tags")
	mkdir -p "$out"
	podman tag "$image" "$repo:$tag"
	podman push --digestfile "$out/digest" "$repo:$tag"
	echo "push: $repo:$tag $(<"$out/digest")"
fi

if $move_tags; then
	digest=$(<"$out/digest")
	if [[ -n ${TAG:-} ]]; then
		releases=$(git tag --list '5.*.*')
		[[ -n $releases ]] || {
			echo "push: git lists no release tag; fetch the tags first" >&2
			exit 1
		}
		newest=$(printf '%s\n' "$releases" "$TAG" | sort -V | tail -n 1)
		if [[ $newest != "$TAG" ]]; then
			echo "push: $newest is newer than $TAG, so the version tag and edge stay where they are"
			exit 0
		fi
	fi
	while read -r tag; do
		crane tag "$repo@$digest" "$tag"
		[[ $(crane digest "$repo:$tag") == "$digest" ]] || {
			echo "push: $repo:$tag does not point at $digest" >&2
			exit 1
		}
		echo "push: $repo:$tag $digest"
	done < <(tail -n +2 <<<"$tags")
fi
