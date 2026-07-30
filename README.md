# DPK Build (`dpk-build`)

[![ShellCheck](https://github.com/dpkimball/dpk-build/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/dpkimball/dpk-build/actions/workflows/shellcheck.yml)

GitHub repository: [`dpkimball/dpk-build`](https://github.com/dpkimball/dpk-build) (renamed from `keepsake-scripts`; old URLs redirect).

Shared `make b` pipeline for DPK platform and Keepsake application repos. Every `make b` call across consuming repos ultimately sources and executes these scripts.

**Stability:** Local checkout folder is `dpk-build` (was `keepsake-scripts`). Path env vars: `SSD`, `WORKSPACE_ROOT`, `BUILD_ROOT`.

**Sibling:** Remote CI (reusable GitHub Actions workflows, base images, deploy families) lives in [`dpk-ci`](https://github.com/dpkimball/dpk-ci) (was `keepsake-images`). Local `make b` does not replace those workflows.

---

## The `make b` pipeline

Running `make b` in any consuming repo executes `build.sh` which runs these steps in order:

1. **Lint** — `lint.sh` (runs `npx biome check`)
2. **Test** — `test.sh` (runs `uv run python -m pytest`)
3. **Wheel** — `build-wheel.sh` (bumps version, builds wheel, uploads to local PyPI)
4. **Docker** — `build-docker-image.sh` (builds and pushes image to local registry)
5. **K8s deploy** — `deploy-k8s.sh` (Helm upgrade + rollout wait)

---

## SKIP_* flags

Any step can be skipped by setting the corresponding flag before `make b`:

| Flag | Skips |
|------|-------|
| `SKIP_LINT=true` | lint step |
| `SKIP_TESTS=true` | test step |
| `SKIP_WHEEL=true` | wheel build and upload |
| `SKIP_DOCKER_IMAGE=true` | Docker build |
| `SKIP_K8S_DEPLOY=true` | Kubernetes deploy |

Note: the K8s deploy step also requires `K8S_DEPLOY=true` to run — both flags must allow it.

**Examples:**
```bash
# Skip lint and tests (fast rebuild after code change)
SKIP_LINT=true SKIP_TESTS=true make b

# Build wheel only (no docker, no deploy)
SKIP_DOCKER_IMAGE=true SKIP_K8S_DEPLOY=true make b

# Deploy only (image already built)
SKIP_LINT=true SKIP_TESTS=true SKIP_WHEEL=true SKIP_DOCKER_IMAGE=true make b
```

---

## First build: `FIRST_BUILD=1`

When a package has never been uploaded to the local PyPI, `build-wheel.sh` cannot find a prior version and will exit with an error. Set `FIRST_BUILD=1` to start at version `0.0.1`:

```bash
FIRST_BUILD=1 make b
```

Without this flag, a missing PyPI version is treated as an error (not a silent fallback) to distinguish a first build from a PyPI connectivity failure.

---

## Required environment variables

These must be set (or available via `env.sh`) before running any script:

| Variable | Used by | Notes |
|----------|---------|-------|
| `SSD` | `paths.sh` | External volume mount (default `/Volumes/KeepsakeSSD`) |
| `WORKSPACE_ROOT` | `paths.sh` | Umbrella checkout (default `$SSD/dpk-workspace`) |
| `BUILD_ROOT` | all scripts | Path to this directory (`dpk-build`) |
| `PROJECT_ROOT` | project `env.sh` | That consuming repo (set after sourcing `BUILD_ROOT/env.sh`) |
| `PROJECT_VENV_DIR` | `build.sh`, `build-wheel.sh` | Path to virtualenv (default: `.venv`) |
| `PYPI_HOST` | `build-wheel.sh`, `get_latest_pypi_version.sh` | Local PyPI hostname (default: `localhost`) |
| `PYPI_PORT` | `build-wheel.sh`, `get_latest_pypi_version.sh` | Local PyPI port (default: `31126`) |
| `PYPI_USERNAME` | `build-wheel.sh`, `get_latest_pypi_version.sh` | PyPI auth username |
| `PYPI_PASSWORD` | `build-wheel.sh`, `get_latest_pypi_version.sh` | PyPI auth password |
| `IMAGE_NAME` | `build-docker-image.sh`, `deploy-k8s.sh` | Docker image name |
| `HELM_RELEASE` | `deploy-k8s.sh` | Single Helm release (takes priority over inherited `HELM_RELEASES`) |
| `HELM_RELEASES` | `deploy-k8s.sh` | Comma-separated multi-release deploy (keepsake backend: prestart + backend) |
| `HELM_CHART_PATH` | `deploy-k8s.sh` | Chart directory when release name ≠ chart folder |
| `K8S_NAMESPACE` | `deploy-k8s.sh` | Target namespace (default from shared `env.sh`: `dev`) |

Optional overrides: `PYPI_HOST_OVERRIDE`, `PYPI_PORT_OVERRIDE` (take precedence over `PYPI_HOST`/`PYPI_PORT` when set).

---

## env.sh

`env.sh` sets ecosystem-wide defaults (ports, URLs, PyPI config, registry URL). Individual projects source it and then override project-specific values:

```bash
# In a project's env.sh:
source "$BUILD_ROOT/env.sh"
export IMAGE_NAME="my-service"
export HELM_RELEASE="my-service"   # single chart — wins over inherited HELM_RELEASES

# Multi-release (keepsake backend only — do not set HELM_RELEASE):
export HELM_RELEASES="keepsake-prestart,keepsake-backend"
```

**Deploy priority** (`deploy-k8s.sh`):

1. `HELM_RELEASE` set → upgrade one chart (resume → `dagster-resume`, even if shell still has `HELM_RELEASES` from another repo)
2. else `HELM_RELEASES` set → upgrade each release in the list
3. else → single release named `IMAGE_NAME`

Single-release projects should set `HELM_RELEASE` (and may `unset HELM_RELEASES` in project `env.sh` for clarity).

`env.sh` sources `paths.sh` for canonical SSD-relative project roots.

---

## Cluster detection (`deploy-k8s.sh`)

The deploy script detects the Kubernetes cluster type by checking the current context and cluster name:

| Context / cluster name | Behavior |
|------------------------|----------|
| contains `kind` | loads image into Kind cluster |
| cluster name contains `rancher-desktop` | assumes image available (Rancher Desktop shares Docker daemon); also matches `keepsake-dev` context since its underlying cluster is named `rancher-desktop` |
| contains `docker-desktop` | assumes image available |
| contains `minikube` | loads image via `minikube image load` |
| anything else | prints a warning; deploy may still succeed if the image is reachable |

---

## Helper functions

All shared shell helpers live in `common.sh`:

| Function | Output |
|----------|--------|
| `print_status` | green `✔` |
| `print_warning` | yellow `⚠` |
| `print_error` | red `✘` |
| `require_tool` | exits if a binary is not on PATH |
| `log_info` | blue `ℹ️` |
| `log_success` | green `✅` |
| `log_error` | red `❌` |
| `log_warning` | yellow `⚠️` |

`utils.sh` is a backwards-compatibility shim that sources `common.sh`.

---

## Consuming repos

| Repo | Uses |
|------|------|
| `dpk-agent` | build + deploy scripts |
| `keepsake-services` | build + wheel scripts |
| `dpk` | build + deploy scripts |
| `dpk-client` | build + wheel scripts |
| `keepsake` | build + deploy scripts |
| `text_ai` | build + wheel scripts |
| `text-decipher` | build + deploy scripts |
| `image-decipher` | build + deploy scripts |
| `audio-decipher` | build + deploy scripts |
| `video-decipher` | build + deploy scripts |

---

## Out of scope

`rust_build.sh`, `rust_build_crate.sh`, `rust_docker_build.sh`, `rust_launch_dev.sh`, `rust_load_k8s.sh` — Rust build scripts are documented separately in `README_RUST.md`.
