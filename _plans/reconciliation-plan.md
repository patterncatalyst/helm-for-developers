---
title: "Reconciliation plan"
layout: plan
render_with_liquid: false
---

# Reconciliation plan

Tracks every claim the tutorial makes about behavior that a real run must confirm. A claim starts as `unverified` and moves to `verified` only with an evidence file under `_plans/evidence/` that records what changed and what was observed. Per-part claims are authored in `_plans/claims/partN.md` and merged here during the live verification sweep.

## Runtime decisions

| Decision | Choice | Reason | Date |
|---|---|---|---|
| Python base | UBI 10 minimal with uv-installed CPython 3.15.0 | No UBI Python 3.15 image exists | 2026-10-08 |
| Fallbacks | F1: `PYTHON_VERSION=3.14`; F2: `ubi9/python-314` | Used only if 3.15 wheels or builds are unavailable; record here when applied | 2026-10-08 |

## Claims

| ID | Chapter | Claim | Status | Evidence |
|---|---|---|---|---|
| | | | | |

## Iteration log

| Iteration | Date | Note |
|---|---|---|
| r1.0 | 2026-10-08 | Scaffold created |
