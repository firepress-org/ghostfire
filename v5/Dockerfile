# syntax=docker/dockerfile:1

# ----------------------------------------------
# 1a) ENV variables (core for all our projects at FirePress)
# ----------------------------------------------
ARG APP_NAME="ghostfire"
ARG VERSION="5.121.0"

ARG GITHUB_USER="firepress-org"
ARG DEFAULT_BRANCH="master"
ARG GITHUB_ORG="firepress-org"
ARG DOCKERHUB_USER="devmtl"
ARG GITHUB_REGISTRY="registry"

# ----------------------------------------------
# 1b) ENV variables (for this project)
# Various docs about our Dockerfile - https://github.com/firepress-org/ghostfire/issues/529
# ----------------------------------------------
ARG GHOST_CLI_VERSION="1.27.0"
ARG NODE_VERSION="20.19.2-alpine3.22"
ARG BASE_OS="alpine"
ARG USER="node"

# ----------------------------------------------
# 2) LAYER to manage base image versioning
# ----------------------------------------------
FROM node:${NODE_VERSION} AS mynode

ARG VERSION
ARG GHOST_CLI_VERSION
ARG USER
ARG NODE_VERSION
ARG ALPINE_VERSION

ENV GHOST_INSTALL="/var/lib/ghost"          \
	GHOST_CONTENT="/var/lib/ghost/content"  \
	NODE_ENV="production"                   \
	USER="${USER}"                          \
	NODE_VERSION="${NODE_VERSION}"          \
	VERSION="${VERSION}"                    \
	GHOST_CLI_VERSION="${GHOST_CLI_VERSION}"

LABEL org.opencontainers.image.authors="Pascal Andy https://firepress.org/en/contact/" \
	org.opencontainers.image.vendor="https://firepress.org/" \
	org.opencontainers.image.created="${BUILD_DATE}" \
	org.opencontainers.image.revision="${VCS_REF}" \
	org.opencontainers.image.title="Ghost" \
	org.opencontainers.image.description="Docker image for Ghost ${VERSION}" \
	org.opencontainers.image.url="https://hub.docker.com/r/devmtl/ghostfire/tags/" \
	org.opencontainers.image.source="https://github.com/firepress-org/ghostfire" \
	org.opencontainers.image.licenses="GNUv3 https://github.com/pascalandy/GNU-GENERAL-PUBLIC-LICENSE/blob/master/LICENSE.md" \
	com.firepress.image.ghost_cli_version="${GHOST_CLI_VERSION}" \
	com.firepress.image.user="${USER}" \
	com.firepress.image.node_env="${NODE_ENV}" \
	com.firepress.image.node_version="${NODE_VERSION}" \
	com.firepress.image.base_os="${BASE_OS}" \
	com.firepress.image.schema_version="1.0"

# Install gosu for easy step-down from root
ENV GOSU_VERSION 1.17
RUN set -eux; \
	apk add --no-cache --virtual .gosu-deps \
	ca-certificates \
	dpkg \
	gnupg \
	; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	apk del --no-network .gosu-deps; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true

# Add the backwards compatibility with the official dockerfile from dockerhub
RUN set -eux; ln -svf gosu /usr/local/bin/su-exec; su-exec nobody true

