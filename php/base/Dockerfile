ARG VERSION=8.5.12
FROM php:${VERSION}-fpm-alpine AS base

ARG IPE_PROCESSOR_COUNT=2

LABEL authors="Tomas Vojik"
LABEL maintainer="Tomas Vojik <vojik@esoul.cz>"

# Add PHP extension installer
COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Install slow, stable telemetry/RPC extensions in their own cacheable layer.
RUN install-php-extensions \
    protobuf \
    opentelemetry

# Install base extensions
RUN install-php-extensions \
    mbstring \
    bcmath \
    igbinary \
    intl \
    opcache \
    sockets \
    zip

# eSoul PHP configuration (build context is php/).
COPY conf.d/10-esoul-security.ini conf.d/20-esoul-runtime.ini $PHP_INI_DIR/conf.d/

# For `composer install` while an application image is built: git and an SSH client with
# GitHub's host keys, so a private package, or any package while GitHub's API fails, can be
# cloned through the SSH agent of the build (RUN --mount=type=ssh). No key is in the image.
RUN apk add --no-cache git openssh-client-default
COPY ssh/github_known_hosts /etc/ssh/ssh_known_hosts

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
