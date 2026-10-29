set shell := ["bash", "-euo", "pipefail", "-c"]

# test, lane, and scan read IMAGE from the environment; the default is ghostfire:local.

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

# Lint the Dockerfile, the scripts, and the justfile
lint:
    hadolint Dockerfile
    node --check rootfs/usr/local/lib/ghostfire/start.mjs
    node --check rootfs/usr/local/lib/ghostfire/healthcheck.mjs
    shellcheck scripts/*.sh
    shfmt -d scripts
    just --fmt --check --unstable

# Run lint, build, test, and scan, in that order
check: _local lint build test scan
    @echo "check ok, $(cat .cache/scan/summary)"

# check tests and scans the image it builds, so IMAGE must name that image
_local:
    @[[ ${IMAGE:-ghostfire:local} == ghostfire:local ]] || { echo "check: IMAGE is $IMAGE; unset it, since check tests and scans the ghostfire:local it builds" >&2; exit 2; }
