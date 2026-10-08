---
title: "r1.1 validation recheck"
render_with_liquid: false
---
# r1.1 validation recheck (Phase 3, after repair), 2026-10-08

Branch `feature/r1.1` at `a1ceded` (13 commits over `origin/main` `4e8ec90`, not pushed: `git ls-remote origin` lists only `main`, `r1.0` and old PR refs). The repair is `5a476a8` (the earlier `a5adc03`, amended: the diff between them is only the Argo CD line in `_plans/evidence/25-gitops-argocd.txt` and `examples/25-gitops-argocd/demo.sh`) plus `a1ceded`. Read from the diff and fresh runs; commit messages, footers and `r1.1-repair-smoke.txt` were treated as claims. No cluster was started.

Fresh clone: `scratchpad/r11-clone2` (branch `feature/r1.1`, `.tools` symlinked, `source scripts/env.sh`).

## Defects from the first report

| Defect | Status | Evidence |
|---|---|---|
| **M1** Argo CD password committed | **fixed** | `git log -p origin/main..HEAD` and `git log -p --all`: 0 matches for `\(admin / [A-Za-z0-9]{8,}\)`. Every `argocd-initial-admin-secret` hit is the retrieval command (`jsonpath='{.data.password}' \| base64 -d`), never a value. `demo.sh:77-78` prints `(admin; password: kubectl -n argocd get secret ... \| base64 -d)` with a comment saying why. `25-gitops-argocd.txt:208` shows the same text; it was edited into the transcript, not re-captured. The old commit `a5adc03` still exists in the local reflog (`git log -g` finds 1 match), but no branch or remote ref contains it, so a push does not send it. Other secrets, tree and branch history: no `AGE-SECRET-KEY-`, `ghp_`/`github_pat_`/`glpat-`, private key block, AWS key or JWT. `password:` hits are chart defaults (`secretKeyRef` key `password`, empty `postgres.password`), SOPS ciphertext from throwaway keys, and the public demo tokens `dev-token` and `sops-dev-token`. The built site's `plans/` pages hold no secret value |
| **M2** NOTES used `minikube service --url` | **fixed** | `git grep -E 'minikube( -p [^ ]+)? service'` outside `_plans`: 0 hits. All 32 shipping/notification `NOTES.txt` branch on `service.type` and `service.nodePort`. Rendered from the clone (`helm install --dry-run=client`, `service.type=NodePort,service.nodePort=30080`): `[host]$ curl http://127.0.0.1:30080/api/info`; without `nodePort` it prints `kubectl -n hfd-x get svc ...`; notification with 30081 prints `curl http://127.0.0.1:30081/api/notifications`. ch07 text and the 101 `deck.js` plus `.pptx` are updated (the slide XML has the `127.0.0.1:{{` line, and no `minikube ... service` remains in either deck). New `tests/notes_test.yaml` in both charts. Versions: `shipping-service` and `notification-service` 1.0.1; umbrella 1.0.1 depends on 1.0.1/1.0.1/1.0.0/1.0.0, and `Chart.lock` matches; `helm dependency build` left `git status` clean. `diff -r charts examples/26-observability/charts` (`.tgz` and starters excluded) differs only by `charts/.gitignore`. Residual: 9 evidence transcripts (`07`, `08`, `08-sops`, `09`, `11`, `15`, `19`, `20`, `21`) still show the old NOTES output. They are historical records, not instructions |
| **m1** ch19 said "unverified" | **fixed, new wording overstates** | The sentence is gone. The new text says both `1.0.0` and `1.0.1` "are listed". Today the live index has only `1.0.0`. The claim is backed by the local merge test (smoke lines 91-105) and by my live-merge run below. It becomes true after the merge deploy. See n3 |
| **m2** forbidden-syntax gaps | **fixed, gaps remain** | Scratch copy (`ROOT_DIR`), rc 1 for: `minikube -p helm4dev tunnel`, `minikube --profile=helm4dev tunnel`, `minikube -p helm4dev service ... --url`, "ssh tunnel" in any case, `minikube -p helm4dev ssh -- curl ...`, `port-forward`, `minikube -p "$PROFILE" tunnel` in `scripts/`, and the same in deck.js and example NOTES. Still rc 0: (a) anything in golden `charts/` (for example `charts/shipping-service/templates/NOTES.txt` with `minikube service --url` or `kubectl port-forward`), because `tun_targets` omits `charts/`, the directory where M2 lived; (b) `minikube -p helm4dev service x -n ns` without `--url`, which still opens a tunnel on Docker Desktop; (c) bare `minikube ssh`. New false positive from `-i`: `ls -l 5:` matches `-L [0-9]+:` |
| **m3** stale tunnel evidence | **fixed** | Both files start with a `SUPERSEDED` header that names the current file, and the tunnel lines are prefixed `[historical, tunnel era]` |
| **m4** SOPS assertions could not fail | **fixed** | `examples/08-config-secrets/demo.sh:96,100`: `[ "$got" = "$want" ] \|\| { echo ... >&2; exit 1; }` |
| **m5** demos used the current context | **fixed, one regression** | Demos 01-26 source `scripts/kube-context.sh` (2 lines each); 27 does not. `kubectl()` calls `command kubectl`, so it cannot recurse. Checked under bash with a scratch kubeconfig whose current context is a decoy: the parent shell, a child `bash -c` and a child `sh -c` all resolve to helm4dev. An explicit `--context decoy` wins, because a later flag overrides. `xargs kubectl` bypasses the function, but no demo or script uses an external wrapper. `HELM_KUBECONTEXT=helm4dev` reaches `helm env` in children. helmfile gets `--kube-context` on template, sync and destroy, and the binary also knows `HELMFILE_KUBE_CONTEXT`. ct gets `KUBECONFIG=<minified helm4dev>` (chmod 600, in a `mktemp -d` removed by a trap) plus `--kube-context helm4dev`. Regression: `command -v kubectl` is now satisfied by the function, so the `kubectl is not on PATH` preflight check in `examples/01-lab-setup/demo.sh:48-50` (and `examples/23-post-renderers/demo.sh:21`) can no longer fail (n2) |
| **m6** deck file names | **fixed** | `Helm-101-r1.1.pptx` (36 slides, 36 non-empty notes) and `Helm-201-r1.1.pptx` (44/44). `OUT`/`REV` bumped in both `deck.js`; the slide text says r1.1, not r1.0. `presentation/README.md` and the root README name the r1.1 files, and both exist. The only `r1.0.pptx` mentions are in `_plans` history |
| **m7** evidence did not echo URLs | **fixed going forward** | `curl()` prints `    curl -> <url>` to stderr and returns `command curl`'s status; stdout is unchanged. `set -euo pipefail` tests in bash: a plain failing call, a pipeline, `v=$(curl ...)` and a call inside a function all exit 7; `if curl` and `curl \|\| ...` take the else branch; a captured `-w '%{http_code}'` returns `[200]` with the URL line on stderr only. The only `2>&1` capture (`ex21:84`) discards output. Header `-H 'Authorization: Bearer dev-token'` and `-u admin:admin` are not echoed (only URL-shaped args are). Older transcripts are unchanged, which is expected |

