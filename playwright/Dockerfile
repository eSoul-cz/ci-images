# The Node 26 binary for the `node26` target; the Playwright image ships Node 24.
FROM node:26-bookworm-slim AS node26-binary

FROM mcr.microsoft.com/playwright:v1.63.0-noble AS base

LABEL authors="Tomáš Vojík"
LABEL maintainer="Tomáš Vojík <vojik@esoul.cz>"

# Install pnpm
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && corepack prepare pnpm@latest --activate

# Same image with Node 26 for applications that need it (`engines`). /usr/local/bin comes before the image's
# /usr/bin/node in PATH; npm, corepack and pnpm stay those of the base image and run on Node 26.
FROM base AS node26
COPY --from=node26-binary /usr/local/bin/node /usr/local/bin/node
RUN node --version | grep -q '^v26\.'
