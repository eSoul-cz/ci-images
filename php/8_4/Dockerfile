FROM php:8.4-cli-alpine

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
    pdo_sqlite

USER php