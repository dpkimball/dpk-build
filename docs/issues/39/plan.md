# Plan — Issue #39

**Spec:** `docs/issues/39/spec.md`  
**Decision baseline:** `docs/issues/39/decision-baseline.md`  
**Branch:** `feature/issue-39-path-env-vars` (existing) · **PR:** #54 (existing — no second branch or PR)  
**Tier:** high-risk  
**Status:** adversarial (decision-correction pass)  
**Adversarial:** `adversarial-plan-review.md`. Approvals recorded before this correction reviewed the superseded scope and are **void** for handoff; the rounds stay in the log.

## Shape of the work

This pass mostly *removes*. The corrected scope leaves no behaviour change in `paths.sh`, `env.sh`, or `src/context.rs`; what ships is regression coverage for the settled contract plus the delivery record. Steps 1–3 return the branch to master for `templates/` and the ShellCheck scope; steps 4–9 rebuild the record honestly.

## Step 1 — Decision baseline first

- Inspect master (`58653db2`), PR #40 (`ae80ca6`), PR #49 (`8c8bd4c`), and the user's Decision Integrity correction comment.
- Write `docs/issues/39/decision-baseline.md` mapping all six filed criteria; two superseded, four already satisfied, zero conflicts.
- Gate before rewriting the spec: the baseline file itself must be complete and well-formed — every filed criterion mapped, evidence resolvable, no `conflict` status.

**What the early run does and does not prove.** `--stage decision-baseline` is not a narrow check on one file. For a high-risk tier it also parses `validation.md` claim sources and the plan's adversarial log. The first run of that command happened before the removal work, so it was reading a `validation.md` that still cited `templates/env.sh` and an approval pair that this correction then voided: it proved the baseline file was well-formed, and nothing more that should be relied on. That early run is therefore **not** citable as evidence for the corrected scope. The decision-baseline stage is re-run after Steps 7–8, once `validation.md` cites only current sources and a post-VOID approval pair exists, and **only that final run is cited** — in `validation.md`, in the PR, and in the checklist below.

## Step 2 — Remove the unjustified restoration

| Action | Command / check |
|--------|-----------------|
| Delete the restored file | `git rm templates/env.sh` |
| Restore lean template docs | `git checkout origin/master -- templates/README.md` |
| Prove `templates/` matches master | `git diff origin/master -- templates/` is empty |

Nothing replaces the file. `templates/Makefile` + `dpk.toml` remain the only onboarding contract, exactly as #49 left them.

## Step 3 — Return the ShellCheck scope to master and de-template the workflow text

Restore the `! -path './templates/*'` exclusion in `.github/workflows/shellcheck.yml`. Removing it existed only to lint the restored file. `templates/` holds no `*.sh`, so the linted set is identical either way; restoring master's line keeps the workflow diff to the one thing this PR actually adds — the behaviour job.

Rename that job's step from `paths.sh / env.sh / templates behaviour matrix` to `paths.sh / env.sh behaviour matrix`. A stable job id is not proof the workflow text is honest: the step name ships in the same file and would advertise template coverage the correction deleted. Verify the master-scope command locally:

```bash
# CI's command runs on a clean checkout; locally, exclude untracked .claude/
# worktrees, which hold stale script copies that CI never sees.
find . -name '*.sh' ! -path './templates/*' -not -path './.claude/*' \
  | sort | xargs shellcheck --severity=warning
```

The workflow's own `find` stays exactly as master wrote it — the local exclusion is a developer convenience, never a narrowing of the CI scope.

## Step 4 — Reduce the behaviour matrix to current behaviour

- Delete the entire `templates/env.sh` section of `tests/shell/paths-env-matrix.sh` (nine assertions: sibling bootstrap, project root, workspace inheritance, helm derivation, two hygiene greps, and three fail-closed cases) along with the now-unused `REPO_PHYSICAL`.
- Keep all `paths/*`, `repo/*`, and `env/*` assertions — they test `paths.sh`, root `env.sh`, and repository shape, all of which are current.
- Update the header comment to describe the reduced scope.
- Keep the script file name and the CI job id `paths-env-matrix` — both describe paths and env and neither names templates — but the step name must be renamed per Step 3, since that is where the stale word actually appears.
- Expected result: **17 assertions, 0 failures**, and `shellcheck --severity=warning` clean on the script itself.

