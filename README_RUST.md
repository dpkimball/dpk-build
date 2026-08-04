# Rust support in dpk-build

Prefer **`make b`** (via `Makefile.common` → `dpk-build deliver`). The scripts under `rust/` are the implementations used by deliver and by optional manual workflows.

## Deliver path

| Phase | Script / tool |
|-------|----------------|
| lint / test / build | Rust CLI (`cargo fmt` / `clippy` / `test` / `build`) |
| image | `rust/build-docker.sh` |
| deploy | `rust/deploy-k8s.sh` |

## Optional scripts under `rust/`

### `rust/build.sh`

Legacy full orchestrator (lint → test → release binary → optional image). Prefer `dpk-build deliver` or `make b`.

```bash
./rust/build.sh
./rust/build.sh --clean
SKIP_LINT=true ./rust/build.sh
```

### `rust/build-docker.sh`

Multi-arch image build + push (used by the deliver image phase).

```bash
./rust/build-docker.sh
CLEAN=true ./rust/build-docker.sh
IMAGE_NAME=my-rust-app ./rust/build-docker.sh
```

### `rust/launch-dev.sh`

Run a local container for interactive development.

```bash
./rust/launch-dev.sh
CLEAN=true ./rust/launch-dev.sh
IMAGE_NAME=my-rust-app CONTAINER_NAME=my-dev ./rust/launch-dev.sh
```

### `rust/build-crate.sh`

Build a crate without the full deliver pipeline (manual / niche).

## Makefile

Aligned Rust services/libraries use the lean project `Makefile` + `include $(BUILD_ROOT)/Makefile.common` (same as Python). `Makefile.rust-common` remains for older known-Rust layouts that call `rust/build.sh` directly.
