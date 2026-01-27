---
title: Memory Graph Service Documentation Review Task Sheet
description: Documentation about memory graph service documentation review task sheet
category: troubleshooting
---
# Memory Graph Service Documentation Review Task Sheet

Central tracker for aligning every documentation asset with the current Rust implementation. Update the status column as each document is validated or revised.

| Document | Status | Notes / Required Actions |
| --- | --- | --- |
| `README.md` | Pending | Verify responsibilities, service catalog, binaries, and workflows match current code. |
| `docs/README.md` | Pending | Ensure index accurately reflects file structure and removes legacy references. |
| `docs/_excluded/event_2_place.md` | Pending | Confirm exclusion rationale and whether content belongs elsewhere. |
| `docs/api/01-document-service.md` | Pending | Cross-check with `DocumentApplicationService` and gRPC handlers. |
| `docs/api/02-grpc-api-reference.md` | Pending | Ensure all listed services, protos, and handlers exist and are current. |
| `docs/architecture/01-folder-structure.md` | Pending | Validate folder descriptions against `src/` layout. |
| `docs/architecture/02-three-tier-refactoring.md` | Pending | Confirm narrative matches actual layering in `src/application` and `src/dal`. |
| `docs/architecture/04-application-service-usage.md` | Pending | Align usage examples with present services. |
| `docs/architecture/04-decay-mechanics-integration.md` | Pending | Check decay pipeline references vs synopsis code. |
| `docs/architecture/emotions.md` | Pending | Verify emotion lexicon usage and references to `src/domain`. |
| `docs/architecture/three_tier_flow.md` | Pending | Ensure diagrams reflect latest control flow. |
| `docs/cursor_todos/environment_variables.md` | Pending | Confirm env var list matches `AppConfig`. |
| `docs/deployment/01-deployment-guide.md` | Pending | Update steps to match `.github/workflows/deploy.yaml` and Make targets. |
| `docs/design/diagrams/dd.md` | Pending | Validate architecture depiction with current code paths. |
| `docs/design/diagrams/display.md` | Pending | Review for accuracy against viewer integrations. |
| `docs/design/diagrams/display_review.md` | Pending | Ensure review notes are still relevant. |
| `docs/design/specifications/01-brain-architecture.md` | Pending | Confirm interactions with memory graph are correct. |
| `docs/design/specifications/02-project-charter.md` | Pending | Trim historical details; keep current scope only. |
| `docs/design/specifications/03-data-model.md` | Pending | Align schema descriptions with storage models. |
| `docs/development/01-pull-request-template.md` | Pending | Ensure template matches current workflow requirements. |
| `docs/development/02-cursor-rules.md` | Pending | Sync with latest Cursor ruleset. |
| `docs/development/03-testing-guide.md` | Pending | Validate commands/tests reflect `Makefile`. |
| `docs/development/04-quick-reference.md` | Pending | Cross-check command list and troubleshooting tips. |
| `docs/development/05-local-services.md` | Pending | Confirm service bootstrapping instructions. |
| `docs/development/legacy/implementation_checklist.md` | Pending | Ensure clearly marked legacy or replaced. |
| `docs/development/legacy/neo/neo.md` | Pending | Confirm legacy tag and current applicability. |
| `docs/development/legacy/neo/neo_implementation_checklist.md` | Pending | Same as above. |
| `docs/development/legacy/neo/neo_q_a.md` | Pending | Same as above. |
| `docs/development/legacy/neo/neo_q_a_2.md` | Pending | Same as above. |
| `docs/development/legacy/neo/phase1_summary.md` | Pending | Same as above. |
| `docs/development/research/brainstorm.md` | Pending | Confirm research doc either up-to-date or clearly historical. |
| `docs/development/research/chat.md` | Pending | Align chat architecture notes with current services. |
| `docs/development/research/handshakes/example_real_world.md` | Pending | Validate data flow references. |
| `docs/development/research/handshakes/full_keepsake_data_flow.md` | Pending | Ensure flows match actual integrations. |
| `docs/development/research/keepsake_infra_langgraph_setup.md` | Pending | Cross-check with infra repo processes. |
| `docs/development/research/langgraph_cicd_complete_setup.md` | Pending | Ensure instructions remain valid. |
| `docs/development/research/memory_decay.md` | Pending | Align with current decay mechanics in code. |
| `docs/development/research/open_questions.md` | Pending | Remove answered items or mark resolved. |
| `docs/development/research/perspective_memory_orb.md` | Pending | Confirm perspective/orb relationships are accurate. |
| `docs/development/research/poly.md` | Pending | Verify content relevance. |
| `docs/development/research/production_readiness_status.md` | Pending | Update to reflect present readiness metrics. |
| `docs/development/research/proto_vs_schema_comparison.md` | Pending | Ensure proto references are correct. |
| `docs/development/research/view.md` | Pending | Validate assumptions vs current viewer. |
| `docs/examples/synopsis-payloads.md` | Pending | Ensure payload samples match actual service responses. |
| `docs/sync-environment-variables.md` | Pending | Align with `sync_all` binary requirements. |

_Updated_: 2025-11-19

