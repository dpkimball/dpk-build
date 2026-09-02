# CLAUDE.md

Guidance for agents working in this repository.

## What this repo is

Shared build orchestrator for DPK repos. Consuming projects set `BUILD_ROOT` and `include Makefile.common`. The Rust binary `dpk-build` runs deliver (lint → test → build → image → deploy → verify). Shell under `python/`, `rust/`, and `java/` is called for image/deploy (and legacy direct use).

**Changes here affect every consumer.** Prefer fixing the CLI over adding per-repo build snowflakes.

## Commands (this repo)

```bash
cargo build --release
cargo test --locked --all
cargo clippy --locked -- -D warnings
cargo fmt --check
./bootstrap.sh                  # release binary path (used by Makefile.common)
```

Consumers:

```bash
make b                          # dpk-build deliver
CI=true make b                  # lint + test + build only
SKIP_LINT=true make b           # env skips; see README
```

## Architecture (short)

- `src/cli.rs` → `dispatch` → `commands/` + `phases/`
- `context.rs` — `BUILD_ROOT`, env files, `dpk.toml`, language
- `skip.rs` — CLI > env > `[skip]` on deliver only
- `config/` — project + workspace manifests
- `maven.rs` — Java lint/test/build
- `output.rs` — sole default JSON `println!` (doctor/version may emit custom JSON)
- Phase detail: `docs/phases.md`; layout: `docs/architecture.md`

## Languages

| Language | Deliver support |
|----------|-----------------|
| python | full |
| rust | full |
| java | full (Maven + shared docker/helm scripts) |
| node | detected only; phases fail until implemented |

## Constraints

- Never `git add -A`
- Never merge to `master` unless the user explicitly asks in that message
- Feature work on a feature branch; one open PR per initiative
- Do not invent Node phase behavior — fail closed until real support lands
- Keep README / `docs/` aligned with code when changing phases or schema

## Config

- **`dpk.toml`** — project root; schema in README and `src/config/project.rs`
- **`dpk-workspace.toml`** — workspace root or `WORKSPACE_ROOT`; required for deploy allowlist
