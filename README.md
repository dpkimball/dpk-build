# 🧠 Memory Graph Service

[![CI/CD (Helm)](https://github.com/dpkimball/memory-graph-service/actions/workflows/deploy.yaml/badge.svg)](https://github.com/dpkimball/memory-graph-service/actions/workflows/deploy.yaml)

Rust gRPC service that owns Keepsake’s canonical memory graph. The crate persists memories, entities, observations, and supporting narrative artifacts, generates synopses, drives Mongo ↔ Neo4j/Weaviate projection jobs, and exposes typed APIs that every other component in the ecosystem consumes.

---

## Service Responsibilities
- **Canonical storage** in MongoDB for every domain aggregate (`src/dal/schema/storage_models.rs` maps Memory, Observation, Entity, Media, Perspective, Story, Transmission, User, Document schema definitions, etc.).
- **Strict three-tier separation**
  - `src/service/**` — tonic gRPC handlers (all V2 servers) registered in `src/server.rs`.
  - `src/application/**` — business logic, synopsis orchestration, validation, and cross-entity workflows.
  - `src/dal/**` — repository traits plus MongoDB, Neo4j, and Weaviate adapters, along with sync helpers.
- **Context + synopsis pipeline** in `src/application/synopsis/*` and `src/service/memory/memory_service_v2.rs`, producing `ContextBundle` payloads for keepsake-brain.
- **Graph + vector projections** via `MemoryGraphSyncService` (`src/service/sync/sync_service.rs`) and the `sync_all`/`sync_user` binaries.
- **Schema-driven Document Service** (`src/service/document/document_service_v2.rs`) that stores arbitrary structured payloads using Mongo collections defined at runtime.
- **Operational health & tooling** through `HealthServiceV2`, `AdminService`, `GdsAnalyticsService`, and exporter binaries for replay/debugging.

---

## Architecture Snapshot
| Layer | Path | Notes |
| --- | --- | --- |
| Presentation | `src/service` | gRPC handlers, callback clients, sync/projector binaries. |
| Application | `src/application` | Use cases, synopsis pipeline, cross-cutting emotion helpers, outbox orchestration. |
| Domain | `src/domain` | Entity models + proto<->domain converters for every aggregate. |
| Data Access | `src/dal` | Repository traits, Mongo implementations, Neo4j & Weaviate adapters, schema definitions. |
| Config | `src/config` | `AppConfig` + tracing init; loads `DPK__*` env vars with figment layering. |

Data stores:
- **MongoDB** — authoritative store for every entity and chat transcript.
- **Neo4j** — served via `neo4rs`; used for graph analytics, GDS, and synopsis enrichment.
- **Weaviate** — vector embeddings for MemoryOrbs, Observations, Perspectives, Entities, Media, Reflections, Stories, Transmissions.
- **ClickHouse (optional)** — telemetry tables seeded by `src/bin/clickhouse_init.rs`.

---

## gRPC Surface Area
Proto sources live in `memory-graph-client/proto`, and Rust stubs are generated into `src/proto_gen` at build time. All public services are under the `dpk` package (admin utilities live under `admin`).

| Category | Proto | gRPC Server | Handler |
| --- | --- | --- | --- |
| Memories & Observations | `memory.proto`, `observation.proto`, `memory_orb.proto`, `observation_event.proto`, `place.proto` | `MemoryService`, `ObservationService`, `MemoryOrbService`, `EventService`, `PlaceService` | `src/service/memory/memory_service_v2.rs`, `src/service/observation/observation_service_v2.rs`, `src/service/event/event_service_v2.rs`, `src/service/place/place_service_v2.rs` |
| Perspectives & Reflections | `perspective.proto`, `reflection.proto`, `reentry.proto`, `intention.proto` | `PerspectiveService`, `ReflectionService`, `ReentryService`, `IntentionService` | `src/service/perspective/perspective_service_v2.rs`, `src/service/reflection/reflection_service_v2.rs`, `src/service/reentry/reentry_service_v2.rs`, `src/service/intention/intention_service_v2.rs` |
| Entities & Identification | `entity.proto`, `entity_identified.proto`, `identification.proto`, `detected_entity.proto` | `EntityService`, `EntityIdentifiedService`, `IdentificationService` | `src/service/entity/entity_service_v2.rs`, `src/service/entity_identified/entity_identified_service_v2.rs`, `src/service/identification/identification_service_v2.rs` |
| Media & Stories | `media.proto`, `story.proto`, `transmission.proto` | `MediaService`, `StoryService`, `TransmissionService` | `src/service/media/media_service_v2.rs`, `src/service/story/story_service_v2.rs`, `src/service/transmission/transmission_service_v2.rs` |
| Users & Chat | `user.proto`, `chat.proto` | `UserService`, `ChatService` | `src/service/user/user_service_v2.rs`, `src/service/chat/chat_service_v2.rs` |
| Documents | `document_service.proto` | `DocumentService` | `src/service/document/document_service_v2.rs` |
| Admin & Health | `admin.proto`, `health.proto` | `AdminService`, `HealthService` | `src/service/admin/admin_service.rs`, `src/service/health/health_service_v2.rs` |

Generated clients ship inside `memory-graph-client/` (Python wheel + proto build scripts) and can be consumed by other languages via `grpc://<host>:50051`.

---

## Supporting Binaries (`src/bin`)
| Binary | Purpose | Helper Target |
| --- | --- | --- |
| `sync_all.rs` | Bulk Mongo → Neo4j/Weaviate sync with optional `USER_ID` scoping. | `make sync-all`, `make sync-user USER_ID=...` |
| `schema.rs` | Create, nuke, or migrate Weaviate classes. | `make schema-migrate`, `make schema-create` |
| `gds_analytics.rs` | Run Neo4j GDS algorithms from within the cluster. | `cargo run --bin gds_analytics` |
| `projector.rs` / `export_memory_debug.rs` | Export graph snapshots and create replay artifacts. | `make export-memory-debug MEMORY_ID=...` |
| `clickhouse_init.rs` | Seed ClickHouse telemetry tables when `DPK__CLICKHOUSE__ENABLED=true`. | `make clickhouse-init`, `make clickhouse-check` |

`bin/build.sh` mirrors the Keepsake-wide build scripts invoked by `make b`.

---

## Getting Started
1. **Configure environment**
   ```bash
   cd /Users/darinkimball/PycharmProjects/memory-graph-service
   cp config.env.example config.env
   # Populate Mongo/Neo4j/Weaviate URLs plus HMAC + ClickHouse where applicable.
   ```
2. **Bring up dependencies** via `keepsake-infra` (`make setup-dev`, `make port-forward-mongodb`, etc.) or point env vars to existing services.
3. **Run local checks**
   ```bash
   make lint          # cargo fmt --check + cargo clippy
   make test          # cargo test with env pulled from config.env
   ```
4. **Start the server**
   ```bash
   make run           # cargo run --bin memory-graph-service
   ```
5. **Deploy to dev/qa**
   ```bash
   make b             # runs fmt + build + clippy + test before Docker build via keepsake-scripts
   ```

Key Make targets: `b`, `ci`, `lint`, `fmt`, `fmt-fix`, `schema-migrate`, `sync-all`, `sync-user`, `client-test`, `k8s-logs`, `k8s-status`, `seed-and-sync`, `export-memory-debug`.

---

## Testing & Validation
- `make test` runs the full Rust suite (unit + integration). Mongo is required; some suites also expect Weaviate/Neo4j endpoints from `config.env`.
- `make test-integration` executes `tests/integration_synopsis_test.rs` (ignored by default) once keepsake-brain + dependencies are reachable.
- gRPC scenario tests live under `tests/grpc_*.rs`; specialized suites exist for health checks, document flows, Weaviate sync, Neo4j analytics, etc.
- Python client coverage: `make client-test` runs `memory-graph-client/run_tests.py` after regenerating proto stubs if needed.

`config.env` is sourced automatically by every Make target so credentials do not leak into shell history.

---

## Sync & Embedded Collections
- `MemoryGraphSyncService` (constructed in `src/server.rs`) is injected into memory/observation services to fan out updates to Neo4j and Weaviate.
- Embedded schemas live under `src/dal/schema/weaviate/` and stay in lock-step with Mongo storage models.
- CLI helpers:
  ```bash
  make sync-all                  # execute /app/sync_all within the dev pod
  make sync-user USER_ID=<uuid>  # scoped sync for one account
  cargo run --bin sync_all       # local run (reads config.env / env vars)
  ```
- Required env vars for sync tooling are documented in `docs/sync-environment-variables.md`.

---

## Health & Observability
- `HealthServiceV2` performs Mongo CRUD, Weaviate `/v1/.well-known/ready` probes + dummy object lifecycle, and reports Neo4j readiness from `MongoHealthRepository`.
- `make k8s-logs` / `make k8s-status` surface pod health; CI mirrors `make ci` before Docker builds.
- Optional ClickHouse dashboards: `make clickhouse-init` seeds tables, `make clickhouse-check` verifies schema when `DPK__CLICKHOUSE__ENABLED=true`.

---

## Repository Guide
| Path | Contents |
| --- | --- |
| `src/` | Core Rust crate (services, application layer, DAL, config, utils, binaries). |
| `tests/` | Integration and scenario suites (`cargo test`). |
| `memory-graph-client/` | Python gRPC client with proto definitions, build scripts, and tests. |
| `docs/` | Living documentation (see `docs/README.md`). |
| `bin/` | Keepsake build helpers invoked by `make b`. |

---

## Documentation Map
- `docs/README.md` — documentation index.
- `docs/architecture/01-folder-structure.md` — definitive view of the layered layout.
- `docs/architecture/three_tier_flow.md` — sequence/mermaid diagrams for typical requests.
- `docs/api/01-document-service.md` & `docs/api/02-grpc-api-reference.md` — application-specific API guidance.
- `docs/development/03-testing-guide.md` & `docs/development/04-quick-reference.md` — workflows, troubleshooting, and commands.
- `docs/deployment/01-deployment-guide.md` — CI/CD + Helm/GitOps flow.
- `docs/examples/synopsis-payloads.md` — concrete payloads for the synopsis pipeline.

All documentation now reflects the current code paths—historical content has been removed.

---

## Contributing
- Follow the Cursor/Keepsake rules in `docs/development/02-cursor-rules.md`.
- Work in feature branches only (never commit directly to `master`/`main`).
- Run `make lint` + `make test` before opening a PR; CI mirrors `make ci` and builds Docker images through `keepsake-scripts`.
- Use emoji-prefixed PR titles per Keepsake convention and keep doc updates in the same branch when possible.

This project is licensed under the MIT License (`LICENSE`). For a cross-repo overview see `/Users/darinkimball/PycharmProjects/ECOSYSTEM_OVERVIEW.md`.
# 🧠 Memory Graph Service

[![CI/CD (Helm)](https://github.com/dpkimball/memory-graph-service/actions/workflows/deploy.yaml/badge.svg)](https://github.com/dpkimball/memory-graph-service/actions/workflows/deploy.yaml)

Rust gRPC service that owns Keepsake’s canonical memory graph. The service persists memories, generates synopses, synchronizes graph/vector projections, and exposes typed APIs that every other component in the ecosystem relies on.

---

## Service Responsibilities
- **Authoritative storage** in MongoDB for memories, observations, perspectives, entities, stories, transmissions, users, document schemas, and structured documents (`src/dal/schema/storage_models.rs`).
- **Three-tier separation**:
  - `src/service/**` – gRPC handlers (V2 services) translate proto requests.
  - `src/application/**` – business logic, synopsis orchestration, emotion analysis.
  - `src/dal/**` – repository interfaces plus Mongo, Neo4j, and Weaviate adapters.
- **Graph + vector projections** via `MemoryGraphSyncService` and the `sync_all` binary.
- **Context + synopsis pipeline** (`src/application/synopsis/*`, `src/service/memory/memory_service_v2.rs`) that powers narrative breakdowns for Keepsake Brain.
- **Document Service v2** (`src/service/document/document_service_v2.rs`) for schema-driven structured storage.
- **Operational health** through `HealthServiceV2` which exercises MongoDB, Weaviate, and reports Neo4j readiness.

---

## Architecture Snapshot
| Layer | Location | Notes |
| --- | --- | --- |
| Presentation | `src/service` | gRPC handlers registered in `src/server.rs`, including admin and legacy MemoryOrb handlers. |
| Application | `src/application` | Use-case orchestration, synopsis flow, cross-cutting emotion analysis helpers. |
| Data Access | `src/dal` | Repository traits with Mongo implementations, Neo4j + Weaviate clients & schemas. |
| Config | `src/config` | `AppConfig` loads DPK-prefixed env vars via `figment`; Makefile sources `config.env`. |

Data stores:
- **MongoDB** – source of truth for every entity and chat transcript.
- **Neo4j** – optional but fully wired (`neo4rs` client) for graph analytics and synopsis retrieval.
- **Weaviate** – vector embeddings for embedded memories, observations, perspectives, entities, etc.
- **ClickHouse (optional)** – telemetry tables seeded by `src/bin/clickhouse_init.rs` when enabled.

---

## gRPC Service Catalog
Proto sources live in `memory-graph-client/proto`, and Rust stubs are generated into `src/proto_gen`. All services use the `dpk.` package (admin endpoints live under `admin.`).

| Category | Service Servers | Implementation Highlights |
| --- | --- | --- |
| Core memory | `MemoryService`, `ObservationService`, `MemoryOrbService`, `ObservationEventService`, `PlaceService` | CRUD plus synopsis & sync hooks (`memory_service_v2`, `observation_service_v2`, `memory/memory_orb.rs`). |
| Emotional context | `PerspectiveService`, `ReentryService`, `ReflectionService`, `IntentionService`, `IdentificationService` | Use-matched application services for validation and cross-entity orchestration. |
| Narrative + sharing | `StoryService`, `TransmissionService`, `MediaService`, `EventService`, `EntityService`, `EntityIdentifiedService` | Repository-backed CRUD with Weaviate + Neo4j integration where relevant. |
| Users & chat | `ChatService`, `UserService`, `AdminService` | Chat service maintains transcripts in Mongo; Admin service aggregates repositories for operational tools. |
| Documents | `DocumentService` | Schema-driven structured storage via `DocumentApplicationService`. |
| Health | `HealthService` | Executes Mongo CRUD + Weaviate readiness probes, reports Neo4j configuration status. |

Generated clients are available in the bundled Python package (`memory-graph-client`) and any gRPC tooling targeting `grpc://<host>:50051`.

---

## Supporting Binaries
| Binary | Purpose |
| --- | --- |
| `sync_all` | Bulk Mongo → Neo4j/Weaviate sync with optional `USER_ID` filtering (`make sync-all`, `make sync-user USER_ID=...`). |
| `schema` | Creates or nukes Weaviate schemas (`make schema-migrate`, `make schema-create`). |
| `gds_analytics` | Executes Neo4j graph algorithms using the GDS adapter. |
| `projector`, `export_memory_debug` | Export/replay utilities for debugging graph state. |
| `clickhouse_init` | Seeds ClickHouse telemetry tables when `DPK__CLICKHOUSE__ENABLED=true`. |

---

## Getting Started
1. **Configure environment**
   ```bash
   cd /Users/darinkimball/PycharmProjects/memory-graph-service
   cp config.env.example config.env
   # Update Mongo, Neo4j, Weaviate, ClickHouse, and HMAC settings.
   ```
2. **Ensure dependencies** – start MongoDB/Neo4j/Weaviate via `keepsake-infra` (`make setup-dev`, `make port-forward-*`) or point to existing services.
3. **Run checks**
   ```bash
   make test          # loads config.env automatically
   make lint          # fmt + clippy (proto files excluded)
   ```
4. **Start the server**
   ```bash
   make run           # cargo run --bin memory-graph-service
   ```
5. **Deploy to dev/qa**
   ```bash
   make b             # runs ci targets then builds/pushes via keepsake-scripts
   ```

Key Makefile targets: `b`, `ci`, `lint`, `schema-migrate`, `sync-all`, `client-test`, `k8s-logs`, `k8s-status`.

---

## Testing & Validation
- `make test` runs all unit + integration tests (requires Mongo; certain suites also expect Weaviate/Neo4j).
- `make test-integration` executes the synopsis integration scenario (`tests/integration_synopsis_test.rs`) once the Brain service + dependencies are reachable.
- Individual integration files (`tests/grpc_*.rs`, `tests/synopsis_test.rs`, `tests/gds_analytics_test.rs`) show concrete request/response flows.
- Python client tests: `make client-test` (runs `memory-graph-client/run_tests.py`).

Use `config.env` to centralize credentials; the Makefile sources it automatically for every target.

---

## Sync & Embedded Collections
- `MemoryGraphSyncService` (`src/service/sync/sync_service.rs`) is constructed inside `src/server.rs` and invoked by `MemoryServiceV2`/`ObservationServiceV2` to push updates to Neo4j and Weaviate.
- Embedded Weaviate schemas live in `src/dal/schema/weaviate/*` (memory orbs, observations, perspectives, media, entities, reflections, transmissions, stories, labels, memory graph links).
- CLI helpers:
  ```bash
  make sync-all                  # run sync_all inside the Kubernetes pod
  make sync-user USER_ID=<uuid>  # scoped sync
  cargo run --bin sync_all       # local bulk sync (requires env vars)
  ```
- Environment requirements for sync tooling are documented in `docs/sync-environment-variables.md`.

---

## Health & Observability
- `HealthServiceV2` runs Mongo CRUD, probes Weaviate (`/v1/.well-known/ready` + test object lifecycle), and reports Neo4j configuration status via `MongoHealthRepository`.
- `make k8s-logs` / `make k8s-status` surface pod health; CI mirrors `make ci` prior to building Docker images.
- Optional ClickHouse dashboards can be seeded with `make clickhouse-init` once `DPK__CLICKHOUSE__ENABLED=true`.

---

## Repository Guide
| Path | Contents |
| --- | --- |
| `src/` | Main Rust crate (services, application layer, DAL, config, utils, binaries). |
| `tests/` | Integration and scenario tests (`cargo test`). |
| `memory-graph-client/` | Python gRPC client with proto sources, build scripts, and tests. |
| `docs/` | Living documentation (see `docs/README.md`). |
| `bin/` | Build helper scripts invoked by keepsake-scripts. |

---

## Documentation Map
- `docs/README.md` – documentation index that links every architecture, API, dev, and ops guide.
- `docs/architecture/three_tier_flow.md` – request flow from gRPC handlers through application services into Mongo.
- `docs/architecture/04-application-service-usage.md` – per-entity mapping of application services, repositories, and tests.
- `docs/architecture/04-decay-mechanics-integration.md` – synopsis and sync orchestration across Mongo, Neo4j, and Weaviate.
- `docs/api/02-grpc-api-reference.md` – gRPC surface area with pointers to proto definitions and `src/service/*`.
- `docs/api/01-document-service.md` – schema-driven structured data workflow implemented by `DocumentServiceV2`.
- `docs/development/03-testing-guide.md` & `docs/development/04-quick-reference.md` – commands, environment preparation, troubleshooting.
- `docs/deployment/01-deployment-guide.md` – CI/CD pipeline description that mirrors `.github/workflows/deploy.yaml`.
- `docs/task_sheet.md` – live checklist that tracks this documentation review.

All documentation now describes the current code paths—historical exploration notes were removed or explicitly labeled as future work.

---

## Contributing
- Follow the Keepsake/Cursor rules in `docs/development/02-cursor-rules.md`.
- Never commit directly to `master`; use feature branches (e.g., `docs/mgs-doc-review`).
- Run `make test` (and `make lint` if touching Rust) before opening a PR.
- CI automatically builds/pushes Docker images and updates the Helm values in `keepsake-infra` after master merges.

This project is licensed under the MIT License (`LICENSE`). For a cross-repo overview, see `/Users/darinkimball/PycharmProjects/ECOSYSTEM_OVERVIEW.md`.
# Keepsake Scripts

This directory contains shared build scripts and utilities for the Keepsake ecosystem.

## Build System Overview

The Keepsake ecosystem uses a standardized build process across all projects. Each project has its own `make b` command that handles the complete build and deployment pipeline.

## Command B Setup

### What is "Command B"?

Each Keepsake project has a `make b` target that:
1. **Sources local environment**: Runs `./bin/build.sh` which sources the project's `env.sh` file
2. **Updates versions**: Automatically updates internal package versions (e.g., `keepsake-services` from 0.0.10 to 0.0.11)
3. **Builds wheel**: Creates a Python wheel and uploads it to the local PyPI server
4. **Docker build**: Builds the Docker image with proper environment variables
5. **Kubernetes deploy**: Deploys to Kubernetes using Helm

### Why Use Command B?

- **Environment consistency**: Each project has its own `env.sh` with specific settings
- **Version management**: Automatically keeps internal dependencies up-to-date
- **Local PyPI integration**: Uses the local PyPI server for internal packages
- **Proper build context**: Sources the right environment variables for Docker builds

## Project Structure

Each Keepsake project follows this structure:

```
project-name/
├── bin/
│   └── build.sh          # Main build script
├── env.sh                # Project-specific environment variables
├── pyproject.toml        # Python project configuration
├── Dockerfile            # Container definition
├── Makefile              # Project makefile with 'b' target
└── README.md
```

## Build Scripts

### `build.sh`
The main build script that:
- Sources `env.sh` for environment variables
- Updates internal package versions
- Builds and uploads Python wheels to local PyPI
- Builds Docker images
- Deploys to Kubernetes

### `build-docker-image.sh`
Generic Docker build script (legacy - use `make b` instead)

### `common.sh`
Shared utilities and functions used across build scripts

## Usage

### Building a Project

```bash
# From within a project directory
make b
```

### Building from Infrastructure

```bash
# From keepsake-infra directory
make dev-build-brain-viewer    # Uses: cd ../keepsake-brain-viewer && make b
make dev-build-langgraph       # Uses: cd ../keepsake-brain && make b
```

## Environment Variables

Each project's `env.sh` file should define:
- `KEEPSAKE_PROJECT_ROOT`: Root directory of all Keepsake projects
- `KEEPSAKE_SCRIPTS_ROOT`: Path to this scripts directory
- Project-specific variables (ports, hosts, etc.)

## Local PyPI Server

The build process uses a local PyPI server for internal packages:
- **URL**: `http://localhost:8080`
- **Purpose**: Hosts internal packages like `keepsake-services`, `memory-graph-client`
- **Authentication**: Uses admin credentials from environment

## Docker Build Process

1. **Environment Setup**: Sources project's `env.sh`
2. **Dependency Resolution**: Uses `uv` for Python package management
3. **Wheel Building**: Creates Python wheels for local packages
4. **Image Building**: Builds Docker image with proper environment
5. **Deployment**: Deploys to Kubernetes using Helm

## Best Practices

1. **Always use `make b`**: Don't use generic build scripts directly
2. **Keep env.sh updated**: Ensure project-specific variables are current
3. **Version management**: Let the build process handle version updates
4. **Local PyPI**: Ensure local PyPI server is running before builds
5. **Environment consistency**: Each project should have its own `env.sh`

## Troubleshooting

### Common Issues

1. **Version mismatches**: Run `make b` to update internal package versions
2. **Environment variables**: Check that `env.sh` is properly sourced
3. **Local PyPI**: Ensure PyPI server is running on localhost:8080
4. **Docker builds**: Check that environment variables are passed correctly

### Debug Commands

```bash
# Check environment variables
source env.sh && env | grep KEEPSAKE

# Check local PyPI packages
curl http://localhost:8080/simple/

# Check Docker build context
docker build --no-cache -t test-image .
```

## Integration with Infrastructure

The `keepsake-infra` Makefile has been updated to use `make b` for all project builds:

- `dev-build-brain-viewer`: Uses `cd ../keepsake-brain-viewer && make b`
- `dev-build-langgraph`: Uses `cd ../keepsake-brain && make b`

This ensures consistent builds across the entire ecosystem.

## Environment-Specific Deployments

### Dagster Components

Dagster (data orchestration platform) is part of the Keepsake ecosystem but has environment-specific deployment strategies:

- **DEV Environment**: Dagster components are **disabled** (`enabled: false` in `values-dev.yaml`)
  - Reason: Dagster performs better on Linux Intel chips than macOS ARM
  - Components: webserver and daemon are not deployed
  - PostgreSQL is still available for other services

- **QA Environment**: Dagster components are **enabled** (`enabled: true` in `values-qa.yaml`)
  - Reason: Linux Intel environment provides optimal performance
  - Components: Full Dagster stack (webserver, daemon, PostgreSQL)
  - Story-runner pipelines are available and configured

### Story-Runner Integration

The Dagster chart is configured for the story-runner project with commented-out workspace entries for:
- `dagster_story_runner_media_pipeline`
- `dagster-story-maker-service`
- `dagster-text-decipher-service`
- `dagster-image-decipher-service`
- `dagster-audio-decipher-service`
- `dagster-video-decipher-service`

These components are built separately and integrated when deployed to QA.

### Build Commands

Dagster build commands are now available for development:

**From keepsake-infra:**
- `make dev-build-dagster-webserver` - Build and deploy Dagster webserver
- `make dev-build-dagster-daemon` - Build and deploy Dagster daemon  
- `make dev-build-dagster` - Build both components

**From story-runner/dagster:**
- `make b-webserver` - Build webserver Docker image
- `make b-daemon` - Build daemon Docker image
- `make b` - Build both components

**Note:** While Dagster is disabled by default in dev (for performance reasons), developers can now build and test Dagster components locally when needed.

## Contributing

When adding new projects to the Keepsake ecosystem:

1. Create project directory with standard structure
2. Add `env.sh` with project-specific variables
3. Add `bin/build.sh` that sources `env.sh`
4. Add `make b` target to project Makefile
5. Update `keepsake-infra` Makefile with new build commands

## Related Documentation

- [Keepsake Ecosystem Overview](../ECOSYSTEM_OVERVIEW.md)
- Individual project READMEs in their respective directories
- [Keepsake Infrastructure](../keepsake-infra/README.md)