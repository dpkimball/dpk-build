# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`dpk-build` is a shared build pipeline consumed by 10+ downstream repos. It provides the `dpk-build` Rust CLI binary that orchestrates lint → test → build → image → deploy → verify for Python, Rust, and Node projects. Downstream repos set `BUILD_ROOT` to point here and include `Makefile.common`.

**Changes here affect the entire ecosystem.** Shell scripts under `python/`, `rust/` are invoked by the CLI as legacy subprocess calls.

## Commands

Within this repo (CLI development):

```bash
cargo build --release          # build the binary
cargo test                     # unit tests
cargo test --test '*'          # integration tests
cargo clippy -- -D warnings    # lint
cargo fmt                      # format
./bootstrap.sh                 # build release binary, print path (used by Makefile.common)
shellcheck **/*.sh             # shell script lint (CI check)
```

In consuming repos:

```bash
make b                                        # full pipeline (local)
CI=true make b                                # lint + test + build only
SKIP_LINT=true SKIP_TESTS=true make b         # skip phases
FIRST_BUILD=1 make b                          # Python: init PyPI version to 0.0.1
uv run pytest tests/test_foo.py::test_fn      # Python: single test
```

## Architecture

### CLI dispatch (`src/`)

`src/main.rs` → `dispatch()` → per-command handlers in `src/commands/` and `src/phases/`.

- `cli.rs` — clap structs (`Cli`, `Command`, `VersionAction`)
- `context.rs` — `resolve()` builds `RunContext`: finds `BUILD_ROOT`, sources env files, loads `dpk.toml`, detects language
- `env_resolver.rs` — sources `BUILD_ROOT/env.sh` then `<project>/env.sh` via `bash -c 'set -a; source ...; env -0'`; project vars win
- `skip.rs` — `SkipFlags` with priority: CLI > env var > toml default; `read_env_skips()`, `resolve()`, `env_overrides_for_child()`
- `lock.rs` — per-project exclusive file lock via `nix::fcntl::Flock`; returns `AlreadyRunning` if held
- `cluster.rs` — `detect()` reads kubectl context → `ClusterType` enum; `load_image()` dispatches per cluster
- `pypi.rs` — `get_latest_version()` parses PyPI HTML index; `next_patch()` increments; `upload_wheel()` via `uv publish`
- `executor.rs` — `run_program()` and `run_legacy_script()`; captures stdout/stderr; respects `OutputMode` and timeout; kills process group on cancel
- `output.rs` — sole caller of `println!`; emits one JSON line per run (schema_version=1)
- `config/project.rs` — `dpk.toml` structs: `ProjectSection`, `DockerSection`, `DeploySection`, `SkipSection`, `TimeoutSection`, `VerifySection`
- `config/workspace.rs` — `dpk-workspace.toml`: deploy context allowlist, named project registry

### Phase logic

Each phase in `src/phases/` follows this pattern: check dry_run → check skip flags → run subprocess → return `PhaseResult`.

- `lint`: runs `ruff check`+`ruff format` (Python) or `cargo clippy -D warnings` (Rust)
- `test`: runs `pytest` (Python) or `cargo test --all` (Rust)
- `build`: runs `python/build-wheel.sh` (Python) or `cargo build --release` (Rust); skips with `not_configured` if `[skip] build=true`
- `image`: skips with `not_configured` if no `[docker]` section; runs `python/build-docker.sh` or `rust/build-docker.sh`
- `deploy`: requires `dpk-workspace.toml` with non-empty allowlist; checks kubectl context against allowlist; runs `python/deploy-k8s.sh` or `rust/deploy-k8s.sh`
- `verify`: runs HTTP check or exec command from `[verify]` section

### `Makefile.common`

Included by consuming repos. `make b` target:
1. Resolves binary: `command -v dpk-build` (PATH) → `bootstrap.sh` (builds from source)
2. If `CI=true`: runs `dpk-build deliver --skip-image --skip-deploy`
3. Otherwise: runs `dpk-build deliver`

### Config files

**`dpk.toml`** — per-project, in project root. Full schema in `src/config/project.rs`.

**`dpk-workspace.toml`** — at workspace root (or `WORKSPACE_ROOT` env). Required for deploy to run locally. Searched upward 5 levels from cwd, or via `WORKSPACE_ROOT`.

### Output

One JSON line to stdout on completion. Phase output streams to stderr.
Exit codes: `0` success, `1` failure, `130` SIGINT.

### Language detection

`context::detect_language()` checks for `Cargo.toml` (rust), `pyproject.toml` (python), `package.json` (node). Errors if ambiguous or unknown. `project.language` in `dpk.toml` or `BUILD_LANG` env var overrides detection.

## CI

- `shellcheck.yml` — self-hosted runner, shellcheck v0.10.0
- `rust-tests.yml` — `cargo test`, integration tests; stdout ownership check (only `src/output.rs` and doctor/version commands may call `println!`)
- `security-audit.yml` — dispatches to `dpk-audit`; skips docs-only PRs
