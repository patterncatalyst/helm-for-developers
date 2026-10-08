---
title: "Phase 3 validation, r1.0"
layout: plan
render_with_liquid: false
---

# Phase 3 validation: r1.0

Validated 2026-10-08 on branch `feature/r1-initial-build` (HEAD `34aae47`) and hub branch `feature/add-helm-for-developers`.
- Every result below comes from a command run or a file read in this session. Executor footers, progress notes and step-status rows were treated as claims, not evidence.
- Nothing was committed. No file other than this report was written in either repo. Scratch output is under the session scratchpad `validate/`.
- Clusters were touched read-only. On CRC that meant `oc get`, `helm list/history` and `curl`. minikube `helm4dev` was not started.

Adjustments applied, as instructed:
- **G10**: ch27 must now be *verified with evidence*.
- **G13**: the 3.14 fallback recorded in CONTRIBUTING satisfies it.
- **S11/S12**: marked *not yet run*.

## Verdict

**Needs a short repair round, then package and publish.**
- There are no blockers. Every automated gate passes, on the working tree and on a fresh clone.
- Two **major** defects mislead readers:
  - a wrong statement about how `helm upgrade` handles values (ch05, a chapter marked verified);
  - the landing page, README, `_config.yml` and outline all advertise "Python 3.15" while the shipped image is 3.14.8.
- Both are text-only fixes, and so are most of the minors. After the fix, re-run `validate-site.sh`, `check-helm-commands.sh`, the voice scan and the Jekyll build. No live re-verification is needed.

## Global acceptance criteria

