---
title: "r1.1 validation"
render_with_liquid: false
---
# r1.1 validation (Phase 3), 2026-10-08

Branch `feature/r1.1` at `a5adc03` (12 commits over `origin/main` `4e8ec90`, not yet pushed). Read from the diff, the evidence files and fresh runs; commit messages, footers and plan status were treated as claims. No cluster was started. The stopped `helm4dev` container was inspected read-only.

Fresh clone: `scratchpad/r11-clone` (branch `feature/r1.1`, `.tools` symlinked, `source scripts/env.sh`).

## Criteria

| # | Criterion | Result | Evidence |
|---|---|---|---|
| 1.1 | Item 1: ch25 Git-sourced Application | met | `apps/shipping-service-git.yaml` (tag `r1.0`, NodePort 30090); `25-gitops-argocd-git.txt` shows Synced/Healthy, `valuesObject` change, self-heal; umbrella-from-Git failure is documented in ch25 "Sourcing from Git" with the cause. r1.1 NodePort re-run in `25-gitops-argocd.txt:211-234` |
| 1.2 | Item 2: ch01 from-scratch bootstrap | met | `01-lab-setup-fresh.txt` (pre-tunnel-removal run, labelled as such) plus `01-lab-setup-nodeports.txt` (port-mismatch refusal, `--replace`, loopback bindings in `docker inspect` and `ss -ltn`, registry catalog, Grafana health) |
| 1.3 | Item 3: ch08 SOPS with helm-secrets | met | `08-config-secrets-sops.txt`: getter and CLI render, cluster Secret `sops-dev-token`, 201 vs 401, wrong-key failure, schema rejection of the raw ciphertext, `helm get values` shows plaintext. Key generated under `.work/` (gitignored), nothing committed |
| 1.4 | Item 4: `ct install` on Actions | met | `gh run view 37836421071`: `workflow_dispatch` on `ci/ct-install`, both jobs success; `14-chart-testing-ci.txt` |
| 1.5 | Item 5: published chart repo | met | Live `GET .../charts/index.yaml` = 200 today, six charts at 1.0.0; `19-published-repo.txt`; local `scripts/publish-charts.sh` into a temp dir produced six archives and an index with Pages URLs |
| 1.6 | Item 6: Streams + console view (partial) | met, partial stated honestly | `27-openshift-crc-streams.txt` (amq-streams 3.2.1-14, v1 and v1beta2, full verify passes); console: plan row, ch27 banner, console section, footer, example README, CHECKLIST and 201 deck note all say the catalog listing was not opened |
| 1.7 | Item 7: hub `gen-books.py` skips `_plans` | met | hub PR #3 merged 2026-10-08T20:02:51Z; `scripts/gen-books.py:62` excludes `/_plans/` |
| 1.8 | Item 9: ch25 umbrella from the Helm repo | met | `apps/shipping-platform-helmrepo.yaml`; `25-gitops-argocd-helmrepo.txt` and the r1.1 re-run in `25-gitops-argocd.txt:237-277` (Synced/Healthy, PostSync migration, NodePorts 30190/30191, drift revert) |
| 2.1 | No tunnels in reader-facing files or scripts | met, one adjacent defect | `git grep` over the branch excluding `_plans`: every hit for `port-forward`, `minikube tunnel`, `tunnel.sh`, `ssh -L`, `minikube ssh` is a prohibition line marked `forbidden-ok` or a "no tunnel" footer. `scripts/tunnel.sh` is deleted. Adjacent: all 32 `NOTES.txt` files still tell readers to run `minikube service --url` (M2) |
| 2.2 | Services at `127.0.0.1:<nodePort>` | met | demos and docs use `127.0.0.1:30080/30081/30190/30191/30300/30443` and `127.0.0.1:5000`; no `127.0.0.1:8080/8081/3000/8443` remains outside `_plans` |
| 2.3 | NodePorts published at creation, loopback only | met | `setup-profile.sh` builds `--ports=127.0.0.1:<p>:<p>` from `HFD_NODE_PORTS` (`lib.sh:35-45`, nine ports) and refuses a profile missing any 127.0.0.1 binding. `docker inspect helm4dev` (stopped): all nine at `HostIp 127.0.0.1`; the remaining entries (22, 2376, 8443, 32443, a second 5000) are minikube's own random ports, also on 127.0.0.1 |
| 2.4 | `forbidden-syntax.sh` enforces the rule | met, with gaps | Scratch copy (`ROOT_DIR`): a Markdown line with `kubectl port-forward`, `minikube tunnel`, `scripts/tunnel.sh` or `ssh -L` fails the check (rc 1); same for a script under `scripts/`. Not caught: `minikube -p helm4dev tunnel`, lowercase "ssh tunnel", `minikube ssh` (m2) |
| 3 | Demos do not assume both clusters | met | No demo or script uses both `crc`/`oc` and minikube. ex27 uses `oc` only; minikube demos use `minikube -p helm4dev` and kubectl. Caveat on current context in m5 |
| 4 | Evidence integrity (spot check) | met, minor gaps | Checked 01, 02, 08, 11, 12, 14, 15, 19, 20, 24, 25, 26, 27: every cited file exists; each r1.1 re-run file starts with the r1.1 NodePort header and has no tunnel lines (02 and 25 carry only the podinfo and Argo CD chart NOTES that print `port-forward`, which is third-party output). Host URLs appear only where the demo echoes them (`20-oci.txt:122`, `24-environments.txt:214-220`, `25-gitops-argocd.txt:208`, `01-lab-setup-nodeports.txt`); elsewhere NodePort use is inferred from the demo source at `a5adc03`. ch19 live repo, ch25 Git + helmrepo, ch08 SOPS, ch27 Streams all present. Two uncited tunnel-era files remain (m3) |
| 5.1 | No secrets committed | **not met** | Argo CD admin password in plain text at `_plans/evidence/25-gitops-argocd.txt:208` (M1). No age private key, kubeadmin password, pull secret, GitHub token or private key block found |
| 5.2 | `.gitignore` coverage | met | `/.claude/`, `/.tools`, `.work/`, `*.agekey`, `examples/**/charts/*.tgz` in `.gitignore`; `**/charts/*.tgz` in `charts/.gitignore` |
| 6.1 | 27 `demo.sh offline` | met | all 27 exit 0 |
| 6.2 | `test-starter.sh`, `helm unittest` | met | test-starter 4/4; unittest after `helm dependency build` (as CI does): notification 8/8, shipping-platform 23/23, shipping-service 25/25 |
| 6.3 | `validate-site.sh`, `check-helm-commands.sh`, `forbidden-syntax.sh` | met | OK; 508 helm commands in 92 files; forbidden OK |
| 6.4 | Clean tree after runs | met | `git status --porcelain` empty in the clone (after demos, dependency builds, publish, Jekyll) and in the working repo |
| 6.5 | Jekyll build and links | met | `ruby:3.3` build succeeded; 836 internal `href`/`src` checked, 0 broken |
| 6.6 | `publish-charts.sh` | met | six `.tgz` plus `index.yaml` with `https://patterncatalyst.github.io/helm-for-developers/charts/...` URLs |
| 6.7 | Decks | met | 101: 36 slides, 36 notes; 201: 44 slides, 44 notes. 201 `.pptx` matches `deck.js`: Grafana at `127.0.0.1:30300` (notes 37), Streams 3.2.1 and console status (notes 38), "listed all six charts" (notes 41), published URL on slide 41; no tunnel text in either deck |
| 6.8 | actionlint | met | `rhysd/actionlint` 1.7.12 (container): no findings |
| 7.1 | Voice scan, ban tier | met | 0 matching lines, rc 0 |
| 7.2 | Spot read of new sections | met, one stale sentence | ch01 Host access, ch08 SOPS, ch15 Uninstall order (every listed `clean` deletes KafkaTopics first, plus ex27), ch25 Git and Helm repository sections, ch27 Streams and console: accurate against the evidence, no internal terms. ch19 Published repository still says the Pages URL is unverified (m1) |
| 8.1 | Conventional Commits, no AI trailers | met | 12/12 subjects match `type(scope): `; author PatternCatalyst; no `Co-Authored-By` or generated-by lines |
| 8.2 | No tracked generated files | met | no `_site`, `.jekyll-cache`, `__pycache__`, `.pyc`, chart `.tgz` or keys tracked. `.pptx` and diagram SVGs are tracked deliverables by design |

