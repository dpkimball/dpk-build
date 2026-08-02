# dpk-build

[![Rust Tests](https://github.com/dpkimball/dpk-build/actions/workflows/rust-tests.yml/badge.svg)](https://github.com/dpkimball/dpk-build/actions/workflows/rust-tests.yml)
[![ShellCheck](https://github.com/dpkimball/dpk-build/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/dpkimball/dpk-build/actions/workflows/shellcheck.yml)
[![Security Audit](https://github.com/dpkimball/dpk-build/actions/workflows/security-audit.yml/badge.svg)](https://github.com/dpkimball/dpk-build/actions/workflows/security-audit.yml)

Shared build pipeline for all DPK/Keepsake repos. Consuming repos include `Makefile.common` and add a `dpk.toml`. The Rust CLI binary (`dpk-build`) orchestrates all phases.

## Onboarding a consuming repo

**`Makefile`** (project root):
```makefile
BUILD_ROOT ?= ../dpk-build
include $(BUILD_ROOT)/Makefile.common
```

**`dpk.toml`** (project root):
```toml
[project]
name = "my-service"
language = "python"   # python | rust | node
```

Language auto-detected if omitted: `Cargo.toml`→rust, `pyproject.toml`→python, `package.json`→node. Error if ambiguous.

## `make b`

Resolves binary via PATH then falls back to `bootstrap.sh` (builds from source). Runs `dpk-build deliver`.

| Mode | Phases |
|------|--------|
| local | lint → test → build → image → deploy → verify |
| `CI=true` | lint → test → build (image/deploy skipped via `--skip-image --skip-deploy`) |

Phase stops pipeline on failure; subsequent phases get `reason: previous_phase_failed`.

## dpk.toml full schema

```toml
[project]
name = "my-service"           # optional; falls back to directory name
language = "python"           # optional; auto-detected

[skip]                        # permanent defaults for `deliver` only
lint   = false
tests  = false
build  = false
image  = false
deploy = false

[docker]                      # required for image phase to run
image_name = "my-service"
platforms  = ["linux/amd64"]  # optional; multi-arch
# Companion images (built after primary). Each entry: image_name:Dockerfile path
extra_image_builds = ["my-runner:containers/my-runner/Dockerfile"]
worker_image_name  = "my-runner"   # Helm --set config.workerImage
# Extra docker/buildx flags (BuildKit --build-context, etc.)
extra_args = "--build-context sibling=../sibling"

[deploy]                      # values passed as env to deploy-k8s.sh
helm_release   = "my-service" # mutually exclusive with helm_releases
helm_releases  = ["a", "b"]   # multi-chart; do not set with helm_release
k8s_namespace  = "dev"
helm_chart_path = "charts/"   # when chart dir ≠ release name

[verify]
command = ["curl", "-f", "http://localhost:8080/health"]
# OR
[verify.http]
url             = "http://localhost:8080/health"
expected_status = 200
timeout         = "10s"

[timeout]
lint_secs   = 120
test_secs   = 600
build_secs  = 300
image_secs  = 600
deploy_secs = 300
verify_secs = 60
```

- Image phase skips with `not_configured` when `[docker]` section is absent.
- Deploy phase errors with `deploy_requires_workspace_manifest` when no `dpk-workspace.toml` is found.

## dpk-workspace.toml

Place at workspace root (or set `WORKSPACE_ROOT` env var). Required for local deploy.

```toml
[deploy.local.contexts]
allowlist = ["rancher-desktop"]   # kubectl context names permitted to deploy

[projects]                        # optional: named project registry
my-service = "my-service/"        # relative path from workspace root
```

Named projects enable `dpk-build deliver my-service` from any directory.

## Skip flags

Priority: CLI flag > env var > `dpk.toml [skip]` (deliver only).

| Phase | CLI flag | Env var |
|-------|----------|---------|
| lint | `--skip-lint` | `SKIP_LINT=true` |
| test | `--skip-tests` | `SKIP_TESTS=true` |
| build | `--skip-build` | `SKIP_BUILD=true` |
| image | `--skip-image` | `SKIP_DOCKER_IMAGE=true` or `SKIP_IMAGE=true` |
| deploy | `--skip-deploy` | `SKIP_K8S_DEPLOY=true` |

## CLI reference

```
dpk-build deliver [project] [--skip-lint] [--skip-tests] [--skip-build] [--skip-image] [--skip-deploy]
dpk-build lint    [project]
dpk-build test    [project]
dpk-build build   [project]
dpk-build image   [project]
dpk-build deploy  [project] [--target local]
dpk-build verify  [project]
dpk-build version show [project]
dpk-build version bump [project]
dpk-build doctor  [project] [--online]

Global: --quiet  --verbose  --dry-run
```

## JSON output

One JSON line emitted to stdout on completion. Live process output goes to stderr.

```json
{
  "schema_version": 1,
  "project": "my-service",
  "operation": "deliver",
  "status": "success",
  "duration_ms": 12345,
  "phases": {
    "lint":   { "status": "success",  "duration_ms": 234 },
    "build":  { "status": "skipped",  "duration_ms": 0, "reason": "project_default" },
    "deploy": { "status": "failure",  "duration_ms": 0, "error": { "code": "context_not_in_allowlist", "message": "..." } },
    "verify": { "status": "skipped",  "duration_ms": 0, "reason": "previous_phase_failed" }
  }
}
```

**`status`:** `success` `failure` `cancelled`

**Phase `status`:** `success` `failure` `skipped` `timed_out` `cancelled`

**Skip `reason`:** `cli` `environment` `project_default` `not_configured` `previous_phase_failed` `dry_run` `cancelled`

**Exit codes:** `0` success · `1` failure · `130` SIGINT cancelled

## Environment resolution

`BUILD_ROOT/env.sh` sourced first, then `<project>/env.sh`. Project vars override build-root vars. All resolved vars exported to child processes. `BUILD_ROOT` required (`KEEPSAKE_SCRIPTS_ROOT` accepted as legacy alias).

## Cluster detection (deploy phase)

| kubectl context | Strategy |
|----------------|----------|
| contains `kind` | `kind load docker-image` |
| `rancher-desktop` | no load (shared daemon) |
| `docker-desktop` | no load |
| `minikube` | `minikube image load` |
| other | allowed if listed in `dpk-workspace.toml` allowlist |

## CI workflows

| Workflow | Trigger | What it checks |
|----------|---------|----------------|
| `shellcheck.yml` | PR/push | all `*.sh` via shellcheck v0.10.0 |
| `rust-tests.yml` | PR/push | CLI unit + integration tests |
| `security-audit.yml` | PR/push | dispatches to `dpk-audit`; skips docs-only PRs |
