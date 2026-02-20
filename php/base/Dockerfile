ARG VERSION=8.5.3
FROM php:${VERSION}-fpm-alpine

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