## Defects

### Blocker

None.

### Major

**M1. Argo CD admin password committed and published.** `_plans/evidence/25-gitops-argocd.txt:208` contains the plain-text `admin` password after `Argo CD UI: https://127.0.0.1:30443`, added in `a5adc03`. Source: `examples/25-gitops-argocd/demo.sh:77` prints the decoded `argocd-initial-admin-secret`. `_plans` is a Jekyll collection with `output: true`, so the file is also served at `/plans/25-gitops-argocd.txt` on Pages (confirmed in the local `_site`). Every other evidence file redacts this line (`25-gitops-argocd-git.txt:48`, r1.0 used `<password>`). Impact is low today (the Argo CD install was removed by `clean`, and it was loopback-only), but it breaks the redaction rule and every future re-capture repeats it.
Failure scenario: the branch is pushed; the password is in public Git history and on the public site.
Fix: before pushing, replace the value with `<redacted>` and amend `a5adc03` (the branch is not on the remote yet, so a rewrite keeps it out of history); change `demo.sh:77` to print the retrieval command (`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`) instead of the value.

**M2. Every chart's NOTES still sends readers to `minikube service --url`.** `charts/shipping-service/templates/NOTES.txt:6`, `charts/notification-service/templates/NOTES.txt:6` and 30 copies under `examples/*/` (32 files); described in `_docs/07-helpers-and-notes.md:67` and shown in `presentation/helm-101/deck.js:350,359`; printed in evidence (`08-config-secrets.txt:34`). With the docker driver on macOS, Windows or Docker Desktop, `minikube service --url` starts a foreground tunnel process; on Docker Engine on Linux it prints the node IP (`192.168.49.2:<port>`), not `127.0.0.1`. Both contradict the r1.1 rule that host access is `127.0.0.1:<nodePort>`.
Failure scenario: a reader follows the install output, gets a tunnel process that dies when the terminal closes, or a node-IP URL that the chapters never use.
Fix: in the NodePort branch print `[host]$ curl http://127.0.0.1:{{ .Values.service.nodePort }}/api/info` (note the port must be in `HFD_NODE_PORTS`); update the ch07 sentence and the 101 slide/notes; rebuild the 101 deck; re-run the affected unit tests and `check-helm-commands.sh`. Optionally add `minikube( -p [a-z0-9]+)? service` to the forbidden-syntax tunnel pattern.

