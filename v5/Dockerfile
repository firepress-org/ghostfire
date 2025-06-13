# syntax=docker/dockerfile:1

###############################################################################
# 1) CI-visible build-time arguments                                           #
###############################################################################
# ── FirePress common ─────────────────────────────────────────────────────────
ARG APP_NAME="ghostfire"
ARG VERSION="5.121.0"
ARG GITHUB_USER="firepress-org"
ARG DEFAULT_BRANCH="master"
ARG GITHUB_ORG="firepress-org"
ARG DOCKERHUB_USER="devmtl"
ARG GITHUB_REGISTRY="registry"

# ── Image-specific ───────────────────────────────────────────────────────────
ARG GHOST_CLI_VERSION="1.27.0"
ARG NODE_VERSION="20-alpine3.20"          # stay on a stable Alpine branch
ARG BASE_OS="alpine"
ARG USER="node"                           # will really be honoured

# ── Pin Alpine build packages (optional: freeze these digests in CI) ─────────
ARG PKG_GCC="g++"
ARG PKG_MAKE="make"
ARG PKG_PY3="python3"
ARG PKG_PKGCONF="pkgconfig"
ARG PKG_LIBC6="libc6-compat"
ARG PKG_VIPS="vips-dev"
ARG PKG_BASH="bash"
ARG PKG_CURL="curl"
ARG PKG_TZDATA="tzdata"

###############################################################################
# 2) Build stage                                                               #
###############################################################################
FROM node:${NODE_VERSION} AS builder

# re-declare only the ARGs needed in this stage
ARG VERSION
ARG GHOST_CLI_VERSION
ARG USER
ARG PKG_GCC PKG_MAKE PKG_PY3 PKG_PKGCONF PKG_LIBC6 PKG_VIPS PKG_BASH PKG_CURL PKG_TZDATA

# ---- OS packages (with versions if you froze them above) --------------------
RUN apk update && apk upgrade --no-cache \
	&& apk add --no-cache --virtual .build-deps \
	${PKG_GCC} ${PKG_MAKE} ${PKG_PY3} ${PKG_PKGCONF} ${PKG_LIBC6} ${PKG_VIPS} \
	&& apk add --no-cache ${PKG_BASH} ${PKG_CURL} ${PKG_TZDATA}

# ---- Enable Yarn via Corepack (bundled with Node 20) ------------------------
RUN corepack enable && corepack prepare yarn@stable --activate

# ---- Runtime env ------------------------------------------------------------
ENV GHOST_INSTALL=/opt/ghost \
	GHOST_CONTENT=/opt/ghost/content \
	NODE_ENV=production

# Create the directory and give it to the future unprivileged user
RUN mkdir -p ${GHOST_INSTALL} ${GHOST_CONTENT} \
	&& chown -R ${USER}:${USER} /opt/ghost

# Switch to the unprivileged user before installing Ghost
USER ${USER}
WORKDIR ${GHOST_INSTALL}

# ---- Ghost CLI + Ghost core -------------------------------------------------
RUN npm i -g "ghost-cli@${GHOST_CLI_VERSION}" \
	&& ghost install "${VERSION}" \
	--db=mysql --dbhost=mysql \
	--no-setup --no-prompt --no-stack \
	--dir "${GHOST_INSTALL}" \
	&& ghost config paths.contentPath "${GHOST_CONTENT}"

# ---- npm CVE clean-up -------------------------------------------------------
RUN npm audit fix --omit=dev \
	&& yarn cache clean \
	&& npm  cache clean --force

# ---- Back to root to delete build deps --------------------------------------
USER root
RUN apk del --no-network .build-deps \
	&& rm -rf /root/.npm /root/.cache /var/cache/apk/*

###############################################################################
# 3) Runtime stage (same Node-Alpine base; slimmer, patched)                   #
###############################################################################
FROM node:${NODE_VERSION} AS runtime

# re-declare CI ARGs so labels can see them
ARG APP_NAME VERSION USER NODE_VERSION BASE_OS
LABEL org.opencontainers.image.title="Ghost" \
	org.opencontainers.image.description="Ghost ${VERSION} (FirePress build)" \
	org.opencontainers.image.version="${VERSION}" \
	org.opencontainers.image.source="https://github.com/firepress-org/ghostfire" \
	org.opencontainers.image.base_os="${BASE_OS}" \
	org.opencontainers.image.node_version="${NODE_VERSION}"

ENV GHOST_INSTALL=/opt/ghost \
	GHOST_CONTENT=/opt/ghost/content \
	NODE_ENV=production

WORKDIR ${GHOST_INSTALL}
VOLUME ["/opt/ghost/content"]         # <-- data now persists by default

# copy application from the build stage
COPY --from=builder --chown=${USER}:${USER} ${GHOST_INSTALL} ${GHOST_INSTALL}

USER ${USER}
EXPOSE 2368

# health-check without /bin/sh
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
	CMD node -e "require('http').get('http://127.0.0.1:2368',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

ENTRYPOINT ["node", "current/index.js"]
