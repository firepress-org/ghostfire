set shell := ["bash", "-euo", "pipefail", "-c"]

# test, lane, and scan read IMAGE from the environment; the default is ghostfire:local.
# push and promote act on REPO.

export REPO := env("REPO", "docker.io/devmtl/ghostfire")

# List the recipes
default:
    @just --list

# Build the Dockerfile into ghostfire:local
build:
    podman build --format docker -f Dockerfile -t ghostfire:local \
        --label org.opencontainers.image.revision="$(git rev-parse --short HEAD)" \
        --label org.opencontainers.image.created="$(date -u +%Y-%m-%dT%H:%M:%SZ)" .

# Boot IMAGE on SQLite and probe the home page and the admin
test *args:
    scripts/test-image.sh {{ args }}

# Run IMAGE on a scratch copy of a real site from ~/.cache/ghostfire-lanes
lane name *args:
    scripts/lane.sh {{ args }} {{ name }}

# Scan IMAGE with Grype; fail on an OS-layer Critical or High finding with a fix
scan:
    scripts/scan.sh --gate

# Lint the Dockerfile, the scripts, the workflows, and the justfile
lint:
    hadolint Dockerfile
    node --check rootfs/usr/local/lib/ghostfire/start.mjs
    node --check rootfs/usr/local/lib/ghostfire/healthcheck.mjs
    shellcheck scripts/*.sh
    shfmt -d scripts
    actionlint
    zizmor .github/workflows
    just --fmt --check --unstable

# Run lint, build, test, and scan, in that order
check: _local lint build test scan
    @echo "check ok, $(cat .cache/scan/summary)"

# check tests and scans the image it builds, so IMAGE must name that image
_local:
    @[[ ${IMAGE:-ghostfire:local} == ghostfire:local ]] || { echo "check: IMAGE is $IMAGE; unset it, since check tests and scans the ghostfire:local it builds" >&2; exit 2; }

# Print the tags of a release of HEAD; TAG, when set, must match the Ghost version
tags:
    scripts/tags.sh ${TAG:+--tag "$TAG"}

# Push ghostfire:local to REPO: its immutable tag, then the version tag and edge (see scripts/push.sh --help)
push *args:
    scripts/push.sh {{ args }}

# Point stable at the digest of a tag in REPO; the operator runs it from a workstation
promote tag:
    digest="$(crane digest "$REPO:{{ tag }}")"; crane tag "$REPO@$digest" stable; echo "promote: $REPO:stable -> $digest"
