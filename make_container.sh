#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_CONFIG_FILE="${SCRIPT_DIR}/runtime.env"
LEGACY_RUNTIME_CONFIG_FILE="${SCRIPT_DIR}/config/runtime.env"
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
  # Keep one interactive login shell as PID 1 so `docker attach` opens a
  # usable shell instead of attaching to `sleep infinity`.
  docker run "${CREATE_ARGS[@]}" -i -t "${IMAGE_NAME}" zsh -il >/dev/null
else
  echo "Reusing existing container: ${CONTAINER_NAME}" >&2
  echo "Use --recreate after changing volumes, ports, or the image." >&2
fi

if [[ "$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}")" != "true" ]]; then
  docker start "${CONTAINER_NAME}" >/dev/null
fi

CONTAINER_COMMAND="$(docker inspect -f '{{range .Config.Cmd}}{{printf "%s " .}}{{end}}' "${CONTAINER_NAME}")"
if [[ "${CONTAINER_COMMAND}" != "zsh -il " ]]; then
  echo "Error: ${CONTAINER_NAME} uses the old non-interactive container command." >&2
  echo "Recreate it to enable docker attach: bash make_container.sh --recreate" >&2
  exit 1
fi

if ! docker exec "${CONTAINER_NAME}" test -d "${WORKSPACE_DIR}"; then
  echo "Error: WORKSPACE_DIR does not exist in ${CONTAINER_NAME}: ${WORKSPACE_DIR}" >&2
  echo "Recreate it with: bash make_container.sh --recreate" >&2
  exit 1
fi

sync_container_secret() {
  local value="$1"
  local filename="$2"

  if [[ -n "${value}" ]]; then
    printf '%s' "${value}" | docker exec -i "${CONTAINER_NAME}" \
      sh -c 'umask 077; mkdir -p "$HOME/.config/dolphin-auth"; chmod 700 "$HOME/.config/dolphin-auth"; cat > "$HOME/.config/dolphin-auth/$1"' \
      sh "${filename}"
  else
    docker exec "${CONTAINER_NAME}" \
      sh -c 'rm -f "$HOME/.config/dolphin-auth/$1"' sh "${filename}"
  fi
}

sync_container_secret "${GITHUB_TOKEN_VALUE}" github.token
sync_container_secret "${HF_TOKEN_VALUE}" huggingface.token
sync_container_secret "${WANDB_API_KEY_VALUE}" wandb.key
sync_container_secret "${DSBA_LITELLM_API_KEY_VALUE}" dsba-litellm.key

if [[ -n "${GITHUB_TOKEN_VALUE}" ]]; then
  docker exec "${CONTAINER_NAME}" zsh -fc \
    'export GITHUB_TOKEN="$(< "$HOME/.config/dolphin-auth/github.token")"; gh auth setup-git >/dev/null 2>&1 || true'
fi

if ((!ATTACH)); then
  echo "Container is running: ${CONTAINER_NAME}"
  exit 0
fi

echo "Attach with Ctrl-p Ctrl-q to leave the shell running." >&2
docker attach --detach-keys='ctrl-p,ctrl-q' "${CONTAINER_NAME}"