| # | Criterion | Result | Evidence |
|---|---|---|---|
| 1 | Helm 4 project-local, global Helm 3 untouched | **met** | `source scripts/env.sh; helm version --short` → `v4.3.0+gbec5b06`; `~/.local/bin/helm version --short` → `v3.18.3+g6838ebc` |
| 2 | 31 chapters, 27 example dirs | **met** | `ls _docs/*.md \| wc -l` → 31; `ls -d examples/*/ \| wc -l` → 27 (01–27) |
| 3 | `validate-site.sh` | **met** | exit 0: "front matter: 40 files parsed / diagrams: 29 svg, 29 excalidraw parsed / includes: 29 checked / demo.sh: 27 scripts syntax-checked / validate-site: OK" |
| 4 | Jekyll build | **met** (container) | Host Ruby 4.0 fails in bundler, as the plan expected. `podman run … ruby:3.3 … jekyll build` exits 0. A link check of the built site covered 750 internal href/src: **1 broken** (`28-appendix-helm3-to-helm4.md` from ch30, minor m1) |
| 5 | `check-helm-commands.sh`, `forbidden-syntax.sh` | **met** | "check-helm-commands: OK (491 helm commands checked in 91 files)", exit 0; "forbidden-syntax: OK", exit 0 |
| 6 | Book-citation rule | **met** | No ISBN lines in ch12/13/20/21/22/23/28. All 42 ISBN lines belong to the 9 kept books, each within its allowed chapters (LH 02,04,05,06,07,09,11,16,17,19; MKR 06,09,14,16,25; KP 03,08,09,10,11,15,26; KUR/CKAD 03; K4D 03,11; GOK 25; PEK 18,24,25; EPE 17,18,24; all also in ch30). Every LH/MKR "Used here for" is a concept scope. All 55 helm.sh / github.com/helm URLs cited in `_docs` return HTTP 200 |
| 7 | Every `demo.sh offline` | **met** | All 27 exit 0 in the working tree and in a **fresh clone** (no ignored `.tgz`). The two kubeconform `Invalid: 1` results are deliberate negative controls (ch13 rung 3b CNPG wrong type; fault 5 string containerPort). See m6 for fresh-clone churn |
| 8 | `helm unittest`, at least 20 tests | **met** | shipping-service 25, notification-service 8, shipping-platform 23 = **56 passed**; `failedTemplate` cases present (`shipping-service/tests/schema_test.yaml` and others) |
| 9 | Golden evidence | **met** | `golden-04-cross-service.txt:9-11`: `"shipmentId":1` in `/api/notifications`. `golden-05-helm-test.txt:24,28`: two test suites `Phase: Succeeded`. `golden-08-negative-control.txt:3,12-13`: "has been rolled back due to rollback-on-failure", rev 4 failed, rev 5 "Rollback to 3". `golden-06-tempo-trace.txt`: one trace with spans from both services |
| 10 | (changed) Verified footers have evidence; ch27 verified with evidence; `verify-crc.sh` | **met** | All 30 cited `_plans/evidence/*.txt` exist. Ch27 footer is verified on OpenShift Local 2.64.0 / OCP 4.22.14, with full-PASS runs for both profiles at `27-openshift-crc.txt:69,417`. `verify-crc.sh` passes `bash -n` and implements all ten checks with PASS/FAIL. No "untested" banner remains in `_docs`, `examples` or `deck.js`. Live read-only: 5 pods Running with `openshift.io/scc=restricted-v2`, two edge/Redirect Routes, `curl -sk https://<route>/api/info` → 200 (`environment: openshift`, `storage: postgres`), `helm list` → `platform` rev 2 deployed. Footer quality gaps: E1–E4 |
| 11 | Decks | **met** | 101: 36 slides / 36 notes; 201: 44 / 44. The committed pptx are byte-equivalent in `slides/*.xml` and `notesSlides/*.xml` to a scratch rebuild from the committed `deck.js` |
| 12 | Voice scan | **met** | `scan.sh --tier ban --fail _docs examples presentation/*/deck.js README.md` → 0 hits, exit 0. Repo-wide `scan.sh --fail .` exits 1 only because of third-party files in ignored `.tools/` and `CONTRIBUTING.md:87`, which is the ban list itself (justified in `_plans/voice-pass-p3.md:8`). `grep -rniE 'honest\|capstone' _docs examples/*/README.md` → empty |
| 13 | Python version or recorded fallback | **met** (fallback) | Runtime image: `sys.version_info[:2]` → `(3, 14)`. F1 recorded in `CONTRIBUTING.md:134`, `_plans/reconciliation-plan.md:258` and `services/README.md:32-39` (uv offers only 3.15.0rc3; aiokafka 0.14.0 has no cp315 wheel). Reader-facing pages still say 3.15 (**M2**) |
| 14 | Hub branch | **met** | YAML parses. `git diff main -- _data/books.yml`: 0 removals, 90 additions = 9 entries, alphabetical. New category lists 9 titles, all present in `books.yml`. `sites.yml` entry is under "Cloud-Native & Kubernetes" with `site_url: null` and a note. `ALLOWED_REPOS` has the one-line addition. gen-books dry run to scratch finds all 9 ISBNs. ruby:3.3 container build exits 0 and leaves `git status` clean. Not pushed (no upstream) |
| 15 | Git hygiene | **met** | `git log main --oneline` → 1 commit (`chore: scaffold Jekyll site…`). 31 branch commits, all Conventional (`docs/feat/fix/chore/style` with `§NN`/`r1.0`). Trailer grep (co-authored-by, generated with, claude, anthropic) → 0. `git remote -v` → empty. Single author `PatternCatalyst` |

## Per-step acceptance

