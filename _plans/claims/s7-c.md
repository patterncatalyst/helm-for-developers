---
title: "S7c results (chapters 22-26)"
render_with_liquid: false
---
# S7c results, 2026-10-08, Helm 4.3.0, minikube helm4dev

End state: release `platform` installed in `hfd-26` (golden restored); no other example releases or `hfd-*` namespaces; Argo CD and its CRDs removed; no tunnels. `.tools/helm/plugins` holds only `helm-diff` and `helm-unittest`.

| Claim | Chapter | Result | Evidence | Note |
|---|---|---|---|---|
| `helm shipping-env RELEASE -n NS` prints the same env list as the `--chart` form | 22 | verified | 22-plugins.txt | Installed chart in `hfd-22`; diff identical; matches `kubectl get deploy -o yaml` |
| `plugin.wasm` builds on a clean module cache | 22 | verified | 22-plugins.txt | Empty GOPATH, downloads `go-pdk v1.1.3`, Go 1.26.8 |
| `maxPages: 16` error | 22 | verified | 22-plugins.txt | Real text has an `Error: failed to create existing plugin:` prefix; chapter updated |
| `ignoreFlags: true` leaves Wasm `extraArgs` empty | 22 | verified | 22-plugins.txt | `Hello, world!` |
| Unsigned tarball install fails; `--verify=false` lists `unsigned` | 22 | verified | 22-plugins.txt | In the demo |
| Directory install provenance `local dev` | 22 | partial | 22-plugins.txt | The Wasm plugin (symlinked dir) shows `local dev`; shipping-env shows `unknown` in the demo. Chapter already prints exactly this |
| Helm exports `HELM_BIN`, `HELM_NAMESPACE`, `HELM_PLUGIN_DIR` | 22 | verified | 22-plugins.txt | `HELM_BIN=helm` (not an absolute path); also `HELM_PLUGIN_NAME` |
| `ignoreFlags` false passes args, true none | 22 | verified | 22-plugins.txt | `true`: usage message, exit 2 |
| `--post-renderer kustomize-postrender` label on live objects and stored manifest | 23 | verified | 23-post-renderers.txt | Deployment, Service, ConfigMap, Secret; install and upgrade manifests |
| `includeSelectors: false` keeps selector | 23 | verified | 23-post-renderers.txt | Live `matchLabels` unchanged |
| Two `--post-renderer-args` arrive as `$1`, `$2` | 23 | verified | 23-post-renderers.txt | Throwaway plugin |
| Missing-annotations Deployment fails | 23 | verified, text corrected | 23-post-renderers.txt | Helm shows only `plugin "kustomize-postrender" exited with error`; the script's stderr (`add operation does not apply...`) is visible only when run by hand. Chapter updated |
| Path and unknown name give `plugin: {Name:... Type:postrenderer/v1} not found` | 23 | verified | 23-post-renderers.txt | Demo |
| `helmfile -l env=dev sync --skip-deps` installs `platform` with `rollbackOnFailure` | 24 | verified | 24-environments.txt | Revision 1 deployed, `helm test` three Succeeded |
| `./demo.sh pin` digest pulled by the node | 24 | failed then fixed | 24-environments.txt | `docker push` from Docker Desktop (VM) cannot reach the host tunnel (`dial tcp [::1]:5000: i/o timeout`). With `BUILD_ENGINE=podman` the pin was written and the pod ran `localhost:5000/shipping-service:0.1.0@sha256:...`. Chapter and README now say so |
| `version:` ignored for local path | 24 | verified | 24-environments.txt | 1.0.1 renders byte-identical |
| `version:` enforced for `oci://` | 24 | verified | 24-environments.txt | 9.9.9 fails with `FetchReference ... not found`; needs a plain-HTTP shim because Helmfile 1.8.1 does not pass `--plain-http` to `helm pull`. Chapter updated |
| Dev NodePorts 30080/30081 clash with other releases | 24, 25 | verified | 24-environments.txt | Dev Services use them; each example was cleaned before the next |
| Argo CD chart 10.10.1 installs with `--wait --rollback-on-failure`, CRDs apply | 25 | verified | 25-gitops-argocd.txt | Twice |
| NodePort 30082/30443; UI 200 on 127.0.0.1:8443 | 25 | verified | 25-gitops-argocd.txt | |
| Repo Secret `enableOCI` + `insecureOciForceHttp` | 25 | failed then fixed | 25-gitops-argocd.txt | Key is case-sensitive: `insecureOCIForceHttp`. With the old spelling repo-server pulled over HTTPS and the Application stayed `Unknown`. Fixed `apps/repo-registry.yaml` and chapter; rerun from scratch Synced/Healthy |
| `helm push --plain-http` through the registry tunnel | 25 | verified | 25-gitops-argocd.txt | |
| Application Synced/Healthy; `helm list -n hfd-25` empty | 25 | verified | 25-gitops-argocd.txt | |
| `defaultCarrier: ARGO-Post` at `/api/info` | 25 | verified | 25-gitops-argocd.txt | |
| Migration runs as PostSync hook | 25 | verified | 25-gitops-argocd.txt | `Job/platform-shipping-migrate PostSync Succeeded`; `schema_migrations` versions 1, 2 |
| Self-heal reverts drift (behavioral) | 25 | verified | 25-gitops-argocd.txt | Scaled to 3, back to 1 within about 6 s |
| `lookup` empty under Argo CD | 25 | verified | 25-gitops-argocd.txt | Probe chart: `yes` from `helm install`, `no` from Argo CD. Chapter updated |
| Git Application syncs incl. `file://` deps | 25 | not verified | | Repository not pushed |
| Grafana sidecar watches only own namespace until `searchNamespace=ALL` | 26 | verified | 26-observability.txt | No `NAMESPACE` env, search `[]`; after upgrade `NAMESPACE=ALL` |
| `helm upgrade grafana ... --reuse-values --set sidecar.dashboards.searchNamespace=ALL` | 26 | verified | 26-observability.txt | |
| Dashboard in folder Shipping | 26 | verified | 26-observability.txt | |
| `http_server_duration_milliseconds_count` in Mimir with `service_name` | 26 | failed then fixed | 26-observability.txt | Metric exists; label is `job` (`shipping/platform-shipping`), no `service_name`. Dashboard panel changed in golden and example copies (identical); `helm unittest` 23 pass |
| Loki label `service_name` | 26 | verified | 26-observability.txt | Values `platform-notification`, `platform-shipping` |
| Dispatch trace spans both services | 26 | verified, demo fixed | 26-observability.txt | Demo dispatch lacked the bearer token (401), so its trace was shipping-only, and it reused order 2601 on rerun. Demo now sends the token, uses a random order id, and asserts both services plus the Mimir query |

## Fixes

- `examples/25-gitops-argocd/apps/repo-registry.yaml` and `_docs/25`: `insecureOCIForceHttp`. `demo.sh clean` also deletes the Argo CD CRDs the chart keeps.
- `examples/26-observability/demo.sh`: auth header, unique order id, retry flags, trace/metric assertions.
- Dashboard JSON (golden `charts/` and example 26, identical): request-rate panel uses `job`.
- Chapters 22 to 26 and READMEs: footers promoted to verified (25 and 26 note unverified parts); 23 error text; 24 push engine and OCI notes.

## Notes

- `scripts/build-images.sh push` with Docker Desktop on Linux fails. Resolved in repair round 2: push mode now prefers podman when installed.
- `scripts/platform/setup-lgtm.sh` (kept as is on purpose; ch26 teaches the trap) still does not set `sidecar.dashboards.searchNamespace`; the demo upgrades Grafana in place (now `ALL` on the live cluster).
