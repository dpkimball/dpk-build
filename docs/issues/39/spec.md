# Spec — Issue #39

**Issue:** https://github.com/dpkimball/dpk-build/issues/39  
**Owner:** cursor-delivery  
**Status:** adversarial (decision-correction pass)  
**Complexity tier:** high-risk  
**run_id:** `4EE04D9C-35A4-4D91-81A2-AF85CE04E7F2`  
**Decision baseline:** `docs/issues/39/decision-baseline.md`. No validator badge is claimed here: the citable run is the post-correction re-run described in `plan.md` Step 1, recorded in `validation.md`.  
**Adversarial:** see `adversarial-spec-review.md`. Every approval recorded before this correction reviewed the superseded scope and is **void** for handoff; the rounds remain in the log as history.

## Problem

Issue #39 asked for a path-variable rename that has already happened, plus a template bootstrap that has since been deleted on purpose. Two merged decisions moved underneath the filed wording:

- **PR #40 (`ae80ca6`)** settled the canonical exports as `SSD`, `WORKSPACE_ROOT`, `BUILD_ROOT` in `paths.sh`, dropping `SCRIPTS_ROOT` and `COMPOSE_PROJECT_ROOT` and leaving `PROJECT_ROOT` as a per-repo variable.
- **PR #49 (`8c8bd4c`)** removed `templates/env.sh` as an obsolete keepsake-scripts-era artifact and moved new-project onboarding to the lean **Makefile + `dpk.toml`** contract.

An earlier revision of this delivery read the filed text literally and restored `templates/env.sh`, then built a fail-closed guard, documentation, and CI assertions on top of it. Every gate passed on that work and it was still wrong, because nothing in the process asked whether the requirement was still live. The user's Decision Integrity correction on the issue confirms the file stays deleted absent a new evidenced use case.

The real gap that remains is narrower and worth doing: **the settled contract has no deterministic regression coverage.** `paths.sh` defaults, workspace discovery, legacy-input fallbacks, and `resolve_build_root` precedence are all load-bearing for the fleet via `make b`, and nothing in CI would catch a silent regression.

## Decision baseline summary

