# Validation — Issue #39

**Spec:** `docs/issues/39/spec.md` · **Plan:** `docs/issues/39/plan.md` · **Decision baseline:** `docs/issues/39/decision-baseline.md`  
**Branch:** `feature/issue-39-path-env-vars` · **PR:** #54 (existing) · **Tier:** high-risk  
**Base:** `origin/master` @ `58653db28366f81746419fedc311f5934564419a`  
**Written for:** the Decision Integrity correction pass. Everything recorded here describes the corrected scope; the prior revision of this file described the superseded template work and has been replaced rather than patched.

## Authority

The four PR CI checks on the pushed head are the authoritative gates for behaviour. A note on the word "required": `master` has no branch protection and this repository has no rulesets, so GitHub does not itself block a merge on these checks. They are gates because this process treats them as such, and because a human reviewer can see them; they are not enforced by branch protection, and saying otherwise would overstate them. Local runs below are development reproductions and are labelled as such — they do not stand in for a pipeline result. Diff-shaped claims (files identical to master, files not modified) are deterministic but have no CI owner; they are re-derivable by any reviewer from the PR diff, and that is how they are labelled in the manifest.

**Claim-truth rule.** A claim reads `pass` only when it is true at the moment it is written. Claims about steps that happen later in the sequence — the post-VOID adversarial pair, the corrected issue body, the CI checks — are written `pending` here and flipped only once the step has actually happened and can be cited. A `pending` row in this file is a statement that the work is not done yet, not a formality.

## What changed in this pass

| Action | Result |
|--------|--------|
| `git rm templates/env.sh` | file absent, as on master |
| `git checkout origin/master -- templates/README.md` | lean Makefile + `dpk.toml` contract restored verbatim |
| Restored `! -path './templates/*'` in the ShellCheck `find` | workflow lint scope identical to master |
| Renamed the matrix step to `paths.sh / env.sh behaviour matrix` | no workflow text advertises template coverage |
| Removed the nine template assertions from the matrix | 26 → 17 assertions, all current-contract |
| Added `docs/issues/39/decision-baseline.md` | six filed criteria mapped, no conflicts |
| Rewrote `spec.md`, `plan.md`, this file; voided prior approvals in both adversarial logs | records match the corrected decision |

## Commands executed (local — informative)

### Branch diff against master

Literal transcript from the **worktree at the time of writing**, before the correction commit existed. The tip of PR #54 still carried the restored template at this point, so nothing here yet proves what the PR ships; the post-push transcript below is what does.

```console
$ git diff origin/master --name-status
M	.github/workflows/shellcheck.yml
A	docs/issues/39/adversarial-plan-review.md
A	docs/issues/39/adversarial-spec-review.md
A	docs/issues/39/artifact-integrity.json
A	docs/issues/39/plan.md
A	docs/issues/39/spec.md
A	docs/issues/39/validation.md
M	tests/integration/mod.rs
A	tests/integration/resolve_build_root.rs
A	tests/shell/paths-env-matrix.sh

$ git status --short
 M .github/workflows/shellcheck.yml
 M docs/issues/39/adversarial-plan-review.md
 M docs/issues/39/adversarial-spec-review.md
 M docs/issues/39/plan.md
 M docs/issues/39/spec.md
 M docs/issues/39/validation.md
M  templates/README.md
D  templates/env.sh
 M tests/shell/paths-env-matrix.sh
?? .claude/
?? docs/issues/39/decision-baseline.md

$ git diff origin/master -- templates/
(no output — templates/ is identical to master in the worktree)
```

`decision-baseline.md` is untracked at this point and so is absent from the diff; `.claude/` is untracked and stays that way. `paths.sh`, `env.sh`, and `src/context.rs` do not appear at all: the settled contract is verify-only in this PR. The sole workflow delta is the added `paths-env-matrix` job; the ShellCheck step itself is byte-identical to master.

### Branch diff at the pushed head

