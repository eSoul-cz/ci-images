FROM node:25-alpine

LABEL authors="Tomáš Vojík"
LABEL maintainer="Tomáš Vojík <vojik@esoul.cz>"

# Install pnpm
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

USER node