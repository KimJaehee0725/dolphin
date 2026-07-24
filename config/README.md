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
copying an SSH key into the image. First create a project-scoped profile with
the `track-research-history` client's `memctl.py`. Then set these local-only
paths in `config/runtime.env`:

```bash
RESEARCH_MEMORY_ENABLED=1
RESEARCH_MEMORY_PROFILE=fab-gym-rw
RESEARCH_MEMORY_CLIENT_DIR=/absolute/path/to/track-research-history/client
RESEARCH_MEMORY_CONFIG=/absolute/path/to/.config/research-memory/client.json
RESEARCH_MEMORY_IDENTITY_FILE=/absolute/path/to/.ssh/research-memory-fab-gym-rw
RESEARCH_MEMORY_KNOWN_HOSTS=/absolute/path/to/.ssh/known_hosts
# Optional; set only when the profile's SSH host needs this file.
RESEARCH_MEMORY_SSH_CONFIG=/absolute/path/to/.ssh/config
```

All listed values are paths or a profile name. The private key remains in its
existing host file and is mounted read-only. When enabled, Dolphin validates
the client directory, JSON profile config, key, and `known_hosts` before it
starts Docker. It mounts them at fixed read-only container paths and exposes:

```bash
RESEARCH_MEMORY_MEMCTL=/opt/research-memory-client/memctl.py
MEMORY_PROFILE=<selected profile>
MEMORY_CONFIG=/run/research-memory/client.json
MEMORY_IDENTITY_FILE=/run/research-memory/id_ed25519
MEMORY_KNOWN_HOSTS=/run/research-memory/known_hosts
```

If `RESEARCH_MEMORY_SSH_CONFIG` is set, it is mounted read-only and exported as
`MEMORY_SSH_CONFIG=/run/research-memory/ssh_config`. Inside the container:

```bash
research-memory note list
research-memory note search "ablation"
```

`RESEARCH_MEMORY_KNOWN_HOSTS` is intentionally required. Do not work around a
host-key failure with `StrictHostKeyChecking=no`; update or verify the host key
instead. A profile that supplies SSH options should keep
`StrictHostKeyChecking=yes`.

Docker cannot add or remove bind mounts from an already-created container. If
you enable research memory, disable it after it was enabled, or change one of
its mounted paths, the script checks that the current container has the exact
required read-only mounts. If it does not, it stops with this safe one-time
recreation command:

```bash
AUTO_RECREATE=1 bash make_container.sh
```

This does not alter the memory server, project permissions, or SSH host-key
policy. `RESEARCH_MEMORY_ENABLED=0` remains the default and preserves the
normal Dolphin workflow.

Legacy `config/.tokens`, `config/github/token`, `config/huggingface/token`, and
`config/runtime_tmp.env` files are no longer read by the scripts.
