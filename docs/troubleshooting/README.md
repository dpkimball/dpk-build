# Memory Graph Service Documentation
## Overview

## Responsibilities

## Non-Responsibilities

## System Context

## Usage

## Configuration Summary

## Extended Documentation

## Lifecycle Status


Active
## Architecture
- `architecture/three_tier_flow.md` – illustrates how requests traverse `src/service/**`, `src/application/**`, and `src/dal/**`, using `MemoryServiceV2` as the canonical example.
- `architecture/04-application-service-usage.md` – enumerates every application service, the repositories it drives, and the gRPC handlers that invoke it.
- `architecture/04-decay-mechanics-integration.md` – details how the synopsis pipeline, `BreakdownOrchestrator`, and `MemoryGraphSyncService` coordinate Mongo ↔ Neo4j ↔ Weaviate updates.
- `architecture/emotions.md` – explains the shipped emotion enums (`storage_models::Emotion`) and the `EmotionAnalysisService` integration points.

## API Surface
- `api/02-grpc-api-reference.md` – maps each proto (`memory_graph_client/proto/*.proto`) to its Rust handler in `src/service`.
- `api/01-document-service.md` – deep dive into `DocumentServiceV2`, schema definitions, and `DocumentApplicationService`.

## Development Workflow
- `development/01-pull-request-template.md` – PR checklist that mirrors the repo’s CI and testing requirements.
- `development/02-cursor-rules.md` – AI assistant guardrails (mirrors `.cursorrules` expectations).
- `development/03-testing-guide.md` – how to run `make test`, configure `config.env`, and satisfy Mongo/Neo4j dependencies.
- `development/04-quick-reference.md` – condensed command sheet with common fixes.
- `development/05-local-services.md` – port-forwarding and verification for Mongo, Neo4j, and Weaviate.

## Deployment & Operations
- `deployment/01-deployment-guide.md` – documents the Helm-based workflow defined in `.github/workflows/deploy.yaml` and `Makefile b`.
- `sync-environment-variables.md` – required environment for `sync_all`, `schema`, and other binaries.

## Examples & Payloads
- `examples/` – sample requests/responses for the synopsis pipeline plus JSON payloads used by `tests/synopsis_test.rs`.
- `example_3_sources.json` – fixture that drives the multi-source synopsis tests.

## Design Specifications
- `design/specifications/01-brain-architecture.md` – describes the shipped Context Engine, Decision Kernel, and GDS services under `src/service`.
- `design/specifications/02-project-charter.md` – scope and invariants for memory evolution entities (Observation, Perspective, MemoryOrb, etc.).
- `design/specifications/03-data-model.md` – summarizes the storage-facing attributes present in `storage_models.rs`.
- `design/diagrams/*` – Mermaid diagrams consumed by the architecture docs (kept in sync with the specs above).

## Task Tracking
- `01-review-task-sheet.md` – live checklist for the current documentation audit. Each row records comparison notes between docs and code (`src/`, `tests/`, `.github/`).

Need a starting point? Read `README.md` in the repository root, then dive into the sections above based on the task at hand.
# Memory Graph Service Documentation

This directory describes the production behavior of the Rust gRPC service. Each section links directly to the files that mirror the current implementation under `src/`, `tests/`, and `.github/`.

## Architecture
- `architecture/three_tier_flow.md` – illustrates how requests traverse `src/service/**`, `src/application/**`, and `src/dal/**`, using `MemoryServiceV2` as the canonical example.
- `architecture/04-application-service-usage.md` – enumerates every application service, the repositories it drives, and the gRPC handlers that invoke it.
- `architecture/04-decay-mechanics-integration.md` – details how the synopsis pipeline, `BreakdownOrchestrator`, and `MemoryGraphSyncService` coordinate Mongo ↔ Neo4j ↔ Weaviate updates.
- `architecture/emotions.md` – explains the shipped emotion enums (`storage_models::Emotion`) and the `EmotionAnalysisService` integration points.

