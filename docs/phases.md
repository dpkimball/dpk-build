# Deliver phases

Runs in order during `dpk-build deliver`. A terminal phase failure marks later phases `skipped` with `reason: previous_phase_failed`.

## lint

| Language | Command |
|----------|---------|
| Python | `uv run ruff check` then `uv run ruff format --check` (`LINT_DIRECTORY`, default `.`) |
| Rust | `cargo clippy --workspace --all-targets --all-features -- -D warnings` then `cargo fmt --all -- --check` |
| Java | `mvn -B -f <pom> -DskipTests validate compile` (or Docker Maven) |
| Node | fails (`language_unsupported_for_operation`) |

## test

| Language | Command |
|----------|---------|
| Python | `uv run python -m pytest <TEST_DIRECTORY>` (default `tests`; exit 5 → success) |
| Rust | `cargo test --all` |
| Java | `mvn -B -f <pom> test` |
| Node | fails |

## build

| Language | Command |
|----------|---------|
| Python | `python/build-wheel.sh` (PyPI publish path) |
| Rust | `cargo build --release --workspace` |
| Java | `mvn -B -f <pom> -DskipTests package` |
| Node | fails |

`[skip] build = true` in `dpk.toml` → skipped with `reason: project_default` on deliver only.

## image

Skipped with `not_configured` if `[docker]` is absent.

| Language | Script |
|----------|--------|
| Python, Java, Node | `python/build-docker.sh` |
| Rust | `rust/build-docker.sh` |

`[docker]` fields map to env (`IMAGE_NAME`, `DOCKERFILE`, `EXTRA_IMAGE_BUILDS`, `WORKER_IMAGE_NAME`, `DOCKER_EXTRA_ARGS`, …).

## deploy

Requires `dpk-workspace.toml` with a non-empty `[deploy.local.contexts].allowlist`. Current kubectl context (after cluster typing) must be on that list; otherwise `context_not_in_allowlist`.

| Language | Script |
|----------|--------|
| Python, Java, Node | `python/deploy-k8s.sh` |
| Rust | `rust/deploy-k8s.sh` |

`[deploy]` maps to `HELM_RELEASE` / `HELM_RELEASES`, `K8S_NAMESPACE`, `HELM_CHART_PATH`.

## verify

Skipped with `not_configured` if `[verify]` is absent. Otherwise runs `[verify.http]` and/or `[verify].command`.

## Maven POM resolution (Java)

1. `MAVEN_POM` env  
2. `project.maven_pom` in `dpk.toml`  
3. `pom.xml`  
4. `jobs/pom.xml`
