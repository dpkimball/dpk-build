# Rust support in dpk-build

Prefer **`make b`** → `dpk-build deliver`. Scripts under `rust/` implement image/deploy (and optional manual flows).

## Deliver path

| Phase | Implementation |
|-------|----------------|
| lint | `cargo clippy --workspace --all-targets --all-features -- -D warnings` |
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
| `rust/build-crate.sh` | Package a crate; optional publish via `PUBLISH_CRATE=true CARGO_REGISTRY=dpk` (Kellnr, never crates.io) |

## Private Cargo registry (Kellnr)

Do not `cargo publish` to crates.io for DPK crates. PyPI pypiserver (`:31126` / `:32491`) is Python-only. Kellnr is the Cargo analog: DEV `:31127`, QA `:32492`.

Python **binder-sdk** `make b` twines to pypiserver. Rust libraries opt in with `PUBLISH_CRATE=true CARGO_REGISTRY=dpk` in project `env.sh` (see **bindb**). Then `make b` / `dpk-build deliver` runs `rust/build-crate.sh` after `cargo build --release`. `CI=true` skips publish (PR test jobs).

1. Crate `Cargo.toml`: `publish = ["dpk"]`.
2. Project `.cargo/config.toml` or `CARGO_REGISTRIES_DPK_INDEX`.
3. Token: `CARGO_REGISTRIES_DPK_TOKEN` / `~/.cargo/credentials.toml` (never commit a credentials file).
4. Do not set Cargo `[registry] default` — public crates stay on crates.io.

Index URLs: DEV `sparse+http://127.0.0.1:31127/api/v1/crates/`, QA `sparse+http://192.168.86.47:32492/api/v1/crates/`. Chart: dpk-infra `charts/kellnr`.

## Makefile

Aligned projects: lean `Makefile` + `include $(BUILD_ROOT)/Makefile.common`.  
`Makefile.rust-common` remains only for older layouts that still call `rust/build.sh` directly.
