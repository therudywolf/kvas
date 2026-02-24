#!/usr/bin/env bash
# CI: build .ipk, run tests, validate package. Exit 0 only if all steps pass.
# Usage: ./scripts/ci.sh [--quick|--docker|--sdk]  or  CI_BUILD_MODE=docker ./scripts/ci.sh
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$(cd "${REPO_ROOT}" && mkdir -p "${OUTPUT_DIR:-output}" && cd "${OUTPUT_DIR:-output}" && pwd)"
APP_NAME=frt

# Build mode: from first arg or CI_BUILD_MODE env
mode="${1:-${CI_BUILD_MODE:-quick}}"
case "${mode}" in
  --quick|quick|--pack-only) build_mode="--quick" ;;
  --docker|docker) build_mode="--docker" ;;
  --sdk|sdk) build_mode="--sdk" ;;
  -h|--help)
    echo "Usage: $0 [--quick|--docker|--sdk]"
    echo "  --quick   Pack-only build (default)"
    echo "  --docker  Build via Docker"
    echo "  --sdk     Build via Entware SDK (TOPDIR)"
    echo "Env: CI_BUILD_MODE, OUTPUT_DIR"
    exit 0
    ;;
  *) echo "Unknown mode: ${mode}" >&2; exit 1 ;;
esac

echo "=== Step 1: Build .ipk (${build_mode}) ==="
mkdir -p "${OUTPUT_DIR}"
export OUTPUT_DIR
if ! ( cd "${REPO_ROOT}" && bash "${REPO_ROOT}/scripts/build-ipk.sh" ${build_mode} -o "${OUTPUT_DIR}" ); then
  echo "CI: build failed." >&2
  exit 1
fi

ipk=$(find "${OUTPUT_DIR}" -maxdepth 1 -name "${APP_NAME}_*.ipk" -type f 2>/dev/null | head -1)
if [ -z "${ipk}" ] || [ ! -f "${ipk}" ]; then
  echo "CI: .ipk not found in ${OUTPUT_DIR}" >&2
  exit 1
fi
echo "Built: ${ipk}"

echo "=== Step 2: Run tests ==="
if ! ( cd "${REPO_ROOT}" && sh "${REPO_ROOT}/tests/run_tests.sh" ); then
  echo "CI: tests failed." >&2
  exit 1
fi

echo "=== Step 3: Validate .ipk ==="
if ! command -v ar &>/dev/null; then
  echo "CI: ar not found, skip .ipk structure check."
else
  contents=$(ar t "${ipk}" 2>/dev/null || true)
  for want in debian-binary control.tar.gz data.tar.gz; do
    if ! echo "${contents}" | grep -q -F "${want}"; then
      echo "CI: .ipk missing member: ${want}" >&2
      exit 1
    fi
  done
  # Check control: Package and Architecture
  tmpdir=$(mktemp -d)
  trap "rm -rf '${tmpdir}'" EXIT
  ( cd "${tmpdir}" && ar x "${ipk}" && tar -xzf control.tar.gz ./control 2>/dev/null )
  if [ -f "${tmpdir}/control" ]; then
    grep -q "^Package: ${APP_NAME}" "${tmpdir}/control" || { echo "CI: control missing Package: ${APP_NAME}" >&2; exit 1; }
    grep -q "^Architecture: all" "${tmpdir}/control" || { echo "CI: control missing Architecture: all" >&2; exit 1; }
  fi
  rm -rf "${tmpdir}"
  trap - EXIT
fi

echo "=== Ready for upload. .ipk in ${OUTPUT_DIR}/ ==="
exit 0
