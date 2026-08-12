# dpk-build

[![Rust Tests](https://github.com/dpkimball/dpk-build/actions/workflows/rust-tests.yml/badge.svg)](https://github.com/dpkimball/dpk-build/actions/workflows/rust-tests.yml)
[![ShellCheck](https://github.com/dpkimball/dpk-build/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/dpkimball/dpk-build/actions/workflows/shellcheck.yml)
[![Security Audit](https://github.com/dpkimball/dpk-build/actions/workflows/security-audit.yml/badge.svg)](https://github.com/dpkimball/dpk-build/actions/workflows/security-audit.yml)

Shared build pipeline for DPK repos. Consumers include `Makefile.common` and add a `dpk.toml`. The Rust CLI (`dpk-build`) runs lint → test → build → image → deploy → verify.

## Onboarding

**`Makefile`:**
```makefile
BUILD_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../dpk-build)
include $(BUILD_ROOT)/Makefile.common
```

Use `:=` with an abspath, not `?=`. An ambient `BUILD_ROOT` (often the project cwd) would otherwise make `include` look for `./Makefile.common`.

**`dpk.toml`:**
```toml
[project]
name = "my-service"
language = "python"   # python | rust | java | node  (optional; auto-detected)
```

Auto-detect: `Cargo.toml` → rust, `pyproject.toml` → python, `pom.xml` / `build.gradle` → java, `package.json` → node. Error if ambiguous. Set `project.language` or `BUILD_LANG` to override.

**Supported languages:** python, rust, java.  
**Node:** image and deploy use `python/build-docker.sh` and `python/deploy-k8s.sh`. Lint, test, and build phases are not implemented — skip them in `[skip]` or via `--skip-lint --skip-tests` (and `[skip] build = true` when the image build is the compile).

### Java / Flink

| Phase | Maven goals |
|-------|-------------|
| lint | `validate compile` (`-DskipTests`) |
| test | `test` |
| build | `package` (`-DskipTests`) |

POM: `MAVEN_POM` env → `project.maven_pom` → `pom.xml` → `jobs/pom.xml`.  
Runner: local `mvn`, else Docker (`MAVEN_IMAGE`, default `maven:3.9-eclipse-temurin-17`).

Image/deploy use `[docker]` / `[deploy]`. Set `[skip] lint/tests/build = true` when `make b` should only ship a runtime image.

## `make b`

Resolves `dpk-build` on PATH, else `bootstrap.sh`. Runs `dpk-build deliver`.

| Mode | Phases |
|------|--------|
| local | lint → test → build → image → deploy → verify |
| `CI=true` | lint → test → build (`--skip-image --skip-deploy`) |

Failure stops the pipeline; later phases get `reason: previous_phase_failed`.

Per-phase detail: [docs/phases.md](docs/phases.md).

## `dpk.toml` schema

```toml
[project]
name = "my-service"           # optional; directory name if omitted
language = "python"           # optional; auto-detected
maven_pom = "jobs/pom.xml"    # java only

[skip]                        # deliver defaults only
lint   = false
tests  = false
build  = false
image  = false
deploy = false

[docker]                      # required for image phase
image_name = "my-service"
dockerfile = "Dockerfile"
dockerfile_dir = "."
platforms  = ["linux/amd64"]
extra_image_builds = ["my-runner:containers/my-runner/Dockerfile"]
worker_image_name  = "my-runner"
extra_args = "--build-context sibling=../sibling"

[deploy]
helm_release   = "my-service" # mutually exclusive with helm_releases
helm_releases  = ["a", "b"]
k8s_namespace  = "dev"
helm_chart_path = "charts/"

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

- No `[docker]` → image skipped (`not_configured`).
- No usable `dpk-workspace.toml` allowlist → deploy fails (`deploy_requires_workspace_manifest`).
- No `[verify]` → verify skipped (`not_configured`).

## `dpk-workspace.toml`

Workspace root (or `WORKSPACE_ROOT`). Required for local deploy.

```toml
[deploy.local.contexts]
allowlist = ["rancher-desktop"]

[projects]
my-service = "my-service/"
```

Named projects: `dpk-build deliver my-service` from any directory.

## Skip flags

Priority: CLI > env > `dpk.toml [skip]` (deliver only).

| Phase | CLI | Env |
|-------|-----|-----|
| lint | `--skip-lint` | `SKIP_LINT=true` |
| test | `--skip-tests` | `SKIP_TESTS=true` |
| build | `--skip-build` | `SKIP_BUILD=true` |
| image | `--skip-image` | `SKIP_DOCKER_IMAGE=true` or `SKIP_IMAGE=true` |
| deploy | `--skip-deploy` | `SKIP_K8S_DEPLOY=true` |

## CLI

```
dpk-build deliver [project] [--skip-lint] [--skip-tests] [--skip-build] [--skip-image] [--skip-deploy]
dpk-build lint | test | build | image | deploy | verify [project]
dpk-build deploy [project] [--target local]
dpk-build version show | bump [project]
dpk-build doctor [project] [--online]

Global: --quiet  --verbose  --dry-run
```

## JSON output

One JSON line on stdout; live logs on stderr.

```json
{
  "schema_version": 1,
  "project": "my-service",
  "operation": "deliver",
  "status": "success",
  "duration_ms": 12345,
  "phases": {
    "lint":   { "status": "success", "duration_ms": 234 },
    "build":  { "status": "skipped", "duration_ms": 0, "reason": "project_default" },
    "deploy": { "status": "failure", "duration_ms": 0, "error": { "code": "context_not_in_allowlist", "message": "..." } },
    "verify": { "status": "skipped", "duration_ms": 0, "reason": "previous_phase_failed" }
  }
}
```

**`status`:** `success` · `failure` · `cancelled`  
**Phase `status`:** `success` · `failure` · `skipped` · `timed_out` · `cancelled`  
**Skip `reason`:** `cli` · `environment` · `project_default` · `not_configured` · `previous_phase_failed` · `dry_run` · `cancelled`  
**Exit:** `0` · `1` · `130` (SIGINT)

## Environment

`BUILD_ROOT/env.sh` then `<project>/env.sh` (project wins). `BUILD_ROOT` required (`KEEPSAKE_SCRIPTS_ROOT` legacy alias).

## Cluster (deploy)

Allowlist is checked in the CLI. Image load runs inside `python|rust/deploy-k8s.sh` via `shared/detect-cluster.sh`:

| Context / cluster | Image load |
|-------------------|------------|
| name contains `kind` | `kind load docker-image` |
| `rancher-desktop` or context `keepsake-dev` | none (shared daemon); allowlist key `rancher-desktop` |
| `docker-desktop` | none |
| `minikube` | `minikube image load` |
| other | allowed only if listed in workspace allowlist |

## Documentation

- [Architecture](docs/architecture.md)
- [Phases](docs/phases.md)
- [Docs index](docs/README.md)

## CI

| Workflow | What |
|----------|------|
| `shellcheck.yml` | all `*.sh`; paths/env matrix; Makefile `BUILD_ROOT` guard; `_SCRIPTS_DIR` probe; **in-repo consumer contract** (python/rust/java/node image+deploy probes) |
| `rust-tests.yml` | `cargo fmt` / clippy / test; stdout ownership check |
| `security-audit.yml` | dpk-ci → security-audit API; skips docs-only PRs |
