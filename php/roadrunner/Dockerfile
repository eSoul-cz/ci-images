ARG VERSION=8.5.12
ARG ROADRUNNER_VERSION=2025.1.15

FROM ghcr.io/roadrunner-server/roadrunner:${ROADRUNNER_VERSION} AS roadrunner-binary
FROM php:${VERSION}-cli-alpine AS runtime

ARG IPE_PROCESSOR_COUNT=2

LABEL authors="Tomas Vojik"
LABEL maintainer="Tomas Vojik <vojik@esoul.cz>"

COPY --from=ghcr.io/mlocati/php-extension-installer:2.13.2@sha256:4fd45396c16685266d32bf147a24ecd5e81029d3820295895bf4a90131190ac9 /usr/bin/install-php-extensions /usr/local/bin/

# Keep slow, stable telemetry/RPC extensions in their own cacheable layer.
RUN install-php-extensions \
    protobuf \
    opentelemetry

# Application runtime contract. Core extensions such as curl, fileinfo,
# SimpleXML, and zlib are supplied by the official PHP image.
RUN install-php-extensions \
    bcmath \
    mbstring \
    pdo_sqlite \
    pdo_mysql \
    sqlite3 \
    opcache \
    redis \
    igbinary \
    zip \
    sockets \
    gd \
    intl \
    gettext \
    exif

# eSoul PHP configuration (build context is php/). Workers are long-lived CLI
# processes, so they need the CLI opcache.
COPY conf.d/10-esoul-security.ini conf.d/20-esoul-runtime.ini $PHP_INI_DIR/conf.d/
ENV PHP_OPCACHE_ENABLE_CLI=1

WORKDIR /app

FROM runtime AS roadrunner

COPY --from=roadrunner-binary /usr/bin/rr /usr/local/bin/rr
