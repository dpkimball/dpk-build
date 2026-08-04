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
| `rust/build-crate.sh` | Single crate without full deliver |

## Makefile

Aligned projects: lean `Makefile` + `include $(BUILD_ROOT)/Makefile.common`.  
`Makefile.rust-common` remains only for older layouts that still call `rust/build.sh` directly.