Correction commit `0d940ac380fd5fc9337655020be1eac4151c9e6d`, pushed to `feature/issue-39-path-env-vars`. This is what PR #54 actually ships, and it is the evidence the tip-describing claims below rest on.

```console
$ git diff origin/master HEAD --name-status
M	.github/workflows/shellcheck.yml
A	docs/issues/39/adversarial-plan-review.md
A	docs/issues/39/adversarial-spec-review.md
A	docs/issues/39/artifact-integrity.json
A	docs/issues/39/decision-baseline.md
A	docs/issues/39/plan.md
A	docs/issues/39/spec.md
A	docs/issues/39/validation.md
M	tests/integration/mod.rs
A	tests/integration/resolve_build_root.rs
A	tests/shell/paths-env-matrix.sh

$ git diff origin/master HEAD -- templates/
(no output — templates/ is identical to master at the tip)

$ git ls-tree --name-only HEAD templates/
templates/Makefile
templates/README.md
```

`templates/env.sh` is gone from the tip, which is the whole point of this pass: before the correction commit, `git ls-tree HEAD templates/` still listed it. The only workflow delta is the added `paths-env-matrix` job, whose step reads `paths.sh / env.sh behaviour matrix`; the ShellCheck step is byte-identical to master. `paths.sh`, `env.sh`, and `src/context.rs` appear nowhere in the diff. Every changed path is inside this repository.

This validation file and the regenerated `artifact-integrity.json` land in a follow-up commit on the same branch, so the PR head that reviewers see contains this evidence.

### Behaviour matrix

```console
$ bash tests/shell/paths-env-matrix.sh
PASS paths/default_ssd_constant
PASS paths/default_workspace_dir_is_dpk_workspace
PASS paths/build_root_defaults_under_workspace
PASS paths/prefers_dpk_workspace_when_both_present
PASS paths/discovers_legacy_workspace_dir
PASS paths/legacy_ssd_input_maps_to_ssd
PASS paths/legacy_project_root_input_maps_to_workspace_root
PASS paths/legacy_scripts_root_input_maps_to_build_root
PASS paths/canonical_ssd_wins_over_legacy
PASS paths/canonical_workspace_root_wins_over_legacy
PASS paths/canonical_build_root_wins_over_legacy
PASS paths/no_legacy_path_exports
PASS repo/no_legacy_paths_file
PASS repo/legacy_path_aliases_confined_to_paths_sh
PASS repo/umbrella_name_confined_to_paths_sh
PASS env/forces_build_root_to_own_directory
PASS env/keeps_keepsake_port_names_out_of_scope

17 passed, 0 failed
```

No assertion id begins with `template/`. The `repo/*` assertions grep **tracked shell scripts** only, excluding `paths.sh` (which owns the read fallbacks) and the matrix itself (which must name the legacy strings to assert them); they claim nothing about Rust, Python, or YAML sources.

### Rust

```console
$ cargo fmt --check          # clean
$ cargo clippy --locked -- -D warnings   # clean
$ cargo test --locked --all
running 12 tests   → 12 passed; 0 failed      (unit)
running 24 tests   → 24 passed; 0 failed      (integration)
```

The integration set includes the four `resolve_build_root` cases. Three discriminate:

- a decoy legacy value loses to a valid canonical `BUILD_ROOT`;
- a decoy canonical value wins and fails with `language_unsupported` even though a valid legacy value is present;
- `resolve_build_root_selects_legacy_keepsake_scripts_root_over_debug_fallback` points `KEEPSAKE_SCRIPTS_ROOT` at a temporary build root whose `env.sh` exports `BUILD_LANG=rust`, runs in a temporary project with no language indicators, and asserts success — then repeats the identical run with **neither** variable set and asserts it fails with `language_unsupported`.

The fourth case is acceptance-only (`BUILD_ROOT` pointing at this repository) and now says so in the test, because a debug build falls back to `CARGO_MANIFEST_DIR`.

