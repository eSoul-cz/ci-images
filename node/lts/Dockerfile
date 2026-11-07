FROM node:lts-alpine

LABEL authors="Tomáš Vojík"
LABEL maintainer="Tomáš Vojík <vojik@esoul.cz>"

# Node 25+ images no longer ship Corepack, so install it from npm.
# COREPACK_HOME is shared instead of /root/.cache, so pnpm is already present for
# any UID (CI runs containers as the agent user) and works without network.
ENV COREPACK_HOME=/usr/local/share/corepack
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
# pnpm 11+ downloads its native binary on first run; `pnpm --version` fetches it at build time.
RUN npm install --global corepack@latest \
    && corepack enable \
    && corepack install --global pnpm@latest \
    && pnpm --version \
    && chmod -R a+rwX "$COREPACK_HOME"
