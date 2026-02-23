ARG VERSION=8.5.3
FROM php:${VERSION}-fpm-alpine AS base

LABEL authors="Tomas Vojik"
LABEL maintainer="Tomas Vojik <vojik@esoul.cz>"

# Add PHP extension installer
COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Install base extensions
RUN install-php-extensions \
    grpc \
    protobuf \
    opentelemetry \
    mbstring \
    bcmath \
    igbinary \
    intl \
    opcache \
    sockets \
    zip

# ── Laravel minimal ──────────────────────────────────────────────────────────
FROM base AS laravel-minimal

RUN install-php-extensions \
    pdo_sqlite \
    pdo_mysql \
    sqlite3 \
    redis

# ── Laravel ──────────────────────────────────────────────────────────────────
FROM laravel-minimal AS laravel

RUN install-php-extensions \
    gd \
    imagick \
    exif
