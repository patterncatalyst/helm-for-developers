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

The pattern has four limits. `lookup` is empty under `helm template` and `--dry-run=client`, so an offline render of `generate: true` shows a different token each time (`demo.sh offline` asserts that). Argo CD renders with `helm template` and cannot run `lookup`, so a generated token would change on every sync (chapter 25). Deleting the Secret by hand loses the token; to protect it from `helm uninstall` add the `helm.sh/resource-policy: keep` annotation. And every value you pass, including `auth.token`, is stored in the release record: `helm get values shipping -n hfd-08` prints it. Use `token` for development only.

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

The first three leave Helm unchanged and rely on `existingSecret`, which is why the pattern is worth building into every chart. The SOPS route is a set of Helm plugins that decrypts on the client.

### SOPS and age with helm-secrets under Helm 4

`scripts/install-tools.sh` installs `sops` 3.13.3 and `age` 1.3.2 into `.tools/bin`, each checked against a pinned SHA-256. helm-secrets 4.x is distributed for Helm 4 as three plugins: `secrets` (the `helm secrets` command), `secrets-getter` (the `secrets://` protocol) and `secrets-post-renderer`. `./demo.sh sops` installs the first two from the project's OCI artifacts into `.tools/helm/plugins-secrets`, separate from the plugins the other chapters use:

```bash
[host]$ HELM_PLUGINS=$PWD/.tools/helm/plugins-secrets helm plugin install oci://ghcr.io/jkroepke/helm-secrets/secrets:4.7.9 --verify=false
[host]$ HELM_PLUGINS=$PWD/.tools/helm/plugins-secrets helm plugin install oci://ghcr.io/jkroepke/helm-secrets/secrets-getter:4.7.9 --verify=false
```

`--verify=false` is needed because Helm 4 verifies installs by default and the maintainer's key is not in the project keyring. Installing the repository URL as a Helm 3 plugin gives only the getter, with no `helm secrets` command. On Helm 4.3.0 the `.tgz` URL form wrote into the shared plugin directory and ignored `HELM_PLUGINS`, and the OCI form left download leftovers there, which the demo removes.

The demo generates a throwaway age key under `.work/`, which is gitignored, and a SOPS rule for files named `secrets.<env>.yaml`. It encrypts a values file whose only content is `auth.token: sops-dev-token`:

```text
auth:
    token: ENC[AES256_GCM,data:OoOWa/8hVaPaVBFnuqs=,iv:R7v/bKVNRqcunPUIs4IaH75dn5bbemZHZs4KfU7JxOA=,tag:m52YXaFUoQqw6QWV7ONIag==,type:str]
```

SOPS encrypts values and leaves keys readable, so the file diffs and reviews like any other values file. Helm reads it through the getter, which calls `sops` with the key from `SOPS_AGE_KEY_FILE`:

```bash
[host]$ helm upgrade --install shipping ./shipping-service -n hfd-08 --create-namespace --wait -f values-dev.yaml -f secrets://.work/secrets.dev.yaml
```

The `helm secrets` command from the CLI plugin takes the same arguments as the Helm command it wraps and accepts the encrypted file as a plain path, so `helm secrets template shipping ./shipping-service -f values-dev.yaml -f .work/secrets.dev.yaml` is the equivalent render. Both forms rendered `api-token` as the base64 of `sops-dev-token`. In the cluster, `kubectl -n hfd-08 get secret shipping-shipping-service -o jsonpath='{.data.api-token}' | base64 -d` printed `sops-dev-token`, a write with `Bearer sops-dev-token` returned 201, and the old `dev-token` returned 401, because `values-dev.yaml` is overridden by the later file.

Two negative controls failed as intended. With an age key that is not a recipient, `sops` printed `Failed to get the data key required to decrypt the SOPS file` and `helm` exited non-zero. Passing the encrypted file as a plain `-f` argument was rejected by the chart schema with `additional properties 'sops' not allowed`, so ciphertext never reaches a Secret.

The scope of the protection is the repository. Helm receives the decrypted value, so `helm get values shipping -n hfd-08` prints `token: sops-dev-token` and the release record holds it, exactly as with a plain values file. Use `existingSecret` with an operator-managed Secret when the value must stay out of the release record.

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

- Bilgin Ibryam and Roland Huß, *Kubernetes Patterns, 2nd ed.* (O'Reilly, 2023), ISBN 9781098131678. Used here for: the Configuration Resource and Immutable Configuration patterns.
- Helm project, "Chart Development Tips and Tricks" (automatic rollout on ConfigMap change), https://helm.sh/docs/howto/charts_tips_and_tricks/.
- Helm project, template function list (`lookup`, `dig`, `randAlphaNum`), https://helm.sh/docs/chart_template_guide/function_list/.

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/08-config-secrets.txt` and `_plans/evidence/08-config-secrets-sops.txt`. Observed on Helm 4.3.0: writes returned 401 without the token and 201 with it, a ConfigMap change replaced the pods, `auth.generate=true` kept the same token across an upgrade, `existingSecret` rendered no Secret and authenticated with its value, and `helm get values` printed the token. helm-secrets 4.7.9 with SOPS 3.13.3 and age 1.3.2 decrypted an encrypted values file through both `-f secrets://` and `helm secrets template`, the decrypted token reached the Secret in `hfd-08` and authenticated, a wrong age key failed, and `helm get values` printed the decrypted value (`_plans/evidence/08-config-secrets-sops.txt`).*
