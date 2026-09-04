#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_CONFIG_FILE="${SCRIPT_DIR}/config/runtime.env"
RECREATE=0
ATTACH=1

usage() {
  cat <<'EOF'
Usage: make_container.sh [--recreate] [--no-attach]

Create or reuse the Dolphin container, then open a login shell.
  --recreate   Remove and recreate an existing container.
  --no-attach  Leave the container running without opening a shell.
EOF
}

while (($#)); do
  case "$1" in
    --recreate) RECREATE=1 ;;
    --no-attach) ATTACH=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ ! -f "${RUNTIME_CONFIG_FILE}" ]]; then
  echo "Error: missing runtime config file: ${RUNTIME_CONFIG_FILE}" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${RUNTIME_CONFIG_FILE}"
set +a

IMAGE_NAME="${IMAGE_NAME:?IMAGE_NAME must be set in ${RUNTIME_CONFIG_FILE}}"
CONTAINER_NAME="${CONTAINER_NAME:?CONTAINER_NAME must be set in ${RUNTIME_CONFIG_FILE}}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
VOLUMES="${VOLUMES:-}"
PORTS="${PORTS:-}"
MOUNT_DOCKER_SOCKET="${MOUNT_DOCKER_SOCKET:-0}"

# Accept the old aliases without exposing two copies inside the container.
GITHUB_TOKEN_VALUE="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
HF_TOKEN_VALUE="${HF_TOKEN:-${HUGGINGFACE_TOKEN:-}}"
WANDB_API_KEY_VALUE="${WANDB_API_KEY:-}"
DSBA_LITELLM_API_KEY_VALUE="${DSBA_LITELLM_API_KEY:-}"

CREATE_ARGS=(
  -d
  --gpus all
  --ipc=host
  --name "${CONTAINER_NAME}"
  --hostname "${CONTAINER_NAME}"
  -w "${WORKSPACE_DIR}"
)

append_list() {
  local flag="$1"
  local raw="${2//,/ }"
  local item

  for item in ${raw}; do
    [[ -n "${item}" ]] && CREATE_ARGS+=("${flag}" "${item}")
  done
}

validate_volume_hosts() {
  local raw="${1//,/ }"
  local volume host_path

  for volume in ${raw}; do
    host_path="${volume%%:*}"
    if [[ "${host_path}" = /* && ! -e "${host_path}" ]]; then
      echo "Error: volume host path does not exist: ${host_path}" >&2
      exit 1
    fi
  done
}

validate_volume_hosts "${VOLUMES}"
append_list -v "${VOLUMES}"
append_list -p "${PORTS}"

case "${MOUNT_DOCKER_SOCKET}" in
  0) ;;
  1)
    if [[ ! -S /var/run/docker.sock ]]; then
      echo "Error: MOUNT_DOCKER_SOCKET=1 but /var/run/docker.sock is unavailable." >&2
      exit 1
    fi
    CREATE_ARGS+=(
      -v /var/run/docker.sock:/var/run/docker.sock
      --group-add "$(stat -c '%g' /var/run/docker.sock)"
    )
    ;;
  *)
    echo "Error: MOUNT_DOCKER_SOCKET must be 0 or 1." >&2
    exit 1
    ;;
esac

container_exists() {
  docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1
}

if ((RECREATE)) && container_exists; then
  docker rm -f "${CONTAINER_NAME}" >/dev/null
fi

if ! container_exists; then
  docker run "${CREATE_ARGS[@]}" "${IMAGE_NAME}" sleep infinity >/dev/null
else
  echo "Reusing existing container: ${CONTAINER_NAME}" >&2
  echo "Use --recreate after changing volumes, ports, or the image." >&2
fi

if [[ "$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}")" != "true" ]]; then
  docker start "${CONTAINER_NAME}" >/dev/null
fi

if ! docker exec "${CONTAINER_NAME}" test -d "${WORKSPACE_DIR}"; then
  echo "Error: WORKSPACE_DIR does not exist in ${CONTAINER_NAME}: ${WORKSPACE_DIR}" >&2
  echo "Recreate it with: bash make_container.sh --recreate" >&2
  exit 1
fi

if [[ -n "${DSBA_LITELLM_API_KEY_VALUE}" ]]; then
  printf '%s' "${DSBA_LITELLM_API_KEY_VALUE}" | docker exec -i "${CONTAINER_NAME}" \
    sh -c 'umask 077; mkdir -p "$HOME/.config"; cat > "$HOME/.config/dsba-litellm.key"'
fi

if ((!ATTACH)); then
  echo "Container is running: ${CONTAINER_NAME}"
  exit 0
fi

SESSION_ARGS=(
  -e "TERM=${TERM:-xterm-256color}"
  -e "COLORTERM=${COLORTERM:-truecolor}"
  -e "TERM_PROGRAM=${TERM_PROGRAM:-}"
)
[[ -n "${GITHUB_TOKEN_VALUE}" ]] && SESSION_ARGS+=(-e "GITHUB_TOKEN=${GITHUB_TOKEN_VALUE}")
[[ -n "${HF_TOKEN_VALUE}" ]] && SESSION_ARGS+=(-e "HF_TOKEN=${HF_TOKEN_VALUE}")
[[ -n "${WANDB_API_KEY_VALUE}" ]] && SESSION_ARGS+=(-e "WANDB_API_KEY=${WANDB_API_KEY_VALUE}")
[[ -n "${DSBA_LITELLM_API_KEY_VALUE}" ]] && SESSION_ARGS+=(-e "DSBA_LITELLM_API_KEY=${DSBA_LITELLM_API_KEY_VALUE}")

docker exec -it \
  "${SESSION_ARGS[@]}" \
  -w "${WORKSPACE_DIR}" \
  "${CONTAINER_NAME}" \
  zsh -lc 'if [[ -n "${GITHUB_TOKEN:-}" ]]; then gh auth setup-git >/dev/null 2>&1 || true; fi; exec zsh -l'
