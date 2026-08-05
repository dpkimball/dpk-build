# Adversarial spec review — Issue #39

> **RETRACTION (2026-08-05, after PR Review changes-requested on PR #54).**
> A previous summary at the end of this file asserted an approved pair citing a
> spec round 3. This log records rounds 1, 2 and 4 only; no round 3 was ever
> produced, so that assertion was not reconstructable from evidence and is
> **withdrawn**. Nothing recorded below has been renumbered, backdated or
> deleted: the gap is left visible on purpose. High-risk ceremony was re-earned
> by running fresh findings-only reviews against the current spec and appending
> each under the next unused number (Rounds 5 onward). The `## Round` sections in
> this file are the only authoritative record.

## Round 1

```yaml
target_path: /Volumes/KeepsakeSSD/dpk-workspace/dpk-build/docs/issues/39/spec.md
round: 1
verdict: request_changes

findings:
  - severity: major
    description: >
      Spec lists full #39 AC as unchecked work while stating #40 already landed the core
      rename and this delivery only closes remaining gaps. There is no explicit
      Already-on-master vs Remaining-for-this-PR inventory. On a high-risk shared path
      contract that invites either re-litigating paths.sh/context.rs or shipping only
      validation.md without restoring the real gap (templates/env.sh + README reconciliation).
    recommendation: >
      Add a Shipped vs Remaining table. Mark paths.sh rename/exports, legacy folder
      discovery, env.sh BUILD_ROOT force, and context.rs legacy alias as already on
      master (verify-only). Remaining must be explicit: restore templates/env.sh,
      update templates/README for optional env.sh use, re-verify #40 invariants after
      #49, record validation.md, and call out consumer follow-ups in the PR body.

  - severity: major
    description: >
      Restoring templates/env.sh collides with #49, which deleted it as obsolete in favor
      of lean Makefile + dpk.toml. Risks/non-goals mention optional use, but AC only
      requires the file to exist. That allows reverts to the pre-#49 “copy Makefile +
      env.sh” primary quickstart and undoes the deliver lean path.
    recommendation: >
      Add AC that (1) lean Makefile + dpk.toml remains the default new-project path,
      (2) templates/env.sh is optional for projects that still need env.sh, (3)
      templates/README must not restore dual-copy as primary onboarding, and (4)
      restored template must match the #40 contract: sibling ../dpk-build bootstrap,
      source BUILD_ROOT/env.sh, PROJECT_ROOT=repo after source, HELM_CHART_PATH via
      WORKSPACE_ROOT, and no re-export of KEEPSAKE_* path names.

  - severity: major
    description: >
      Fleet consumers (e.g. foreman, binder-cloud) still hardcode
      …/keepsake-workspace/dpk-build when sibling bootstrap fails and dual-export
      KEEPSAKE_SCRIPTS_ROOT. Issue Notes still say sibling SCRIPTS_ROOT and the
      PROJECT_ROOT helm-capture sequencing. Spec correctly defers consumer edits but
      does not encode the canonical cutover recipe, so follow-ups and the restored
      template lack a single authoritative migration contract.
    recommendation: >
      Add a Consumer cutover (follow-up PRs) section: bootstrap BUILD_ROOT via sibling
      only (no umbrella folder name in happy or fallback path); source BUILD_ROOT/env.sh;
      set PROJECT_ROOT to the repo after sourcing; derive helm/chart paths from
      WORKSPACE_ROOT (capture any PROJECT_ROOT-as-workspace helm values before
      overwriting); stop writing/exporting KEEPSAKE_* path names; leave ports/URLs
      unchanged. Point PR Notes at this section and note issue-body SCRIPTS_ROOT/
      COMPOSE wording is superseded.

  - severity: major
    description: >
      Test Strategy claims “existing legacy alias coverage” for context.rs, but there
      are no unit/integration tests asserting resolve_build_root honors
      KEEPSAKE_SCRIPTS_ROOT when BUILD_ROOT is unset. paths.sh fallbacks are only
      covered by ad-hoc bash smoke. For a high-risk cutover policy, that is a
      verification gap, not inherited coverage.
    recommendation: >
      Require either (a) a focused Rust test for BUILD_ROOT then KEEPSAKE_SCRIPTS_ROOT
      precedence, plus documented bash smoke for paths.sh defaults and legacy inputs,
      or (b) explicitly drop the “existing coverage” claim and make the bash smoke
      matrix mandatory acceptance evidence in validation.md (including both-dirs-present
      prefers dpk-workspace, and template sibling layout).

  - severity: minor
    description: >
      CI ShellCheck excludes templates/*, so a restored templates/env.sh will not be
      gated despite being the fleet bootstrap exemplar.
    recommendation: >
      Require local shellcheck --severity=warning on templates/env.sh in the test plan,
      or narrow the CI exclude so templates/env.sh is checked.

  - severity: minor
    description: >
      GitHub issue body AC still lists PROJECT_ROOT (workspace), SCRIPTS_ROOT, and
      COMPOSE_PROJECT_ROOT. Spec supersedes via comments but does not require updating
      the issue body or linking supersession, which risks PR-review confusion.
    recommendation: >
      In delivery Notes/PR body, state that issue comments + this spec are authoritative
      over the original AC list; optionally comment on #39 with the refined AC checklist.
```

## Round 2

```yaml
target_path: /Volumes/KeepsakeSSD/dpk-workspace/dpk-build/docs/issues/39/spec.md
round: 2
verdict: approve

findings:
  - severity: minor
    description: >
      Restored templates/env.sh contract is specified as bullet requirements
      without pinning a concrete restore baseline.
    recommendation: >
      Pin restore baseline to `git show ae80ca6:templates/env.sh`.

  - severity: minor
    description: >
      Smoke matrix never asserts env.sh overwrites a pre-exported BUILD_ROOT.
    recommendation: >
      Add smoke: export BUILD_ROOT=/tmp/wrong; source env.sh → BUILD_ROOT equals dpk-build dir.

  - severity: minor
    description: >
      GitHub issue body AC still lists superseded names.
    recommendation: >
      Comment on #39 with refined AC checklist on handoff.
```

## Round 4

```yaml
target_path: /Volumes/KeepsakeSSD/dpk-workspace/dpk-build/docs/issues/39/spec.md
round: 4
verdict: approve

findings:
  - severity: minor
    description: >
      Smoke matrix row 2 still does not explicitly say source paths.sh only.
      Deferred to plan/validation.
    recommendation: >
      In plan/validation, label rows 1–3 as source paths.sh only.

  - severity: minor
    description: >
      GitHub issue body AC still lists superseded names.
    recommendation: >
      On handoff, comment on #39 with refined AC checklist.
```

**Superseded summary (RETRACTED):** an approval-pair claim citing spec round 3
stood here. Round 3 does not exist in this log, so the claim is withdrawn; see
the retraction notice at the top of this file.

## Round 5

```yaml
target_path: /Volumes/KeepsakeSSD/dpk-workspace/dpk-build/docs/issues/39/spec.md
round: 5
verdict: request_changes

findings:
  - severity: blocker
    description: >
      Round 4 approved the pre-repair revision (no fail-closed guard, no CI-owned
      behaviour matrix, templates still ShellCheck-excluded). The validator only
      requires the last two numerically consecutive rounds to approve, so Round 4
      + Round 5 would reconstruct as a valid pair even though Round 4 never
      reviewed the repaired contract — the same unsupported-evidence class that
      caused the PR #54 rejection.
    recommendation: >
      State explicitly that approvals recorded before this repair pass (Rounds 2
      and 4) are void for handoff against the current revision, require a new
      consecutive approve pair earned only on the repaired spec, and forbid
      citing Round 4 as half of the post-repair pair.

  - severity: major
    description: >
      Spec AC requires validation.md plus an integrity manifest but does not
      require retracting still-present pre-repair evidence claims (validation
      Remaining says CI ShellCheck excludes templates/*; the PR Test plan centres
      local VERIFY_*/ROW* smoke). That omission lets Delivery ship contradictory
      gates again after QE rejected local-only matrix evidence.
    recommendation: >
      Add AC that validation.md and the PR Test plan name the CI jobs as the
      behavioural/lint gates with ci: sources, label local runs development-only,
      and delete text claiming templates are CI-excluded or that local smoke gates.

  - severity: major
    description: >
      Restored-template AC pins `git show ae80ca6:templates/env.sh` and forbids
      deltas, while also requiring ShellCheck --severity=warning over
      templates/env.sh. Exact ae80ca6 fails SC2155, so the restore-baseline and
      ShellCheck criteria conflict.
    recommendation: >
      Enumerate allowed behaviour-preserving deltas from ae80ca6: fail-closed
      guard, SC2155-safe declare-then-export, README wording. Keep "no thinner
      scaffolding" for the service/library blocks.

  - severity: minor
    description: >
      The contract requires non-empty BUILD_ROOT and a readable
      ${BUILD_ROOT}/env.sh, but the matrix only mandates the unset-BUILD_ROOT
      case. A preset BUILD_ROOT pointing at a missing env.sh is unasserted.
    recommendation: >
      Extend the matrix with a case where BUILD_ROOT is set to a directory
      without a readable env.sh; it must fail closed with the same diagnostic.

  - severity: minor
    description: >
      The restored contract requires HELM_CHART_PATH via
      ${WORKSPACE_ROOT}/dpk-infra/..., but matrix coverage only requires a
      non-empty WORKSPACE_ROOT.
    recommendation: >
      Add a named assertion that HELM_CHART_PATH expands under
      ${WORKSPACE_ROOT}/dpk-infra/charts/ after a successful template source.
```

## Round 6

```yaml
target_path: /Volumes/KeepsakeSSD/dpk-workspace/dpk-build/docs/issues/39/spec.md
round: 6
verdict: request_changes

findings:
  - severity: major
    description: >
      Round 5 findings are resolved (Review-evidence voids pre-repair approvals;
      AC forces CI-named gates and retracts stale templates-exclude / local-smoke
      claims; allowed ae80ca6 deltas reconcile ShellCheck; Test Strategy asserts
      both fail-closed modes and HELM_CHART_PATH under WORKSPACE_ROOT, matching
      the live matrix). However, Review-evidence only constrains what a final
      summary may cite and never requires appending the reconstructable
      consecutive-approval summary that validate_artifacts.py demands for
      high-risk (missing_final_approval_claim). Delivery could satisfy the
      written AC with approve rounds alone and still fail integrity, or invent a
      summary — the class that burned PR #54.
    recommendation: >
      Extend Review-evidence / AC: after two consecutive post-repair approve
      rounds exist, append exactly one final summary citing only those rounds
      (keep RETRACTED text; forbid claiming the pair earlier or citing voided
      rounds). Keep adversarial approval claims in validation.md pending until
      that summary is reconstructable from the log.

  - severity: minor
    description: >
      The repository-shape row says no tracked script other than paths.sh may
      mention KEEPSAKE_* aliases or umbrella names, but the mandated matrix must
      mention them and already carves itself out.
    recommendation: >
      Explicitly carve out tests/shell/paths-env-matrix.sh (assert-only) in the
      spec wording so the contract matches the checked-in matrix.

  - severity: minor
    description: >
      Review-evidence lists plan round 3 among pre-repair approvals to void, but
      plan round 3 recorded request_changes.
    recommendation: >
      Void only pre-repair rounds that actually approved: spec rounds 2 and 4,
      plan round 5.
```

> **Note:** a duplicate transcription of Round 6 was appended here by mistake and
> removed. It restated the same reviewer output in different words; it was not a
> second review, and collapsing it does not renumber or drop any round.

## Round 7

```yaml
target_path: /Volumes/KeepsakeSSD/dpk-workspace/dpk-build/docs/issues/39/spec.md
round: 7
verdict: approve

findings:
  - severity: minor
    description: >
      Round 6 is resolved on the contract that matters: Review-evidence now
      requires exactly one reconstructable final summary after a genuine
      post-repair approve pair and keeps validation.md adversarial claims pending
      until then; the repository-shape row carves out
      tests/shell/paths-env-matrix.sh; voided approvals are correctly limited to
      spec rounds 2 and 4 and plan round 5. Fail-closed coverage, the ae80ca6
      allowed deltas, the CI-owned matrix, both fail-closed modes, and the
      HELM_CHART_PATH assertion match the live matrix (26/26), templates/env.sh,
      and shellcheck.yml. However, Review-evidence does not require unique
      `## Round N` headings, and the live log currently records Round 6 twice;
      validate_artifacts.py fails with duplicate_round before any approval
      summary could succeed.
    recommendation: >
      Add one line to Review-evidence / AC: each round number appears exactly
      once, and an accidental duplicate append of the same N is not distinct
      history — collapse it to a single section without renumbering other rounds.
      Remove the second Round 6 block before claiming integrity.
```

## Round 8

```yaml
target_path: /Volumes/KeepsakeSSD/dpk-workspace/dpk-build/docs/issues/39/spec.md
round: 8
verdict: approve

findings: []
```

> **VOID — approvals superseded by the Decision Integrity correction
> (2026-08-05).** Every approving round recorded above — rounds 2, 4, 7 and 8 —
> reviewed a spec whose premise was wrong: it treated the filed `templates/env.sh`
> criterion as live, when merged PR #49 (`8c8bd4c`) had already deleted that file
> deliberately. Those rounds argued about how well the restoration was specified,
> never whether it should exist, so their approval carries no weight for the
> corrected scope and is **void as handoff evidence**. Nothing above is deleted,
> renumbered or backdated; the numbering gap at round 3 remains visible. The spec
> was rewritten against `decision-baseline.md`, and high-risk ceremony must be
> re-earned by fresh findings-only rounds appended below under the next unused
> numbers. No future round number is reserved or predicted here.

## Round 9

First review after the Decision Integrity correction. Target: the rewritten spec.

```yaml
target_path: /Volumes/KeepsakeSSD/dpk-workspace/dpk-build/docs/issues/39/spec.md
round: 9
verdict: request_changes

findings:
  - severity: major
    description: >
      The claim that every deterministic check is workflow-owned is false. CI does
      not verify template equality with master, unchanged contract files, issue-body
      correction, decision-baseline completeness, adversarial history, or the
      cross-repository criterion. The matrix also scans only tracked shell scripts,
      so it cannot prove the broader criteria that legacy discovery exists nowhere
      except paths.sh and all internal scripts use canonical names.
    recommendation: >
      Add explicit reconstructable evidence and ownership for each criterion.
      Narrow repository-shape criteria to tracked shell scripts or add checks covering
      all relevant source types. Remove the pipeline-first overclaim unless every
      deterministic acceptance check is actually CI-owned.

  - severity: minor
    description: >
      The corrected workflow still labels the matrix step "paths.sh / env.sh /
      templates behaviour matrix", despite all template assertions being removed.
      This is residue of the superseded template premise.
    recommendation: >
      Rename the workflow step to "paths.sh / env.sh behaviour matrix" so CI
      accurately describes the corrected scope.

  - severity: minor
    description: >
      The Rust strategy describes four resolve_build_root cases as using a decoy
      BUILD_LANG, but only the two precedence-conflict cases use a decoy. The
      canonical-only and legacy-only cases merely prove acceptance.
    recommendation: >
      State that four cases cover resolution and two decoy-based conflict cases
      prove canonical precedence.
```

## Round 10

```yaml
target_path: /Volumes/KeepsakeSSD/dpk-workspace/dpk-build/docs/issues/39/spec.md
round: 10
verdict: request_changes

findings:
  - severity: major
    description: >
      Round 9's ownership and narrowing fixes are real in Who verifies and Test
      Strategy §5 (tracked shell scripts; matrix carve-out; pipeline-first limited
      to behavioural checks; step renamed; decoy wording corrected; 17 assertions
      match the live matrix; shellcheck exclusion / rust job / security-audit
      descriptions match on-disk workflows). But Verified-as-satisfied still says
      legacy discovery and the umbrella name appear only in paths.sh, and that
      internal shell scripts "use the canonical names" with the matrix as coverage.
      On disk the matrix itself contains keepsake-workspace and KEEPSAKE_* strings,
      and it only greps tracked *.sh excluding paths.sh and itself for legacy
      aliases / umbrella hardcoding — it does not assert positive use of
      SSD/WORKSPACE_ROOT/BUILD_ROOT. Mapping that AC to authoritative CI therefore
      still overclaims what paths-env-matrix proves (residual of the Round 9 major).
    recommendation: >
      Rewrite the Verified repository-shape bullets to match Test Strategy §5 and
      the live greps: among tracked shell scripts, legacy path aliases and the
      umbrella folder name are confined to paths.sh and tests/shell/paths-env-matrix.sh.
      Drop or move the positive "use the canonical names" claim off matrix authority
      onto decision-baseline file: evidence (and rust for context.rs) so Who verifies
      does not present CI as proving more than it runs.
```

## Round 11

```yaml
target_path: /Volumes/KeepsakeSSD/dpk-workspace/dpk-build/docs/issues/39/spec.md
round: 11
verdict: approve

findings:
  - severity: minor
    description: >
      Round 9-10 fixes are genuine in this target: no decision-baseline pass
      badge; Verified repository-shape names both carve-outs (paths.sh and
      tests/shell/paths-env-matrix.sh); Who verifies limits matrix authority to
      negative greps and attributes positive canonical-name adoption to
      decision-baseline file evidence; workflow step name, decoy wording, 17
      assertions, shellcheck exclusion, and rust job description match disk;
      templates/ is identical to origin/master and templates/env.sh is absent.
      Sibling validation.md Already-satisfied still says tracked scripts "use
      canonical names" with legacy strings "confined to paths.sh" citing the
      negative repo/* greps, and decision-baseline "What this leaves" item 1
      likewise omits the matrix carve-out. Spec text is sound; the delivery
      record remains partially stale relative to Who verifies.
    recommendation: >
      In the same correction pass, align those sibling rows with Spec Who
      verifies (negative greps only; both carve-outs; positive adoption =
      decision-baseline file evidence). No further Spec change is required for
      that alignment.
```

Minor addressed in the same pass: `validation.md` now labels the `repo/*` greps as
negative with both carve-outs named and moves positive canonical-name adoption onto
decision-baseline file evidence; `decision-baseline.md` item 1 carries the same
correction. `spec.md` itself was not changed for this round.

## Round 12

```yaml
target_path: /Volumes/KeepsakeSSD/dpk-workspace/dpk-build/docs/issues/39/spec.md
round: 12
verdict: request_changes

findings:
  - severity: major
    description: >
      The spec calls paths-env-matrix "required CI," but GitHub reports no
      required checks for PR #54, the master branch-protection endpoint is absent,
      and the repository has no rulesets. The job runs on pull requests, but
      nothing makes it a GitHub-required gate.
    recommendation: >
      Either configure and evidence paths-env-matrix as a required status check,
      or consistently describe it as a spec/process-required PR CI gate rather
      than implying branch-protection enforcement.

  - severity: major
    description: >
      "No other repository is modified" remains an unverifiable acceptance
      criterion, and Who verifies incorrectly assigns that claim to this
      repository's git diff. A dpk-build diff can prove only that PR #54 contains
      dpk-build paths. validation.md now explicitly makes that narrower claim, so
      the sibling artifacts are inconsistent.
    recommendation: >
      Replace the criterion and authority row with "PR #54 contains changes only
      in dpk-build," verified by its branch diff, or provide explicit
      cross-repository workspace evidence if the broader claim is genuinely
      required.
```

## Round 13

```yaml
target_path: /Volumes/KeepsakeSSD/dpk-workspace/dpk-build/docs/issues/39/spec.md
round: 13
verdict: request_changes

findings:
  - severity: major
    description: >
      Round 12's two fixes are real in this target: the Who-verifies preamble
      correctly states master has no branch protection and no rulesets (verified:
      protection 404, rulesets length 0), defines "authoritative" as deciding the
      question rather than GitHub blocking merge, and drops "required CI"; AC and
      Who verifies now say "PR #54 contains changes only in dpk-build paths" /
      that a single-repo diff cannot prove other repositories (aligned with
      validation.md). But the same preamble (and AC "The matrix runs on every
      pull request") newly claims the four jobs run on every pull request. That
      is false on disk: shellcheck.yml (hosting paths-env-matrix) is gated by
      pull_request.paths **/*.sh and the workflow file; rust-tests.yml is path-
      filtered to src/tests/Cargo; security-audit.yml paths-ignores markdown.
      Same class of overclaimed CI authority as Round 12.
    recommendation: >
      Replace "every pull request" with path-filter-accurate wording (e.g. the
      jobs run on pull_request events that match each workflow's path rules;
      for this PR, the head that touches those paths). Align AC line about the
      matrix the same way — validation.md's "Matrix runs as PR CI job" is the
      safer shape.
```

## Round 14

```yaml
target_path: /Volumes/KeepsakeSSD/dpk-workspace/dpk-build/docs/issues/39/spec.md
round: 14
verdict: approve

findings: []
```

Reviewer note: the Round 13 path-filter fix matches `shellcheck.yml`, `rust-tests.yml`
and `security-audit.yml` on disk; no residual "every pull request", required-CI, or
template-premise overclaim; the 17-assertion matrix, decoy Rust tests, and
workflow-only-job delta match the tree. Prior majors stay cleared.

## Round 15

```yaml
target_path: /Volumes/KeepsakeSSD/dpk-workspace/dpk-build/docs/issues/39/spec.md
round: 15
verdict: approve

findings: []
```

Reviewer note: reviewed independently of round 14. The spec frames the PR honestly as
regression coverage plus a decision record, with no behaviour change in `paths.sh`,
`env.sh` or `src/context.rs`; CI authority is path-filter accurate and claims no
branch-protection enforcement; no template-premise residue remains; the decoy wording
matches the Rust tests; and the sibling artifacts agree on carve-outs, pending-vs-pass,
and the dpk-build-only scope of PR #54.

**Final spec verdict:** two consecutive `approve` (rounds 14–15). Both were recorded
after the Decision Integrity VOID marker and both targeted the corrected spec. The
pre-correction approvals (rounds 2, 4, 7, 8) remain in the log and remain void: they
are not counted here. Spec status → approved for the corrected scope.
