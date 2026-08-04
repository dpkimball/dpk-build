# New project quickstart

Aligned projects use a **lean Makefile** + **`dpk.toml`** (no project `env.sh`).

```bash
cp $BUILD_ROOT/templates/Makefile ./Makefile
# Add dpk.toml for language, [docker], [deploy], [skip] — see README.md
```

Then edit the Makefile:

- Set `BUILD_ROOT` depth (`../` for a top-level repo, `../../` for a sub-project)
- Set `INTERNAL_PKGS` to the space-separated list of internal packages this project depends on (leave empty if none)

`make b` runs `dpk-build deliver` (full cycle locally; lint/test/build only when `CI=true`).

## Standard targets (from `Makefile.common`)

| Target | What it does |
|--------|-------------|
| `make b` | Full cycle via `dpk-build deliver` |
| `make test` | Run tests only (language dispatcher) |
| `make lint` | Lint only |
| `make clean` | Remove `.venv`, `dist/`, build artefacts |
| `make update-versions` | Bump `INTERNAL_PKGS` to latest from local PyPI |
| `make deploy-local` | Push wheel to local PyPI (libraries) |
| `make help` | List available targets |

## Skipping phases

Prefer `[skip]` in `dpk.toml`, or CLI flags / env documented in the main README:

```bash
make b   # respects dpk.toml [skip] and CI=true image/deploy skip
```
