# Docker Runtime Config

`build_image.sh` and `make_container.sh` read one local runtime file:
`config/runtime.env`.

## Setup

Create the local runtime file from the shared example:

```bash
cp config/runtime.env.example config/runtime.env
vim config/runtime.env
chmod 600 config/runtime.env
```

The real `config/runtime.env` is intentionally ignored by git because it may
contain credentials.

## Runtime Settings

Image build settings, container runtime settings, volumes, ports, and optional
auth values are managed in `config/runtime.env`.

```bash
IMAGE_NAME=jaehee-base:0404
DOCKERFILE_PATH=Dockerfile
BUILD_CONTEXT_DIR=.
NO_CACHE=0

CONTAINER_NAME=jaehee-contaccum-refine
AUTO_RECREATE=0
WORKSPACE_DIR=/workspace
VOLUMES="/home/jaeheekim/codes:/workspace /media/data:/data"
EXTRA_VOLUMES=
PORTS=9204:9204
MOUNT_DOCKER_SOCKET=1

GITHUB_TOKEN=
GH_TOKEN=
HF_TOKEN=
HUGGINGFACE_TOKEN=
WANDB_API_KEY=
```

`DOCKERFILE_PATH` and `BUILD_CONTEXT_DIR` may be absolute paths or paths relative
to the repository root. Build the image with:

```bash
bash build_image.sh
```

Use whitespace or commas for multiple entries, e.g.:

```bash
PORTS="9204:9204 7860:7860"
EXTRA_VOLUMES="/tmp:/tmp,/scratch:/scratch"
```

Start or attach to the container with:

```bash
bash make_container.sh
```

If you change `VOLUMES`, `PORTS`, or `WORKSPACE_DIR` after a container has
already been created, remove and recreate the container:

```bash
docker rm -f jaehee-contaccum-refine
bash make_container.sh
```

Alternatively, recreate it in one command:

```bash
AUTO_RECREATE=1 bash make_container.sh
```

Auth values are passed from `runtime.env` through `docker run` and `docker exec`
each time. Existing containers receive updated auth values on the next attach,
but volume, port, and working-directory changes still require recreation.

`MOUNT_DOCKER_SOCKET=1` mounts the host Docker daemon socket and adds the socket
group to the dev container. This is required for helper scripts that start
sibling containers.

## Optional Research Memory Access

The Dolphin container can use the central research-memory service without
copying an SSH key into the image. `config/runtime.env` needs only one setting:

```bash
RESEARCH_MEMORY_ROOT=/absolute/path/to/research-memory-dolphin
```

Leave it blank to disable shared memory. The root is a private local directory
with this fixed layout:

```text
research-memory-dolphin/
  client/        -> track-research-history/client
  client.json    -> non-secret profile configuration
  id_ed25519     -> project-scoped RPC private key
  known_hosts    -> verified SSH host keys
  ssh_config     -> optional, only for SSH aliases such as Local
```

Create this layout once without copying key material:

```bash
scripts/research-memory-init \
  --root "$HOME/.config/dolphin/research-memory" \
  --client /absolute/path/to/track-research-history/client \
  --config /absolute/path/to/client.json
```

The script resolves the config's default profile and links its key,
`known_hosts`, and optional SSH config. To switch a multi-profile config at
setup time, add `--profile NAME`; it becomes the config's default. One root is
one active project key. Use a separate root and a separate Dolphin container
when a different project key is needed.

At start, Dolphin follows each link on the host and individually mounts only
the resolved client, config, key, `known_hosts`, and optional SSH config as
read-only files. It never mounts the root directory as a whole.

`known_hosts` is intentionally required. Do not work around a host-key failure
with `StrictHostKeyChecking=no`; update or verify the host key instead. A
profile that supplies SSH options should retain `StrictHostKeyChecking=yes`.

The profile config's `default_profile` selects the project; no profile or key
path needs to be placed in `runtime.env`. Inside the container:

```bash
research-memory note list
research-memory note search "ablation"
```

Docker cannot add or remove bind mounts from an already-created container. On
the first migration to this layout, or whenever the root's resolved targets
change, rebuild and recreate once:

```bash
bash build_image.sh
AUTO_RECREATE=1 bash make_container.sh
```

The earlier enable/profile/individual-path variables are no longer read. This
setup does not alter the memory server, project permissions, or SSH host-key
policy. If `MOUNT_DOCKER_SOCKET=1`, use only a project-scoped forced-command
key and do not give an untrusted agent this container: Docker socket access can
otherwise undercut ordinary bind-mount isolation.

Legacy `config/.tokens`, `config/github/token`, `config/huggingface/token`, and
`config/runtime_tmp.env` files are no longer read by the scripts.
