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
    corepack enable; \
    corepack prepare pnpm@10.12.2 --activate; \
    rm -rf /var/lib/apt/lists/*

# Copy workspace (build context is the repo root of pgpm-modules)
COPY . .

# Install workspace deps and bundle packages
RUN set -eux; \
    pnpm install --frozen-lockfile; \
    pnpm -r bundle

# Collect packaged SQL and relevant metadata into /out
RUN set -eux; \
    mkdir -p /out; \
    for p in /app/packages/*; do \
      name="$(basename "$p")"; \
      dest="/out/${name}"; \
      mkdir -p "$dest"; \
      # copy packaged SQL if present
      if [ -d "$p/sql" ]; then \
        mkdir -p "$dest/sql"; \
        cp -R "$p/sql"/* "$dest/sql/" || true; \
      fi; \
      # copy plan for reference (optional at runtime)
      if [ -f "$p/pgpm.plan" ]; then \
        cp "$p/pgpm.plan" "$dest/"; \
      fi; \
      # include package.json for provenance/versioning
      if [ -f "$p/package.json" ]; then \
        cp "$p/package.json" "$dest/"; \
      fi; \
    done

################################################################################
FROM debian:bookworm-slim AS runtime

LABEL org.opencontainers.image.source="https://github.com/launchql/pgpm-modules"
WORKDIR /pgpm

# Minimal runtime with CA certs for potential HTTPS fetches
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates; \
    update-ca-certificates || true; \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /out /pgpm/packages

ENV PGPM_MODULES_DIR=/pgpm/packages

# Default command: list packaged modules
CMD ["sh", "-lc", "ls -1 ${PGPM_MODULES_DIR} || true"]
