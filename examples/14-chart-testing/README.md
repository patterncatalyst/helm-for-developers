# 14 Chart testing

Chapter: [`_docs/14-chart-testing.md`](../../_docs/14-chart-testing.md).

The shipping-service chart (version 0.14.0) with a `helm test` pod, six helm-unittest suites (30 tests, two snapshots), CI values for chart-testing, and a `ct.yaml`. The repository's CI workflow is `.github/workflows/charts-ci.yml`.

## Contents

| Path | What it is |
|---|---|
| `charts/shipping-service/templates/tests/test-connection.yaml` | The `helm.sh/hook: test` pod. |
| `charts/shipping-service/tests/` | helm-unittest suites and `__snapshot__/`. |
| `charts/shipping-service/ci/ci-values.yaml` | Values `ct` uses for lint and install (in-memory storage, dev token). |
| `charts/shipping-service/.helmignore` | Contains `/tests/`, anchored. See the chapter for the unanchored trap. |
| `ct.yaml` | chart-testing config; `ct` reads it from the current directory. |
| `demo.sh` | `offline`, no argument (offline then cluster), or `clean`. |

## Usage

```bash
./demo.sh offline    # lint --strict, unittest, kubeconform, ct lint, three planted failures
./demo.sh            # offline, then helm test and ct install (needs the helm4dev cluster)
./demo.sh clean      # uninstall and delete hfd-14
```

The offline planted failures: an unanchored `tests/` in `.helmignore`, a stale snapshot, and an unknown `Chart.yaml` key rejected by `ct lint`.

Run the pieces by hand:

```bash
helm unittest charts/shipping-service
helm unittest -u charts/shipping-service      # accept changed snapshots after review
ct lint --config ct.yaml --all
```

## Verification status

Partially verified on 2026-10-08 (Helm 4.3.0, ct 3.15.0, minikube `helm4dev`), evidence `_plans/evidence/14-chart-testing.txt`. The full demo exits 0: `helm test shipping -n hfd-14` reports `Phase: Succeeded`, an install with the unanchored `tests/` prints `TEST SUITE: None`, and `ct install --charts charts/shipping-service` installs, tests and removes its generated namespace. Not verified: the workflow `.github/workflows/charts-ci.yml` on GitHub Actions.
