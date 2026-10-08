---
title: "Configuration and secrets"
order: 8
part: "From manifests to a chart"
description: "Roll pods when a ConfigMap changes, supply API_TOKEN from values, an existing Secret or a generated one that survives upgrades, and compare the ways to keep secrets out of Git."
duration: 45 minutes
---

The ConfigMap from chapter 04 has a flaw that surfaces on the first upgrade: change `config.defaultCarrier`, run `helm upgrade`, and the ConfigMap updates while the running pods keep the old environment, because environment variables are read once at container start. This chapter fixes that with a checksum annotation, then adds the `API_TOKEN` Secret three ways: from values, from a Secret you manage, and generated once and preserved with `lookup`. It closes by comparing the tools that keep secrets out of Git.

The code is in `examples/08-config-secrets/`. `./demo.sh offline` asserts the Secret, checksum and `existingSecret` behavior without a cluster; `./demo.sh` installs the chart into `hfd-08` and drives the API with and without the token.

{% include excalidraw.html
   file="08-secrets-options"
   alt="Diagram: a chart-created Secret and an existingSecret reach the Deployment's API_TOKEN environment variable directly, while External Secrets Operator, Sealed Secrets and SOPS produce a Secret from outside the chart"
   caption="Figure 8.1 — Five sources for the Secret that feeds API_TOKEN" %}

## Rolling pods on config change

