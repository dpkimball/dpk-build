# Documentation Review Task Sheet

This tracker captures the documentation audit for `memory-graph-service`. Update statuses as each section is aligned with the current codebase.

| Section | Files / Scope | Status | Notes |
| --- | --- | --- | --- |
| Root Overview | `README.md` | ✅ Complete | Replaced with current architecture, service catalog, and workflows |
| Docs Index | `docs/README.md` | 🔄 In progress | Need to align file lists + legacy section callouts |
| API Docs | `docs/api/*.md` | 🔄 In progress | Update gRPC catalog + document service v2 references |
| Architecture | `docs/architecture/*.md` | 🔄 In progress | Refresh folder structure + application service usage details |
| Development Guides | `docs/development/*.md` | 🔄 In progress | Testing + quick reference still mention outdated port-forward & status text |
| Deployment | `docs/deployment/01-deployment-guide.md` | 🔄 In progress | Should mirror Helm workflow in `.github/workflows/deploy.yaml` |
| Design Specs | `docs/design/**/*` | 🔄 In progress | Remove Brain-only historical context; focus on modules that live in this repo |
| Examples | `docs/examples/*` | 🔄 In progress | Validate payloads against current proto messages |
| Sync & Env | `docs/sync-environment-variables.md`, `docs/cursor_todos/environment_variables.md` | 🔍 Review next | Double-check against `config.env.example` + `sync_all` flags |
| Legacy / Research | `docs/development/legacy/*`, `docs/development/research/*` | 🚧 Decide | Determine which content should be archived vs. summarized |

Legend: ✅ complete · 🔄 in progress · 🔍 queued · 🚧 needs decision
# Documentation Review Task Sheet

This sheet tracks the documentation audit for `memory-graph-service`. Update the status and notes as each document is reviewed against the live codebase.

| Section | Files | Status | Notes |
| --- | --- | --- | --- |
| Root Overview | `README.md` | Pending | Verify services/features match current Rust modules |
| Docs Index | `docs/README.md` | Pending | Ensure navigation + references are valid |
| API Docs | `docs/api/*.md` | Pending | Confirm proto + service coverage |
| Architecture | `docs/architecture/*.md` | Pending | Align layer descriptions with current module tree |
| Development Guides | `docs/development/*.md` | Pending | Validate commands, env vars, and workflow |
| Deployment | `docs/deployment/*.md` | Pending | Check against Makefile + infra expectations |
| Design Specs | `docs/design/**/*.md` | Pending | Confirm diagrams/specs reflect code concepts |
| Examples | `docs/examples/*` | Pending | Test payloads/types with latest schema |
| Sync & Env | `docs/sync-environment-variables.md`, `docs/cursor_todos/environment_variables.md` | Pending | Cross-check with `config.env.example` |
| Legacy/Research | `docs/development/legacy/*`, `docs/development/research/*` | Pending | Identify outdated or redundant content |


