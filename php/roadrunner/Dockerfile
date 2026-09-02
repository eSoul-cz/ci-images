ARG VERSION=8.5.10
ARG ROADRUNNER_VERSION=2025.1.15

FROM ghcr.io/roadrunner-server/roadrunner:${ROADRUNNER_VERSION} AS roadrunner-binary
FROM php:${VERSION}-cli-alpine AS runtime

ARG IPE_PROCESSOR_COUNT=2

LABEL authors="Tomas Vojik"
LABEL maintainer="Tomas Vojik <vojik@esoul.cz>"

COPY --from=ghcr.io/mlocati/php-extension-installer@sha256:b6d3fa381b9ba5cf051117c1c601d6a523b590e534bf3d56eb4fbe352949c138 /usr/bin/install-php-extensions /usr/local/bin/

# Keep slow, stable telemetry/RPC extensions in their own cacheable layer.
RUN install-php-extensions \
    grpc \
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

WORKDIR /app

FROM runtime AS roadrunner

COPY --from=roadrunner-binary /usr/bin/rr /usr/local/bin/rr