### Minor

**m1. ch19 contradicts its own footer.** `_docs/19-packaging-and-repos.md:145`: "The commands against the real Pages URL run after the r1.1 deploy; until then treat that URL as unverified." The footer (line 171) and `19-published-repo.txt` show the live check passed, and the URL answers 200 today. Fix: replace with the observed result (`helm repo add`, six charts at 1.0.0, `helm template` rendered 15 objects).

**m2. Forbidden-syntax pattern gaps.** `scripts/forbidden-syntax.sh:72`. Verified in a scratch copy: `minikube -p helm4dev tunnel` (the form every command in this project uses), "ssh tunnel" in lowercase, and `minikube ssh ... curl` pass the check. Fix: `minikube( -p [^ ]+)? tunnel`, `-i` for "ssh tunnel", add `minikube( -p [^ ]+)? ssh`.

**m3. Stale tunnel-era evidence labelled r1.1.** `_plans/evidence/15-kafka-notification-clean.txt:18-20` and `_plans/evidence/26-observability-r1.1.txt:175-178` record `scripts/tunnel.sh` and `127.0.0.1:8080/3000`. Neither is cited by a chapter (the ch15 and ch26 footers cite the NodePort re-runs), but both are published on the site and their headers say "r1.1". Fix: delete them or add a header line "superseded by <file>, recorded before NodePorts were published".

**m4. Two SOPS assertions cannot fail.** `examples/08-config-secrets/demo.sh:94,97`: `[ "$got" = "$want" ] && echo ...` does not trip `set -e`, so a wrong decrypted value only drops the success line. Fix: `[ "$got" = "$want" ] || { echo "decrypted value mismatch" >&2; exit 1; }`.

**m5. Live demos use the current kube context.** Demos 03 to 26 call `helm`/`kubectl` without `--kube-context helm4dev` (only ex02 pins it). After a CRC session with minikube stopped, a demo that does not build images first (for example the `sops` target, which checks `kubectl --context helm4dev` at `demo.sh:111` and then installs at line 113 into whatever context is current) can act on the CRC cluster. Pre-existing pattern from r1.0, made sharper by the one-cluster-at-a-time policy. Fix: export `HELM_KUBECONTEXT=helm4dev` and use `kubectl --context helm4dev` (or fail when `current-context` is not `helm4dev`) in `scripts/env.sh` or each live target.

**m6. Deck file names still say r1.0.** `presentation/helm-201/Helm-201-r1.0.pptx` carries r1.1 content. Rename at release time if the files are versioned by iteration.

**m7. Most evidence does not echo the host URL.** Integrity of "host requests at `127.0.0.1:30080`" in footers for 03 to 18 rests on the demo source at `a5adc03` (verified to use `127.0.0.1:<nodePort>` with `curl --retry`), not on the transcript. Consider having demos echo the URL they hit.

## Verdict

**Not ready as is; ready to merge and release r1.1 once M1 is fixed before the branch is pushed.** M1 is a one-line redaction plus a demo change, and must be done by amending the unpushed commit so the value never reaches the public history. M2 should be fixed in r1.1 because it is the one reader-facing instruction left that contradicts the host-access rule; if the owner defers it, record that in the plan and in ch07. Everything else in scope checked out: items 1 to 7 and 9 are delivered with evidence, the console view is stated as partial everywhere, the tunnel removal holds in docs, scripts and decks, the published NodePorts bind to 127.0.0.1 only, and all regression checks pass from a fresh clone.
