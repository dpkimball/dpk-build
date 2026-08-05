# Decision baseline — Issue #39

**Issue:** https://github.com/dpkimball/dpk-build/issues/39  
**Base branch:** master  
**Base SHA:** `58653db28366f81746419fedc311f5934564419a`  
**Assessed at:** 2026-08-05T17:50:33Z  
**Tier:** high-risk

## Why this file exists

Issue #39 was filed before two merged decisions changed the ground it stands on. Delivery implemented its wording literally, restoring `templates/env.sh`, and the whole spec/plan/review chain then validated that restoration internally without ever asking whether the requirement was still true. Every gate passed and the outcome was still wrong. This baseline reconciles the filed criteria against what master actually does before any further specification.

## Current-state reconciliation

Two merged PRs define the current contract:

**PR [#40](https://github.com/dpkimball/dpk-build/pull/40) — `ae80ca63dab8b862ccf8b9a6d7e79ca854b554e5`** renamed `keepsake-paths.sh` to `paths.sh` and settled the canonical path exports as `SSD`, `WORKSPACE_ROOT`, and `BUILD_ROOT`. It deliberately did **not** ship the names the issue text asks for: there is no `SCRIPTS_ROOT` and no `COMPOSE_PROJECT_ROOT`, and `PROJECT_ROOT` is a per-repo variable set by each consuming project rather than a workspace path. Legacy `KEEPSAKE_SSD`, `KEEPSAKE_PROJECT_ROOT`, and `KEEPSAKE_SCRIPTS_ROOT` survive as read-only input fallbacks in `paths.sh`, and `KEEPSAKE_SCRIPTS_ROOT` likewise in `src/context.rs`.

**PR [#49](https://github.com/dpkimball/dpk-build/pull/49) — `8c8bd4cd6e0e80ed43a11accfbef944fa3077cb6`** removed dead keepsake-scripts-era shell shims and helpers, and `templates/env.sh` was removed in that sweep as an obsolete artifact. Its commit message names the file directly: "drop keepsake-scripts era aliases, cleanup-docker, jupyter/load-k8s, and obsolete `templates/env.sh`." The same commit rewrote `templates/README.md` around the lean **Makefile + `dpk.toml`** contract, which needs no project `env.sh` for `deliver`.

On master today, `templates/` contains exactly `Makefile` and `README.md`. No consumer in this repository requires a template `env.sh`, and no post-#49 decision reverses that deletion.

**User decision (2026-08-05, recorded on the issue):** `templates/env.sh` is not to be restored. The filed template-bootstrap criterion is stale wording, not live intent, and reversing #49 would need a new evidenced use case that does not exist.

## Acceptance-criteria reconciliation

| Filed criterion | Status | Evidence | Rationale |
|-----------------|--------|----------|-----------|
| Canonical path file exports `SSD`, `PROJECT_ROOT` (workspace), `SCRIPTS_ROOT`, `COMPOSE_PROJECT_ROOT` | superseded | `pr:https://github.com/dpkimball/dpk-build/pull/40`, `commit:ae80ca63dab8b862ccf8b9a6d7e79ca854b554e5`, `file:paths.sh` | #40 settled the canonical set as `SSD` / `WORKSPACE_ROOT` / `BUILD_ROOT`. `SCRIPTS_ROOT` and `COMPOSE_PROJECT_ROOT` were dropped, and `PROJECT_ROOT` means the consuming repo, not the workspace. |
| Default workspace dir is `dpk-workspace`, legacy discovery only inside that one file | already_satisfied | `file:paths.sh`, `commit:ae80ca63dab8b862ccf8b9a6d7e79ca854b554e5` | `paths.sh` defaults to `dpk-workspace`, discovers `keepsake-workspace` only as a fallback, and prefers `dpk-workspace` when both exist. No other file performs discovery. |
| File renamed off `keepsake-paths.sh` | already_satisfied | `file:paths.sh`, `commit:ae80ca63dab8b862ccf8b9a6d7e79ca854b554e5` | `paths.sh` is the canonical file; `keepsake-paths.sh` is absent from master. |
| Template `env.sh` bootstraps via sibling `../dpk-build` | superseded | `pr:https://github.com/dpkimball/dpk-build/pull/49`, `commit:8c8bd4cd6e0e80ed43a11accfbef944fa3077cb6`, `issue-comment:https://github.com/dpkimball/dpk-build/issues/39#issuecomment-5195265997`, `file:templates/README.md` | #49 deleted the file as an obsolete keepsake-scripts-era artifact and moved new-project onboarding to lean Makefile + `dpk.toml`. The user's Decision Integrity correction confirms it stays deleted absent a new evidenced use case. Restoring it in this PR was the decision failure being corrected. |
| Internal dpk-build scripts/docs use the new names | already_satisfied | `file:python/deploy-k8s.sh`, `file:rust/deploy-k8s.sh`, `file:README.md` | Internal scripts read `WORKSPACE_ROOT` / `BUILD_ROOT`. Remaining `KEEPSAKE_*` mentions are the documented read-only fallbacks in `paths.sh` and the README note about the legacy alias. |
| Old `KEEPSAKE_*` path names accepted as read fallbacks only during cutover | already_satisfied | `file:paths.sh`, `file:src/context.rs` | `paths.sh` reads the legacy names only when the canonical variable is unset and never re-exports them; `resolve_build_root` honours `KEEPSAKE_SCRIPTS_ROOT` only when `BUILD_ROOT` is unset. |

No criterion is in `conflict`: the two superseded rows are resolved by merged decisions plus an explicit user instruction on the issue, not by agent judgment.

## What this leaves for the PR

Every filed criterion is already satisfied on master or superseded. The honest remaining value of this branch is therefore **not** new path behaviour — it is deterministic regression coverage that pins the settled contract so it cannot drift silently, plus the delivery record:

1. A CI-owned behaviour matrix for `paths.sh` and root `env.sh` (defaults, `dpk-workspace` preference, legacy discovery, legacy-input mapping, canonical precedence, no legacy exports, `BUILD_ROOT` forcing, ports untouched) and for repository shape (`keepsake-paths.sh` absent; among tracked shell scripts, legacy aliases and the umbrella name appear only in `paths.sh` and in the matrix itself, which must contain those strings to assert them). These are negative greps: they prove legacy strings are gone, not that canonical names are used, which stays file evidence.
2. Rust integration tests that prove `resolve_build_root` precedence with a decoy tree rather than accepting "either value works".
3. The `docs/issues/39/` bundle recording the decision, the evidence, and the correction.

Consumer-repo cutovers (Foreman, Binder Cloud, resume-pipeline) remain follow-up work in their own repositories and are not completed or claimed here.

## Superseded filed wording

The original AC list is preserved in the issue's "Superseded filed wording" section and in this table. Nothing is erased: the record should show that the template criterion was filed, was superseded by #49, and was then wrongly implemented before this correction.

## Decision integrity manifest

```json
{
  "schema_version": 1,
  "issue": 39,
  "base_ref": "master",
  "base_sha": "58653db28366f81746419fedc311f5934564419a",
  "acceptance_criteria": [
    {
      "criterion": "Canonical path file exports SSD, PROJECT_ROOT (workspace), SCRIPTS_ROOT, COMPOSE_PROJECT_ROOT (no KEEPSAKE_ prefix on these)",
      "status": "superseded",
      "evidence": [
        "pr:https://github.com/dpkimball/dpk-build/pull/40",
        "commit:ae80ca63dab8b862ccf8b9a6d7e79ca854b554e5",
        "file:paths.sh"
      ],
      "rationale": "Merged PR #40 settled the canonical exports as SSD, WORKSPACE_ROOT and BUILD_ROOT; SCRIPTS_ROOT and COMPOSE_PROJECT_ROOT were dropped and PROJECT_ROOT is per-repo, not the workspace."
    },
    {
      "criterion": "Default workspace dir is dpk-workspace, with optional discovery of the legacy folder only inside this one file",
      "status": "already_satisfied",
      "evidence": [
        "file:paths.sh",
        "commit:ae80ca63dab8b862ccf8b9a6d7e79ca854b554e5"
      ],
      "rationale": "paths.sh defaults to dpk-workspace, discovers keepsake-workspace only as a fallback, prefers dpk-workspace when both exist, and is the only file performing discovery."
    },
    {
      "criterion": "File renamed off keepsake-paths.sh (e.g. paths.sh)",
      "status": "already_satisfied",
      "evidence": [
        "file:paths.sh",
        "commit:ae80ca63dab8b862ccf8b9a6d7e79ca854b554e5"
      ],
      "rationale": "paths.sh is canonical on master and keepsake-paths.sh no longer exists."
    },
    {
      "criterion": "Template env.sh bootstraps via sibling ../dpk-build (no umbrella folder name)",
      "status": "superseded",
      "evidence": [
        "pr:https://github.com/dpkimball/dpk-build/pull/49",
        "commit:8c8bd4cd6e0e80ed43a11accfbef944fa3077cb6",
        "issue-comment:https://github.com/dpkimball/dpk-build/issues/39#issuecomment-5195265997",
        "file:templates/README.md"
      ],
      "rationale": "Merged PR #49 deleted templates/env.sh as an obsolete keepsake-scripts-era artifact and moved onboarding to lean Makefile + dpk.toml; the user's Decision Integrity correction confirms it stays deleted without a new evidenced use case."
    },
    {
      "criterion": "Internal dpk-build scripts/docs use the new names",
      "status": "already_satisfied",
      "evidence": [
        "file:python/deploy-k8s.sh",
        "file:rust/deploy-k8s.sh",
        "file:README.md"
      ],
      "rationale": "Internal scripts consume WORKSPACE_ROOT and BUILD_ROOT; remaining legacy mentions are the documented read-only fallbacks."
    },
    {
      "criterion": "Old KEEPSAKE_* path names accepted as read fallbacks only during cutover",
      "status": "already_satisfied",
      "evidence": [
        "file:paths.sh",
        "file:src/context.rs"
      ],
      "rationale": "Legacy names are read only when the canonical variable is unset and are never re-exported; resolve_build_root honours KEEPSAKE_SCRIPTS_ROOT only when BUILD_ROOT is unset."
    }
  ]
}
```
