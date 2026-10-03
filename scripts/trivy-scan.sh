#!/usr/bin/env bash
# Report known vulnerabilities in container images with a pinned Trivy container.
#
# Usage: scripts/trivy-scan.sh [-o REPORT_DIR] IMAGE...
#
# For every IMAGE, writes REPORT_DIR/<image>.json (Trivy JSON) and
# REPORT_DIR/<image>.txt (table), and prints the table.
#
# Exit status:
#   0   no matching vulnerabilities
#   10  at least one image has matching vulnerabilities
#   1   at least one scan failed (takes precedence over 10)
#   2   usage error
#
# Any TRIVY_* environment variable is forwarded to Trivy by name, so registry
# credentials (TRIVY_USERNAME / TRIVY_PASSWORD) never appear in process args.
# Defaults: TRIVY_SEVERITY=HIGH,CRITICAL, TRIVY_IGNORE_UNFIXED=true,
# TRIVY_SCANNERS=vuln. Set TRIVY_IMAGE_SRC=remote to skip the local daemon.
#
# SCAN_TRIVY_IMAGE overrides the Trivy container image; SCAN_CACHE_VOLUME
# overrides the Docker volume that caches the vulnerability database.
set -euo pipefail

SCAN_TRIVY_IMAGE="${SCAN_TRIVY_IMAGE:-aquasec/trivy:0.75.0@sha256:af6acf9a6b85dfe389a1941505c0ce9efef52a4719635e1a962f022a3d855daa}"
SCAN_CACHE_VOLUME="${SCAN_CACHE_VOLUME:-trivy-cache}"
export TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"
export TRIVY_IGNORE_UNFIXED="${TRIVY_IGNORE_UNFIXED:-true}"
export TRIVY_SCANNERS="${TRIVY_SCANNERS:-vuln}"
export TRIVY_NO_PROGRESS="${TRIVY_NO_PROGRESS:-true}"
FINDINGS_EXIT_CODE=10

usage() {
	sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'
}

report_dir="build/trivy"
while getopts 'o:h' opt; do
	case "$opt" in
		o) report_dir="$OPTARG" ;;
		h) usage; exit 0 ;;
		*) usage >&2; exit 2 ;;
	esac
done
shift $((OPTIND - 1))
if [ "$#" -eq 0 ]; then
	usage >&2
	exit 2
fi

mkdir -p "$report_dir"
report_dir="$(cd "$report_dir" && pwd)"

docker_args=(--rm -v "${SCAN_CACHE_VOLUME}:/root/.cache/trivy")
while IFS='=' read -r name _; do
	case "$name" in
		TRIVY_*) docker_args+=(-e "$name") ;;
	esac
done < <(env)
# Lets Trivy read images that exist only in the local Docker daemon.
if [ -S /var/run/docker.sock ]; then
	docker_args+=(-v /var/run/docker.sock:/var/run/docker.sock)
fi

findings=()
failures=()
for ref in "$@"; do
	file="$(printf '%s' "$ref" | tr '/:@' '___')"
	echo "==> Scanning ${ref}"

	# Reports go to stdout and are written by this shell, so the root-owned
	# container never creates files in the (Jenkins) workspace.
	if ! docker run "${docker_args[@]}" "$SCAN_TRIVY_IMAGE" \
		image --format json "$ref" >"${report_dir}/${file}.json"; then
		echo "!! Trivy could not scan ${ref}" >&2
		rm -f "${report_dir}/${file}.json"
		failures+=("$ref")
		continue
	fi

	status=0
	docker run "${docker_args[@]}" -v "${report_dir}:/reports:ro" "$SCAN_TRIVY_IMAGE" \
		convert --format table --table-mode detailed --exit-code "$FINDINGS_EXIT_CODE" "/reports/${file}.json" \
		| tee "${report_dir}/${file}.txt" || status=$?
	case "$status" in
		0) ;;
		"$FINDINGS_EXIT_CODE") findings+=("$ref") ;;
		*)
			echo "!! Trivy could not render the report for ${ref}" >&2
			failures+=("$ref")
			;;
	esac
done

echo
echo "Trivy summary (severity ${TRIVY_SEVERITY}, ignore unfixed: ${TRIVY_IGNORE_UNFIXED}):"
echo "  scanned:      $#"
echo "  with issues:  ${#findings[@]}"
for ref in ${findings[@]+"${findings[@]}"}; do echo "    - ${ref}"; done
echo "  scan errors:  ${#failures[@]}"
for ref in ${failures[@]+"${failures[@]}"}; do echo "    - ${ref}"; done
echo "  reports:      ${report_dir}"

if [ "${#failures[@]}" -gt 0 ]; then
	exit 1
fi
if [ "${#findings[@]}" -gt 0 ]; then
	exit "$FINDINGS_EXIT_CODE"
fi
