# CI build docker images

This repository contains Dockerfiles and related resources for building Docker images used in our Continuous Integration (CI) pipelines on a Jenkins server.

## Contents

### Docker Images
- **node/**: Node.js images with different versions (24, 26, LTS)
- **php/**: PHP 8.4/8.5 CI and FPM/Laravel images, plus production PHP 8.5 CLI and RoadRunner images
- **playwright/**: Microsoft Playwright image with pnpm

## Security scan (Trivy)

`scripts/trivy-scan.sh` reports known vulnerabilities with a digest-pinned Trivy container, so only Docker is required:

```sh
docker build -t local/node:lts node/lts
scripts/trivy-scan.sh local/node:lts                 # local image
scripts/trivy-scan.sh -o /tmp/trivy node:lts-alpine  # remote image, custom report dir
```

It writes `<image>.json` and `<image>.txt` per image to `build/trivy/` (default) and exits `0` when clean, `10` when an image has findings, `1` when a scan failed. By default it reports `HIGH,CRITICAL` vulnerabilities that already have a fix; any `TRIVY_*` variable is passed to Trivy (for example `TRIVY_SEVERITY=MEDIUM,HIGH,CRITICAL` or `TRIVY_IGNORE_UNFIXED=false`).

The Jenkins pipeline runs the same script on every published image after the multi-arch manifests are created. It is a soft report: findings or scan errors mark only the `Security scan (Trivy)` stage `UNSTABLE`, the build stays successful, and reports are archived as build artifacts. Untick the `SECURITY_SCAN` build parameter to skip it.

## Version updates (Renovate)

Renovate runs self-hosted as the first stage of the nightly Jenkins pipeline (`master` only), in the Docker image pinned by `RENOVATE_IMAGE`. It authenticates as the eSoul GitHub App through the Jenkins GitHub App credential `renovate` (GitHub Branch Source plugin), which mints a short-lived installation token per run. Failures mark only the `Renovate` stage `UNSTABLE`; untick the `RENOVATE` build parameter to skip it.

`renovate.json5` makes it open update PRs on Monday mornings (Europe/Prague) for:

- PHP patch releases, grouped into one PR across `php/*/Dockerfile` and the `Jenkinsfile` tags/`VERSION` build args. Each directory stays on its PHP minor; new minors (e.g. 8.6) and new Node majors are added by hand.
- The Playwright base image, created only after approval on the Dependency Dashboard issue, because consumers' `@playwright/test` version must match the image.
- RoadRunner, the digest-pinned PHP extension installer, the Trivy image in `scripts/trivy-scan.sh`, and Renovate itself.

Floating tags (`node:24-alpine`, `node:lts-alpine`, `pnpm@latest`) are not touched; the nightly build refreshes them. Pull-request builds do not build images, so review Renovate PRs before merging.

Validate config changes with:

```sh
docker run --rm -v "$PWD:/repo" -w /repo renovate/renovate renovate-config-validator --strict renovate.json5
```
