#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_CONFIG_FILE="${SCRIPT_DIR}/runtime.env"
LEGACY_RUNTIME_CONFIG_FILE="${SCRIPT_DIR}/config/runtime.env"
P10K_CONFIG_FILE="${SCRIPT_DIR}/p10k.zsh"

usage() {
  cat <<'EOF'
Usage: sync_p10k_config.sh export|import

export  Copy ~/.p10k.zsh from the running Dolphin container into this repository.
import  Copy this repository's p10k.zsh into the running Dolphin container.
EOF
}

if (($# != 1)); then
  usage >&2
  exit 2
fi

case "$1" in
  export|import) DIRECTION="$1" ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Error: expected export or import." >&2; usage >&2; exit 2 ;;
esac

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

CONTAINER_NAME="${CONTAINER_NAME:?CONTAINER_NAME must be set in ${RUNTIME_CONFIG_FILE}}"

if ! docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
  echo "Error: container does not exist: ${CONTAINER_NAME}" >&2
  exit 1
fi

if [[ "$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}")" != "true" ]]; then
  echo "Error: container is not running: ${CONTAINER_NAME}" >&2
  exit 1
fi

CONTAINER_HOME="$(docker exec "${CONTAINER_NAME}" sh -c 'printf %s "$HOME"')"
CONTAINER_UID="$(docker exec "${CONTAINER_NAME}" id -u)"
CONTAINER_GID="$(docker exec "${CONTAINER_NAME}" id -g)"

case "${DIRECTION}" in
  export)
    if ! docker exec "${CONTAINER_NAME}" test -f "${CONTAINER_HOME}/.p10k.zsh"; then
      echo "Error: p10k configuration is not present in ${CONTAINER_NAME}." >&2
      echo "Run p10k configure in the attached shell first." >&2
      exit 1
    fi
    docker cp "${CONTAINER_NAME}:${CONTAINER_HOME}/.p10k.zsh" "${P10K_CONFIG_FILE}"
    echo "Exported p10k configuration to ${P10K_CONFIG_FILE}"
    ;;
  import)
    docker cp "${P10K_CONFIG_FILE}" "${CONTAINER_NAME}:${CONTAINER_HOME}/.p10k.zsh"
    docker exec "${CONTAINER_NAME}" chown "${CONTAINER_UID}:${CONTAINER_GID}" "${CONTAINER_HOME}/.p10k.zsh"
    echo "Imported p10k configuration into ${CONTAINER_NAME}."
    echo "Detach and attach again to load it in the main shell."
    ;;
esac
