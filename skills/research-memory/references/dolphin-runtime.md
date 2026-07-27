# Dolphin runtime connection

## Personal password mode

For the simple personal-server workflow, put only these values in the ignored
Docker-host `config/runtime.env`:

```bash
RESEARCH_MEMORY_HOST=147.47.39.138
RESEARCH_MEMORY_USER=memory-rpc
RESEARCH_MEMORY_PASSWORD='set-this-locally'
# Optional. Empty means the agent asks which project memory to use.
RESEARCH_MEMORY_PROJECT=
```

No host-side key bundle or enable helper is needed in this mode. Dolphin passes
the values to each new container, and its bundled client uses password SSH with
host-key verification disabled. Never print or commit the real runtime file.

## Legacy project-key mode

The Docker host enables the optional project-key connection with:

```bash
scripts/research-memory-enable
```

It writes the ignored `config/research-memory.env` overlay. The root it creates
contains fixed-name links to one active profile's client, configuration, key,
and host verification:

```text
client/  client.json  id_ed25519  known_hosts  [ssh_config]
```

Pass explicit locations or choose a profile only when the defaults do not fit:

```bash
scripts/research-memory-enable \
  --root "$HOME/.config/dolphin/research-memory" \
  --client /absolute/path/to/track-research-history/client \
  --config /absolute/path/to/client.json \
  --profile project-rw
```

The profile config must have a `default_profile`. Use `--profile NAME` during
initialization to select one. Dolphin follows the host links, mounts each
resolved source read-only, and sets container-only `MEMORY_*` overrides. Do
not mount the root as a whole or change the selected profile in the container.

On first migration, rebuild the image and recreate the Dolphin container:

```bash
bash build_image.sh
AUTO_RECREATE=1 bash make_container.sh
```

Never place keys or `known_hosts` under version control, disable host-key
checking, or use a shared root for unrelated project keys.
