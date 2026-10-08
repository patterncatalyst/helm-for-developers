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

## Recorded deviations
| Date | Item | Decision | Reason |
|---|---|---|---|
| 2026-10-08 | Python base | F1: CPython 3.14.8 on UBI 10 ubi-minimal via uv | uv offered only 3.15.0rc3; aiokafka 0.14.0 has no cp315 wheel. Swap `ARG PYTHON_VERSION` when available. |
| 2026-10-08 | Arbitrary UID test | `--user 54321:0` instead of `123456:0` | Rootless podman maps 65536 ids; OpenShift-sized UID checked on CRC host (ch27). |
