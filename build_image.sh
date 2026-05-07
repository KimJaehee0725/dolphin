#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR}"
DOCKER_CONFIG_DIR="${SCRIPT_DIR}/config"
RUNTIME_CONFIG_FILE="${DOCKER_CONFIG_DIR}/runtime.env"

if [[ ! -f "${RUNTIME_CONFIG_FILE}" ]]; then
  echo "Error: missing runtime config file: ${RUNTIME_CONFIG_FILE}" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${RUNTIME_CONFIG_FILE}"
set +a

IMAGE_NAME="${IMAGE_NAME:?IMAGE_NAME must be set in ${RUNTIME_CONFIG_FILE}}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:?DOCKERFILE_PATH must be set in ${RUNTIME_CONFIG_FILE}}"
BUILD_CONTEXT_DIR="${BUILD_CONTEXT_DIR:?BUILD_CONTEXT_DIR must be set in ${RUNTIME_CONFIG_FILE}}"
NO_CACHE="${NO_CACHE:?NO_CACHE must be set in ${RUNTIME_CONFIG_FILE}}"

resolve_repo_path() {
  local path="$1"
  if [[ "${path}" = /* ]]; then
    printf '%s\n' "${path}"
  else
    printf '%s/%s\n' "${REPO_DIR}" "${path}"
  fi
}

DOCKERFILE_PATH="$(resolve_repo_path "${DOCKERFILE_PATH}")"
BUILD_CONTEXT_DIR="$(resolve_repo_path "${BUILD_CONTEXT_DIR}")"

if [[ ! -f "${DOCKERFILE_PATH}" ]]; then
  echo "Error: Dockerfile does not exist: ${DOCKERFILE_PATH}" >&2
  exit 1
fi
if [[ ! -d "${BUILD_CONTEXT_DIR}" ]]; then
  echo "Error: build context directory does not exist: ${BUILD_CONTEXT_DIR}" >&2
  exit 1
fi
if [[ "${NO_CACHE}" != "0" && "${NO_CACHE}" != "1" ]]; then
  echo "Error: NO_CACHE must be 0 or 1 in ${RUNTIME_CONFIG_FILE}" >&2
  exit 1
fi

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
HOST_USER="$(whoami)"

GIT_NAME="$(git config --global user.name 2>/dev/null || echo "Jaehee Kim")"
GIT_EMAIL="$(git config --global user.email 2>/dev/null || echo "jaehee_kim@snu.ac.kr")"

BUILD_FLAGS=(--progress=plain)
if [[ "${NO_CACHE}" == "1" ]]; then
  BUILD_FLAGS+=(--no-cache)
fi

docker build \
  "${BUILD_FLAGS[@]}" \
  --build-arg UID="${HOST_UID}" \
  --build-arg GID="${HOST_GID}" \
  --build-arg USERNAME="${HOST_USER}" \
  --build-arg GIT_NAME="${GIT_NAME}" \
  --build-arg GIT_EMAIL="${GIT_EMAIL}" \
  -t "${IMAGE_NAME}" \
  -f "${DOCKERFILE_PATH}" \
  "${BUILD_CONTEXT_DIR}"