| Step | Result | Evidence |
|---|---|---|
| S1 scaffold | **met** | 9 `_parts`, orders 0–8, `part_name`s match the outline. `_config.yml` has baseurl, github_* and brand_emoji. Branch is correct and `main` has 1 commit |
| S2 tools/platform | **met** | Every `scripts/*.sh`, `scripts/platform/*.sh` and `examples/*/demo.sh` passes `bash -n`. kubeconform v0.8.0, ct v3.15.0, cosign v3.1.3. `helm plugin list` shows diff 3.15.15 and unittest 1.2.1. `bootstrap.sh` creates no `kind: Cluster/Kafka` |
| S3 services | **met** (F1) | `podman build --target test` exits 0 for both services. Runtime `id -u` → 1001. With `--user 54321:0`, `/health` → 200. Rootless podman refuses uid 123456 (`setresuid … Invalid argument`), a host subuid limit, not an image fault |
| S4 charts/plugins | **met** | `helm lint --strict` passes for all 6 charts. Dev render through kubeconform: 16/16 valid, 0 skipped. `--api-versions route.openshift.io/v1` gives 2 Routes, without it 0. `runAsUser` count in the render: 0. `scripts/test-starter.sh` exit 0 (lint plus 4 unittest). `ct lint --config .github/ct.yaml --all` passes. Raw `helm lint --strict charts/starters/pc-fastapi` fails, which is expected for an unscaffolded starter; CI's `charts/*/Chart.yaml` glob excludes it |
| S5 golden run | **met** | See G9 |
| S6 chapters | **met with minors** | Front matter is complete in all 31. Word counts with code included: all hands-on chapters within 1,400–1,900 except ch09 (1,393), ch12 (1,943) and ch13 (1,939). Prose-only, 13 chapters fall below 1,400 (m9) |
| S7 live sweep | **met with gaps** | Footer claims are backed. Some in-body quotes are not in the evidence (E1–E4) |
| S8 decks | **met** | Red Hat fonts embedded (`pdffonts`: RedHatDisplay/Text/Mono plus OpenSymbol bullets, no fallbacks). 32 slides viewed: logo bottom-right on all, theme colors and roles correct, no clipping, single-line captions. Slide commands are Helm 4 syntax. The only `--atomic` is on the 101 flag-map slide, marked `helm3-reference` |
| S9 hub | **met** | See G14 |
| S10 voice | **met** | See G12. `git diff` was not re-audited for code-block edits beyond the spot-checks |
| S11 package | **not yet run** | n/a |
| S12 publish | **not yet run** (gated) | `.github/workflows/*.yml` cannot be exercised without a remote, so CI is **not checkable** |

## Original user requirements

