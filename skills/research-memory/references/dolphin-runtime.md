# Dolphin runtime connection

The host's ignored `config/runtime.env` has one optional setting:

```bash
RESEARCH_MEMORY_ROOT=/absolute/path/to/research-memory-dolphin
```

An empty value disables shared memory. The root must contain fixed-name links
to one active profile's client, configuration, key, and host verification:

```text
client/  client.json  id_ed25519  known_hosts  [ssh_config]
```

Create it once on the Docker host without copying key material:

```bash
scripts/research-memory-init \
  --root "$HOME/.config/dolphin/research-memory" \
  --client /absolute/path/to/track-research-history/client \
  --config /absolute/path/to/client.json
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
