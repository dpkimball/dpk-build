# Architecture

`dpk-build` is a Rust CLI that orchestrates deliver. Language-specific heavy lifting for image and deploy still lives in shell scripts under `python/` and `rust/`.

## Deliver flow

```
make b
  → Makefile.common
  → dpk-build deliver
  → lint → test → build → image → deploy → verify
```

`CI=true` adds `--skip-image --skip-deploy`.

## Source layout (`src/`)

| Module | Role |
|--------|------|
| `main.rs` / `cli.rs` | clap dispatch, Ctrl-C → exit 130 |
| `context.rs` | `BUILD_ROOT`, `dpk.toml`, language detection, `RunContext` |
| `env_resolver.rs` | Source `BUILD_ROOT/env.sh` then `<project>/env.sh` |
| `skip.rs` | CLI > env > `[skip]` (deliver only) |
| `config/project.rs` | `dpk.toml` schema |
| `config/workspace.rs` | `dpk-workspace.toml` allowlist + named projects |
| `phases/*` | One module per phase |
| `maven.rs` | Java: local `mvn` or Docker Maven |
| `cluster.rs` | kubectl context → cluster type (allowlist check) |
| `executor.rs` | Process spawn, timeouts, cancel |
| `output.rs` | Single JSON line on stdout |
| `commands/deliver.rs` | Phase loop + `previous_phase_failed` |
| `commands/doctor.rs` / `version.rs` | Tool checks; version show/bump |

## Scripts invoked by phases

| Language | lint / test / build | image | deploy |
|----------|---------------------|-------|--------|
| Python | CLI (`uv` / pytest / `python/build-wheel.sh`) | `python/build-docker.sh` | `python/deploy-k8s.sh` |
| Rust | CLI (`cargo clippy` / `test` / `build --release`) | `rust/build-docker.sh` | `rust/deploy-k8s.sh` |
| Java | CLI → `maven.rs` | `python/build-docker.sh` | `python/deploy-k8s.sh` |
| Node | **not supported** (fails the phase; skip via `[skip]` / CLI) | `python/build-docker.sh` | `python/deploy-k8s.sh` |

Deploy scripts call `shared/detect-cluster.sh` for Kind / minikube image load. The Rust allowlist check also treats kubectl context `dev` like Rancher Desktop (shared daemon).

## Config files

| File | Where | Purpose |
|------|-------|---------|
| `dpk.toml` | project root | language, skip, docker, deploy, verify, timeouts |
| `dpk-workspace.toml` | workspace root (or `WORKSPACE_ROOT`) | deploy context allowlist; optional `[projects]` |
| `Makefile.common` | this repo | `make b` → deliver |
| `env.sh` / `paths.sh` | this repo | shared paths; optional project `env.sh` overrides |

## Tests

- Unit: alongside modules under `src/` (language → image/deploy script matrix)
- Integration: `tests/integration/` (skip, lock, dry-run, doctor, JSON, Node skip-lint deliver)
- Shell (CI, no sibling checkout required):
  - `tests/shell/paths-env-matrix.sh`
  - `tests/shell/makefile-build-root-guard.sh`
  - `tests/shell/script-dir-survives-project-env.sh`
  - `tests/shell/consumer-contract.sh` — python / rust / java / node fixtures, including an `env.sh` that sets `SCRIPT_DIR`
- Shell (local workspace only): `tests/shell/workspace-consumer-dry-run.sh` — walks sibling `dpk.toml` trees; **skips in GitHub CI**
