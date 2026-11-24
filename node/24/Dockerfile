FROM node:24-alpine

LABEL authors="Tomáš Vojík"
LABEL maintainer="Tomáš Vojík <vojik@esoul.cz>"

# git: test commands that clone or inspect history (`git describe`, `skills add --list`) need it, and Alpine has none.
RUN apk add --no-cache git

# Install pnpm
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN npm install --global corepack@latest && corepack enable && corepack prepare pnpm@latest --activate