## Step 5 — Keep the Rust coverage

`tests/integration/resolve_build_root.rs` stays as-is. It spawns the built binary with `Command` and child-only environment control (no `set_var` in-process mutation), and uses a decoy `BUILD_ROOT` whose `env.sh` sets `BUILD_LANG=not-a-language` so precedence is provable: canonical-only passes, legacy-only passes, canonical beats a decoy legacy, and a decoy canonical fails with `language_unsupported` even when a valid legacy value is present.

## Step 6 — Verify-only invariants (never modify)

`paths.sh`, `env.sh`, and `src/context.rs` are read-only in this PR. Confirm with `git diff origin/master --name-only` — none of the three may appear. If a fix to them ever looks necessary, that is a new issue, not a silent edit here.

## Step 7 — Rebuild the record

- Rewrite `spec.md` and `plan.md` around the corrected decision.
- In both adversarial logs, mark the pre-correction approvals **void** with the reason, delete nothing, invent nothing, renumber nothing, and leave existing numbering gaps visible.
- Rewrite `validation.md` for the corrected scope with the Artifact integrity manifest. **Claim-truth rule:** a claim may read `pass` only if it is true at the moment it is written. `ci:` claims stay `pending` until the checks are green on the pushed head, and any claim describing a later step — the post-VOID approving pair, the corrected issue AC — is written `pending` and flipped to `pass` only once that step has actually happened, with a citation a reviewer can re-derive.
- No delivery header may carry a validator badge for a run that would not pass on the current bundle. `spec.md` therefore records the baseline path without asserting a stage result; the citable result lives in `validation.md`.
- Correct issue #39's AC section and preserve the filed text under "Superseded filed wording" linking #40 and #49.

## Step 8 — Fresh adversarial review

Spawn findings-only reviewers with fresh context against the corrected baseline, spec, and plan. Continue the existing round numbering in each log — the next spec round and the next plan round, whatever numbers those are. Do not pre-name the approving pair.

The approving pair must satisfy all of the following, and "the last two rounds parse as `approve`" alone is **not** sufficient:

1. Both rounds are recorded **after** the Decision Integrity VOID marker in that log.
2. Both target the corrected artifact text, not the superseded scope.
3. Their numbers are consecutive.
4. No voided round may be cited in the final summary, even though its YAML verdict still reads `approve` — the void is a scope judgment, and rewriting a past verdict would falsify the record.

Write the final summary only when a pair meeting all four exists, naming those actual numbers and nothing else.

**The machine gate does not understand "void."** `validate_artifacts.py` reconstructs approval claims with a `DOTALL` regex that spans from any `two consecutive ... approve` prose to the next `rounds N–M` range anywhere later in the file. Historical round bodies discussing earlier ceremony can therefore be stitched into a claim nobody made — including a claim citing voided rounds, which then fails as `superseded_approval` for the rest of the file's life. Fix such a false match by breaking the span, never by changing history: reword a range in prose to `rounds N and M`, leaving every recorded number, verdict and finding intact, and record the normalization in the log so the edit is auditable. Verdicts, round numbers, and findings text are never rewritten to make a gate pass.

## Step 9 — Integrity, push, handoff

```bash
python3 <workspace>/.cursor/skills/issue-delivery-agent/scripts/validate_artifacts.py \
  --repo-root . --issue 39 --tier high-risk --stage pre-pr \
  --github-repo dpkimball/dpk-build --output docs/issues/39/artifact-integrity.json
```

Must pass before any push or success claim.

Then commit and push — staging alone ships nothing, and this correction spans staged (`templates/env.sh` deletion), unstaged (workflow, matrix, artifacts), and untracked (`decision-baseline.md`) changes. Stage exactly this allowlist, never `git add -A`:

The `templates/` correction is the whole point of this pass, so it goes on the allowlist explicitly rather than being assumed already staged. `HEAD` still carries the restored file; only a commit containing its deletion fixes PR #54.

