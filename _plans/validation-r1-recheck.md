---
title: "Phase 3 validation recheck, r1.0"
layout: plan
render_with_liquid: false
---

# Phase 3 validation recheck: r1.0

Rechecked 2026-10-08 against the repair commit `9944267` on `feature/r1-initial-build` and hub `28bef2c` on `feature/add-helm-for-developers`.
- Every result below comes from the diff (`git diff HEAD~1`) or from a command run in this session. The commit message and executor notes were not used as evidence.
- Nothing was committed. This file is the only file written in either repo. Scratch work lives in the session scratchpad: the clone, logs, deck rebuild, renders and site builds.
- On CRC, only `oc get` was run. minikube stayed stopped.

## Verdict

**Not ready to package and publish.** The repair introduced one blocker: five offline demos now fail on a fresh clone.
- The m6 fix untracked every `examples/**/charts/*.tgz`. On a fresh clone, `examples/22`–`26` `demo.sh offline` exit 1 with `no template "pc-lib.fullname"` / `chart directory is missing these dependencies: pc-lib`.
- Cause: `22-plugins` and `23-post-renderers` never run `helm dependency build`. `24`–`26` build only the umbrella (`deps() { helm dependency build "$UMBRELLA"; }`), and `helm dependency build` does not recurse into the service charts' own `pc-lib` dependency.
- The working tree hides this, because the now-ignored `.tgz` files are still on disk there.
- Fix: follow the pattern in `examples/17-library-chart/demo.sh:45`. Build `charts/shipping-service` and `charts/notification-service` first, then the umbrella. In 22 and 23, add a `helm dependency build` of `chart/`. Then re-run all 27 demos on a fresh clone.

One residual major: the M1 claim still sits unqualified in the Helm 101 speaker notes.

Every other gate passes, and the remaining items are minor.

## Per-defect status

