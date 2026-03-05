FROM php:8.4-cli-alpine AS base

LABEL authors="Tomáš Vojík"
LABEL maintainer="Tomáš Vojík <vojik@esoul.cz>"

# Add PHP extension installer
COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Add composer
RUN install-php-extensions @composer

# Install some base extensions
RUN install-php-extensions \
    mbstring \
    bcmath \
    bz2 \
    calendar \
    exif \
    gd \
    gettext \
    igbinary \
    imap \
    intl \
    mysqli \
    opcache \
    pcov \
    pgsql \
    redis \
    sockets \
    zip \
    zlib \
    sqlite3 \
    pdo_mysql \
    pdo_pgsql \
    pdo_sqlite \
    imagick

RUN install-php-extensions opentelemetry
RUN install-php-extensions grpc protobuf

# Create php user and group (available if needed, but don't switch to it by default)
# This allows the container to run as any user, which is important for CI/CD
# where mounted volumes may have different ownership
RUN addgroup -g 1000 php && \
    adduser -u 1000 -G php -s /bin/sh -D php

FROM base AS node

# Install Node.js (LTS) via apk
RUN apk add --no-cache nodejs npm

# Install pnpm via corepack
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && corepack prepare pnpm@latest --activate