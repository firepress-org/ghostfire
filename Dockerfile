# Ghost 5 on Node 22. The builder installs Ghost on Debian 13; the runtime is
# distroless, with no shell, no package manager, and no curl.

ARG GHOST_VERSION=5.130.6
ARG GHOST_CLI_VERSION=1.34.0

FROM docker.io/library/node:22-trixie-slim@sha256:2117f713a417f3aff682ac8f5bc2ebbdf1beed51f36e67ab1e0fd3866b6d2d8f AS builder

ARG GHOST_VERSION
ARG GHOST_CLI_VERSION

ENV NODE_ENV=production

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# node-gyp builds sqlite3 from source; on Python 3.13 it needs setuptools.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends g++ make python3 python3-setuptools \
	&& rm -rf /var/lib/apt/lists/* \
	&& npm install -g "ghost-cli@${GHOST_CLI_VERSION}" \
	&& npm cache clean --force \
	&& install -d -o node -g node /var/lib/ghost

# The node user of the base image owns the install, as Ghost-CLI requires.
# hadolint ignore=DL3066
USER node
WORKDIR /var/lib/ghost

# The MySQL flags only let the install skip its setup; the config makes SQLite
# the default database. The empty content directory is made outside
# /var/lib/ghost, because COPY --chown sets the owner only of a directory it
# creates.
RUN ghost install "${GHOST_VERSION}" --db mysql --dbhost mysql --no-setup --no-stack --no-prompt --dir /var/lib/ghost \
	&& ghost config --no-prompt --ip '::' --port 2368 --url 'http://localhost:2368' \
	&& ghost config paths.contentPath /var/lib/ghost/content \
	&& ghost config database.client sqlite3 \
	&& ghost config database.connection.filename /var/lib/ghost/content/data/ghost.db \
	&& ln -s config.production.json config.development.json \
	&& mv content content.orig \
	&& mkdir /tmp/content

# Ghost-CLI skips the optional sqlite3 without an error, so add it and fail
# the build unless both native modules load.
WORKDIR /var/lib/ghost/current
RUN yarn add "sqlite3@$(node -p 'require("./package.json").optionalDependencies.sqlite3')" --force \
	&& yarn cache clean \
	&& node -e 'require("sqlite3"); if (!require("@tryghost/image-transform").canTransformFiles()) process.exit(1)'

FROM gcr.io/distroless/nodejs22-debian13:nonroot@sha256:10747a1323be68f206aed893599d43e6697ad67257e7c42703553f99fbce3d33

ARG GHOST_VERSION

ENV NODE_ENV=production

COPY --from=builder --chown=0:0 /var/lib/ghost /var/lib/ghost
COPY --from=builder --chown=1000:1000 /tmp/content /var/lib/ghost/content
COPY --chown=0:0 rootfs/ /

USER 1000:1000
WORKDIR /var/lib/ghost
VOLUME /var/lib/ghost/content
EXPOSE 2368

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
	CMD ["/nodejs/bin/node", "/usr/local/lib/ghostfire/healthcheck.mjs"]

CMD ["/usr/local/lib/ghostfire/start.mjs"]

# `just build` sets org.opencontainers.image.revision and .created with
# --label: Buildah reuses a cached LABEL layer even when a build argument
# in it changes.
LABEL org.opencontainers.image.title="ghostfire" \
	org.opencontainers.image.description="Ghost ${GHOST_VERSION} on Node 22, on a distroless runtime" \
	org.opencontainers.image.version="${GHOST_VERSION}" \
	org.opencontainers.image.source="https://github.com/firepress-org/ghostfire" \
	org.opencontainers.image.url="https://hub.docker.com/r/devmtl/ghostfire" \
	org.opencontainers.image.vendor="FirePress" \
	org.opencontainers.image.authors="Pascal Andy https://firepress.org/en/contact/" \
	org.opencontainers.image.licenses="MIT"
