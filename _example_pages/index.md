---
title: "Examples"
layout: plan
permalink: /examples/
description: "Every runnable example in this repo, mapped to the chapter it supports."
---

Every hands-on chapter ships a runnable example under
[`examples/`](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples),
a snapshot of the chart or workflow that chapter builds. Each one runs against
the project-local Helm 4 and a single minikube profile; the OpenShift Local
example runs on CRC.

| # | Example | What it shows | Chapter |
|---|---------|---------------|---------|
| 01 | [lab-setup](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/01-lab-setup) | Project-local Helm 4 toolchain and the minikube profile | [Ch1]({{ '/docs/01-prerequisites/' | relative_url }}) |
| 02 | [helm-tour](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/02-helm-tour) | A first install, upgrade, and rollback with Helm 4 | [Ch2]({{ '/docs/02-helm-4-tour/' | relative_url }}) |
| 03 | [raw-manifests](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/03-raw-manifests) | The pain a chart removes: three environments from raw YAML | [Ch3]({{ '/docs/03-shipping-service-raw-manifests/' | relative_url }}) |
| 04 | [first-chart](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/04-first-chart) | A first chart: Chart.yaml, templates, release revisions | [Ch4]({{ '/docs/04-first-chart/' | relative_url }}) |
| 05 | [values](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/05-values) | A designed values interface, schema, and per-environment overrides | [Ch5]({{ '/docs/05-values-and-overrides/' | relative_url }}) |
| 06 | [templates](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/06-templates) | Template built-ins, functions, and control flow | [Ch6]({{ '/docs/06-templates/' | relative_url }}) |
| 07 | [helpers-notes](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/07-helpers-notes) | `_helpers.tpl` names and labels, and NOTES.txt | [Ch7]({{ '/docs/07-helpers-and-notes/' | relative_url }}) |
| 08 | [config-secrets](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/08-config-secrets) | ConfigMaps, Secrets, and the sources that feed them | [Ch8]({{ '/docs/08-config-and-secrets/' | relative_url }}) |
| 09 | [postgres-subchart](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/09-postgres-subchart) | A parent chart, a subchart dependency, and the values between them | [Ch9]({{ '/docs/09-dependencies-postgres/' | relative_url }}) |
| 10 | [crds-operators](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/10-crds-operators) | Who owns the CRD, the custom resources, and the operator | [Ch10]({{ '/docs/10-crds-and-operators/' | relative_url }}) |
| 11 | [hooks-migrations](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/11-hooks-migrations) | Lifecycle hooks and a migration job | [Ch11]({{ '/docs/11-hooks-and-migrations/' | relative_url }}) |
| 12 | [release-lifecycle](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/12-release-lifecycle) | Install, upgrade, rollback, and the paths out of a failed upgrade | [Ch12]({{ '/docs/12-release-lifecycle/' | relative_url }}) |
| 13 | [debugging](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/13-debugging) | The debug ladder: template, lint, dry-run, and API-server checks | [Ch13]({{ '/docs/13-debugging-charts/' | relative_url }}) |
| 14 | [chart-testing](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/14-chart-testing) | The chart test pyramid and `helm test` | [Ch14]({{ '/docs/14-chart-testing/' | relative_url }}) |
| 15 | [kafka-notification](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/15-kafka-notification) | A dispatch event path and the Strimzi resources behind the topic | [Ch15]({{ '/docs/15-kafka-and-notification/' | relative_url }}) |
| 16 | [umbrella](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/16-umbrella) | An umbrella chart: aliases, switches, global and imported values | [Ch16]({{ '/docs/16-umbrella-charts/' | relative_url }}) |
| 17 | [library-chart](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/17-library-chart) | One library chart, many consumers | [Ch17]({{ '/docs/17-library-charts/' | relative_url }}) |
| 18 | [starters](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/18-starters) | Starters and golden-path scaffolding | [Ch18]({{ '/docs/18-starters-golden-paths/' | relative_url }}) |
| 19 | [packaging-repos](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/19-packaging-repos) | Packaging a chart, an index, and a served repository | [Ch19]({{ '/docs/19-packaging-and-repos/' | relative_url }}) |
| 20 | [oci](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/20-oci) | Pushing and pulling charts from an OCI registry | [Ch20]({{ '/docs/20-oci-registries/' | relative_url }}) |
| 21 | [signing](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/21-signing) | Helm provenance and cosign registry signing | [Ch21]({{ '/docs/21-provenance-and-signing/' | relative_url }}) |
| 22 | [plugins](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/22-plugins) | The Helm 4 plugin system, subprocess and Wasm runtimes | [Ch22]({{ '/docs/22-plugins/' | relative_url }}) |
| 23 | [post-renderers](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/23-post-renderers) | A post-renderer between render and apply | [Ch23]({{ '/docs/23-post-renderers/' | relative_url }}) |
| 24 | [environments](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/24-environments) | Build once, promote by edit across environments | [Ch24]({{ '/docs/24-environment-promotion/' | relative_url }}) |
| 25 | [gitops-argocd](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/25-gitops-argocd) | The Argo CD loop around a Helm chart | [Ch25]({{ '/docs/25-gitops-argocd/' | relative_url }}) |
| 26 | [observability](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/26-observability) | A dashboard ConfigMap and the LGTM stack from the chart | [Ch26]({{ '/docs/26-observability-lgtm/' | relative_url }}) |
| 27 | [openshift-crc](https://github.com/{{ site.github_username }}/{{ site.github_repo }}/tree/main/examples/27-openshift-crc) | The same chart on OpenShift Local (CRC), with a verify script | [Appendix]({{ '/docs/27-appendix-openshift-local/' | relative_url }}) |

## Build, run, observe

Each example is a self-contained snapshot. Set up the project-local Helm 4 and
the cluster, then install the chart and inspect the result:

```bash
source scripts/env.sh                 # project-local Helm 4 on PATH
cd examples/04-first-chart
helm install hfd . --namespace hfd --create-namespace --wait
helm test hfd --namespace hfd         # where the example ships tests
```

Each chapter's **Build, run, observe** section names the exact commands for that
example and what to look for. See [Prerequisites]({{ '/docs/01-prerequisites/' | relative_url }})
for the toolchain setup.