| ID | Status | Evidence |
|---|---|---|
| **M1** upgrade values semantics | **partially fixed** | ch05:80 and the summary bullet are now correct. Proven from source: `gh api repos/helm/helm/contents/pkg/action/upgrade.go?ref=v4.3.0` (tag v4.3.0 → commit `bec5b06`, matching binary `v4.3.0+gbec5b06`), `reuseValues()` lines 607–645. The ResetValues, ReuseValues and ResetThenReuseValues branches run first, then `if len(newVals) == 0 && len(current.Config) > 0 { newVals = current.Config }`. So with no value flags the old values are reused; with any flag, new values are coalesced over chart defaults. The ch05 footer correctly says this rule was not run live. **Not fixed:** the 101 deck notes, `presentation/helm-101/deck.js:219` (and the committed pptx, slide "Values precedence"), still say "On upgrade, previous flags are forgotten unless the same -f files are passed again or --reuse-values…". The original fix item asked for this to be checked |
| **M2** Python 3.15 claims | **fixed** | `index.html:8,27,39`, `_config.yml:9`, `README.md:5,7`, `_docs/00-outline.md:9` and `CLAUDE.md` now say "3.14 (3.15-ready)" or "3.14". Grepping for `3.15` over `.md/.html/.yml/.js` in reader-facing pages finds none claiming the image is 3.15. Residual nit: `CONTRIBUTING.md:32` (contributor-facing) still lists "Python 3.15.0" under Versions, though F1 is recorded at :134 |
| **E1** unbacked quotes | **fixed** | ch05 `key "Post" has no value` and the lint block are now in `05-values.txt:121-123` and `:113-119`, and I reproduced both. The lint code block now matches the evidence order, and the `replicaCount` type error moved to prose, backed by `05-values.txt:94,105`. ch12:91: the unbacked claims about the label, data and managedFields were removed and the text now says they were not captured (also in the example README). ch13 `could not find schema for Cluster` is in `13-debugging.txt:327-330`, and I reproduced it. ch27: the `touch` block was replaced by a jsonpath `readOnlyRootFilesystem` → `true`. That and the SCC securityContext (ch27:233-236) are in `27-openshift-crc.txt:431-437`, and both match the live CRC pod byte for byte (`oc get`, this session) |
| **E2** ch21 per-run values | **fixed** | ch21:68 fingerprint `19A1449A6F1689891E99B998C2916464491D113E` = `21-signing.txt:54`. The tamper hash `ab39f0ea…` = `:58` |
| **E3** ch16 namespace | **fixed** | ch16 now quotes `Deployment/hfd-16/...`, which equals `16-umbrella.txt:311-312` (with `--timeout 3m`, matching the S7 header). ch11 keeps the `hfd-26` quote and now says it comes from the chapter 26 install with `--timeout 8m`. That matches `golden-01-install-attempt1-deadlock.txt:1-4` |
| **E4** ch21 dry run | **fixed** (wording nit) | ch21 body, summary and footer now say `--dry-run=client` / `STATUS: pending-install`, matching `demo.sh:145` and `21-signing.txt:156`. Nit: `examples/21-signing/README.md` says the step "shows that verification is skipped". Verification is not skipped; it is satisfied from the cached `.prov`. Reword to "satisfied from the cache" |
| **E5** inference and duplicates | **fixed** | ch11:100 now says "the likely cause, inferred from the timing and not observed directly". The evidence duplicates were removed: `11-hooks-migrations.txt` ends with one V1 line and one V2 line |
| **m1** broken ch28 link | **fixed** | ch30 uses `relative_url`. In the built site the link is `/helm-for-developers/docs/28-appendix-helm3-to-helm4/`, and the link check finds 0 broken |
| **m2** source credits | **fixed** | "Sources and related projects" was added to `README.md` and `_docs/30-appendix-further-reading.md`, linking all three repos. It went in ch30 rather than the suggested ch00/03, which is acceptable |
| **m3** ch30 metadata | **fixed** | The footer is reworded (catalog-checked 2026-10-08, no meta-narration), "three GitOps and platform books" is fixed, and editions are added to every citation line (KP 2nd, KUR 3rd, CKAD 2nd, MKRUH 2nd). The CKAD title has no extra parentheses. The ch30 footer still shows the `unverified` status chip while the text says the metadata was checked. That is consistent with no live example, so leaving it is fine |
| **m4** internal leaks | **fixed** (one residual) | The `_plans/evidence` paths in ch12:44/65 and ch10:94 bodies are gone, and `CONTRIBUTING.md:128` was updated. Residual: `_docs/26-observability-lgtm.md:87` still cites `_plans/evidence/golden-06-tempo-trace.txt` in body prose. **New** small inaccuracy from this fix: ch12:44 now says "The umbrella-chart run in Chapter 16 recorded the negative control", but the quoted run is in `hfd-26` (golden run, `golden-08-negative-control.txt`). Say "the chapter 26 umbrella run" |
| **m5** `--validate` | **fixed** | ch27:84 now says `--dry-run=server`. `helm template --help` on 4.3.0 confirms `--dry-run` client/server for `template` |
| **m6** vendored `.tgz` | **fixed as specified, but caused a regression (blocker above)** | `.gitignore` gains `examples/**/charts/*.tgz`. `git ls-files 'examples/**/*.tgz'` → 0, so ch16's "git-ignored" is now true. Fresh clone at scratchpad `recheck-clone` with `.tools` symlinked to the original: `source scripts/env.sh` → rc 0, `helm` resolves to the clone's `.tools/bin/helm`, `v4.3.0+gbec5b06`, plugins diff 3.15.15 and unittest 1.2.1. **22 of 27 demos exit 0. `22-plugins`, `23-post-renderers`, `24-environments`, `25-gitops-argocd` and `26-observability` exit 1**, all with a missing `pc-lib`. After the run, `git status --porcelain` shows only `?? .tools`. That line comes from the symlink, because the `.gitignore` pattern `.tools/` matches directories only, not a symlink. A copied `.tools` stays ignored. Changing the pattern to `.tools` would cover both. No tracked file was modified |
| **m7** diagrams | **fixed** | I rendered 09, 11, 12, 20, 22 and 23 and viewed them. 09: no text overflow. 11: the Option A failure branches from the pre-install hook, and edge labels clear the borders. 12: Conflict now hangs off "Render and apply" ("at apply"), and the spurious Timeout→Conflict edge is gone. 20: one `registry:2` container (`-p 127.0.0.1:5001:5000`) serves the registry box, so the conflation is gone. 22: subtitles inside the boxes. 23: a separate down arrow and up arrow, no diamond. `validate-site` parses all 29 svg and 29 excalidraw files. Cosmetic only: in 20 the "authenticates" label sits close to its dashed arrow |
| **m8** decks | **fixed** | 201 slide 41 URL is now `https://<your-chart-repo-host>/charts`, with matching caption and notes (ch27:177 also changed). The 201 multi-line commands (slides 6, 10, 17, 19, 21, 24, 25, 29, 40) now carry `[host]$` or `[crc-host]$` on the first line with indented continuations, the same style the 101 deck already uses. `presentation/helm-101/package.json` was added. The 101 slide 13 `--history-max` label is now mono, and the render shows a double hyphen. I converted both pptx to PDF and viewed the 10 touched 201 slides and 101 slide 13: no clipping, logo present, Red Hat fonts embedded (`pdffonts`). A scratch rebuild from the committed `deck.js` is byte-identical in `slides/`, `notesSlides/` and `media/` for both decks |
| **m9** word counts | **partially fixed** | ch09 gained a version-constraint paragraph (now 1,535 words by `wc -w` on the file, 1,434 before the repair). ch12 and ch13 remain about 1,940–1,966. Accepted as a minor |
| **m10** hub synopsis | **fixed** | `_data/sites.yml` synopsis now names Helm 4, OCI and signing, GitOps, minikube, OpenShift and the 101/201 decks |

