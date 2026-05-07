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

Legacy `config/.tokens`, `config/github/token`, `config/huggingface/token`, and
`config/runtime_tmp.env` files are no longer read by the scripts.
