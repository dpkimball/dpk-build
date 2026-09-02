# New project quickstart

Lean **Makefile** + **`dpk.toml`** (no project `env.sh` required for deliver).

```bash
cp $BUILD_ROOT/templates/Makefile ./Makefile
# Add dpk.toml — see root README.md
```

Edit the Makefile:

- `BUILD_ROOT` depth (`../` or `../../`)
- `INTERNAL_PKGS` — space-separated internal PyPI packages to bump (or empty)

`make b` → `dpk-build deliver` (full cycle locally; lint/test/build when `CI=true`).

## Targets (`Makefile.common`)

| Target | What |
|--------|------|
| `make b` | `dpk-build deliver` |
| `make test` | Legacy root `test.sh` dispatcher |
| `make lint` | Legacy root `lint.sh` dispatcher |
| `make clean` | Remove `.venv`, `dist/`, build artefacts |
| `make update-versions` | Bump `INTERNAL_PKGS` from local PyPI |
| `make deploy-local` | Wheel → local PyPI |
| `make help` | List targets |

Prefer `dpk-build lint|test|…` or `make b` over the legacy `make lint` / `make test` shims when debugging a single phase.

## Skipping

`[skip]` in `dpk.toml`, or CLI/env flags in the root README.