# Add bash and set timezone
RUN apk add --no-cache bash curl tzdata && \
	cp /usr/share/zoneinfo/America/New_York /etc/localtime && \
	echo "America/New_York" > /etc/timezone && \
	apk del tzdata && \
	rm -rvf /var/cache/apk/* /tmp/*

# ----------------------------------------------
# 3) LAYER debug
#   If a package crash on layers 4 or 5, we don't know which one crashed.
#   This layer reveal package(s) versions and keep a trace in the CI's logs.
# ----------------------------------------------
FROM mynode AS debug
RUN apk upgrade

# ----------------------------------------------
# 4) LAYER builder
# ----------------------------------------------
FROM mynode AS builder

# Use bash for shell commands, and fail builds if any command in a pipeline fails.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
	npm install -g "ghost-cli@$GHOST_CLI_VERSION"; \
	npm cache clean --force; \
	mkdir -p "$GHOST_INSTALL"; \
	chown node:node "$GHOST_INSTALL"; \
	apkDel=; \
	echo "Installing Ghost version: $VERSION"; \
	installCmd='gosu node ghost install "$VERSION" --db mysql --dbhost mysql --no-prompt --no-stack --no-setup --dir "$GHOST_INSTALL"'; \
	if ! eval "$installCmd"; then \
	echo "Initial Ghost installation failed, installing build dependencies..."; \
	virtual='.build-deps-ghost'; \
	apkDel="$apkDel $virtual"; \
	apk add --no-cache --virtual "$virtual" g++ linux-headers make python3 pkgconfig libc6-compat; \
	echo "Retrying Ghost installation with build dependencies..."; \
	eval "$installCmd"; \
	fi; \
	cd "$GHOST_INSTALL"; \
	gosu node ghost config --no-prompt --ip '::' --port 2368 --url 'http://localhost:2368'; \
	gosu node ghost config paths.contentPath "$GHOST_CONTENT"; \
	gosu node ln -s config.production.json "$GHOST_INSTALL/config.development.json"; \
	readlink -f "$GHOST_INSTALL/config.development.json"; \
	mv "$GHOST_CONTENT" "$GHOST_INSTALL/content.orig"; \
	mkdir -p "$GHOST_CONTENT"; \
	chown node:node "$GHOST_CONTENT"; \
	chmod 1777 "$GHOST_CONTENT"; \
	cd "$GHOST_INSTALL/current"; \
	packages="$(node -p ' \
	var ghost = require("./package.json"); \
	var sharpVersion = ""; \
	try { \
	var transform = require("./node_modules/@tryghost/image-transform/package.json"); \
	sharpVersion = transform.optionalDependencies["sharp"] || transform.dependencies["sharp"]; \
	} catch(e) { \
	try { \
	sharpVersion = ghost.optionalDependencies["sharp"] || ghost.dependencies["sharp"]; \
	} catch(e2) { \
	sharpVersion = "latest"; \
	} \
	} \
	var sqlite3Version = ghost.optionalDependencies["sqlite3"] || ghost.dependencies["sqlite3"] || "latest"; \
	[ \
	"sharp@" + sharpVersion, \
	"sqlite3@" + sqlite3Version, \
	].join(" ") \
	')"; \
	echo "Detected packages to install: $packages"; \
	if echo "$packages" | grep 'undefined'; then \
	echo "Error: undefined package version detected"; \
	exit 1; \
	fi; \
	for package in $packages; do \
	echo "Installing package: $package"; \
	installCmd='gosu node yarn add "$package" --force'; \
	if ! eval "$installCmd"; then \
	echo "Yarn installation failed, trying with npm: $package"; \
	npmInstallCmd='gosu node npm install "$package" --save --force'; \
	if ! eval "$npmInstallCmd"; then \
	echo "Package installation failed, installing build dependencies for: $package"; \
	virtualPackages='g++ make python3 pkgconfig vips-dev libc6-compat'; \
	virtual=".build-deps-${package%%@*}"; \
	apkDel="$apkDel $virtual"; \
	apk add --no-cache --virtual "$virtual" $virtualPackages; \
	echo "Retrying yarn installation with build-from-source: $package"; \
	if ! eval "$installCmd --build-from-source"; then \
	echo "Retrying npm installation with build-from-source: $package"; \
	eval "$npmInstallCmd --build-from-source"; \
	fi; \
	fi; \
	fi; \
	echo "Successfully installed: $package"; \
	done; \
	if [ -n "$apkDel" ]; then \
	apk del --no-network $apkDel; \
	fi; \
	gosu node yarn cache clean; \
	gosu node npm cache clean --force; \
	npm cache clean --force; \
	rm -rv /tmp/yarn* /tmp/v8*

# Pre-initialize Ghost content for distroless compatibility
# This replaces the functionality of docker-entrypoint.sh for distroless runtime
RUN set -eux; \
	cd "$GHOST_INSTALL"; \
	if [ -d "content.orig" ]; then \
		echo "Pre-initializing Ghost content for distroless runtime..."; \
		# Copy default content if target doesn't exist \
		for src in content.orig/*/ content.orig/themes/*; do \
			if [ -d "$src" ]; then \
				src="${src%/}"; \
				target="$GHOST_CONTENT/${src#*/content.orig/}"; \
				mkdir -p "$(dirname "$target")"; \
				if [ ! -e "$target" ]; then \
					echo "Copying $src to $target"; \
					cp -r "$src" "$target"; \
				fi; \
			fi; \
		done; \
		# Set proper ownership for distroless nonroot user (UID 65532) \
		chown -R 65532:65532 "$GHOST_CONTENT"; \
		chown -R 65532:65532 "$GHOST_INSTALL"; \
		echo "Content initialization completed for distroless runtime"; \
	else \
		echo "Warning: content.orig directory not found, skipping content initialization"; \
	fi