## API Surface
- `api/02-grpc-api-reference.md` – maps each proto (`memory_graph_client/proto/*.proto`) to its Rust handler in `src/service`.
- `api/01-document-service.md` – deep dive into `DocumentServiceV2`, schema definitions, and `DocumentApplicationService`.

## Development Workflow
- `development/01-pull-request-template.md` – PR checklist that mirrors the repo’s CI and testing requirements.
- `development/02-cursor-rules.md` – AI assistant guardrails (mirrors `.cursorrules` expectations).
- `development/03-testing-guide.md` – how to run `make test`, configure `config.env`, and satisfy Mongo/Neo4j dependencies.
- `development/04-quick-reference.md` – condensed command sheet with common fixes.
- `development/05-local-services.md` – port-forwarding and verification for Mongo, Neo4j, and Weaviate.

## Deployment & Operations
- `deployment/01-deployment-guide.md` – documents the Helm-based workflow defined in `.github/workflows/deploy.yaml` and `Makefile b`.
- `sync-environment-variables.md` – required environment for `sync_all`, `schema`, and other binaries.

## Examples & Payloads
- `examples/` – sample requests/responses for the synopsis pipeline plus JSON payloads used by `tests/synopsis_test.rs`.
- `example_3_sources.json` – fixture that drives the multi-source synopsis tests.

## Design Specifications
- `design/specifications/01-brain-architecture.md` – describes the shipped Context Engine, Decision Kernel, and GDS services under `src/service`.
- `design/specifications/02-project-charter.md` – scope and invariants for memory evolution entities (Observation, Perspective, MemoryOrb, etc.).
- `design/specifications/03-data-model.md` – summarizes the storage-facing attributes present in `storage_models.rs`.
- `design/diagrams/*` – Mermaid diagrams consumed by the architecture docs (kept in sync with the specs above).

## Task Tracking
- `01-review-task-sheet.md` – live checklist for the current documentation audit. Each row records comparison notes between docs and code (`src/`, `tests/`, `.github/`).

Need a starting point? Read `README.md` in the repository root, then dive into the sections above based on the task at hand.
# 📚 Memory Graph Service Documentation

Living documentation for every part of the service. Each file describes the **current** implementation; historical brainstorms and backlog notes were removed during the November 2025 audit.

---

## 📁 Structure

| Directory | Purpose |
| --- | --- |
| `architecture/` | Three-tier layout, folder breakdowns, and sequence diagrams. |
| `api/` | Integration guides for Document Service and the broader gRPC surface. |
| `deployment/` | CI/CD workflow, Helm, and GitOps expectations. |
| `development/` | PR template, Cursor rules, testing guide, quick reference, and local service notes. |
| `design/` | Viewer/brain/data-model specs plus the ancestry-style graph diagrams. |
| `examples/` | Concrete payloads for synopsis/context flows. |
| `cursor_todos/` | Environment-variable checklist for Cursor assistants. |
| `sync-environment-variables.md` | Required exports for running `sync_all` and schema binaries. |
| `01-memory-graph-service-review-task-sheet.md` | Tracker for this doc-alignment effort. |

---

## 🏗 Architecture (`architecture/`)

| File | Description |
| --- | --- |
| [`01-folder-structure.md`](architecture/01-folder-structure.md) | Maps every folder in `src/` to presentation/application/DAL boundaries. |
| [`02-three-tier-refactoring.md`](architecture/02-three-tier-refactoring.md) | Status of the refactor, evaluation checklist for new code, and remaining gaps. |
| [`04-application-service-usage.md`](architecture/04-application-service-usage.md) | Which gRPC handlers call which application services and repositories today. |
| [`04-decay-mechanics-integration.md`](architecture/04-decay-mechanics-integration.md) | How salience/decay heuristics inside the synopsis pipeline are implemented (no legacy Edge service references). |
| [`emotions.md`](architecture/emotions.md) | Emotion signal enrichment, NRC lexicon usage, and how scores feed synopsis/context. |
| [`three_tier_flow.md`](architecture/three_tier_flow.md) | Mermaid diagrams for a typical MemoryService request moving through all three layers. |

