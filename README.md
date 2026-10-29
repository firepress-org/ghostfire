&nbsp;

<p align="center">
  <a href="https://firepress.org/">
    <img src="https://user-images.githubusercontent.com/6694151/50166045-2cc53000-02b4-11e9-8f7f-5332089ec331.jpg" width="340px" alt="FirePress" />
  </a>
</p>

<p align="center">
    <a href="https://firepress.org/">FirePress.org</a> |
    <a href="https://play-with-ghost.com/">play-with-ghost</a> |
    <a href="https://github.com/firepress-org/">GitHub</a> |
    <a href="https://twitter.com/askpascalandy">Twitter</a>
    <br /> <br />
</p>

&nbsp;

# [ghostfire](https://github.com/firepress-org/ghostfire)

<!-- Build Status -->
[![Release](https://img.shields.io/github/actions/workflow/status/firepress-org/ghostfire/release.yml?label=release)](https://github.com/firepress-org/ghostfire/actions/workflows/release.yml)

<!-- Docker Metrics -->
[![Docker Pulls](https://img.shields.io/docker/pulls/devmtl/ghostfire)](https://hub.docker.com/r/devmtl/ghostfire)
[![Docker Image Size](https://img.shields.io/docker/image-size/devmtl/ghostfire/stable)](https://hub.docker.com/r/devmtl/ghostfire)
[![Docker Image Version](https://img.shields.io/docker/v/devmtl/ghostfire?sort=semver)](https://hub.docker.com/r/devmtl/ghostfire)

<!-- Versions -->
[![Ghost Version](https://img.shields.io/badge/Ghost-v5.130.6-brightgreen)](https://github.com/TryGhost/Ghost)
[![Node Version](https://img.shields.io/badge/Node.js-22%20distroless-green)](https://nodejs.org/)
[![Platform](https://img.shields.io/badge/platform-linux%2Famd64-lightgrey)](https://hub.docker.com/r/devmtl/ghostfire)

<!-- Repository Health -->
[![GitHub last commit](https://img.shields.io/github/last-commit/firepress-org/ghostfire)](https://github.com/firepress-org/ghostfire/commits)
[![GitHub issues](https://img.shields.io/github/issues/firepress-org/ghostfire)](https://github.com/firepress-org/ghostfire/issues)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/firepress-org/ghostfire/blob/master/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/firepress-org/ghostfire?style=social)](https://github.com/firepress-org/ghostfire)

<br>

## What is this?

**What is Ghost?** — Ghost is an open-source software that lets you create your website with a blog. See the [FAQ section](https://play-with-ghost.com/ghost-themes/faq/#what-is-ghost) for more details. This project makes it run in a Docker image.

<br>

## Breaking change in 5.130.6

This notice is for users of the `stable` and `edge` tags. From 5.130.6 on, the image runs Ghost on a distroless Node 22 runtime. It has no shell, no `curl`, and no `gosu`.

- A healthcheck that runs `curl` inside the container fails, so the container turns `unhealthy`. An orchestrator that restarts unhealthy containers then restarts Ghost in a loop. Remove your `curl` healthcheck. The image has its own, described in [Health check](#health-check)
- `docker exec <container> sh` fails with `executable file not found`. Use `docker cp` to read files
- The image starts as UID 1000 and GID 1000, never as root. The content volume must be writable by that user. Volumes made by earlier images already are. If you ran an earlier image as root with a volume owned by root, run `chown -R 1000:1000` on the volume once
- The image no longer sets a time zone. Mount `/etc/localtime` read-only to set one
- The image is built for `linux/amd64` only
- Ghost 5 checks for updates by running `npm -v` through a shell. Without a shell, Ghost logs `spawn /bin/sh ENOENT` when the check is due, about once a day, and keeps serving

Ghost migrates the SQLite database the first time 5.130.6 starts on it. Back up the content directory before you update.

<br>

## Docker image features :

- [x] **Ghost 5.130.6 on Node 22**
- [x] **Multi-stage build**: Ghost is installed on `node:22-trixie-slim`, then copied into `gcr.io/distroless/nodejs22-debian13:nonroot`. Both base images are pinned by digest
- [x] **No shell, no package manager, no `curl`**, and no `gosu`
- [x] **Non-root**: runs as UID 1000 and GID 1000. The Ghost code is owned by root, so Ghost cannot change it
- [x] **Read-only root filesystem**: runs with `--read-only` and a writable `/tmp`
- [x] **Built-in health check** on the admin site API, under the path of the site url
- [x] **SQLite by default**, at `/var/lib/ghost/content/data/ghost.db`. MySQL works through the Ghost config
- [x] **Native modules checked at build time**: the build fails unless `sqlite3` and `sharp` load
- [x] **Labels** based on the OpenContainer standard
- [x] **`linux/amd64`** only

The image is about 620 MB.

<br>

## Release flow :

`.github/workflows/release.yml` runs only when a tag such as `5.130.6` is pushed. It runs one job on `ubuntu-24.04`, for `linux/amd64`, with Podman:

1. It installs the tools pinned in `mise.toml`, then runs `just check`
2. It logs in to Docker Hub, then runs `just push --immutable`, which pushes the image that `just check` tested under its immutable tag, such as `5.130.6_1a2b3c4_2026-10-28_12H00`
3. It signs the build provenance of that digest with `actions/attest`
4. It runs `just push --mutable`, which points the version tag and `edge` at the same digest. It moves them only when the release tag is the newest one in git, so a rerun of an older release publishes its immutable tag alone
5. It copies this README to the Docker Hub description

A merge to `master` publishes nothing. The workflow never moves `stable`.

A fix to a base image ships as a rebuild. Dependabot opens one grouped PR a month for the base-image digests, and one for the GitHub Actions. After the base-image PR merges, push the next `-N` tag of the same Ghost version, such as `5.130.6-1`, then `5.130.6-2`.

<br>

## Live Demo

Want to try Ghost quickly? This is for you!

[play-with-ghost.com](https://play-with-ghost.com/) is a playground to learn about Ghost. What's remarkable here, is that you have the option to log into the admin panel of each live demo available, by using dummy credentials.

In short, you can try Ghost on the spot without having to sign-up!

<br>

[![pwg-video-preview-e](https://user-images.githubusercontent.com/6694151/50233512-9bbc8a80-0381-11e9-83bb-f29a67000378.jpg)
](https://play-with-ghost.com/)

<br>

#### Continuous integration

See [Github Actions sections](https://github.com/firepress-org/ghostfire/actions)

At this point, this docker image has been pulled more than **11 millions of time**!

![docker-hub](https://user-images.githubusercontent.com/6694151/53067692-4c8af700-34a3-11e9-9fcf-9c7ad169a91b.jpg)

## Quick Start

#### Option #1 (basic run)

```bash
GHOSTFIRE_IMG="devmtl/ghostfire:stable"

docker run -d \
  --name ghostblog \
  -p 2368:2368 \
  -e url=http://localhost:2368 \
  ${GHOSTFIRE_IMG}
```

#### Option #2 (production with persistent data)

```bash
GHOSTFIRE_IMG="devmtl/ghostfire:stable"

docker run -d \
  --name ghostblog \
  --read-only \
  --tmpfs /tmp \
  -p 2368:2368 \
  -e url=https://example.com \
  -v /myuser/localpath/ghost/content:/var/lib/ghost/content \
  -v /myuser/localpath/ghost/config.production.json:/var/lib/ghost/config.production.json:ro \
  -v /etc/localtime:/etc/localtime:ro \
  ${GHOSTFIRE_IMG}
```

The content directory must be writable by UID 1000. Ghost writes uploads and temporary files to `/tmp`, so a read-only container needs the `/tmp` tmpfs.

To configure the `config.production.json` refer the [ghost docs](https://docs.ghost.org/concepts/config/).

#### Health check

The image has its own `HEALTHCHECK`. Every 30 seconds, it requests the admin site API, `<path>ghost/api/admin/site/`, where `<path>` is the path of the site url. It reads the site url, the admin url, and the port from the environment (`url`, `admin__url`, `server__port`), or else from the config, as Ghost does. It reports `healthy` only when Ghost answers 200. Read the status with:

```bash
docker inspect --format '{{.State.Health.Status}}' ghostblog
```

Do not add a health check that runs `curl` or a shell: the image has neither. To change the timing, set only `--health-interval`, `--health-timeout`, `--health-retries`, or `--health-start-period`, and keep the image's test. In a Compose file, leave out the `healthcheck` block.

## Tags

Each release pushes three tags:

```
devmtl/ghostfire:5.130.6_<sha7>_<date>   # never moves; pin this one
devmtl/ghostfire:5.130.6                 # the latest build of 5.130.6
devmtl/ghostfire:edge                    # the latest release
```

`stable` moves only when the maintainer runs `just promote <tag>`, after the release has run well on a real site. A `-N` rebuild pushes a new `5.130.6_<sha7>_<date>` tag and moves `5.130.6` and `edge`.

Find the latest tags on **DockerHub** here:
[https://hub.docker.com/r/devmtl/ghostfire/tags/](https://hub.docker.com/r/devmtl/ghostfire/tags/)

## Architecture & Security

### Multi-Stage Build Process

The `Dockerfile` has two stages:

1. **`builder`** installs Ghost-CLI, then Ghost, on `node:22-trixie-slim`, with the build tools that `sqlite3` needs. The build fails unless `sqlite3` and `sharp` load
2. The **runtime** stage copies `/var/lib/ghost` into `gcr.io/distroless/nodejs22-debian13:nonroot`, owned by root, with an empty `content` directory owned by UID 1000. It adds `start.mjs` and `healthcheck.mjs` from `rootfs/`

At start, `start.mjs` copies each missing directory and default theme from `content.orig` into `content`, then starts Ghost. It never overwrites what the volume holds. The default themes, `casper` and `source`, stay links into the image, so they update with it.

### Security Features

- **Non-root execution**: runs as UID 1000 and GID 1000
- **Read-only code**: the Ghost code is owned by root
- **Minimal attack surface**: a distroless runtime, with no shell, no package manager, and no network tools
- **Vulnerability scanning**: `just scan` runs Grype and fails on any Critical or High finding with a fix in the OS layer
- **Advisories**: [SECURITY.md](SECURITY.md) lists the Ghost 5 advisories that have no 5.x fix, and how to report a problem

### Volume Management

Critical paths for data persistence:

```bash
/var/lib/ghost/content              # All Ghost content, themes, uploads
/var/lib/ghost/config.production.json  # Runtime configuration, mounted read-only
/var/lib/ghost/content/logs         # Application logs
/var/lib/ghost/content/data/ghost.db    # SQLite database
/tmp                                # Uploads and imports in progress; a tmpfs with --read-only
```

<br>

## DevOps best practices

Let's understand our processes. In this post « [How we update hundreds of Ghost's websites on Docker Swarm?](https://firepress.org/en/how-we-update-hundreds-of-ghosts-websites-on-docker-swarm/) », we explain how we deploy Ghost in production and which best practices we do follow.

## Test the image locally

Install the pinned tools with `mise install`, then run `just check`. It lints the repo, builds the image with Podman, boots it on SQLite, and scans it with Grype. [AGENTS.md](AGENTS.md) lists every recipe.

<br>

## Developing Ghost themes locally

I open-sourced [my setup here](https://github.com/firepress-org/ghost-local-dev-in-docker). It’s a workflow to run Ghost locally within a Docker container. Once your local paths are defined, it’s enjoyable and easy to work **between many themes**.

<br>

## Configuration & Database

### Database Support

- **SQLite** (default): Zero-configuration, file-based database at `/var/lib/ghost/content/data/ghost.db`
- **MySQL**: Full support with connection configuration in `config.production.json`

### Configuration Management

The image's `config.production.json` sets the url to `http://localhost:2368`, listens on port 2368, uses SQLite, and keeps the content in `/var/lib/ghost/content`. To change it, mount your own `config.production.json` read-only over it.

Ghost reads environment variables before `config.production.json`. A variable such as `url` or `database__client` wins over the mounted config.

### Version Information

**Current Stack:**
- **Ghost**: v5.130.6
- **Node.js**: 22, on `gcr.io/distroless/nodejs22-debian13`
- **Ghost CLI**: v1.34.0, in the build stage only

Check versions in a running container:
```bash
docker inspect --format '{{ index .Config.Labels "org.opencontainers.image.version" }}' <container-id>
docker exec <container-id> /nodejs/bin/node --version
```

### Migration Notes

**Path consistency across versions:**
```
- Ghost 5.x.x: /var/lib/ghost/content ✅ (current)
- Ghost 4.x.x: /var/lib/ghost/content
- Ghost 3.x.x: /var/lib/ghost/content
- Ghost 2.x.x: /var/lib/ghost/content
- Ghost 1.x.x: /var/lib/ghost/content
- Ghost 0.11.x: /var/lib/ghost (deprecated)
```

From an earlier image to 5.130.6, read [Breaking change in 5.130.6](#breaking-change-in-51306).

<br>

## FirePress Hosting

At FirePress we empower entrepreneurs and small organizations to create their websites on top of [Ghost](https://firepress.org/en/faq/#what-is-ghost).

At the moment, our **pricing** for hosting one Ghost website is $15 (Canadian dollars). This price will be only available for our first 100 new clients, starting May 1st, 2019 🙌. [See our pricing section](https://firepress.org/en/pricing/) for details.

More details [about this announcement](https://forum.ghost.org/t/host-your-ghost-website-on-firepress/7092/1) on Ghost's forum.

<br>

## Contributing

The power of communities pull request and forks means that `1 + 1 = 3`. You can help to make this repo a better one! Here is how:

1. Fork it
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request

Check this post for more details: [Contributing to our Github project](https://pascalandy.com/blog/contributing-to-our-github-project/). Also, by contributing you agree to the [Contributor Code of Conduct on GitHub](https://pascalandy.com/blog/contributor-code-of-conduct-on-github/). It's plain common sense really.

<br>

## License

- This git repo is under the **MIT** license. [Find it here](https://github.com/firepress-org/ghostfire/blob/master/LICENSE).
- The Ghost's software is under the **MIT** license. [Find it here](https://ghost.org/license/).

<br>

## Sources & Fork

- This Git repo is available at [https://github.com/firepress-org/ghostfire](https://github.com/firepress-org/ghostfire)
- Forked from the [official](https://github.com/docker-library/ghost/) Ghost image

<br>

## Why all this work?

Our [mission](https://firepress.org/en/our-mission/) is to empower freelancers and small organizations to build an outstanding mobile-first website.

Because we believe your website should speak up in your name, we consider our mission completed once your site has become your impresario.

For more info about the man behind the startup, check out my [now page](https://pascalandy.com/blog/now/). You can also follow me on Twitter [@askpascalandy](https://twitter.com/askpascalandy).

— The FirePress Team 🔥📰
