# Voice pass, partition p2 (chapters 11-20, example READMEs 11-20)

Before the pass: 0 ban-tier hits, 27 watch-tier hits on the first scan (some counted twice across patterns). After: 0 ban-tier, 27 watch-tier, all kept (see survivors). The prose was already close to house voice, so the pass was a manual read plus 24 targeted rewrites in 10 chapters. The 10 example READMEs and the `examples/13-debugging/broken` tree (no README) needed no changes. No fenced code, inline code, front matter, Liquid tags, citation lines or footer evidence paths were touched. Word counts after: 11 1780, 12 1902, 13 1897, 14 1464, 15 1511, 16 1452, 17 1419, 18 1422, 19 1491, 20 1715 (all >= 1400).

## Notable rewrites
1. ch11: "The golden umbrella chart hit exactly this while it was being built" -> "The umbrella chart of chapter 16 hit exactly this" (internal term removed).
2. ch11: "That reuse is deliberate: the Job and the Deployment cannot disagree" -> "Reusing the helper means the Job and the Deployment cannot disagree".
3. ch12: "Installing a chart is the easy half of Helm." -> "Installing a chart is half of Helm."; "The message deserves a warning." -> "The message misleads."; footer lead-in sentence "The chapter and `demo.sh` were corrected where the first run disagreed." removed.
4. ch13: "(the original claim that `--dry-run=server` rejects it was refuted)" removed from the footer prose; "Fault 3 is a classic." -> "Fault 3 is a common mistake."
5. ch15: "(a stable pod after about 40 seconds to a stable pod)" (garbled) -> "(stable after about 40 seconds)"; "Keep that last setting in mind before..." -> "Check the data on a cluster before pointing such a values file at it."
6. ch16: dropped self-referential "this chapter spends as much time on the traps as on the mechanics". ch17: "application code in a library's clothing" -> "application code placed in a library". ch19: "During authoring it packaged" -> "Helm packaged". ch20: removed "Every command below was checked against ... --help" and "that happened on the authoring machine".

## Justified survivors (watch tier)
- "environment-specific noun" (minikube) x20: all in verification footers/status lines (evidence environment), the registry-addon section of ch20 (literal addon name), and example README status lines. Facts, not explanation.
- "silently" x3 (ch13 `-ignore-missing-schemas`, ch17 template overwrite, ch20 tag pinning): machine behavior.
- "Three charts, three releases" (ch15 and README parallel-number): factual count, not a synthetic title.
- ch12 opening "This chapter takes the chart...": one opening sentence of coverage is allowed.
- "golden path" in ch18 title/body and example 18 README: industry term for platform engineering, not the internal "golden" label. Kept. ch12 body names `_plans/evidence/golden-08-negative-control.txt` in an inline code span (path, left unchanged); prose around it now says "The umbrella run".