---

## 🔌 API (`api/`)

| File | Description |
| --- | --- |
| [`01-document-service.md`](api/01-document-service.md) | Schema definition lifecycle, insert/query RPCs, and how `DocumentServiceV2` maps to Mongo collections. |
| [`02-grpc-api-reference.md`](api/02-grpc-api-reference.md) | Service-by-service overview tying proto packages to handler modules and regeneration steps. |

---

## 🚀 Deployment (`deployment/`)

| File | Description |
| --- | --- |
| [`01-deployment-guide.md`](deployment/01-deployment-guide.md) | Summary of `.github/workflows/deploy.yaml`, required Make targets, Helm release inputs, and post-deploy validation. |

---

## 👨‍💻 Development (`development/`)

| File | Description |
| --- | --- |
| [`01-pull-request-template.md`](development/01-pull-request-template.md) | PR skeleton enforced for every change (tests, risks, rollout). |
| [`02-cursor-rules.md`](development/02-cursor-rules.md) | Full Cursor/Keepsake ruleset for AI collaborators. |
| [`03-testing-guide.md`](development/03-testing-guide.md) | Mongo/Neo4j/Weaviate setup plus instructions for each test suite. |
| [`04-quick-reference.md`](development/04-quick-reference.md) | Frequently used commands, troubleshooting, and log collection. |
| [`05-local-services.md`](development/05-local-services.md) | How to bootstrap dependencies via `keepsake-infra` and verify health locally. |

---

## 🎨 Design (`design/`)

### Diagrams (`design/diagrams/`)
| File | Focus |
| --- | --- |
| [`dd.md`](design/diagrams/dd.md) | Node graph visual spec based on `GetMemoryExpandedResponse`. |
| [`display.md`](design/diagrams/display.md) | UI contract for slicing gRPC data into viewer panels. |
| [`display_review.md`](design/diagrams/display_review.md) | Acceptance checklist that keeps the viewer implementation grounded in real proto fields. |

### Specifications (`design/specifications/`)
| File | Description |
| --- | --- |
| [`01-brain-architecture.md`](design/specifications/01-brain-architecture.md) | How keepsake-brain orchestrates LangGraph nodes against this service. |
| [`02-project-charter.md`](design/specifications/02-project-charter.md) | Current mission/objectives for memory-graph-service inside the Keepsake ecosystem. |
| [`03-data-model.md`](design/specifications/03-data-model.md) | Entity definitions that tie `src/domain/*` to `memory_graph_client/proto/*`. |

---

## 📄 Examples & Operational Docs

- [`examples/synopsis-payloads.md`](examples/synopsis-payloads.md) — Example payloads for every hop in the synopsis pipeline.
- [`cursor_todos/environment_variables.md`](cursor_todos/environment_variables.md) — `DPK__*` variables surfaced from `src/config/mod.rs`.
- [`sync-environment-variables.md`](sync-environment-variables.md) — Env requirements for running `sync_all` and schema binaries locally or in Kubernetes.

---

## 🧭 Navigation Tips

- **New contributors**: start with [`architecture/01-folder-structure.md`](architecture/01-folder-structure.md), then read the testing guide and quick reference docs.
- **API consumers**: review [`api/02-grpc-api-reference.md`](api/02-grpc-api-reference.md) plus the synopsis examples before integrating.
- **SRE/DevOps**: follow [`deployment/01-deployment-guide.md`](deployment/01-deployment-guide.md) together with the Makefile targets called out there.
- **Design/Product**: read the charter + data-model spec, then consult the diagrams for viewer requirements.

Docs are ASCII-only, grouped with two-digit prefixes, and updated alongside code so they stay truthful.

