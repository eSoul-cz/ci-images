FROM node:26-alpine

LABEL authors="Tomáš Vojík"
LABEL maintainer="Tomáš Vojík <vojik@esoul.cz>"

# Install pnpm
#RUN wget -qO- https://get.pnpm.io/install.sh | ENV="$HOME/.shrc" SHELL="$(which sh)" sh -
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN npm install --global corepack@latest && corepack enable && corepack prepare pnpm@latest --activate