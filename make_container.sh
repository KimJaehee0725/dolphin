#!/usr/bin/env bash
set -euo pipefail

##### env-overridable settings #####
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_CONFIG_DIR="${SCRIPT_DIR}/config"
RUNTIME_CONFIG_FILE="${DOCKER_CONFIG_DIR}/runtime.env"
RESEARCH_MEMORY_CONFIG_FILE="${DOCKER_CONFIG_DIR}/research-memory.env"
AUTO_RECREATE_OVERRIDE="${AUTO_RECREATE-}"

if [[ ! -f "${RUNTIME_CONFIG_FILE}" ]]; then
  echo "Error: missing runtime config file: ${RUNTIME_CONFIG_FILE}" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${RUNTIME_CONFIG_FILE}"
set +a

# This optional local-only overlay is written by research-memory-enable. It
# contains only the path to a host-side connection bundle, never key contents.
if [[ -f "${RESEARCH_MEMORY_CONFIG_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${RESEARCH_MEMORY_CONFIG_FILE}"
  set +a
fi

IMAGE_NAME="${IMAGE_NAME:?IMAGE_NAME must be set in ${RUNTIME_CONFIG_FILE}}"
CONTAINER_NAME="${CONTAINER_NAME:?CONTAINER_NAME must be set in ${RUNTIME_CONFIG_FILE}}"
if [[ -n "${AUTO_RECREATE_OVERRIDE}" ]]; then
  AUTO_RECREATE="${AUTO_RECREATE_OVERRIDE}"
else
  AUTO_RECREATE="${AUTO_RECREATE:-0}"
fi

# Whitespace- or comma-separated lists.
# Example:
#   PORTS="9204:9204 7860:7860"
#   VOLUMES="/home/jaeheekim/codes:/workspace /media/data:/data"
PORTS="${PORTS:?PORTS must be set in ${RUNTIME_CONFIG_FILE}}"
VOLUMES="${VOLUMES:?VOLUMES must be set in ${RUNTIME_CONFIG_FILE}}"
EXTRA_VOLUMES="${EXTRA_VOLUMES:-}"
WORKSPACE_DIR="${WORKSPACE_DIR:?WORKSPACE_DIR must be set in ${RUNTIME_CONFIG_FILE}}"
MOUNT_DOCKER_SOCKET="${MOUNT_DOCKER_SOCKET:-0}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GH_TOKEN="${GH_TOKEN:-}"
HF_TOKEN="${HF_TOKEN:-}"
HUGGINGFACE_TOKEN="${HUGGINGFACE_TOKEN:-}"
WANDB_API_KEY="${WANDB_API_KEY:-}"

# Optional, project-scoped research-memory client. A non-empty root has a
# fixed, symlink-friendly layout; private-key contents stay outside runtime.env.
RESEARCH_MEMORY_ROOT="${RESEARCH_MEMORY_ROOT:-}"
RESEARCH_MEMORY_ENABLED=0
if [[ -n "${RESEARCH_MEMORY_ROOT}" ]]; then
  RESEARCH_MEMORY_ENABLED=1
fi
RESEARCH_MEMORY_CLIENT_DIR=""
RESEARCH_MEMORY_CONFIG=""
RESEARCH_MEMORY_IDENTITY_FILE=""
RESEARCH_MEMORY_KNOWN_HOSTS=""
RESEARCH_MEMORY_SSH_CONFIG=""
####################################

RESEARCH_MEMORY_CONTAINER_DIR="/run/research-memory"
RESEARCH_MEMORY_CONTAINER_CLIENT_DIR="/opt/research-memory-client"
RESEARCH_MEMORY_CONTAINER_CONFIG="${RESEARCH_MEMORY_CONTAINER_DIR}/client.json"
RESEARCH_MEMORY_CONTAINER_IDENTITY="${RESEARCH_MEMORY_CONTAINER_DIR}/id_ed25519"
RESEARCH_MEMORY_CONTAINER_KNOWN_HOSTS="${RESEARCH_MEMORY_CONTAINER_DIR}/known_hosts"
RESEARCH_MEMORY_CONTAINER_SSH_CONFIG="${RESEARCH_MEMORY_CONTAINER_DIR}/ssh_config"
RESEARCH_MEMORY_LAYOUT="v2"

TERM_VALUE="${TERM:-xterm-256color}"
COLORTERM_VALUE="${COLORTERM:-truecolor}"
TERM_PROGRAM_VALUE="${TERM_PROGRAM:-}"

ENV_ARGS=(
  -e "TERM=${TERM_VALUE}"
  -e "COLORTERM=${COLORTERM_VALUE}"
  -e "TERM_PROGRAM=${TERM_PROGRAM_VALUE}"
  -e "GITHUB_TOKEN=${GITHUB_TOKEN}"
  -e "GH_TOKEN=${GH_TOKEN}"
  -e "HF_TOKEN=${HF_TOKEN}"
  -e "HUGGINGFACE_TOKEN=${HUGGINGFACE_TOKEN}"
  -e "WANDB_API_KEY=${WANDB_API_KEY}"
)
MOUNT_ARGS=()
PORT_ARGS=()
EXTRA_DOCKER_ARGS=()
RESEARCH_MEMORY_MOUNTS=()

add_list_args() {
  local flag="$1"
  local raw="${2//,/ }"
  local item

  for item in ${raw}; do
    [[ -n "${item}" ]] && "$3" "${flag}" "${item}"
  done
}

append_mount_arg() {
  local flag="$1"
  local value="$2"
  MOUNT_ARGS+=("${flag}" "${value}")
}

append_port_arg() {
  local flag="$1"
  local value="$2"
  PORT_ARGS+=("${flag}" "${value}")
}

die() {
  echo "Error: $*" >&2
  exit 1
}

absolute_research_memory_file() {
  local label="$1"
  local candidate="$2"
  local link_target

  [[ -n "${candidate}" ]] || die "${label} must be set when RESEARCH_MEMORY_ENABLED=1"
  if [[ "${candidate}" == "~/"* ]]; then
    candidate="${HOME}/${candidate:2}"
  fi
  if [[ "${candidate}" == *$'\n'* || "${candidate}" == *$'\r'* || \
        "${candidate}" == *$'\t'* || "${candidate}" == *,* ]]; then
    die "${label} path contains an unsupported character"
  fi
  while [[ -L "${candidate}" ]]; do
    link_target="$(readlink "${candidate}")" || die "cannot resolve ${label}: ${candidate}"
    if [[ "${link_target}" == /* ]]; then
      candidate="${link_target}"
    else
      candidate="$(dirname -- "${candidate}")/${link_target}"
    fi
  done
  [[ -f "${candidate}" ]] || die "${label} must be an existing file: ${candidate}"
  (
    cd -P -- "$(dirname -- "${candidate}")"
    printf '%s/%s\n' "$(pwd -P)" "$(basename -- "${candidate}")"
  )
}

absolute_research_memory_dir() {
  local label="$1"
  local candidate="$2"

  [[ -n "${candidate}" ]] || die "${label} must be set when RESEARCH_MEMORY_ENABLED=1"
  if [[ "${candidate}" == "~/"* ]]; then
    candidate="${HOME}/${candidate:2}"
  fi
  if [[ "${candidate}" == *$'\n'* || "${candidate}" == *$'\r'* || \
        "${candidate}" == *$'\t'* || "${candidate}" == *,* ]]; then
    die "${label} path contains an unsupported character"
  fi
  [[ -d "${candidate}" ]] || die "${label} must be an existing directory: ${candidate}"
  (
    cd -P -- "${candidate}"
    pwd -P
  )
}

append_research_memory_mount() {
  local source="$1"
  local destination="$2"

  append_mount_arg --mount "type=bind,src=${source},dst=${destination},readonly"
  RESEARCH_MEMORY_MOUNTS+=("${source}"$'\t'"${destination}")
}

configure_research_memory() {
  [[ "${RESEARCH_MEMORY_ENABLED}" == "1" ]] || return

  RESEARCH_MEMORY_ROOT="$(absolute_research_memory_dir \
    RESEARCH_MEMORY_ROOT "${RESEARCH_MEMORY_ROOT}")"

  RESEARCH_MEMORY_CLIENT_DIR="$(absolute_research_memory_dir \
    RESEARCH_MEMORY_ROOT/client "${RESEARCH_MEMORY_ROOT}/client")"
  [[ -f "${RESEARCH_MEMORY_CLIENT_DIR}/memctl.py" ]] || \
    die "RESEARCH_MEMORY_ROOT/client must contain memctl.py: ${RESEARCH_MEMORY_CLIENT_DIR}"
  [[ -f "${RESEARCH_MEMORY_CLIENT_DIR}/profiles.py" ]] || \
    die "RESEARCH_MEMORY_ROOT/client must contain profiles.py: ${RESEARCH_MEMORY_CLIENT_DIR}"
  RESEARCH_MEMORY_CONFIG="$(absolute_research_memory_file \
    RESEARCH_MEMORY_ROOT/client.json "${RESEARCH_MEMORY_ROOT}/client.json")"
  RESEARCH_MEMORY_IDENTITY_FILE="$(absolute_research_memory_file \
    RESEARCH_MEMORY_ROOT/id_ed25519 "${RESEARCH_MEMORY_ROOT}/id_ed25519")"
  RESEARCH_MEMORY_KNOWN_HOSTS="$(absolute_research_memory_file \
    RESEARCH_MEMORY_ROOT/known_hosts "${RESEARCH_MEMORY_ROOT}/known_hosts")"
  if [[ -e "${RESEARCH_MEMORY_ROOT}/ssh_config" || -L "${RESEARCH_MEMORY_ROOT}/ssh_config" ]]; then
    RESEARCH_MEMORY_SSH_CONFIG="$(absolute_research_memory_file \
      RESEARCH_MEMORY_ROOT/ssh_config "${RESEARCH_MEMORY_ROOT}/ssh_config")"
  fi

  append_research_memory_mount \
    "${RESEARCH_MEMORY_CLIENT_DIR}" "${RESEARCH_MEMORY_CONTAINER_CLIENT_DIR}"
  append_research_memory_mount \
    "${RESEARCH_MEMORY_CONFIG}" "${RESEARCH_MEMORY_CONTAINER_CONFIG}"
  append_research_memory_mount \
    "${RESEARCH_MEMORY_IDENTITY_FILE}" "${RESEARCH_MEMORY_CONTAINER_IDENTITY}"
  append_research_memory_mount \
    "${RESEARCH_MEMORY_KNOWN_HOSTS}" "${RESEARCH_MEMORY_CONTAINER_KNOWN_HOSTS}"
  if [[ -n "${RESEARCH_MEMORY_SSH_CONFIG}" ]]; then
    append_research_memory_mount \
      "${RESEARCH_MEMORY_SSH_CONFIG}" "${RESEARCH_MEMORY_CONTAINER_SSH_CONFIG}"
  fi

  # The mounted config supplies host/user/default-profile details. The path
  # overrides below make it use only the in-container read-only files.
  ENV_ARGS+=(
    -e "RESEARCH_MEMORY_ENABLED=1"
    -e "RESEARCH_MEMORY_LAYOUT=${RESEARCH_MEMORY_LAYOUT}"
    -e "RESEARCH_MEMORY_MEMCTL=${RESEARCH_MEMORY_CONTAINER_CLIENT_DIR}/memctl.py"
    -e "RESEARCH_MEMORY_PROFILE="
    -e "MEMORY_PROFILE="
    -e "MEMORY_CONFIG=${RESEARCH_MEMORY_CONTAINER_CONFIG}"
    -e "MEMORY_IDENTITY_FILE=${RESEARCH_MEMORY_CONTAINER_IDENTITY}"
    -e "MEMORY_KNOWN_HOSTS=${RESEARCH_MEMORY_CONTAINER_KNOWN_HOSTS}"
  )
  if [[ -n "${RESEARCH_MEMORY_SSH_CONFIG}" ]]; then
    ENV_ARGS+=(-e "MEMORY_SSH_CONFIG=${RESEARCH_MEMORY_CONTAINER_SSH_CONFIG}")
  fi
}

existing_container_has_research_memory_mount() {
  local source="$1"
  local destination="$2"
  local mounted_source mounted_destination mounted_rw

  while IFS=$'\t' read -r mounted_source mounted_destination mounted_rw; do
    if [[ "${mounted_source}" == "${source}" && \
          "${mounted_destination}" == "${destination}" && \
          "${mounted_rw}" == "false" ]]; then
      return 0
    fi
  done < <(docker inspect -f '{{range .Mounts}}{{printf "%s\t%s\t%t\n" .Source .Destination .RW}}{{end}}' "${CONTAINER_NAME}")
  return 1
}

existing_container_has_any_research_memory_mount() {
  local mounted_destination

  while IFS= read -r mounted_destination; do
    case "${mounted_destination}" in
      "${RESEARCH_MEMORY_CONTAINER_CLIENT_DIR}"|"${RESEARCH_MEMORY_CONTAINER_DIR}"/*)
        return 0
        ;;
    esac
  done < <(docker inspect -f '{{range .Mounts}}{{printf "%s\\n" .Destination}}{{end}}' "${CONTAINER_NAME}")
  return 1
}

existing_container_has_research_memory_layout() {
  docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "${CONTAINER_NAME}" | \
    grep -Fxq "RESEARCH_MEMORY_LAYOUT=${RESEARCH_MEMORY_LAYOUT}"
}

validate_existing_research_memory_mounts() {
  if [[ "${RESEARCH_MEMORY_ENABLED}" != "1" ]]; then
    if existing_container_has_any_research_memory_mount; then
      echo "Error: existing container '${CONTAINER_NAME}' still has research-memory mounts while RESEARCH_MEMORY_ROOT is empty." >&2
      echo "Recreate it once to detach those mounts: AUTO_RECREATE=1 bash ${BASH_SOURCE[0]}" >&2
      exit 1
    fi
    return
  fi

  if ! existing_container_has_research_memory_layout; then
    echo "Error: existing container '${CONTAINER_NAME}' uses an older research-memory layout." >&2
    echo "Recreate it once with AUTO_RECREATE=1: AUTO_RECREATE=1 bash ${BASH_SOURCE[0]}" >&2
    exit 1
  fi

  local mount source destination
  local -a missing=()
  for mount in "${RESEARCH_MEMORY_MOUNTS[@]}"; do
    source="${mount%%$'\t'*}"
    destination="${mount#*$'\t'}"
    if ! existing_container_has_research_memory_mount "${source}" "${destination}"; then
      missing+=("${destination}")
    fi
  done

  if ((${#missing[@]})); then
    echo "Error: existing container '${CONTAINER_NAME}' does not have the required read-only research-memory mount(s): ${missing[*]}" >&2
    echo "Docker cannot add these mounts through docker exec." >&2
    echo "Recreate it once with AUTO_RECREATE=1: AUTO_RECREATE=1 bash ${BASH_SOURCE[0]}" >&2
    exit 1
  fi
}

docker_socket_gid() {
  if stat -c '%g' /var/run/docker.sock >/dev/null 2>&1; then
    stat -c '%g' /var/run/docker.sock
  else
    stat -f '%g' /var/run/docker.sock
  fi
}

CONTAINER_COMMAND=(zsh -lc "init-dev-auth >/dev/null 2>&1 || true; exec zsh -l")

validate_volume_hosts() {
  local raw="${1//,/ }"
  local volume host_path

  for volume in ${raw}; do
    [[ -z "${volume}" ]] && continue
    host_path="${volume%%:*}"
    if [[ "${host_path}" = /* && ! -e "${host_path}" ]]; then
      echo "Error: volume host path does not exist: ${host_path}" >&2
      exit 1
    fi
  done
}

validate_volume_hosts "${VOLUMES}"
validate_volume_hosts "${EXTRA_VOLUMES}"
configure_research_memory
add_list_args -v "${VOLUMES}" append_mount_arg
add_list_args -v "${EXTRA_VOLUMES}" append_mount_arg
add_list_args -p "${PORTS}" append_port_arg

if [[ "${MOUNT_DOCKER_SOCKET}" == "1" ]]; then
  if [[ ! -S /var/run/docker.sock ]]; then
    echo "Error: MOUNT_DOCKER_SOCKET=1 but /var/run/docker.sock is not available on host." >&2
    exit 1
  fi
  MOUNT_ARGS+=(-v /var/run/docker.sock:/var/run/docker.sock)
  DOCKER_SOCK_GID="$(docker_socket_gid)"
  EXTRA_DOCKER_ARGS+=(--group-add "${DOCKER_SOCK_GID}")
elif [[ "${MOUNT_DOCKER_SOCKET}" != "0" ]]; then
  echo "Error: MOUNT_DOCKER_SOCKET must be 0 or 1 in ${RUNTIME_CONFIG_FILE}" >&2
  exit 1
fi

# If the container already exists, reuse it.
if docker ps -a --format '{{.Names}}' | grep -Fxq "${CONTAINER_NAME}"; then
  echo "Reusing existing container: ${CONTAINER_NAME}" >&2
  echo "Note: changed VOLUMES/PORTS/WORKSPACE_DIR only apply after removing and recreating the container." >&2

  if [[ "${AUTO_RECREATE}" == "1" ]]; then
    docker rm -f "${CONTAINER_NAME}" >/dev/null
  else
    if ! docker inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
      echo "Error: container exists in docker ps output but cannot be inspected: ${CONTAINER_NAME}" >&2
      exit 1
    fi
    validate_existing_research_memory_mounts
    if ! docker start "${CONTAINER_NAME}" >/dev/null; then
      echo "Error: failed to start existing container: ${CONTAINER_NAME}" >&2
      echo "Remove it and rerun: docker rm -f ${CONTAINER_NAME}" >&2
      exit 1
    fi
    if ! docker exec -w / "${CONTAINER_NAME}" test -d "${WORKSPACE_DIR}"; then
      old_workdir="$(docker inspect -f '{{.Config.WorkingDir}}' "${CONTAINER_NAME}" 2>/dev/null || true)"
      echo "Error: WORKSPACE_DIR does not exist inside existing container: ${WORKSPACE_DIR}" >&2
      if [[ -n "${old_workdir}" ]]; then
        echo "Existing container image/workdir: ${old_workdir}" >&2
      fi
      echo "This usually means the container was created with old volume/workdir settings." >&2
      echo "Remove and recreate it: docker rm -f ${CONTAINER_NAME} && bash ${BASH_SOURCE[0]}" >&2
      echo "Or run once with AUTO_RECREATE=1: AUTO_RECREATE=1 bash ${BASH_SOURCE[0]}" >&2
      exit 1
    fi
  fi
fi

if docker ps -a --format '{{.Names}}' | grep -Fxq "${CONTAINER_NAME}"; then
  if [[ "$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}")" != "true" ]]; then
    docker start "${CONTAINER_NAME}" >/dev/null
  fi

  docker exec -it \
    "${ENV_ARGS[@]}" \
    -w "${WORKSPACE_DIR}" \
    "${CONTAINER_NAME}" \
    "${CONTAINER_COMMAND[@]}"

  exit 0
fi

DOCKER_ARGS=(
  -it
  --gpus all
  --ipc=host
  --name "${CONTAINER_NAME}"
  --hostname "${CONTAINER_NAME}"
  "${ENV_ARGS[@]}"
  "${MOUNT_ARGS[@]}"
  "${PORT_ARGS[@]}"
)
if ((${#EXTRA_DOCKER_ARGS[@]})); then
  DOCKER_ARGS+=("${EXTRA_DOCKER_ARGS[@]}")
fi
DOCKER_ARGS+=(-w "${WORKSPACE_DIR}")

docker run \
  "${DOCKER_ARGS[@]}" \
  "${IMAGE_NAME}" \
  "${CONTAINER_COMMAND[@]}"