| Requirement | Result | Evidence / notes |
|---|---|---|
| lgtm-tutorial / lgtm-jekyll conventions | **met** | Template layouts, parts and chapters, Figure captions with alt text, verification footers, `{% raw %}` guarding (validate-site), card homepage |
| Helm 101 and 201 decks (lgtm-presentation, theme.md) | **met** | See S8 |
| Fits the existing shipping app; reuses Python from the three sibling repos | **met in code, under-surfaced** | `services/common/pcobs/{otel,kafka,logging,propagation}.py` adapt observability-python-otel-lgtm `obs/`. The `Settings` with `PG_*` and the health split come from datamesh. Shipment / ShipmentDispatched / `V2__unique_order_id.sql` come from MEA. No reader-facing page names the source projects (m2) |
| Leverages the datamesh project | **met in code** | CNPG/Strimzi CR templates, the probes block, and the `patterncatalyst.io/{domain,owner,data-product}` annotations (`charts/pc-lib/templates/_metadata.tpl:8-14`, ch17:52). The datamesh repo itself is never linked (m2) |
| Added to the workshop list, including books | **met** | See G14 |
| All salient Helm capabilities | **met** | All of the following are present across `_docs`: lifecycle; values flags including `--set-literal/json/file` and `--reset-then-reuse-values`; schema; templating with `tpl/required/fail/lookup/.Files`; dependencies with alias/condition/tags/global/import-values; CRDs with `--skip-crds`; hooks with weights and policies; `helm get hooks`; tests; helm-unittest/ct/kubeconform/diff; library and starter charts; package/repo index/search; OCI push/pull/digest/registry login; provenance plus cosign; plugins (cli/getter/postrenderer, subprocess plus Wasm); SSA/`--force-conflicts`/`--take-ownership`/`--force-replace`; kstatus wait, `--wait-for-jobs`; `--history-max`; `HELM_DRIVER`; chart API v3 status; Helmfile; Argo CD; OpenShift. Small gaps, acceptable: `--hide-secret` and `kubeVersion` in Chart.yaml are not mentioned; `.Capabilities.KubeVersion` appears only in the cheat sheet |
| Python 3.15 latest stable with FastAPI (fallback recorded) | **met (fallback)**, but see **M2** | |
| O'Reilly/Manning books, only for Helm-4-valid content | **met** | See G6. Metadata for all 9 checked against the O'Reilly platform: ISBNs, editions, years and author lists correct (EPE first author is Oliver; the plan's own order was wrong) |
| Professional voice | **met with minors** | 0 ban-tier hits. No meta-narration found. Internal leaks: m4 |
| Progressive build-up | **met** | Chart versions run 0.4.0 → 0.18.0, then 1.0.0 from ch19. Features accumulate: schema (05), helpers/notes (07), checksum (08), CNPG plus unittest (09), CRDs (10), hooks (11), Kafka (15), umbrella (16), library (17). `diff -r` of `examples/26-observability/charts/<each>` against golden `charts/<each>`, excluding `.tgz` and `Chart.lock`: **identical** for all 6 charts |
| OpenShift CRC appendix | **met** | See G10 |

## Spot-checks (8 chapters in depth: 05, 11, 12, 13, 16, 21, 25, 27)

- **Holds in all eight:**
  - Footer behavioral claims trace to evidence lines. Examples: ch21 `sha256 sum does not match`, `failed to fetch provenance`, cosign `no signatures found` on the moved tag; ch25 self-heal 3→1 in about 6 s and `Synced Healthy`; ch12 rev 5 `Rollback to 3`; ch11 the deadlock and `CreateContainerConfigError`.
  - Helm 4 prose semantics match `.tools/bin/helm <sub> --help`. That covers: bare `--wait` = watcher and omitted = hookOnly; `--rollback-on-failure` implying watcher; `--server-side` true on install and `auto` on upgrade/rollback; `--force-replace` rejected under SSA (evidence: `cannot use server-side apply and force replace together`); `--take-ownership` lifting only the annotation check; `--dry-run` none/client/server, with template defaulting to client; plugin install `--verify` default true.
- **Deprecated-flag behavior confirmed directly:**
  - `helm install … --atomic` → "Flag --atomic has been deprecated, use --rollback-on-failure instead".
  - `helm upgrade … --force` → the deprecation warning.
  - `--post-renderer ./foo.sh` → "plugin … not found". This matches the ch02/ch28 wording.
- **Clean:** no `helm2`/`tiller`, no `helm repo add` for OCI, no post-renderer path outside the migration appendix.
- **Diagrams:** 13 of 29 SVGs rendered and viewed. All use Red Hat Text and the amber palette, and all are technically correct for Helm 4. Minor layout and semantic nits are listed under m7.

## Defects (ranked)

### Blocker
None.

### Major

**M1. Wrong `helm upgrade` values semantics in a verified chapter.**
- **Where:** `_docs/05-values-and-overrides.md:80`. The text says "The `helm upgrade` command starts from the new chart's defaults, not from the previous release. Flags given last time are gone unless you repeat them."
- **What Helm actually does:** that only holds when the upgrade passes some `-f`/`--set`. With no values at all, Helm copies the previous release's values. The Helm 4.3.0 binary contains this path: `strings .tools/bin/helm` shows "copying values from old release" and "reusing the old release's values". This is the long-standing upgrade.go behavior.
- **Failure scenario:** a reader runs a bare `helm upgrade shipping ./chart` after a chart bump, expects defaults, and gets the old overrides. Or the reverse: they assume the overrides are lost and re-pass them. The checks miss this because they test flag existence, not prose meaning.
- **Fix:** "…starts from the new chart's defaults *when you pass any `-f` or `--set`*; with no value flags at all, Helm reuses the last release's values." Check the same idea in the 101 deck notes for the override-flags slide.

**M2. Reader-facing pages advertise Python 3.15; the image is 3.14.8.**
- **Where:**
  - `index.html:8` (hero eyebrow), `index.html:27` (stat "FastAPI services on Python 3.15"), `index.html:39`
  - `_config.yml:9` (site description, also used for SEO and feed)
  - `README.md:5` (badge `Python-3.15`), `README.md:7`
  - `_docs/00-outline.md:9` ("both Python 3.15 and FastAPI")
  - `CLAUDE.md` ("Python 3.15 FastAPI services")
- **Contradicts:** `_docs/01-prerequisites.md:22`, `CONTRIBUTING.md:134` and `services/README.md:37`.
- **Failure scenario:** the published site and hub card promise 3.15. A reader running the image sees 3.14.8, and the "fallback recorded, never silent" decision is silently contradicted on the most visible pages.
- **Fix:** say "Python 3.14 (3.15-ready)" or "Python 3.14; moves to 3.15 when aiokafka ships cp315 wheels" in all six places, or flip `ARG PYTHON_VERSION` once 3.15.0 GA and the wheels exist (GA is 2026-10-09) and re-run S3.

### Minor

- **E1. Quoted outputs not in any evidence file, under verified footers.**
  - ch05:68 (`key "Post" has no value`): reproduced, accurate.
  - ch05:105-106 lint error: reproduced, but the line order is reversed.
  - ch12:91: the adopted ConfigMap's `managed-by: Helm` label, `data.purpose` replacement and managedFields (`helm Apply` + `kubectl-create Update`). The evidence shows only the two `meta.helm.sh` annotations. This is an unbacked behavioral claim.
  - ch13: `could not find schema for Cluster`: reproduced.
  - ch27:44-46: read-only filesystem `touch` output, not in evidence and not checkable read-only.
  - ch27:235-237: the SCC-filled securityContext. Not in evidence, but it matches the live cluster byte for byte.
  - Fix: capture into the evidence files, or drop the ch12:91 claims.
- **E2. Quotes from a different run than the evidence.**
  - ch21:68 and :77: the GPG fingerprint `636B6576…` and the tamper hash `98567611…` differ from evidence `19A1449A…` and `ab39f0ea…`. The throwaway key is regenerated per run.
  - Fix: paste the evidence values, or note that they vary per run.
- **E3. Namespace from a different example.**
  - ch16:88 and ch11:32 quote `Deployment/hfd-26/...` from the golden run, with parentheticals.
  - The ch16 evidence has the exact `hfd-16` line at `16-umbrella.txt:311`. Use it.
- **E4. ch21 overstates a dry run.**
  - ch21:88 and :126 say the byte-identical unsigned copy "passed `helm install --verify`".
  - The demo step is `--dry-run=client` (`examples/21-signing/demo.sh:145`), and evidence line 156 shows `STATUS: pending-install`. Say it was a dry run.
- **E5. Inference stated as observation, and the evidence repeats lines.**
  - ch11:100 "Helm's wait treated the CNPG Cluster as ready before PostgreSQL accepted connections" is an inference.
  - Evidence lines 155-158 also repeat "migrate applied" four times, a capture artifact. Soften the sentence and clean the capture.
- **m1. Broken link on the built site.** `_docs/30-appendix-further-reading.md:13` has `[chapter 28](28-appendix-helm3-to-helm4.md)`, which 404s. Use the site's chapter link form (`{{ '/docs/28-appendix-helm3-to-helm4/' | relative_url }}`) like the other cross-links.
- **m2. Source projects never credited to readers.** No reader-facing page names datamesh-reference-arch-python, observability-python-otel-lgtm or modernizing-enterprise-applications, so the series fit is invisible. Add a short "Where the application comes from" paragraph to ch00 (or ch03) and the README, linking the three repos.
- **m3. ch30 metadata notes.**
  - `_docs/30-appendix-further-reading.md:64` footer says the author lists "were written from memory… should be checked". They are now verified correct against O'Reilly. Reword, and drop the meta-narration.
  - `:29` says "The two GitOps and platform books" for three books.
  - Book citation forms and editions vary across chapters, and ch30 omits editions (KP 2nd, KUR 3rd, CKAD 2nd). Normalize, keeping the CKAD title free of extra parentheses.
- **m4. Internal leaks in reader-facing body prose.**
  - `_docs/12-release-lifecycle.md:44` (`_plans/evidence/golden-08-negative-control.txt`, "golden" in the internal sense) and `:65`.
  - `_docs/10-crds-and-operators.md:94` (`_plans/evidence/...` in the body).
  - `CONTRIBUTING.md:128` still says "Chapter 27 stays `unverified` and states 'untested on the authoring machine'", which contradicts the plan change and the ch27 footer.
- **m5. Deprecated flag recommended.** `_docs/27-appendix-openshift-local.md:85` recommends `helm template --validate`. In Helm 4.3.0 it is hidden and prints "Flag --validate has been deprecated, use '--dry-run=server'". The command checker misses it because it sits in prose. Rewrite with `--dry-run=server`.
- **m6. Committed vendored `.tgz` files.**
  - 36 `examples/**/charts/*.tgz` are committed. Their content matches their sources, checked by extracting each and diffing.
  - The root `.gitignore` has no `*.tgz` (only `charts/.gitignore` covers `charts/`).
  - On a fresh clone, `examples/16` and `examples/17` `demo.sh offline` rewrite 10 of them, so the tree goes dirty after a demo run.
  - `_docs/16-umbrella-charts.md:60` claims "The tarballs are build output and are git-ignored", which is false.
  - Fix: add `examples/**/charts/*.tgz` to `.gitignore` and `git rm --cached` them. Demos already run `helm dependency build`. Or reword ch16.
- **m7. Diagrams.**
  - `09-subchart-tree.svg`: "Cluster (CNPG custom resource)" and "PG_HOST, PG_PASSWORD from Secret" overflow their boxes.
  - `11-hook-timeline.svg`: the edge labels overlap box borders, and the Option A failure box hangs after "Release stored" although the failure occurs at the pre-install hook.
  - `12-upgrade-failure-paths.svg`: a spurious "Timeout or error → Conflict" edge; SSA conflicts happen at apply time.
  - `20-oci-flow.svg`: the minikube addon (5000) points into the box for the local registry (5001), conflating them.
  - `23-post-render-pipeline.svg`: the two overlapping arrowheads read as a diamond.
  - `22-plugin-types.svg` and `12-…`: subtitles touch the box edges.
  - The plan's `27-openshift-differences` shipped as `27-openshift-deploy`. Harmless.
- **m8. Decks.**
  - 201 slide 41 (`presentation/helm-201/deck.js:559`) and `_docs/27-appendix-openshift-local.md:178`: the `ProjectHelmChartRepository` URL points at the GitHub Pages site, which will publish no `index.yaml`. Use a `<your-chart-repo>` placeholder or publish an index.
  - Multi-line commands without the `[host]$` prompt on 201 slides 25 and 40 and the 101 slide 17 continuations, against the house rule.
  - `presentation/helm-101/` has no `package.json`; the plan expects one and helm-201 has it.
  - 101 slide 13 diagram renders `--history-max` as "–history-max" (en dash) in `presentation/helm-101/diagrams.py`.
- **m9. Word counts.**
  - With code included, ch09 is 1,393 (below 1,400), and ch12 (1,943) and ch13 (1,939) exceed 1,900.
  - Prose-only, 13 hands-on chapters are below 1,400. The plan does not define the measure; the executor counted including code.
- **m10. Hub synopsis.** The `_data/sites.yml` synopsis doesn't mention Helm 4 or OpenShift, so the card undersells the tutorial. Optional.

## Not checkable here
- GitHub Actions `pages.yml` and `charts-ci.yml`: no remote. Local equivalents pass: Jekyll in ruby:3.3, ct lint, unittest, kubeconform, offline demos.
- ch25 Git-sourced Argo CD path: waits for the S12 push.
- Arbitrary uid above the rootless subuid range on this host. uid 54321 works.