```bash
git add templates/README.md \
        .github/workflows/shellcheck.yml \
        tests/shell/paths-env-matrix.sh \
        docs/issues/39/decision-baseline.md \
        docs/issues/39/spec.md \
        docs/issues/39/plan.md \
        docs/issues/39/validation.md \
        docs/issues/39/adversarial-spec-review.md \
        docs/issues/39/adversarial-plan-review.md \
        docs/issues/39/artifact-integrity.json
git rm --cached --ignore-unmatch templates/env.sh   # deletion explicitly on the allowlist
git status --short          # .claude/ still untracked and unstaged
git diff --cached --stat    # exactly the allowlist above, nothing else
git commit -m "…" && git push origin feature/issue-39-path-env-vars
```

**Post-commit gate — check the tip, not the worktree.** A clean worktree proves nothing about what PR #54 ships. After the commit, and again against the pushed SHA:

```bash
git diff origin/master HEAD -- templates/    # must be empty
git ls-tree HEAD templates/                  # Makefile and README.md only
```

If either shows `templates/env.sh`, the correction is not on the PR and no success claim, PR update, or lifecycle move may follow.

Only then update the PR title/body for the corrected scope, comment the correction and exact diff scope, and refresh the diff-shaped rows in `validation.md` from transcripts taken at the pushed SHA, flipping them from `pending` to `pass` with that SHA cited.

**Evidence must be on the PR before the lifecycle moves.** The validator reads the worktree, so it cannot tell committed evidence from uncommitted edits; running it against a dirty tree would certify artifacts PR #54 does not contain. Refreshing `validation.md` also invalidates the committed report, so regenerate it rather than shipping the pre-correction copy:

```bash
python3 <workspace>/.cursor/skills/issue-delivery-agent/scripts/validate_artifacts.py \
  --repo-root . --issue 39 --tier high-risk --stage pre-pr \
  --github-repo dpkimball/dpk-build --output docs/issues/39/artifact-integrity.json
```

Commit and push the refreshed `validation.md` **and** that regenerated report as a second commit, then require all three of:

```bash
git status --short --untracked-files=no              # must be empty: no tracked changes remain
git rev-parse HEAD                                   # local tip
gh pr view 54 -R dpkimball/dpk-build --json headRefOid --jq .headRefOid   # must equal it
```

The gate is "no tracked changes remain", not a literally clean `git status`: untracked `.claude/` is expected to stay untracked, so it is excluded from the check rather than silently tolerated. Only with no tracked changes and `headRefOid` equal to the local tip may the validator run at `--stage code-review --pr 54` and the label move `lifecycle:in-progress` → `lifecycle:code-review`. Any later artifact edit repeats this gate: commit, push, re-verify head, re-validate. The PR is **not** merged and issue #39 is **not** closed: consumer cutovers remain open work, and both actions are the human's call.

## Migrations

None. No behaviour, schema, or interface changes.

## Testing

| Gate | Owner | Authority |
|------|-------|-----------|
| `paths-env-matrix` (17 assertions) | CI job in `shellcheck.yml` | authoritative |
| `shellcheck` (`--severity=warning`, master scope) | CI | authoritative |
| `rust` — the whole job: fmt, clippy, `cargo test --locked --all`, stdout ownership check | CI | authoritative |
| `security-audit` | CI | authoritative; agents do not rerun scanners |
| Local reproductions of the above | developer | informative only, labelled as such in `validation.md` |

## Deployment

None. `dpk-build` has no `make b` deploy obligation for this change, and no QA cluster state is touched.

## Rollback

Every shipped item is additive (a test script, a CI job, Rust tests, docs). Reverting the branch restores master exactly; nothing consumers depend on changes, so no coordinated rollback is required.

## Validation checklist

- [ ] `git diff origin/master -- templates/` is empty
- [ ] `.github/workflows/shellcheck.yml` differs from master only by the added job, and no step name in it mentions templates
- [ ] `paths.sh`, `env.sh`, `src/context.rs` absent from the branch diff
- [ ] `bash tests/shell/paths-env-matrix.sh` → 17 passed, 0 failed, no template assertions
- [ ] `cargo test --locked --all` green, including the four `resolve_build_root` cases
- [ ] All four PR CI checks green on the pushed head
- [ ] Validator passes at `--stage pre-pr` and `--stage code-review --pr 54`, plus a `--stage decision-baseline` re-run on the corrected bundle (the pre-correction run is not cited)
- [ ] Issue AC corrected with the filed wording preserved as superseded
- [ ] PR #54 changes only `dpk-build` paths; issue not closed; PR not merged
