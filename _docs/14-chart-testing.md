---
title: "Chart testing"
order: 14
part: "Debugging and testing"
description: "A test pod for helm test, helm-unittest suites with snapshots and failedTemplate, chart-testing lint and install, and a CI workflow that needs no cluster."
duration: 45 minutes
---

Chapter 13 found bugs by hand. This chapter makes the checks permanent: a test pod that `helm test` runs against a live release, unit tests that render templates and assert on the result in milliseconds, `ct` to lint every chart the same way, and a GitHub Actions workflow that runs all of it on each pull request without a cluster.

The code is in `examples/14-chart-testing/`. Run it with `cd examples/14-chart-testing && ./demo.sh offline`; the no-argument run adds `helm test` and `ct install` in namespace `hfd-14`.

{% include excalidraw.html
   file="14-test-pyramid"
   alt="Pyramid of chart tests from bottom to top: helm-unittest on every push, ct lint on every pull request, kubeconform on every pull request, and ct install with helm test as a manual or nightly job"
   caption="Figure 14.1 — The chart test pyramid: many fast tests below, few cluster tests on top" %}

## What each layer is for

Unit tests and linters are cheap and run everywhere. `helm test` and `ct install` need a cluster and a built image, so they sit on top and run less often. The chart carries the first three layers in its own directories: `tests/` for helm-unittest suites, `templates/tests/` for the test pod, and `ci/` for values files that `ct` iterates over. The [chart tests documentation](https://helm.sh/docs/topics/chart_tests/) defines the `helm test` contract, and the book chapter listed below covers chart testing as a concept; every command here is Helm 4.

## How the code works

### The test pod

`templates/tests/test-connection.yaml` is a Pod with the hook annotation `helm.sh/hook: test`. Helm renders it with the rest of the chart but does not create it on install; `helm test RELEASE` creates it, waits for it to finish, and reports the phase.

```yaml
metadata:
  name: {% raw %}{{ include "shipping-service.fullname" . }}{% endraw %}-test-connection
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
```

`before-hook-creation` removes a leftover pod from a previous run, and `hook-succeeded` cleans up on success while a failed pod stays for `kubectl logs`. The container runs the application image and probes the Service with Python's standard library:

```yaml
image: {% raw %}{{ default (include "shipping-service.image" .) .Values.tests.image | quote }}{% endraw %}
command:
  - python
  - -c
  - >-
    import urllib.request as u;
    u.urlopen("http://{% raw %}{{ include "shipping-service.fullname" . }}:{{ .Values.service.port }}{% endraw %}/healthz", timeout=10).read()
```

`urlopen` raises on a non-2xx status, so the pod exits non-zero when readiness fails. The probe uses the app image because a `ubi-minimal` image with `curl` runs as root, and the pod's `runAsNonRoot: true` makes the kubelet refuse it. The application image has a numeric `USER 1001`, which satisfies the check. The `tests.image` value overrides it.

### The `.helmignore` trap

The chart's `.helmignore` contains `/tests/`, with the leading slash. `.helmignore` follows gitignore-style rules, so an unanchored `tests/` matches a directory named `tests` at any depth, including `templates/tests/`. The unit-test directory should stay out of the packaged chart, but the test pod must stay in. The symptom of the wrong pattern is quiet: the chart installs fine and `helm test` prints `TEST SUITE: None`, because the pod template was never loaded. The demo reproduces the loader side of it, with no cluster:

```text
Error: could not find template templates/tests/test-connection.yaml in chart
```

Packaging the same chart with `helm package` leaves `templates/tests/` in the archive with `/tests/` and drops the root `tests/` directory, which is the intent.

### helm-unittest suites

A suite is a YAML file in `tests/` ending in `_test.yaml`. It names the templates it loads, then lists tests, each with an `it` description, optional `set` values and `asserts`. The example has six suites and 30 tests.

```yaml
- it: fails when kafka is enabled without a bootstrap address
  template: templates/deployment.yaml
  set:
    kafka.enabled: true
  asserts:
    - failedTemplate:
        errorPattern: kafka.bootstrap is required
```

`failedTemplate` asserts that rendering fails, and `errorPattern` is a regular expression on the message. It tests the `required` call in `_helpers.tpl` and the schema rules in `schema_test.yaml`, such as rejecting `config.storage: sqlite`. The release name inside unit tests is `RELEASE-NAME`, which is why `test_pod_test.yaml` matches `RELEASE-NAME-shipping-service:9090/healthz` and not `shipping-...`.

Other assertions in the suites are `equal` on a path, `isKind`, `hasDocuments` with `count: 0` to prove a Secret is not rendered, `notExists` to prove no `runAsUser` leaks in, `contains` for list entries and `matchRegex`.

### Snapshots

`matchSnapshot` stores the rendered document in `tests/__snapshot__/snapshot_test.yaml.snap` on the first run and compares against it afterwards. The ConfigMap snapshot is the example's contract for the env names the service reads. A snapshot is a change detector, not a correctness test: the ConfigMap labels include `helm.sh/chart: shipping-service-0.14.0`, so every chart version bump changes the snapshot. Review the diff, then accept it with `helm unittest -u`. The demo changes `defaultCarrier` in a temporary copy and shows the failure with its diff before updating.

### `ci/` values and `ct`

`ct` installs and tests a chart once per file matching `ci/*-values.yaml`. This chart has `ci/ci-values.yaml` with in-memory storage and a dev token, so it needs no database. `ct lint` does three things: validates `Chart.yaml` against a Yamale schema, runs `yamllint` with a lint config, and runs `helm lint` for each values file.

`ct` needs the schema and lint config files. Its help lists the lookup order: the current directory, `$HOME/.ct`, then `/etc/ct`. Without a hit it stops with `'chart_schema.yaml' neither specified nor found in default locations`. The lab keeps copies in `.tools/ct/`, so pass them explicitly. The example's `ct.yaml` does it (`ct` also reads a `ct.yaml` in the current directory):

```yaml
chart-dirs:
  - charts
chart-yaml-schema: ../../.tools/ct/chart_schema.yaml
lint-conf: ../../.tools/ct/lintconf.yaml
check-version-increment: false
validate-maintainers: false
```

`check-version-increment` compares against a target branch, and `validate-maintainers` looks up GitHub users, so both are off for the lab. Turn the first on in a real repository: it forces a version bump whenever a chart changes.

### The workflow

`.github/workflows/charts-ci.yml` runs on pull requests, pushes to `main` and `feature/**`, and manually. The `lint-test` job calls `scripts/install-tools.sh`, which downloads Helm 4.3.0, kubeconform 0.8.0 and `ct` 3.15.0 and verifies each against the upstream checksum file, then installs the helm-unittest 1.2.1 and helm-diff 3.15.15 plugins. A step asserts the pinned versions. The remaining steps loop over `charts/*/Chart.yaml`: `helm dependency build` bottom-up (the service charts first, then the umbrella, because the `.tgz` files are not committed), `helm lint --strict`, `helm unittest` for charts with a `tests/` directory, `kubeconform` with the CRDs-catalog, and `ct lint --config .github/ct.yaml --all`. Then every `examples/*/demo.sh offline` runs. None of it needs a cluster. `ct install` lives in a separate `ct-install` job that runs only on a manual dispatch with `run_ct_install` set, and it creates a kind cluster (kind v0.33.0, node image `kindest/node:v1.34.0`), builds the `shipping-service` image, loads it with `kind load docker-image` and runs `ct install` with the project-local Helm 4.3.0 first on `PATH`. It installs only `shipping-service`, with `ci/ci-values.yaml`: `notification-service` stays Live but never Ready without a Kafka broker, and `shipping-postgres`, `shipping-kafka` and `shipping-platform` need the CloudNativePG and Strimzi operators, which the job does not install. The whole run takes about three minutes.

## Build, run, observe

```bash
cd examples/14-chart-testing && ./demo.sh offline
```

Observed output from the unit tests and the planted failures:

```text
 PASS  shipping-service snapshots	charts/shipping-service/tests/snapshot_test.yaml
 PASS  shipping-service helm test pod	charts/shipping-service/tests/test_pod_test.yaml
Test Suites: 6 passed, 6 total
Tests:       30 passed, 30 total
Snapshot:    2 passed, 2 total
...
Error: could not find template templates/tests/test-connection.yaml in chart
...
Snapshot Summary: 1 snapshot failed in 1 test suite. Check changes and use `-u` to update snapshot.
...
	owner: Unexpected element
```

The last line comes from `ct lint` rejecting an unknown key in `Chart.yaml`. The full run then does the cluster half:

```bash
helm test shipping -n hfd-14 --timeout 3m
ct install --charts charts/shipping-service --helm-extra-args '--timeout 3m'
```

`ct install` has no context flag and runs `kubectl` itself, so the demo hands it a kubeconfig that contains only the `helm4dev` context (`KUBECONFIG` pointing at the output of `kubectl config view --minify --flatten --context helm4dev`) and adds `--kube-context helm4dev` to the Helm arguments. A different current context then cannot redirect the install.

## Cross-check

Three tools that share no code check the same render: `helm lint --strict` and `ct lint` (which runs `helm lint` for each `ci/*-values.yaml`) validate the chart, and kubeconform validates the five resources rendered from the CI values, test pod included. A manifest that passes the unit tests but fails kubeconform means an assertion is missing, so add one.

## What you learned

- Pods annotated `helm.sh/hook: test` run under `helm test`; an unanchored `tests/` in `.helmignore` removes them and produces `TEST SUITE: None`.
- helm-unittest asserts on rendered templates; `failedTemplate` covers `required` and schema failures, and snapshots detect drift at the cost of churn.
- `ct lint` needs its schema and lint config passed or found; `ci/*-values.yaml` drives both lint and install.
- Keep cluster-dependent tests, `ct install` among them, out of the default pull-request path.

Chapter 15 adds Kafka and a second service, and with them a second chart to test.

## Further reading

- Andrew Block and Austin Dewey, *Managing Kubernetes Resources Using Helm, 2nd ed.* (Packt, 2022), ISBN 9781803242897. Used here for: chart-testing concepts (what to test in a chart and at which layer).
- [Chart tests](https://helm.sh/docs/topics/chart_tests/) and [helm test](https://helm.sh/docs/helm/helm_test/) in the Helm docs.
- [helm-unittest](https://github.com/helm-unittest/helm-unittest) and [chart-testing](https://github.com/helm/chart-testing), including [ct lint](https://github.com/helm/chart-testing/blob/main/doc/ct_lint.md) and [ct install](https://github.com/helm/chart-testing/blob/main/doc/ct_install.md).

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/14-chart-testing.txt` and `_plans/evidence/14-chart-testing-ci.txt`. Observed on Helm 4.3.0 and ct 3.15.0 against minikube: `helm test` reported `Phase: Succeeded` for `shipping-shipping-service-test-connection`, a release upgraded with the unanchored `tests/` printed `TEST SUITE: None`, and `ct install` installed with `ci/ci-values.yaml`, ran the test pod and deleted its generated namespace. On GitHub Actions the `lint-test` job passed on the pull request for the initial build ([run 37827371593](https://github.com/patterncatalyst/helm-for-developers/actions/runs/37827371593)) and on `main` ([run 37827549730](https://github.com/patterncatalyst/helm-for-developers/actions/runs/37827549730)), and the manual `ct-install` job passed on kind ([run 37836421071](https://github.com/patterncatalyst/helm-for-developers/actions/runs/37836421071)): `helm test` reported `Phase: Succeeded` and ct printed `All charts installed successfully`. Re-run on r1.1 with published NodePorts (bound to 127.0.0.1) on 2026-10-08: `./demo.sh` exited 0 and `./demo.sh clean` removed the namespace; `helm test` and `ct install` both passed.*
