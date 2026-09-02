---
id: open-source-readiness
title: dpk-build open-source readiness
status: draft
created: 2026-09-02
updated: 2026-09-02
owner: dpk-build
github_issue: https://github.com/dpkimball/dpk-build/issues/73
related:
  - https://github.com/dpkimball/dpk-build/issues/73
  - https://github.com/dpkimball/binder-workspace/issues/194
---

# dpk-build — open-source readiness

## Purpose

Make `dpk-build` safe to **open-source as a public git repository** (unlike bindb / binder-llm / binder-ai, which stay private-source with public binaries).

## Decisions

| Topic | Decision |
|-------|----------|
| Distribution model | **Open-source the source repo** (MIT) |
| Rename to `binder-build` | **Deferred** — keep `dpk-build` name for fleet compatibility |
| GitHub visibility flip | **Human gate** after scrub evidence |
| Kellnr registry name `dpk` | Remains the Cargo registry *id* for operators who publish crates privately; not a LAN hardcode |

## Scrubbed in this slice

- No default `QA_BOX_IP` LAN address
- No baked `PYPI_PASSWORD` placeholder default
- `LICENSE` (MIT) + `Cargo.toml` `license = "MIT"`
- Consumer-facing README framing for third parties
- Example PyPI URL uses placeholders, not a private LAN host

## Remaining before visibility flip

- [ ] Confirm CI default path works without private-only secrets (or document required secrets)
- [ ] History / secret scan on files that remain public
- [ ] Optional rename epic
- [ ] Human sets repo to Public

## Out of scope

Changing every consumer Makefile path; private-source/public-binary (already have `install.sh` + release workflow for binary installs).
