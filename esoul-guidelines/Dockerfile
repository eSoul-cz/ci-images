ARG VERSION=8.5.12

# The PHAR of one eSoul-cz/guidelines release (https://github.com/eSoul-cz/guidelines/releases), checked against the
# .sha256 file of the same release. GUIDELINES_VERSION has no default: the Jenkinsfile (`guidelinesVersion`) is the
# only place that names the release, e.g. --build-arg GUIDELINES_VERSION=0.3.1.
FROM php:${VERSION}-cli-alpine AS fetch

ARG GUIDELINES_VERSION

RUN set -eux; \
    test -n "$GUIDELINES_VERSION"; \
    base="https://github.com/eSoul-cz/guidelines/releases/download/v${GUIDELINES_VERSION}"; \
    mkdir /dist; \
    cd /dist; \
    curl -fsSL -O "$base/esoul-guidelines.phar" -O "$base/esoul-guidelines.phar.sha256"; \
    sha256sum -c esoul-guidelines.phar.sha256; \
    chmod 0755 esoul-guidelines.phar

FROM php:${VERSION}-cli-alpine AS runtime

ARG GUIDELINES_VERSION

LABEL authors="Tomas Vojik"
LABEL maintainer="Tomas Vojik <vojik@esoul.cz>"
LABEL org.opencontainers.image.title="esoul-guidelines"
LABEL org.opencontainers.image.source="https://github.com/eSoul-cz/guidelines"
LABEL org.opencontainers.image.version="${GUIDELINES_VERSION}"

COPY --from=fetch /dist/esoul-guidelines.phar /usr/local/bin/esoul-guidelines

# The PHAR needs nothing but the PHP CLI (no Composer, no extra extensions) and writes only into the mounted project,
# so it runs as any uid: `--user "$(id -u):$(id -g)"` makes the generated files belong to the invoking user. Without
# `--user` the files belong to uid 1000, which is what a default Linux user and Docker Desktop/OrbStack mounts expect.
USER 1000:1000
WORKDIR /app

ENTRYPOINT ["esoul-guidelines"]
CMD ["list"]
