#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_CONFIG_FILE="${SCRIPT_DIR}/runtime.env"
LEGACY_RUNTIME_CONFIG_FILE="${SCRIPT_DIR}/config/runtime.env"
NO_CACHE=0

usage() {
  cat <<'EOF'
Usage: build_image.sh [--no-cache]

Build the Dolphin image configured by runtime.env.
EOF
}

while (($#)); do
  case "$1" in
    --no-cache) NO_CACHE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ ! -f "${RUNTIME_CONFIG_FILE}" && -f "${LEGACY_RUNTIME_CONFIG_FILE}" ]]; then
  mv "${LEGACY_RUNTIME_CONFIG_FILE}" "${RUNTIME_CONFIG_FILE}"
  echo "Moved legacy config/runtime.env to runtime.env." >&2
fi

if [[ ! -f "${RUNTIME_CONFIG_FILE}" ]]; then
  echo "Error: missing runtime config file: ${RUNTIME_CONFIG_FILE}" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${RUNTIME_CONFIG_FILE}"
set +a

IMAGE_NAME="${IMAGE_NAME:?IMAGE_NAME must be set in ${RUNTIME_CONFIG_FILE}}"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
HOST_USER="$(whoami)"
GIT_NAME="$(git config --global user.name 2>/dev/null || printf '%s' 'Codex User')"
GIT_EMAIL="$(git config --global user.email 2>/dev/null || printf '%s' 'codex@example.com')"

BUILD_ARGS=(--progress=plain)
if ((NO_CACHE)); then
  BUILD_ARGS+=(--no-cache)
fi

docker build \
  "${BUILD_ARGS[@]}" \
  --build-arg UID="${HOST_UID}" \
  --build-arg GID="${HOST_GID}" \
  --build-arg USERNAME="${HOST_USER}" \
  --build-arg GIT_NAME="${GIT_NAME}" \
  --build-arg GIT_EMAIL="${GIT_EMAIL}" \
  -t "${IMAGE_NAME}" \
  -f "${SCRIPT_DIR}/Dockerfile" \
  "${SCRIPT_DIR}"
