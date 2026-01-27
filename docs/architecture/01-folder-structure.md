---
title: Architecture Folder Structure
description: Documentation about architecture folder structure
category: architecture
---
# Architecture Folder Structure

Snapshot of how the repository maps to the three-tier architecture as of November 2025.

---

## Layer Legend

| Layer | Responsibility | Primary Paths |
| --- | --- | --- |
| 🎯 Presentation | gRPC handlers, binaries, server bootstrap, proto bindings | `src/service/**`, `src/bin/**`, `src/server.rs`, `src/proto_gen/**` |
| 🧠 Application | Business logic, orchestration, validation, synopsis pipeline | `src/application/**`, `src/domain/**`, `src/container/**` |
| 💾 Data Access | Repository traits, Mongo/Neo4j/Weaviate implementations, schema definitions | `src/dal/**`, `src/migration/**` |

---

## Presentation Layer

| Path | Description |
| --- | --- |
| `src/service/` | One module per gRPC domain (`memory/`, `observation/`, `entity/`, `document/`, `chat/`, etc.). Each exposes a `*_service_v2.rs` handler plus `mod.rs`. Supporting helpers (`callback_client.rs`, `context_engine.rs`, `response_generator.rs`, etc.) also live here because they serve the transport layer. |
| `src/server.rs` | Builds `tonic::transport::Server`, wires every V2 handler, injects application services, and starts background sync/watch loops. |
| `src/bin/` | Standalone binaries compiled from the same crate: `sync_all`, `schema`, `gds_analytics`, `projector`, `export_memory_debug`, and `clickhouse_init`. |
| `src/proto_gen/` | Prost-generated Rust code produced at build time from `memory-graph-client/proto/*.proto`. Treat as read-only. |

---

## Application Layer

| Path | Description |
| --- | --- |
| `src/application/` | Use-case specific services (`memory`, `observation`, `synopsis`, `document`, etc.) plus cross-cutting helpers (emotion analysis, breakdown orchestrator, outbox). |
| `src/domain/` | Canonical domain models and conversion helpers between Mongo schemas, application structs, and proto messages (e.g., `memory.rs`, `observation.rs`, `entity.rs`). |
| `src/container/` | Dependency injection utilities. `service_registry.rs` wires repositories into application services that presentation handlers consume. |

---

## Data Access Layer

| Path | Description |
| --- | --- |
| `src/dal/interfaces/` | Repository traits for every aggregate plus specialized contracts for Neo4j/Weaviate adapters. |
| `src/dal/schema/mongo/` | MongoDB repository implementations backed by `MongoRepository<T>` plus typed storage models. |
| `src/dal/schema/neo4j/` | Neo4j graph adapters, GDS helpers, and query builders. |
| `src/dal/schema/weaviate/` | Vector schema definitions and clients for Weaviate projections. |
| `src/dal/schema/storage_models.rs` | BSON-serializable structs shared across repositories. |
| `src/migration/` | Utilities for schema migrations (primarily for Mongo collections). |

---

## Supporting Paths

| Path | Description |
| --- | --- |
| `src/config/` | `AppConfig`, env loading, tracing initialization. |
| `src/utils/` | Common utilities (e.g., error helpers, chrono conversions). |
| `tests/` | Integration suites. Files prefixed with `grpc_` hit live servers; `synopsis_test.rs` orchestrates end-to-end synopsis generation. |
| `memory-graph-client/` | Python client, proto definitions, build scripts (`bin/generate_proto.sh`), and tests. |
| `Makefile` | Single entry point for lint/test/build/deploy; wraps keepsake-scripts for Docker builds. |
| `docs/` | This documentation set. |

---

## How to Use This Map

1. **Choose the layer** you need to touch (presentation/application/DAL).
2. **Locate the module** using the tables above.
3. **Follow the same structure** when adding new files—presentation code stays under `src/service`, application logic under `src/application`, and persistence concerns under `src/dal`.

This mapping is kept up to date whenever new folders are introduced so contributors can quickly find the right layer.