That third case replaces an earlier legacy-only test that set `KEEPSAKE_SCRIPTS_ROOT` to `CARGO_MANIFEST_DIR` — the same directory the debug fallback uses — so it passed whether or not the alias was ever read. Proof the replacement discriminates, by deleting the legacy branch from `resolve_build_root` and rerunning:

```console
$ cargo test --locked --test integration_tests resolve_build_root   # with the KEEPSAKE_SCRIPTS_ROOT branch removed
test ...resolve_build_root_decoy_canonical_fails_even_with_valid_legacy ... ok
test ...resolve_build_root_prefers_build_root_only ... ok
test ...resolve_build_root_canonical_wins_over_decoy_legacy ... ok
test ...resolve_build_root_selects_legacy_keepsake_scripts_root_over_debug_fallback ... FAILED
test result: FAILED. 3 passed; 1 failed
```

`src/context.rs` was restored immediately afterwards and is unmodified by this branch (`git diff --stat src/context.rs` empty); the mutation existed only long enough to prove the assertion bites.

### Shell lint at CI scope

```console
$ find . -name '*.sh' ! -path './templates/*' | sort | xargs shellcheck --severity=warning
(no output — clean)
```

Local runs may need to skip untracked `.claude/` worktrees, which can contain old script copies; CI runs on a clean checkout, and its `find` is unchanged from master.

## Acceptance criteria

### Corrected scope

| Criterion | Status | Evidence |
|-----------|--------|----------|
| `templates/env.sh` absent; `templates/` matches master | pass | `git diff origin/master HEAD -- templates/` empty at `0d940ac`; `git ls-tree HEAD templates/` shows only `Makefile` and `README.md` |
| `templates/README.md` byte-identical to master | pass | same transcript at `0d940ac` |
| ShellCheck `find` scope restored; only the behaviour job added; no step name mentions templates | pass | `git diff origin/master HEAD -- .github/workflows/shellcheck.yml` at `0d940ac` shows only the added job |
| Matrix contains no template assertion | pass | 17 named assertions above, none `template/*`, committed at `0d940ac` |
| Matrix runs as PR CI job `paths-env-matrix` | pending | `ci:paths-env-matrix` on the pushed head |
| `resolve_build_root` precedence and legacy selection covered by discriminating tests | pass | `file:tests/integration/resolve_build_root.rs`; legacy case verified by deleting the legacy branch and watching only that test fail |
| `paths.sh`, `env.sh`, `src/context.rs` unmodified | pass | absent from `git diff origin/master --name-status` |
| Decision baseline maps every filed criterion, no conflicts | pass | `file:docs/issues/39/decision-baseline.md`, committed at `0d940ac` |
| Issue AC corrected, filed wording preserved as superseded | pass | issue #39 body now carries a Decision integrity note, corrected AC, and a "Superseded filed wording" section linking #40 and #49 |
| Manifest claims cite existing sources; CI claims pending until green | pass | this file |
| Adversarial logs void the pre-correction approvals and record a post-VOID approve pair | pass | spec rounds 14 and 15; plan rounds 17 and 18 — all four recorded after the VOID markers, on the corrected artifacts |
| PR #54 contains changes only in `dpk-build` | pass | `git diff origin/master --name-status` above; every path is in this repository. A single-repository diff cannot prove the broader "no other repository was touched anywhere in the workspace", so that stronger claim is not made |

### Already satisfied on master (verified, unchanged)

