---
title: Rust support in dpk-build
description: How Rust projects use dpk-build for image, deploy, and registry publishing.
category: development
---
# Rust support in dpk-build

Prefer **`make b`** → `dpk-build deliver`. Scripts under `rust/` implement image/deploy (and optional manual flows).

## Deliver path

| Phase | Implementation |
|-------|----------------|
| lint | `cargo clippy --workspace --all-targets --all-features -- -D warnings` then `cargo fmt --all -- --check` |
| test | `cargo test --all` |
| build | `cargo build --release --workspace` |
| image | `rust/build-docker.sh` |
| deploy | `rust/deploy-k8s.sh` |

Full phase tables: [docs/phases.md](docs/phases.md).

## Optional scripts

| Script | Use |
|--------|-----|
| `rust/build.sh` | Legacy full orchestrator; prefer deliver |
| `rust/build-docker.sh` | Multi-arch image (deliver image phase) |
| `rust/deploy-k8s.sh` | Helm deploy (deliver deploy phase) |
| `rust/launch-dev.sh` | Local interactive container |
| `rust/build-crate.sh` | Package + publish to Kellnr (`PUBLISH_CRATE` defaults true when `CI` unset) |

## Private Cargo registry (Kellnr)

Do not `cargo publish` to crates.io for DPK crates. PyPI pypiserver (`:31126` / `:32491`) is Python-only. Kellnr is the Cargo analog: DEV `:31127`, QA `:32492`.

Python **binder-sdk** `make b` twines to pypiserver. Rust **`make b`** (CI unset) publishes to Kellnr the same way: `PUBLISH_CRATE=true CARGO_REGISTRY=dpk` is the dpk-build default. `CI=true` skips publish (PR test jobs). Override with `PUBLISH_CRATE=false`. Virtual workspaces publish each member that is not `publish = false`.

1. Crate `Cargo.toml`: `publish = ["dpk"]` and `registry = "dpk"` for private deps (no cross-repo `path = "../…"`).
2. Index: `CARGO_REGISTRIES_DPK_INDEX` from dpk-build `env.sh` (`CARGO_HOST=localhost` + `CARGO_PORT`, same as `PYPI_HOST`/`PYPI_PORT`).
3. CI: repository secret `PRIVATE_CARGO_URL` (Kellnr base URL, analog of `PRIVATE_PYPI_URL`) — not a host:port in workflow YAML.
4. Token: `CARGO_REGISTRIES_DPK_TOKEN` / `~/.cargo/credentials.toml` (never commit a credentials file).
5. Do not set Cargo `[registry] default` — public crates stay on crates.io.

Chart: dpk-infra `charts/kellnr`.

## Makefile

Aligned projects: lean `Makefile` + `include $(BUILD_ROOT)/Makefile.common`.  
`Makefile.rust-common` remains only for older layouts that still call `rust/build.sh` directly.
