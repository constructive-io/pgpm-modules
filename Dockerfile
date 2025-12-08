ARG BASE=node
ARG BASE_VERSION=20-bookworm
FROM ${BASE}:${BASE_VERSION} AS build

LABEL org.opencontainers.image.source="https://github.com/launchql/pgpm-modules"
ARG BASE
ARG BASE_VERSION
ENV BASE_VERSION=${BASE_VERSION}

WORKDIR /app

# System deps and pnpm (match workspace requirement)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl git; \
    update-ca-certificates || true; \
    npm install -g pnpm@10.12.2; \
    rm -rf /var/lib/apt/lists/*

# Copy workspace (build context is the repo root of pgpm-modules)
COPY . .

# Install workspace deps and bundle packages
RUN set -eux; \
    pnpm install --frozen-lockfile; \
    pnpm -r bundle