| Criterion | Status | Evidence |
|-----------|--------|----------|
| `paths.sh` exports the canonical trio and no `KEEPSAKE_*` path name | pass | `paths/*` assertions |
| Default `dpk-workspace`; prefers it when both exist; discovers legacy otherwise | pass | `paths/default_workspace_dir_is_dpk_workspace`, `paths/prefers_dpk_workspace_when_both_present`, `paths/discovers_legacy_workspace_dir` |
| No `keepsake-paths.sh` | pass | `repo/no_legacy_paths_file` |
| Among tracked shell scripts, legacy path aliases and the umbrella folder name appear only in `paths.sh` and in the matrix itself | pass | `repo/legacy_path_aliases_confined_to_paths_sh`, `repo/umbrella_name_confined_to_paths_sh` — these are **negative** greps over tracked `*.sh` with both files carved out by name |
| Internal scripts and docs positively use the canonical names | pass | file evidence in `file:docs/issues/39/decision-baseline.md` (rows citing `python/deploy-k8s.sh`, `rust/deploy-k8s.sh`, `README.md`); the matrix never greps for canonical names and does not prove this |
| Root `env.sh` forces `BUILD_ROOT`; ports untouched | pass | `env/*` assertions |
| Legacy names are read-only inputs | pass | `paths/legacy_*`, `paths/canonical_*`, `file:tests/integration/resolve_build_root.rs` |

## Not verified here

- Consumer repositories (Foreman, Binder Cloud, resume-pipeline) still source their own `env.sh`; their cutovers are follow-up work in their own repos and are **not** completed or claimed by this PR.
- No deploy was performed: `dpk-build` has no `make b` obligation for this change and no cluster state is touched.
- Dependency posture is whatever the `security-audit` check reports on the head; no scanner was rerun by an agent.

## Artifact integrity manifest

```json
{
  "schema_version": 1,
  "issue": 39,
  "tier": "high-risk",
  "stage": "pre-pr",
  "claims": [
    {
      "statement": "templates/env.sh is absent and templates/ is identical to origin/master at pushed head 0d940ac, matching the merged PR #49 decision",
      "source": "file:templates/README.md",
      "status": "pass"
    },
    {
      "statement": "The decision baseline maps all six filed criteria with resolvable evidence and no conflicts, and is committed on the PR branch at 0d940ac",
      "source": "file:docs/issues/39/decision-baseline.md",
      "status": "pass"
    },
    {
      "statement": "At pushed head 0d940ac the ShellCheck find scope matches master and the only workflow delta is the paths-env-matrix job, whose step name no longer mentions templates",
      "source": "file:.github/workflows/shellcheck.yml",
      "status": "pass"
    },
    {
      "statement": "At pushed head 0d940ac the behaviour matrix contains 17 assertions covering paths.sh, root env.sh and tracked-shell-script repository shape, and none about a template",
      "source": "file:tests/shell/paths-env-matrix.sh",
      "status": "pass"
    },
    {
      "statement": "resolve_build_root precedence and legacy-alias selection are proven by discriminating integration tests; the legacy case fails when the legacy branch is removed, and no longer coincides with the debug CARGO_MANIFEST_DIR fallback",
      "source": "file:tests/integration/resolve_build_root.rs",
      "status": "pass"
    },
    {
      "statement": "Pre-correction adversarial approvals are marked void and the approving pair (spec rounds 14 and 15) is recorded after the VOID marker on the corrected spec",
      "source": "file:docs/issues/39/adversarial-spec-review.md",
      "status": "pass"
    },
    {
      "statement": "The plan log likewise voids its pre-correction approvals and records a post-VOID approving pair (plan rounds 17 and 18)",
      "source": "file:docs/issues/39/adversarial-plan-review.md",
      "status": "pass"
    },
    {
      "statement": "PR CI job paths-env-matrix passes on the pushed head",
      "source": "ci:paths-env-matrix",
      "status": "pending"
    },
    {
      "statement": "PR CI job shellcheck passes on the pushed head",
      "source": "ci:shellcheck",
      "status": "pending"
    },
    {
      "statement": "PR CI job rust passes on the pushed head, including the stdout ownership check",
      "source": "ci:rust",
      "status": "pending"
    },
    {
      "statement": "The security-audit check passes on the pushed head",
      "source": "ci:security-audit",
      "status": "pending"
    }
  ]
}
```

`ci:` claims stay `pending` until the checks are green on the pushed head; the `done`-stage validator is where they must be `pass` on a settled head.