Kubernetes rolls a Deployment only when its pod template changes. A ConfigMap update changes no field of the Deployment, so nothing restarts. The standard Helm answer, from the [chart tips and tricks](https://helm.sh/docs/howto/charts_tips_and_tricks/#automatically-roll-deployments), is an annotation on the pod template that holds a hash of the ConfigMap's rendered text. When the ConfigMap content changes, the hash changes, the pod template changes, and the Deployment rolls.

## How the code works

**`templates/deployment.yaml`** gains one annotation line:

```yaml
{% raw %}      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}{% endraw %}
```

`$.Template.BasePath` is the templates directory of the chart being rendered, so `print` builds the path of the ConfigMap template. `include` with a path renders that template file as a string, using the current context, exactly as it would render for the cluster. `sha256sum` hashes the text. The hash is a pure function of the rendered ConfigMap: unchanged settings give the same annotation and no restart. Observed values from `helm template` with default values and with `--set config.logLevel=DEBUG`:

```text
checksum/config: 9fd402901344d195aefa9bac22ce75ac81fb4d5940868fa364ccdc03b1073889
checksum/config: 5f28424efd70185a2bff2fc561b9fde72173beb724fb816ffc5747da00f59b70
```

Rendering twice with the same values gives the same hash, which `demo.sh offline` asserts. The checksum covers only the ConfigMap. Hashing the Secret the same way would be a mistake when the token is generated, because rendering it calls `randAlphaNum` and the hash would differ on every render.

An alternative for the ConfigMap is `immutable: true` with a content hash in the object's name. Kubernetes then refuses in-place edits, and a changed hash creates a new ConfigMap that the Deployment references, which rolls the pods. The cost is orphaned old ConfigMaps. It suits configuration that must never change under a running pod, the Immutable Configuration pattern.

**`values.yaml`** adds the `auth` block:

```yaml
auth:
  token: ""
  generate: false
  existingSecret: ""
  existingSecretKey: api-token
```

With all three sources unset the API stays open for writes, which matches the service's default. The schema sets `additionalProperties: false` on `auth`, so a misspelled key fails.

**`templates/_helpers.tpl`** gets `shipping-service.tokenSecret`, which returns the name of the Secret to read, or an empty string. `existingSecret` wins; otherwise a `token` or `generate: true` means the chart creates a Secret named after `fullname`. The same helper decides two things: whether the Deployment renders `API_TOKEN` at all, and which Secret it references.

**`templates/deployment.yaml`** renders the variable only when the helper returns a name:

```yaml
{% raw %}            - name: API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: {{ include "shipping-service.tokenSecret" . }}
                  key: {{ ternary .Values.auth.existingSecretKey "api-token" (not (empty .Values.auth.existingSecret)) }}{% endraw %}
```

`valueFrom.secretKeyRef` keeps the token out of the pod spec and the ConfigMap. `ternary a b cond` returns `a` when the condition is true: an external Secret uses the configurable `existingSecretKey`, while the chart's own Secret always uses `api-token`. The environment variable name is `API_TOKEN`, which is what the service reads.

**`templates/secret.yaml`** is the longest template, and its logic reads top to bottom:

```yaml
{% raw %}{{- if and (not .Values.auth.existingSecret) (or .Values.auth.token .Values.auth.generate) }}
{{- $name := include "shipping-service.fullname" . -}}
{{- $token := .Values.auth.token -}}
{{- if not $token }}
{{- $current := dig "data" "api-token" "" (lookup "v1" "Secret" .Release.Namespace $name) -}}
{{- if $current }}
{{- $token = $current | b64dec }}
{{- else }}
{{- $token = randAlphaNum 32 }}
{{- end }}
{{- end }}{% endraw %}
```

The outer `if` creates nothing when you bring your own Secret or configure no token. A token set in values wins and skips the rest. With only `generate: true`, the template asks the cluster for the live Secret with `lookup`. `dig "data" "api-token" "" <map>` walks into the result and returns the empty string when any key is missing, which covers both a missing Secret (empty map) and a Secret without the key. If a value is found, `b64dec` turns it back into the token, so the Secret is rewritten with identical content on every upgrade. If not, `randAlphaNum 32` makes a new one: that happens only on first install. The Secret is emitted with `data:` and `b64enc` of the final value. A variable can be reassigned with `=` inside a nested block, which is what makes this pattern possible; `:=` would create a new inner variable that vanishes at `end`.

The fragile bits are real. `lookup` is empty under `helm template` and `--dry-run=client`, so an offline render of `generate: true` shows a different token each time (`demo.sh offline` asserts that). Argo CD renders with `helm template` and cannot run `lookup`, so a generated token would change on every sync (chapter 25). Deleting the Secret by hand loses the token; to protect it from `helm uninstall` add the `helm.sh/resource-policy: keep` annotation. And every value you pass, including `auth.token`, is stored in the release record: `helm get values shipping -n hfd-08` prints it. Use `token` for development only.

## Build, run, observe

```bash
cd examples/08-config-secrets && ./demo.sh
```

Offline, the script renders and checks four cases: no Secret by default, a Secret and `secretKeyRef` with `-f values-dev.yaml`, no Secret and a `my-token` reference with `--set auth.existingSecret=my-token`, and the checksum comparison. Observed output:

```text
checksum stable for equal input, changes with logLevel
offline render of generate=true differs per run (lookup needs a live cluster)
```

The live half drives the API. A write without the token returns 401; with `Authorization: Bearer dev-token` it returns the created shipment. Then it upgrades with a different carrier and lists the pods before and after, so you see them replaced, and upgrades twice with `auth.generate=true` to compare the stored token.

```bash
[host]$ curl -s -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:8080/api/shipments -H 'Content-Type: application/json' -d '{"orderId":1,"address":"1 Main St"}'
[host]$ helm upgrade shipping examples/08-config-secrets/shipping-service -n hfd-08 -f examples/08-config-secrets/values-dev.yaml --set config.defaultCarrier=Globex --wait
[host]$ kubectl -n hfd-08 get pods -l app.kubernetes.io/instance=shipping
```

## Comparing secret management approaches

Chart-created Secrets put the token in values and in the release record. That is acceptable for a lab and not for production. The options for production differ in where the plaintext lives:

| Approach | What is in Git | Where decryption happens | Helm interaction |
|---|---|---|---|
| `existingSecret` | Nothing | Secret created out of band | Chart references the name |
| [External Secrets Operator](https://external-secrets.io/latest/) | An `ExternalSecret` pointing at a vault | In the cluster, by the operator | Ship the `ExternalSecret` from the chart or beside it, and set `existingSecret` to its target |
| [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) | An encrypted `SealedSecret` | In the cluster, by the controller | Same: the controller produces a Secret the chart references |
| [SOPS with helm-secrets](https://github.com/jkroepke/helm-secrets) | Encrypted values files | On the client, before `helm` runs | A client-side plugin |

The first three leave Helm unchanged and rely on `existingSecret`, which is why the pattern is worth building into every chart. The SOPS route is a Helm plugin. The helm-secrets README states support for Helm 3.9 and later and does not mention Helm 4, so its behavior under Helm 4's plugin system is not verified in this book. Check the plugin's release notes before depending on it, and see chapter 22 for how Helm 4 loads plugins.

## Cross-check

Confirm that the Secret the chart built matches what the pod receives, without printing it into your shell history:

```bash
[host]$ kubectl -n hfd-08 get secret shipping-shipping-service -o jsonpath='{.data.api-token}' | base64 -d | wc -c
```

For `dev-token` the count is 9. Then compare `helm get manifest shipping -n hfd-08` with the live Secret: both hold the same base64 string. After an upgrade with `auth.generate=true`, the string must not change.

## What you learned

- A pod-template checksum annotation turns a ConfigMap change into a rollout; hash only the content that renders deterministically.
- `API_TOKEN` comes from values, an existing Secret or a generated one, chosen by one helper and referenced through `secretKeyRef`.
- `lookup` plus `dig` keeps a generated Secret stable across upgrades, and it is empty offline and under Argo CD.
- Anything passed through values lands in the release record; production secrets belong in an external store or an encrypted-in-Git workflow.

Chapter 09 adds the first dependency: a Postgres subchart, and the Secret wiring that goes with it.

## Further reading

- Bilgin Ibryam, Roland Huß, *Kubernetes Patterns* (O'Reilly, 2023), ISBN 9781098131678. Used here for: the Configuration Resource and Immutable Configuration patterns.
- Helm project, "Chart Development Tips and Tricks" (automatic rollout on ConfigMap change), https://helm.sh/docs/howto/charts_tips_and_tricks/.
- Helm project, template function list (`lookup`, `dig`, `randAlphaNum`), https://helm.sh/docs/chart_template_guide/function_list/.

---

*Verification status: <span class="status status--unverified">unverified</span>. A live run must confirm that a ConfigMap change replaces the pods, that writes return 401 without the token and succeed with it, that `auth.generate=true` keeps the same token across `helm upgrade`, and that `existingSecret` produces a working `secretKeyRef`.*