## Regression checks

| Check | Result |
|---|---|
| `scripts/validate-site.sh` | exit 0: 40 front-matter files, 29 svg and 29 excalidraw, 29 includes, 27 demo.sh |
| `scripts/check-helm-commands.sh` | exit 0: 491 commands in 92 files |
| `scripts/forbidden-syntax.sh` | exit 0 |
| `helm unittest` golden charts | shipping-service 25, notification-service 8, shipping-platform 23 = **56 passed** |
| Voice ban scan (`lgtm-professional-voice/scripts/scan.sh --tier ban --fail` over `_docs examples presentation/*/deck.js README.md index.html _config.yml _parts`) | 0 matches, exit 0. `honest\|capstone` grep empty |
| Deck slide and notes counts | 101: 36 / 36. 201: 44 / 44 |
| Jekyll build (ruby:3.3 container, `git archive HEAD`) | exit 0. Internal link check: 760 href/src, **0 broken** |
| Hub | All `_data/*.yml` parse. ruby:3.3 build exits 0, and the card text appears in `index.html`. Working tree clean |
| Offline demos, fresh clone | **22/27 pass. 22–26 fail (blocker)** |
| Git hygiene, tutorial repo | `main` 1 commit, `git remote -v` empty, 0 trailer hits (co-authored-by / generated with / claude / anthropic), all branch subjects Conventional. The diff has no added key, token or password patterns. No `.pem`, `.key`, `.gpg` or secring files are tracked. Working tree clean |
| Git hygiene, hub | 0 trailer hits on `main..HEAD`, no secrets in the diff. `main` tracks `origin/main` (pre-existing hub remote). The feature branch has no upstream (not pushed) |
| Evidence labeling | Every appended capture sits under a header naming it as separate: `--- repair-round capture 2026-10-08 (offline re-run, Helm 4.3.0)`, `(kubeconform without the CRDs-catalog location)`, `(read-only oc get against the running CRC cluster)`. No chapter presents these as output from the original live run: ch27 introduces the jsonpath check as a property of the pod, and "On the verified run" covers only the `id` block, which is in the original capture at :103. The ch05 footer explicitly says the bare-upgrade rule was not run |

## Remaining issues, ranked

1. **Blocker:** fresh-clone `examples/22`–`26` `demo.sh offline` fail. This is a regression from m6; the fix is above.
2. **Major (residual M1):** `presentation/helm-101/deck.js:219` notes state the unqualified "previous flags are forgotten". Qualify it the way ch05 does, then rebuild the 101 pptx.
3. **Minor:**
   - ch12:44 misattributes the `hfd-26` negative control to Chapter 16.
   - `_docs/26-observability-lgtm.md:87` still cites `_plans/evidence/...` in body text.
   - `examples/21-signing/README.md` says "verification is skipped".
   - `CONTRIBUTING.md:32` still says Python 3.15.0.
   - The `.gitignore` pattern `.tools/` does not cover a symlinked `.tools`.
   - ch12 and ch13 are slightly over 1,900 words.

After fixing 1 and 2, re-run the 27 offline demos on a fresh clone, check that `git status --porcelain` is empty, rebuild the 101 deck and confirm 36 slides / 36 notes. No live re-verification is needed.