# ----------------------------------------------
# 5) LAYER final (Alpine-based - kept for compatibility)
# ----------------------------------------------
FROM mynode AS final

COPY --chown="${USER}":"${USER}" /v5/docker-entrypoint.sh /usr/local/bin
COPY --from=builder --chown="${USER}":"${USER}" "${GHOST_INSTALL}" "${GHOST_INSTALL}"

WORKDIR "${GHOST_INSTALL}"
VOLUME "${GHOST_CONTENT}"
USER "${USER}"
EXPOSE 2368

# HEALTHCHECK must be done during the runtime

ENTRYPOINT [ "docker-entrypoint.sh" ]
CMD [ "node", "current/index.js" ]

# ----------------------------------------------
# 6) LAYER distroless (Production runtime)
# ----------------------------------------------
FROM gcr.io/distroless/nodejs20-debian12 AS distroless

ARG VERSION
ARG GHOST_CLI_VERSION
ARG NODE_VERSION

# Set environment variables for distroless runtime
ENV GHOST_INSTALL="/var/lib/ghost" \
    GHOST_CONTENT="/var/lib/ghost/content" \
    NODE_ENV="production" \
    VERSION="${VERSION}" \
    GHOST_CLI_VERSION="${GHOST_CLI_VERSION}" \
    NODE_VERSION="${NODE_VERSION}"

# Add labels for distroless image
LABEL org.opencontainers.image.authors="Pascal Andy https://firepress.org/en/contact/" \
    org.opencontainers.image.vendor="https://firepress.org/" \
    org.opencontainers.image.title="Ghost (Distroless)" \
    org.opencontainers.image.description="Distroless Docker image for Ghost ${VERSION}" \
    org.opencontainers.image.url="https://hub.docker.com/r/devmtl/ghostfire/tags/" \
    org.opencontainers.image.source="https://github.com/firepress-org/ghostfire" \
    org.opencontainers.image.licenses="GNUv3 https://github.com/pascalandy/GNU-GENERAL-PUBLIC-LICENSE/blob/master/LICENSE.md" \
    com.firepress.image.ghost_cli_version="${GHOST_CLI_VERSION}" \
    com.firepress.image.user="nonroot" \
    com.firepress.image.node_env="${NODE_ENV}" \
    com.firepress.image.node_version="${NODE_VERSION}" \
    com.firepress.image.base_os="distroless" \
    com.firepress.image.schema_version="1.0"

# Copy Ghost installation from builder stage with nonroot ownership
COPY --from=builder --chown=nonroot:nonroot "${GHOST_INSTALL}" "${GHOST_INSTALL}"

# Set working directory and volume
WORKDIR "${GHOST_INSTALL}"
VOLUME "${GHOST_CONTENT}"

# Use nonroot user (UID 65532) for security
USER nonroot

# Expose Ghost port
EXPOSE 2368

# Direct Node.js execution (no shell entrypoint needed in distroless)
CMD ["node", "current/index.js"]