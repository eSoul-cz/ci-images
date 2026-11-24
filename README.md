# CI build docker images

This repository contains Dockerfiles and related resources for building Docker images used in our Continuous Integration (CI) pipelines on a Jenkins server.

## Contents

### Docker Images
- **node/**: Node.js images with different versions (24, 26, LTS): Alpine with pnpm and `git`, for test commands that run `git describe`, clone or list a repository (`git` added 2026-11-24; it reaches the registry with the next nightly build)
- **php/**: PHP 8.4/8.5/8.6 CI images, PHP 8.4/8.5 FPM/Laravel images, plus production PHP 8.5 CLI and RoadRunner images. In the PHP 8.6 CI image (`php:8.6`) the extensions whose PECL releases do not compile on 8.6 yet come from [PIE](https://github.com/php/pie): igbinary, redis and imagick at pinned commits of their 8.6-ready branches, imap from `sirlouen/imap`. pcov is replaced by Xdebug (`xdebug.mode=off` unless `XDEBUG_MODE` is set) and protobuf is missing (as of 2026-11-22; see `php/8_6/Dockerfile`)
- **playwright/**: Microsoft Playwright image with pnpm
- **esoul-guidelines/**: the [eSoul-cz/guidelines](https://github.com/eSoul-cz/guidelines) installer (PHAR on the PHP CLI Alpine image) for repositories without PHP

### PHP configuration

`php/conf.d/` holds the eSoul PHP settings shared by all PHP images, so PHP images build with `php/` as the context:

```sh
docker build -f php/base/Dockerfile --target laravel php
```

- `10-esoul-security.ini` (every PHP image): disables `session.upload_progress` (CVE-2026-115560 / CVE-2026-109619 mitigation) and `expose_php`.
- `20-esoul-ci.ini` (CI images `php/8_4`, `php/8_5`, `php/8_6` only): turns on OPcache for the CLI (`opcache.enable_cli=1`). The cache lives only as long as one PHPUnit or PHPStan process, so the gain is small (see the pull request). Timestamp validation stays on and is checked on every file access (`opcache.revalidate_freq=0`), so a PHP file a test writes (a compiled Blade view) is never served stale. JIT stays off (`opcache.jit_buffer_size=0`) and so does the optimizer (`opcache.optimization_level=0`): with pcov the optimizer drops executable lines such as a `break;` from the coverage report. Turn OPcache off for one run with `php -d opcache.enable_cli=0`.
- `20-esoul-runtime.ini` (FPM and RoadRunner only): production error handling, `zend.assertions=-1`, and OPcache tuning. `PHP_OPCACHE_VALIDATE_TIMESTAMPS`, `PHP_OPCACHE_MEMORY_CONSUMPTION` and `PHP_OPCACHE_ENABLE_CLI` override it at runtime.

### Composer over SSH

`php/ssh/` gives every PHP image what Composer needs to clone from GitHub over SSH, for a private package or while GitHub's API fails. No image holds a key: the key is the one in the SSH agent Jenkins forwards (`composerAuth` of the eSoul Jenkins libraries).

- `github_known_hosts` (every PHP image, as `/etc/ssh/ssh_known_hosts`): GitHub's SSH host keys, so a clone verifies the server it talks to and no other host is trusted. They are the `ssh_keys` of <https://api.github.com/meta>; replace the file when GitHub rotates a key.
- CI images (`php/8_4`, `php/8_5`, `php/8_6`): the OpenSSH client and `ssh`, installed as `/usr/local/bin/ssh` in front of the real one. Jenkins runs these containers as the uid of its own account, which the image's `/etc/passwd` does not know, and OpenSSH refuses to start for such a user; the script answers that one lookup through `nss_wrapper` and then runs the real client.
- FPM/Laravel and CLI/RoadRunner images: `git` and the OpenSSH client, for `composer install` in an application's image build:

  ```dockerfile
  # syntax=docker/dockerfile:1
  RUN --mount=type=secret,id=composer_auth,env=COMPOSER_AUTH --mount=type=ssh \
      composer install --no-dev --prefer-dist --no-interaction --no-progress
  ```

  They add about 12 MB (eight packages) to these images, which are also the runtime images of the applications.

## Security scan (Trivy)

`scripts/trivy-scan.sh` reports known vulnerabilities with a digest-pinned Trivy container, so only Docker is required:

```sh
docker build -t local/node:lts node/lts
scripts/trivy-scan.sh local/node:lts                 # local image
scripts/trivy-scan.sh -o /tmp/trivy node:lts-alpine  # remote image, custom report dir
```

It writes `<image>.json` and `<image>.txt` per image to `build/trivy/` (default) and exits `0` when clean, `10` when an image has findings, `1` when a scan failed. By default it reports `HIGH,CRITICAL` vulnerabilities that already have a fix; any `TRIVY_*` variable is passed to Trivy (for example `TRIVY_SEVERITY=MEDIUM,HIGH,CRITICAL` or `TRIVY_IGNORE_UNFIXED=false`).

The Jenkins pipeline runs the same script on every published image after the multi-arch manifests are created. It is a soft report: findings or scan errors mark only the `Security scan (Trivy)` stage `UNSTABLE`, the build stays successful, and reports are archived as build artifacts. Untick the `SECURITY_SCAN` build parameter to skip it.

## esoul-guidelines image

`esoul-guidelines/` packages the installer of [eSoul-cz/guidelines](https://github.com/eSoul-cz/guidelines) for repositories and pipelines without PHP (an Astro site, for example). It is the PHP CLI Alpine image (`php:<VERSION>-cli-alpine`, nothing else added) plus the PHAR of one guidelines release as `/usr/local/bin/esoul-guidelines`, which is the entrypoint. The image is published as `rg.fr-par.scw.cloud/testing-images/esoul-guidelines` with the tags `<release>` (the `guidelinesVersion` in the `Jenkinsfile`), `<minor>` (e.g. `0.3`) and `latest`; log in first with `docker login rg.fr-par.scw.cloud`.

The image is an optional local convenience. CI does not depend on it: a project's `esoul-guidelines check` runs the installer version the project recorded in its `esoul-guidelines.lock` (`esoulGuidelinesCheck` of the [eSoul Jenkins libraries](https://github.com/eSoul-cz/jenkins-libraries) downloads that release's PHAR, verifies its checksum and runs it in the `php` image), so a guidelines release never breaks a project's check, whatever tag this image carries.

```sh
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/app" -w /app rg.fr-par.scw.cloud/testing-images/esoul-guidelines:0.3 sync
```

Arguments are those of `esoul-guidelines` (`init`, `sync`, `check`, `list`; see the guidelines README). The project is the mounted `/app`, which is also the default working directory.

- `--user "$(id -u):$(id -g)"` makes the generated files belong to the invoking user. Without it the image runs as uid `1000`; Jenkins passes its own uid anyway. The PHAR needs no home directory or other writable path.
- The guidelines release is the only input: `guidelinesVersion` in the `Jenkinsfile` is passed as the `GUIDELINES_VERSION` build argument, and the Dockerfile downloads that release's `esoul-guidelines.phar` and fails the build unless it matches the release's `esoul-guidelines.phar.sha256`. Build locally with `docker build --build-arg GUIDELINES_VERSION=<release> -t local/esoul-guidelines esoul-guidelines`.
- The image pins the release, so a project updates the guidelines by moving to a newer image tag and running `sync`.

## Version updates (Renovate)

Renovate runs self-hosted as the first stage of the nightly Jenkins pipeline (`master` only), in the Docker image pinned by `RENOVATE_IMAGE`. It authenticates as the eSoul GitHub App through the Jenkins GitHub App credential `renovate` (GitHub Branch Source plugin), which mints a short-lived installation token per run. Failures mark only the `Renovate` stage `UNSTABLE`; untick the `RENOVATE` build parameter to skip it.

`renovate.json5` makes it open update PRs on Monday mornings (Europe/Prague) for:

- PHP patch releases, grouped into one PR across `php/*/Dockerfile` and the `Jenkinsfile` tags/`VERSION` build args. Each directory stays on its PHP minor; new minors (e.g. 8.6) and new Node majors are added by hand.
- The Playwright base image, created only after approval on the Dependency Dashboard issue, because consumers' `@playwright/test` version must match the image.
- RoadRunner, the digest-pinned PHP extension installer, the Trivy image in `scripts/trivy-scan.sh`, and Renovate itself.
- The `eSoul-cz/guidelines` release in the `esoul-guidelines` image (`guidelinesVersion` in the `Jenkinsfile`), as a regular PR to review.

Floating tags (`node:24-alpine`, `node:lts-alpine`, `pnpm@latest`) are not touched; the nightly build refreshes them. Pull-request builds do not build images, so review Renovate PRs before merging.

Validate config changes with:

```sh
docker run --rm -v "$PWD:/repo" -w /repo renovate/renovate renovate-config-validator --strict renovate.json5
```
