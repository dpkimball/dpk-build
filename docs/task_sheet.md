# Documentation Review Task Sheet

| Area | Files | Status | Notes |
| --- | --- | --- | --- |
| Repo Overview | `README.md`, new `docs/README.md` | 🟡 In progress | Align top-level docs with actual module layout and current doc tree. |
| API Docs | `docs/api/01-document-service.md`, `docs/api/02-grpc-api-reference.md` | 🟡 In progress | Verify each RPC against `memory_graph_client/proto` and service implementations in `src/service`. |
| Architecture | `docs/architecture/three_tier_flow.md`, `04-application-service-usage.md`, `04-decay-mechanics-integration.*`, `emotions.md` | 🟡 In progress | Replace outdated edge/decay content with current synopsis, sync, and emotion flows backed by `src/application` + `src/service`. |
| Deployment | `docs/deployment/01-deployment-guide.md` | 🟡 In progress | Ensure content matches `.github/workflows/deploy.yaml` and Makefile targets. |
| Development Workflow | `docs/development/01-pull-request-template.md`, `02-cursor-rules.md`, `03-testing-guide.md`, `04-quick-reference.md`, `05-local-services.md` | 🟡 In progress | Update testing + workflow guidance to match Makefile and current infra expectations. |
| Sync & Ops | `docs/sync-environment-variables.md` | 🟡 In progress | Validate environment requirements against `src/service/sync` and Makefile targets. |
| Examples | `docs/examples/*`, `docs/example_3_sources.json` | 🟡 In progress | Confirm sample payloads still match proto contracts and integration tests. |
| Design Specs | `docs/design/diagrams/*`, `docs/design/specifications/*` | 🟡 In progress | Ensure written specs only describe shipped components (Context Engine, Decision Kernel, GDS). |