## publish-charts.sh

Read line by line, then run from the clone against the live site (`https://patterncatalyst.github.io/helm-for-developers/charts`, which today serves six charts at 1.0.0) into a scratch dir: rc 0. The script kept the six published archives, packaged `pc-lib`, `shipping-postgres` and `shipping-kafka` 1.0.0 (content unchanged, so the published archive was kept) and 1.0.1 of the other three. Compared with the live `index.yaml`, all six 1.0.0 entries keep the live digest and URL, the three 1.0.1 entries are new with Pages URLs, and nothing is missing. Each kept archive's `sha256sum` equals its live digest (for example `pc-lib` `4b246ca4...`).

Negative test: one line appended to a `pc-lib` template in a scratch copy, no version bump. The script exits 1 with `ERROR: pc-lib-1.0.0.tgz is already published with different content ... bump 'version'` and writes no output directory.

Runner: `pages.yml` sources `env.sh` after `install-tools.sh --helm-only` and runs the script on every push and PR, so a chart changed without a bump fails CI before merge. curl and sha256sum are on `ubuntu-latest`. `cp -n` on Ubuntu 24.04 (coreutils 9.4, tested in `ubuntu:24.04`) returns 0 with a deprecation warning, so line 92 does not trip `set -e`.

Findings:

- **N1 (major): the immutability guard fails open.** When `index.yaml` cannot be fetched (network error, Pages outage, 5xx, 404), the script warns and builds a fresh index (lines 42-45). Tested with `HFD_CHARTS_URL=http://127.0.0.1:9/charts` and with a 404 URL: rc 0. Combined with the modified `pc-lib`, the output held a rewritten `pc-lib-1.0.0.tgz` and dropped `shipping-service`, `notification-service` and `shipping-platform` 1.0.0. On a push to `main`, that site would be deployed. It breaks the promise ch19 makes and the ch25 Application that pins `shipping-platform` 1.0.0 from this repository. The archive download (line 38) already fails closed; only the index fetch does not. Fix: exit 1 when the index cannot be fetched, unless `HFD_ALLOW_FRESH_INDEX=1` (first publish, local tests). Or allow the fallback only on HTTP 404, using `curl -w '%{http_code}'`, and fail on anything else. Update the ch19 sentence "If the site cannot be reached, the script prints a warning and builds a fresh index" to match.
- n4 (nit): `helm repo index --merge` regenerates entries from the archives, so the `created` time of every kept version changes on each deploy (digests do not). `content_digest` runs in a command substitution without `inherit_errexit`, so a failed `tar` is not fatal. A corrupt nested `.tgz` would loop forever in the `while find` loop (the `mkdir` fails on the second pass and the archive is never removed). `cp -n` is deprecated: use `--update=none`.

