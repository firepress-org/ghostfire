# syntax=docker/dockerfile:1

###############################################################################
# 1) CI-visible build-time arguments (unchanged)                               #
###############################################################################
# ----- FirePress common ------------------------------------------------------
ARG  APP_NAME="ghostfire"
ARG  VERSION="5.121.0"
ARG  GITHUB_USER="firepress-org"
ARG  DEFAULT_BRANCH="master"
ARG  GITHUB_ORG="firepress-org"
ARG  DOCKERHUB_USER="devmtl"
ARG  GITHUB_REGISTRY="registry"

# ----- Image specific --------------------------------------------------------
ARG  GHOST_CLI_VERSION="1.27.0"
ARG  NODE_VERSION="20-alpine3.20"
ARG  BASE_OS="alpine"
ARG  USER="node"

# Optional but useful for reproducibility
ARG  RUNTIME_BASE="gcr.io/distroless/nodejs20-debian12"
###############################################################################
# 2) Build (compile / install) stage                                           #
###############################################################################
FROM node:${NODE_VERSION} AS builder

# re-declare args inside the stage
ARG  VERSION
ARG  GHOST_CLI_VERSION
ARG  USER

# ---- system packages --------------------------------------------------------
RUN apk update && apk upgrade --no-cache \
	&& apk add --no-cache --virtual .build-deps \
	g++ make python3 pkgconfig libc6-compat vips-dev \
	&& apk add --no-cache bash curl tzdata

# ---- runtime environment ----------------------------------------------------
ENV GHOST_INSTALL=/opt/ghost \
	GHOST_CONTENT=/opt/ghost/content \
	NODE_ENV=production

# user “node” already exists in the official Node image
USER ${USER}
WORKDIR ${GHOST_INSTALL}

# ---- Ghost CLI + Ghost core -------------------------------------------------
RUN npm i -g "ghost-cli@${GHOST_CLI_VERSION}" \
	&& ghost install "${VERSION}"               \
	--db=mysql --dbhost=mysql            \
	--no-setup --no-prompt --no-stack    \
	--dir "${GHOST_INSTALL}"             \
	&& ghost config paths.contentPath "${GHOST_CONTENT}"

# ---- minimise JS CVEs -------------------------------------------------------
RUN npm audit fix --omit=dev \
	&& yarn cache clean         \
	&& npm  cache clean --force

# ---- clean build dependencies ----------------------------------------------
USER root
RUN apk del --no-network .build-deps \
	&& rm -rf /root/.npm /root/.cache \
	&& rm -rf /var/cache/apk/*

###############################################################################
# 3) Runtime stage (distroless)                                                #
###############################################################################
FROM ${RUNTIME_BASE} AS runtime

# carry CI args for downstream logic / labels
ARG  VERSION
ARG  USER
ARG  APP_NAME
ARG  GITHUB_USER
ARG  DEFAULT_BRANCH
ARG  GITHUB_ORG
ARG  DOCKERHUB_USER
ARG  GITHUB_REGISTRY
ARG  NODE_VERSION
ARG  BASE_OS

# ---- labels -----------------------------------------------------------------
LABEL org.opencontainers.image.title="Ghost" \
	org.opencontainers.image.description="Ghost ${VERSION} (FirePress build)" \
	org.opencontainers.image.version="${VERSION}" \
	org.opencontainers.image.source="https://github.com/firepress-org/ghostfire" \
	org.opencontainers.image.base_os="${BASE_OS}" \
	org.opencontainers.image.node_version="${NODE_VERSION}"

# ---- environment ------------------------------------------------------------
ENV  GHOST_INSTALL=/opt/ghost \
	GHOST_CONTENT=/opt/ghost/content \
	NODE_ENV=production

WORKDIR ${GHOST_INSTALL}

# ---- copy application from builder -----------------------------------------
COPY --from=builder --chown=nonroot:nonroot ${GHOST_INSTALL} ${GHOST_INSTALL}

USER nonroot
EXPOSE 2368

# ---- health-check in a shell-less image ------------------------------------
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
	CMD node -e "require('http').get('http://127.0.0.1:2368',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

ENTRYPOINT ["node", "current/index.js"]