`docs/issues/39/decision-baseline.md` maps every filed criterion. Two are **superseded** (the `SCRIPTS_ROOT`/`COMPOSE_PROJECT_ROOT` naming, by #40; the template bootstrap, by #49 plus the user decision) and four are **already satisfied** on master. There are no unresolved conflicts. No filed criterion requires a behaviour change in this PR.

## Goals

- Return the branch to master behaviour for `templates/` — the file absent, the README's lean contract intact.
- Keep the deterministic regression coverage that is genuinely about the current contract, and drop everything that only existed to test the restored file.
- Record the decision baseline so the supersession is auditable rather than re-litigated.
- Correct the issue's acceptance criteria so the stale wording stops driving implementations, without erasing what was filed.

## Non-goals

- Restoring `templates/env.sh`, or adding any replacement template `env.sh`.
- Changing `paths.sh` or root `env.sh` behaviour. Both are verify-only here.
- Renaming ports/URLs (`KEEPSAKE_BACKEND_PORT`, etc.) — out of scope per the issue.
- Editing consumer repositories. Their cutovers are follow-up work.
- Adding a test that forbids a future `templates/env.sh`. The deletion is a product decision recorded in the baseline, not something to freeze in a lint rule.
- Reintroducing `SCRIPTS_ROOT`, `COMPOSE_PROJECT_ROOT`, or a workspace-meaning `PROJECT_ROOT`.

## Architecture

The contract itself is unchanged by this PR; the diagram is what CI now pins.

```text
paths.sh   ──exports──►  SSD  →  WORKSPACE_ROOT  →  BUILD_ROOT
   │                     defaults: /Volumes/KeepsakeSSD, <SSD>/dpk-workspace,
   │                               <WORKSPACE_ROOT>/dpk-build
   │  reads (only when the canonical variable is unset, never re-exports):
   └─ KEEPSAKE_SSD, KEEPSAKE_PROJECT_ROOT, KEEPSAKE_SCRIPTS_ROOT

env.sh     ──sources──►  paths.sh, then forces BUILD_ROOT to its own directory
                         (ports/URLs keep their KEEPSAKE_ names — out of scope)

src/context.rs resolve_build_root:  BUILD_ROOT, else KEEPSAKE_SCRIPTS_ROOT
```

| Concern | Owner |
|---------|-------|
| Umbrella folder discovery and SSD defaults | `paths.sh`, and nowhere else |
| Shared ports/URLs | root `env.sh` (naming unchanged) |
| Per-repo paths (`PROJECT_ROOT`, chart overrides) | each consuming repo's `env.sh` |
| CLI build-root resolution | `src/context.rs` |
| New-project onboarding | `templates/Makefile` + `dpk.toml` (only current path) |

## Risks

| Risk | Mitigation |
|------|------------|
| The correction silently drops coverage that was worth keeping | The matrix keeps every assertion about `paths.sh`, root `env.sh`, and repository shape; only template assertions go |
| Reverting the ShellCheck `templates/*` exclusion looks like weakening a check | The exclusion is restored to its master state; `templates/` contains no `*.sh`, so the linted file set is identical either way, and the change is called out explicitly |
| Stale issue wording drives a third wrong implementation | The issue's AC section is corrected, with the filed text preserved under a "Superseded filed wording" heading linking #40 and #49 |
| Prior adversarial approvals lend false confidence to the old scope | They are marked void in the logs and a fresh review runs against the corrected artifacts |
| Consumer repos still hardcode `keepsake-workspace` | Read-only fallbacks keep them working; cutovers stay explicit follow-up work and are not claimed complete |

## Acceptance Criteria

### Corrected scope for this PR

- [ ] `templates/env.sh` is absent; the branch matches master for `templates/`
- [ ] `templates/README.md` is byte-identical to master (lean Makefile + `dpk.toml` as the only current contract)
- [ ] `.github/workflows/shellcheck.yml` restores the master `find` exclusion; the only workflow change is the added behaviour job, whose step name mentions paths and env only — no workflow text advertises template coverage that no longer exists
- [ ] `tests/shell/paths-env-matrix.sh` contains no assertion about a template, and every remaining assertion targets `paths.sh`, root `env.sh`, or repository shape
- [ ] The matrix runs as CI job `paths-env-matrix` on pull requests touching `**/*.sh` or the workflow file — which this PR does; local runs are development evidence only
- [ ] `resolve_build_root` precedence stays covered by integration tests in which a decoy makes precedence provable
- [ ] `paths.sh`, `env.sh`, and `src/context.rs` are unmodified by this branch
- [ ] `docs/issues/39/decision-baseline.md` maps every filed criterion with evidence and no conflicts
- [ ] Issue #39's AC section reflects the corrected scope and preserves the filed wording as superseded, linking #40 and #49
- [ ] `validation.md` carries an Artifact integrity manifest whose claims cite existing `file:` sources or `ci:` checks, with CI claims `pending` until green
- [ ] Adversarial logs mark the pre-correction approvals void and record a genuine consecutive approve pair earned on these corrected artifacts
- [ ] PR #54 contains changes only in `dpk-build` paths

### Verified as already satisfied (no change made)

- [ ] `paths.sh` exports `SSD`, `WORKSPACE_ROOT`, `BUILD_ROOT` and exports no `KEEPSAKE_*` path name
- [ ] Default workspace directory is `dpk-workspace`, preferred when both directories exist, with legacy discovery as the fallback
- [ ] Among **tracked shell scripts**, legacy path aliases and the umbrella folder name appear only in `paths.sh` and in `tests/shell/paths-env-matrix.sh` — the matrix must contain those strings in order to assert them, so it is a named carve-out, not an exception being hidden
- [ ] No `keepsake-paths.sh` in the tree
- [ ] Root `env.sh` forces `BUILD_ROOT` to its own directory; ports/URLs untouched
- [ ] Legacy `KEEPSAKE_*` names are read-only inputs in `paths.sh` and `src/context.rs`

### Who verifies what

Not every criterion above is machine-checkable, and saying otherwise would repeat the failure this pass exists to correct. Ownership is explicit. "Authoritative" below means the check decides the question and an agent's opinion does not override it — not that GitHub blocks the merge: `master` has no branch protection and the repository has no rulesets, so these jobs are enforced by review discipline rather than by GitHub. They are also **path-filtered**, not universal: `shellcheck.yml` (which hosts both the lint job and `paths-env-matrix`) triggers on `**/*.sh` and its own workflow file, `rust-tests.yml` on `src/**`, `tests/**`, `Cargo.*` and its workflow file, and `security-audit.yml` ignores markdown-only changes. This PR touches shell, test, and workflow paths, so all four run on its head — but a later PR editing only documentation would legitimately show some of them absent rather than failing.

| Criteria | Verified by | Authority |
|----------|-------------|-----------|
| `paths.sh` / root `env.sh` behaviour; absence of `keepsake-paths.sh`; **negative** hygiene over tracked shell scripts (no legacy alias, no umbrella hardcode outside the two carve-outs) | CI job `paths-env-matrix` | authoritative for exactly those greps |
| **Positive** use of the canonical names by internal scripts and docs | `decision-baseline.md` evidence rows citing the files, re-derivable by reading them | file evidence, not a CI assertion — the matrix never greps for canonical names |
| `resolve_build_root` precedence and the legacy fallback | CI job `rust` | authoritative |
| Shell lint over the master file set | CI job `shellcheck` | authoritative |
| Dependency posture | CI `security-audit` | authoritative; agents do not rerun scanners |
| `templates/` identical to master; `paths.sh` / `env.sh` / `src/context.rs` unmodified; only the behaviour job added to the workflow; every changed path inside this repository | `git diff origin/master` against the pushed head, re-derivable by any reviewer from the PR diff | deterministic but diff-based, not a CI job. It cannot prove anything about other repositories, so no such claim is made |
| Decision-baseline completeness, manifest well-formedness, adversarial history | `validate_artifacts.py` at `--stage decision-baseline`, `pre-pr`, `code-review` | tool-checked, run by Delivery and re-runnable by the reviewer |
| Issue AC corrected with the filed wording preserved | issue body on GitHub | human/reviewer-verifiable |

The scope limits are deliberate. The matrix greps **tracked shell scripts** and excludes two files by name: `paths.sh`, which owns the read fallbacks, and the matrix itself, which necessarily contains `KEEPSAKE_*` and `keepsake-workspace` in order to assert them. It says nothing about Rust, Python, YAML, or untracked files, and it only proves the **absence** of legacy strings — it never greps for the canonical names, so it cannot prove positive adoption. Criteria are worded to those limits rather than implying repo-wide proof.

## Test Strategy

Pipeline-first where a pipeline can decide it: every *behavioural* check is owned by a workflow, and local runs are development aids recorded as such in `validation.md`. The diff-shaped and record-shaped criteria above have no CI owner and are labelled accordingly rather than being folded into a "CI proves everything" claim.

- **CI `paths-env-matrix`** — `bash tests/shell/paths-env-matrix.sh`, hermetic (temp SSD roots, child environments via `env -u`, no dependency on any developer volume), 17 named assertions:
  1. `paths.sh` default `SSD`, default workspace directory `dpk-workspace`, `BUILD_ROOT` beneath it
  2. Both workspace directories present → prefer `dpk-workspace`; legacy-only → discover `keepsake-workspace`
  3. Each legacy `KEEPSAKE_*` input maps to its canonical variable, and each canonical value wins when both are set
  4. `paths.sh` exports no `KEEPSAKE_*` path name
  5. Repository shape: no `keepsake-paths.sh`; no tracked **shell** script reads a legacy alias or hardcodes an umbrella folder name, except `paths.sh` (which owns the fallbacks) and the matrix itself (which must name them to assert them)
  6. Root `env.sh` forces `BUILD_ROOT` to its own directory and still defines `KEEPSAKE_BACKEND_PORT`
- **CI `shellcheck`** — `--severity=warning` over the master file set.
- **CI `rust`** — the whole job is the bar: `cargo fmt --check`, `cargo clippy --locked -- -D warnings`, `cargo test --locked --all`, and the repo's stdout-ownership grep. Four `resolve_build_root` cases cover resolution, three of them discriminating: a decoy legacy loses to a valid canonical value; a decoy canonical wins and fails with `language_unsupported` even when a valid legacy value is present; and the legacy-only case points `KEEPSAKE_SCRIPTS_ROOT` at a build root whose `env.sh` forces a language, run against a project with no language indicators, with a paired control showing the same project failing when neither variable is set. The fourth is acceptance-only and is labelled as such in the test, because a debug build falls back to `CARGO_MANIFEST_DIR` and a case pointing at this repository cannot prove selection.
- **CI `security-audit`** — pipeline-owned; agents do not rerun scanners.
- **Deploy:** not applicable; no cluster or `make b` policy attaches to this change.