## Fresh-clone regression

| Check | Result |
|---|---|
| 27 × `examples/*/demo.sh offline` | all rc 0 |
| `scripts/test-starter.sh` | rc 0, 4/4 |
| `helm unittest` after `helm dependency build` | notification-service 10/10, shipping-service 27/27, shipping-platform 23/23 (the new NOTES tests included) |
| `validate-site.sh` / `check-helm-commands.sh` / `forbidden-syntax.sh` | OK / OK (508 commands in 92 files) / OK |
| `git status --porcelain` after demos, dependency builds, `publish-charts.sh` and the Jekyll build | empty |
| Jekyll (`ruby:3.3`, podman) | build rc 0. Internal link check: 846 `href`/`src` checked, 0 broken. Secret scan of `_site` (password, age key, token, private key patterns): no values |
| actionlint | 1.7.7 binary and `rhysd/actionlint:latest` container (with shellcheck): no findings |
| Decks | see m6 |
| Voice, ban tier | 0 hits in the diff's added reader-facing lines. Over the full reader-facing scope with CONTRIBUTING included: 4 hits, all `CONTRIBUTING.md:96`, the line that lists the banned words (present on `main`). With `--ext +sh,yaml`: 21 `on purpose` comments in `values.yaml` copies, also present on `main`. Neither is new in r1.1 |
| Commits | the 2 repair commits are Conventional, author PatternCatalyst, no AI trailers |

## Evidence for the repair

`_plans/evidence/r1.1-repair-smoke.txt` is a condensed log, not a raw transcript. The repair commit changed no verification footers. The re-run footers from `5a476a8` cite their own evidence files, which the first report checked. No chapter cites the smoke file. Against the body claims added in `a1ceded`:

- ch07, NOTES print `curl http://127.0.0.1:<nodePort>/api/info`: supported (smoke 28-29 and 40-42, plus my render).
- m5, demos act on helm4dev under a decoy context: supported for ex04, ex08 `sops` and ex26 (smoke 9-77). The ct path (ch14) and the `helmfile --kube-context` path (ch24) were not run live in the smoke; the chapters describe them as what the demo does, not as observed.
- ch19, immutability: supported by the local merge, the negative and the unreachable-site runs (smoke 91-108), and reproduced here against the live site.
- Smoke line 82, ex26 is identical to golden: confirmed.

## New findings

- **N1 (major)** `publish-charts.sh` fails open when the live index is unreachable (above).
- n2 (minor) `command -v kubectl` in `examples/01-lab-setup/demo.sh` preflight and `examples/23-post-renderers/demo.sh:21` now finds the shell function, so a missing kubectl binary is reported as ok. Use `type -P kubectl`.
- n3 (minor) ch19: "Both `1.0.0` and `1.0.1` ... are listed" is true only after the merge deploy. Reword as expected behaviour or re-run `helm search repo hfd --versions` after the deploy, and cite the smoke file.
- m2 leftovers (minor): add `charts` to `tun_targets`, drop the `--url` requirement for `minikube service`, and decide on bare `minikube ssh`.
- n5 (nit) `examples/24`, `25` and `27` chart copies are still at `1.0.0` but carry the new NOTES. They are local snapshots and never published, but ex25 pushes its own `shipping-platform-1.0.0.tgz` to the in-cluster registry, so "1.0.0" there differs in content from the Pages 1.0.0.
- Housekeeping: `git reflog expire --expire=now --all && git gc --prune=now` removes `a5adc03` locally. Optional, because it is not reachable from any ref that can be pushed.

## Verdict

**Ready to merge and release r1.1, with one recommended fix before the merge deploy.** M1 and M2 are fixed, m1 to m7 are fixed (m2 and m5 with small leftovers), and every regression check passes from a fresh clone. No blocker remains. N1 is the one major issue. It does not affect the normal path (the live fetch works and the merge output is correct), but on a failed fetch it would deploy a repository without the 1.0.0 versions that ch25 pins and without the guard. The fix is a few lines; make it before merging. If it is deferred, check that the merge run's "Publish Helm chart repository" step logs six `kept published` lines, then run `helm search repo hfd --versions` against the live URL.
