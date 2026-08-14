# Docker Runtime Config

Both helper scripts read the local-only `config/runtime.env`. Create it once:

```bash
cp config/runtime.env.example config/runtime.env
chmod 600 config/runtime.env
```

Only environment-specific values belong there:

```bash
IMAGE_NAME=jaehee-base:latest
CONTAINER_NAME=jaehee-dev
WORKSPACE_DIR=/workspace
VOLUMES="/home/jaeheekim/codes:/workspace/codes /data1/jaehee:/data1"
PORTS="9208:9208 9450:9450"
MOUNT_DOCKER_SOCKET=0

GITHUB_TOKEN=
HF_TOKEN=
WANDB_API_KEY=
```

Use whitespace or commas between multiple volume or port specifications. Empty
`VOLUMES` and `PORTS` values are allowed.

Build and run:

```bash
bash build_image.sh
bash make_container.sh
```

The Dockerfile and build context are fixed to this repository. Use
`bash build_image.sh --no-cache` only when the Docker cache must be discarded.

The container runs a small persistent `sleep infinity` process and the helper
opens shells with `docker exec`. Optional auth values are attached only to that
shell session, so they are not stored in the container's configured environment.
The old `GH_TOKEN` and `HUGGINGFACE_TOKEN` names remain accepted as aliases, but
new configs should use the canonical names above.

After changing the image, volumes, ports, working directory, or socket setting,
recreate without opening a shell:

```bash
bash make_container.sh --recreate --no-attach
```

Docker socket access is disabled by default. Set `MOUNT_DOCKER_SOCKET=1` only
when a trusted project really needs to control the host Docker daemon.

No research-history host, password, key, profile, service, database, or extra
mount belongs in `runtime.env`. The image contains the repository-local
`track-research-history` skill, and each project owns its Git-tracked
`history/*.md` files.
