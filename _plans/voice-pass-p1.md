# Voice pass, partition p1

Files: `_docs/00`–`10`, `examples/01`–`10` READMEs, `index.html`, `_parts/*.md`.

## Hit counts (scan.sh, all tiers)

| Tier | Before | After |
|---|---|---|
| ban | 0 | 0 |
| watch | 14 | 12 |

The partition entered the pass nearly clean. Remaining watch hits: `silently` describing machine behavior (ch05, ch07), "this chapter covers" opening sentences (ch06, ch10, one per chapter, allowed), and `minikube` where the lab cluster is the subject (ch01, README 01, index eyebrow). All kept.

## Manual-pass rewrites

Changed files: 00-outline, 01, 02, 05, 06, 08, 10, examples/01 README, `_parts/00`, `index.html`.

1. ch08: "The fragile bits are real." -> "The pattern has four limits."
2. ch10: "One trap showed up while writing this chapter. `helm lint` runs ..." -> "The `helm lint` command runs ..." (meta-narration removed)
3. ch01 / README 01: "`CONTRIBUTING.md` records fallback F1" -> "records the fallback" (internal code removed)
4. ch01: "Operators only is a deliberate decision. The bootstrap installs ..." -> "The bootstrap installs operators only: ..."
5. ch00: "recorded under `_plans/evidence/`" -> "recorded as evidence in the repository" (plan path removed from reader prose)
6. Smaller: "real cluster" -> "cluster", "A real run" -> "A run", "the first real conflict" -> "the first conflict", "feel the problem" -> "the problem ... is concrete", "shows exactly how" -> "shows how", chapter 10 and `_parts/00` and `index.html` minikube mentions generalized.

## Not changed

- Fenced code, inline code, Liquid, verification footers and README verification evidence paths (`_plans/evidence/...`): untouched. `git diff -U0` shows only prose lines.
- "Starters and golden paths" (ch18 title in the ch00 table): "golden path" is the platform-engineering term, not the internal "golden" label.
- Word counts of ch01–10 remain between 1,434 and 1,715.

## Checks

`scan.sh --tier ban --fail` exits 0; `validate-site.sh`, `check-helm-commands.sh`, `forbidden-syntax.sh` pass.
