# Dolphin runtime connection

The connection is opt-in and configured only on the Docker host in the ignored
`config/runtime.env`. The values below are paths and a profile name, never key
contents:

```bash
RESEARCH_MEMORY_ENABLED=1
RESEARCH_MEMORY_PROFILE=project-rw
RESEARCH_MEMORY_CLIENT_DIR=/absolute/path/to/track-research-history/client
RESEARCH_MEMORY_CONFIG=/absolute/path/to/client.json
RESEARCH_MEMORY_IDENTITY_FILE=/absolute/path/to/project-key
RESEARCH_MEMORY_KNOWN_HOSTS=/absolute/path/to/known_hosts
# Set only when the profile uses an SSH host alias.
RESEARCH_MEMORY_SSH_CONFIG=/absolute/path/to/ssh_config
```

`make_container.sh` validates these paths, mounts the client/configuration/key
materials read-only, and exposes the container-only paths through
`MEMORY_*` variables. The selected profile may reference host paths in its JSON
configuration: those are intentionally overridden by the mounted container
paths at runtime.

If this connection is enabled after a Dolphin container already exists, or it
is disabled after an existing container had it, set `AUTO_RECREATE=1` once so
Docker can add or remove the required mounts. Rebuild the image after changing
the checked-in skill or wrapper:

```bash
bash build_image.sh
bash make_container.sh
```

The Docker host is responsible for key provisioning and host verification. Do
not place private keys, connection JSON, or `known_hosts` files under version
control.
