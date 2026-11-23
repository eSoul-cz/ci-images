ARG VERSION=8.6.0
FROM php:${VERSION}-cli-alpine AS base

ARG IPE_PROCESSOR_COUNT=2

LABEL authors="Tomáš Vojík"
LABEL maintainer="Tomáš Vojík <vojik@esoul.cz>"

# Add PHP extension installer, and PIE for the extensions whose PECL releases do not build on 8.6 yet (below)
COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
COPY --from=ghcr.io/php/pie:1.5.5-bin /pie /usr/local/bin/pie

# Allow Composer to fall back to source installs when dist downloads fail.
RUN apk add --no-cache git

# Install slow, stable telemetry/RPC extensions in their own cacheable layer.
RUN install-php-extensions \
    opentelemetry

# Install some base extensions.
RUN install-php-extensions \
    @composer \
    mbstring \
    bcmath \
    bz2 \
    calendar \
    exif \
    gd \
    gettext \
    intl \
    mysqli \
    opcache \
    pgsql \
    sockets \
    zip \
    zlib \
    sqlite3 \
    pdo_mysql \
    pdo_pgsql \
    pdo_sqlite \
    pcntl

# Extensions whose PECL releases do not compile against PHP 8.6 yet (checked 2026-11-22: protobuf and igbinary call the removed
# zval_dtor(), pcov the removed INI_BOOL/INI_INT/INI_STR; redis, imagick and imap fail too). They come from PIE (Packagist) instead:
# - igbinary, redis (with the igbinary serializer, as install-php-extensions builds it) and imagick: a pinned commit of the branch
#   that already supports 8.6; switch each to its first release that does.
# - imap: the sirlouen/imap PIE package (the PECL imap release fails on 8.6); check it against PECL imap when that supports 8.6.
# - pcov does not compile on 8.6 in any branch: Xdebug is the coverage driver here (3.6.0alpha1, the first release that allows
#   PHP 8.6; 3.5.x requires <8.6), off unless XDEBUG_MODE is set (`XDEBUG_MODE=coverage` in the composer test scripts).
# - protobuf is left out: no 8.6-compatible version; google/protobuf's PHP runtime works without the extension (slower).
RUN apk add --no-cache --virtual .pie-build $PHPIZE_DEPS linux-headers imagemagick-dev imap-dev krb5-dev openssl-dev \
    && apk add --no-cache imagemagick imagemagick-libs c-client krb5-libs \
    && pie install -n --make-parallel-jobs="${IPE_PROCESSOR_COUNT}" 'igbinary/igbinary:dev-master#2b1f5d62e3037b07c2a46499ac32091cdb41fb40' \
    && pie install -n --make-parallel-jobs="${IPE_PROCESSOR_COUNT}" 'phpredis/phpredis:dev-develop#a6ce1e60b3e81ce3b25174aa5aaefd5590dc64fd' --enable-redis-igbinary \
    && pie install -n --make-parallel-jobs="${IPE_PROCESSOR_COUNT}" 'imagick/imagick:dev-master#55ed2e9fda264395636a2e27e51f31673f5566ab' \
    && pie install -n --make-parallel-jobs="${IPE_PROCESSOR_COUNT}" 'sirlouen/imap:1.1.2' \
    && pie install -n --make-parallel-jobs="${IPE_PROCESSOR_COUNT}" 'xdebug/xdebug:3.6.0alpha1' \
    && echo 'xdebug.mode=off' > "$PHP_INI_DIR/conf.d/zz-xdebug-mode.ini" \
    && apk del .pie-build \
    && rm -rf /tmp/pie* ~/.pie ~/.cache

# eSoul PHP configuration (build context is php/).
COPY conf.d/10-esoul-security.ini conf.d/20-esoul-ci.ini $PHP_INI_DIR/conf.d/

# Composer over SSH, for a private package or while GitHub's API fails: the client, GitHub's
# host keys, and an `ssh` that also starts for the uid Jenkins runs the container as (ssh/ssh).
# No key is in the image; it comes from the SSH agent Jenkins forwards.
RUN apk add --no-cache openssh-client-default nss_wrapper
COPY ssh/github_known_hosts /etc/ssh/ssh_known_hosts
COPY --chmod=755 ssh/ssh /usr/local/bin/ssh

# Create php user and group (available if needed, but don't switch to it by default)
# This allows the container to run as any user, which is important for CI/CD
# where mounted volumes may have different ownership
RUN addgroup -g 1000 php && \
    adduser -u 1000 -G php -s /bin/sh -D php

FROM node:lts-alpine AS node-source

FROM base AS node

# Install Node.js (LTS) via apk
RUN apk add --no-cache nodejs npm

# Copy pnpm from the official node image
COPY --from=node-source /usr/lib /usr/lib
COPY --from=node-source /usr/local/lib /usr/local/lib
COPY --from=node-source /usr/local/include /usr/local/include
COPY --from=node-source /usr/local/bin /usr/local/bin
COPY --from=node-source /opt /opt

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN npm install --global corepack@latest && corepack enable && corepack prepare pnpm@latest --activate
