# New project quickstart

Copy both files to your project root:

```bash
cp $KEEPSAKE_SCRIPTS_ROOT/templates/Makefile   ./Makefile
cp $KEEPSAKE_SCRIPTS_ROOT/templates/env.sh     ./env.sh
chmod +x env.sh
```

Then edit two things:

**`Makefile`**
- Set `KEEPSAKE_SCRIPTS_ROOT` depth (`../` for a top-level repo, `../../` for a sub-project)
- Set `INTERNAL_PKGS` to the space-separated list of internal packages this project depends on (leave empty if none)

**`env.sh`**
- Set `IMAGE_NAME`, `HELM_RELEASE`, `HELM_CHART_PATH` (services) or leave `IMAGE_NAME=""` (libraries)
- Delete the block that doesn't apply (service OR library)
- Set `K8S_NAMESPACE="dagster"` if this is a Dagster code location

That's it. `make b` runs the full build cycle.

## Standard targets (from `Makefile.common`)

| Target | What it does |
|--------|-------------|
| `make b` | Full cycle: update-versions → sync → lint → test → build → deploy |
| `make test` | Run tests only |
| `make lint` | Run linter only |
| `make clean` | Remove `.venv`, `dist/`, build artefacts |
| `make update-versions` | Bump `INTERNAL_PKGS` to latest from local PyPI |
| `make deploy-local` | Push wheel to local PyPI (libraries only) |
| `make help` | List all available targets |

## Skipping phases

Override any `SKIP_*` flag inline:

```bash
SKIP_TESTS=true make b        # skip tests this run
SKIP_LINT=true  make b        # skip lint this run
```

Permanent overrides belong in `env.sh`.
