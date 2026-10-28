# AGENTS.md

This repository builds the `devmtl/ghostfire` image of Ghost.

## Run the checks

- Install the pinned tools with `mise install`, then run `just check`. It runs `lint`, `build`, `test`, and `scan`, in that order, and ends with a line such as `check ok, os C<n>/H<n>, npm C<n>/H<n>`, the Critical and High counts of each layer
- Use Podman. The recipes call `podman`, never `docker`
- `just test`, `just lane`, and `just scan` act on the image that `IMAGE` names. The default is `ghostfire:local`, the image that `just build` makes. For example, `IMAGE=docker.io/devmtl/ghostfire:stable just test`
- `just lane <name>` runs the image on a scratch copy of a real site. Each site lives in `~/.cache/ghostfire-lanes/<name>/`, with `content/` and `config.production.json`
- Scan reports land in `.cache/scan/`, which git ignores
- Each script prints its usage with `--help`

## Where each version lives

- Ghost, Ghost-CLI, and the base images: the Dockerfile that `just build` builds
- Every tool: `mise.toml`

## Rules

- Lane data never enters the repo. It holds copies of real sites, with their databases. Keep it under `~/.cache/ghostfire-lanes/`, outside the checkout
