// deck.js - "Helm for Developers 201": testing, multi-service charts, distribution,
// plugins, delivery, OpenShift. Chapters 13 to 27. Red Hat house style, 16:9.
// Build: NODE_PATH=$(npm root -g) node deck.js
"use strict";

const H = require("./deck-helpers.js");
const {
  COLOR, FONT, W, PNG, ASSETS,
  newDeck, addFooter, addContentTitle, addBullets, addTwoColBullets,
  addStatusTable, addCaption, addCodeSlide, addDiagramSlide, addSectionDivider, addNotes, patchSlide,
} = H;

const OUT = "Helm-201-r1.0.pptx";
const REV = "r1.0";

const pres = newDeck();
pres.title = "Helm for Developers 201";
let pageNum = 0;

function S() { const s = patchSlide(pres.addSlide()); pageNum += 1; addFooter(s, pageNum); return s; }
function divider(code, title, subtitle, notes) {
  const s = patchSlide(pres.addSlide()); pageNum += 1; addSectionDivider(s, code, title, subtitle); addNotes(s, notes);
}

// Notes: "What it shows / What to show / Fallback".
function N(shows, demo, fallback) {
  return `What it shows: ${shows}\n\nWhat to show: ${demo}\n\nFallback: ${fallback}`;
}
// Code helper: a template literal whose lines start at column 0 so that
// check-helm-commands.sh sees every `helm ...` line exactly as shown.
function code(block) { return block.replace(/^\n/, "").replace(/\n$/, "").split("\n"); }

// Bold-lead bullets (bold subject, then text).
function leadBullets(slide, items, opts = {}) {
  const x = opts.x ?? 0.62, y = opts.y ?? 1.95, w = opts.w ?? 12.09, h = opts.h ?? 4.7;
  const fontSize = opts.fontSize ?? 20;
  const runs = [];
  items.forEach((b) => {
    const para = { fontFace: FONT.body, fontSize, bullet: { code: "25CF", indent: 24 }, paraSpaceBefore: 4, paraSpaceAfter: 13 };
    runs.push({ text: b.lead, options: { ...para, bold: true, color: COLOR.ink } });
    runs.push({ text: " — " + b.text, options: { fontFace: FONT.body, fontSize, color: COLOR.body, breakLine: true } });
  });
  slide.addText(runs, { x, y, w, h, valign: "top", margin: 0, lineSpacingMultiple: 1.12 });
}
function leadSlide(eyebrow, title, items, notes, opts) {
  const s = S(); addContentTitle(s, eyebrow, title); leadBullets(s, items, opts || {}); addNotes(s, notes); return s;
}
function codeSlide(eyebrow, title, lang, lines, caption, notes, opts) {
  const s = S(); addCodeSlide(s, eyebrow, title, lang, lines, caption, opts || {}); addNotes(s, notes); return s;
}
function diagramSlide(eyebrow, title, png, caption, notes) {
  const s = S(); addDiagramSlide(s, eyebrow, title, png, caption, { x: 0.62, y: 1.55, w: 12.09, h: 4.90 }); addNotes(s, notes); return s;
}
function tableSlide(eyebrow, title, rows, colW, notes, rowH, fs) {
  const s = S(); addContentTitle(s, eyebrow, title); addStatusTable(s, rows, { colW, rowH: rowH ?? 0.86, fs: fs ?? [17, 16, 15] }); addNotes(s, notes); return s;
}

// ===== 1 COVER ===============================================================
{
  const s = pres.addSlide(); pageNum += 1;
  s.background = { color: COLOR.white };
  try { s.addImage({ path: `${ASSETS}/cover-panel.png`, x: 0, y: 0, w: W, h: 7.5 }); } catch (e) {}
  s.addText("HELM FOR DEVELOPERS · 201", { x: 6.00, y: 1.98, w: 6.90, h: 0.34,
    fontFace: FONT.title, fontSize: 14, bold: true, color: COLOR.red, charSpacing: 5, align: "left", valign: "middle" });
  s.addText([{ text: "Helm for", options: { breakLine: true } },
             { text: "Developers 201" }], {
    x: 5.95, y: 2.42, w: 6.95, h: 2.00, fontFace: FONT.title, fontSize: 50, bold: true, color: COLOR.ink, align: "left", valign: "top" });
  s.addText("Testing, umbrella and library charts, OCI distribution, plugins, GitOps and OpenShift with Helm 4",
    { x: 6.00, y: 4.55, w: 6.70, h: 1.00, fontFace: FONT.body, fontSize: 18, italic: true, color: COLOR.caption, align: "left", valign: "top" });
  s.addText(REV, { x: 11.85, y: 5.85, w: 0.95, h: 0.30, fontFace: FONT.mono, fontSize: 11, color: COLOR.caption, align: "right", valign: "middle" });
  try { s.addImage({ path: `${ASSETS}/logo-candidate-2.png`, x: 11.10, y: 6.80, w: 1.55, h: 0.37 }); } catch (e) {}
  addNotes(s, N("The second of two decks for the Helm for Developers tutorial. The 101 covered charts, values, templates, hooks and safe releases with Helm 4. This deck covers chapters 13 to 27: testing, multi-service charts, distribution, plugins, delivery and OpenShift. Every example runs against Helm 4.3.0 on minikube profile helm4dev; the OpenShift section is the exception and is covered in that section.",
    "nothing live on the cover; have a terminal open in the repository root with `source scripts/env.sh` already run.",
    "none needed; the deck stands on its own and each section names its examples/NN directory."));
}

// ===== 2 AGENDA ==============================================================
{
  const s = S();
  addContentTitle(s, "201 · SESSION MAP", "Agenda");
  addTwoColBullets(s,
    ["Testing and debugging: the debug ladder, helm-unittest, chart-testing", "Multi-service applications: Strimzi, umbrella charts, library charts, starters", "Distribution: SemVer, OCI registries, provenance, cosign"],
    ["Extending Helm: plugin types, Wasm, post-renderer plugins", "Delivery: environments, Helmfile, Argo CD, observability", "OpenShift: SCCs, Routes and the console (Helm 101 is the prerequisite)"],
    { fontSize: 20 });
  addNotes(s, N("Six sections that follow the order a chart team meets the problems: prove the chart works, compose several charts into a platform, publish it, extend Helm where the chart cannot reach, deliver it across environments, and run it on OpenShift. Helm 101 is assumed: charts, values precedence, templates, hooks, --wait and --rollback-on-failure.",
    "the repository tree: `ls examples/` and `ls charts/`; the 201 uses examples/13 to 27.",
    "the tutorial site lists the same chapters in the same order."));
}

// ===== 3 RECAP ===============================================================
leadSlide("201 · RECAP", "Helm 101 recap",
  [{ lead: "Chart and release", text: "a chart is the package, a release is one install of it, stored as a Secret in the release namespace." },
   { lead: "Values", text: "chart defaults, then -f files in order, then --set, --set-json and --set-file; a values.schema.json rejects bad input before rendering." },
   { lead: "Templates", text: "Go templates plus Sprig; named templates in _helpers.tpl; include over template when the result is piped." },
   { lead: "Safe releases", text: "--wait with the kstatus watcher, --rollback-on-failure, server-side apply by default for new releases." }],
  N("The five ideas from the 101 that the 201 builds on. Nothing new here; it is a checkpoint so the audience can place themselves. Helm 4 renamed the rollback and replace flags; the 101 appendix has the Helm 3 to Helm 4 flag map.",
    "`helm history shipping -n hfd-12` from examples/12-release-lifecycle if a release is still installed.",
    "the 101 deck's closing slide carries the same four points."));

// ===== SECTION: TESTING AND DEBUGGING =======================================
divider("01", "Testing and Debugging", "Find chart faults before they reach a cluster.",
  N("Chapters 13 and 14. Most chart bugs are visible without a cluster: schema errors, template errors, invalid YAML, deprecated APIs, wrong field types. This section orders the checks from cheapest to most expensive and then turns them into tests and a CI pipeline.",
    "examples/13-debugging and examples/14-chart-testing.", "the chapters carry recorded output for every failure."));

diagramSlide("TESTING · DEBUGGING", "The debug ladder", "h201-debug-ladder",
  "Figure: seven checks, four without a cluster, three that need an API server.",
  N("Seven rungs from `helm lint --strict` to `helm get manifest`. Rungs one to four need no cluster; five to seven need an API server. The example plants five faults, one per early rung: a values schema violation, a nil pointer in a template, valid template with invalid YAML, a deprecated API that only --strict fails, and a string containerPort that only kubeconform rejects.",
    "`cd examples/13-debugging && ./demo.sh offline` and read the five fault blocks.",
    "the chapter 13 transcript shows the same five error messages."));

codeSlide("TESTING · DEBUGGING", "Diff and server dry-run", "bash · helm 4.3",
  code(`
# Rung 4: compare two chart directories locally (helm-diff plugin)
[host]$ helm diff local charts/shipping-service /tmp/changed
# Rung 5: resolve kinds and run lookup against the API server
[host]$ helm upgrade shipping charts/shipping-service -n hfd-13 \\
          --dry-run=server
# Rung 6: what an upgrade would change in the live release
[host]$ helm diff upgrade shipping charts/shipping-service -n hfd-13 \\
          --set replicaCount=2
# Rung 7: the stored manifest, fed back to the schema check
[host]$ helm get manifest shipping -n hfd-13 | kubeconform -strict -summary
`),
  "From examples/13-debugging. --dry-run=server resolves kinds and runs lookup; it does not schema-validate fields on 4.3.0.",
  N("The cluster-facing rungs. `--dry-run=server` connects to the API server, resolves every kind against it and runs `lookup`, which catches unknown kinds. On Helm 4.3.0 it does not schema-validate fields: a string containerPort, an unknown field, negative replicas and a Pod Security violation all pass. For field validation pipe `helm template` into `kubectl apply --server-side --dry-run=server -f -`, which rejects them. `helm diff` is a plugin that compares rendered output against another chart directory or the live release. `helm get manifest` closes the loop by feeding the stored manifest back into kubeconform.",
    "`cd examples/13-debugging && ./demo.sh` runs the cluster rungs in namespace hfd-13.",
    "the chapter 13 transcript for rungs five to seven."));

diagramSlide("TESTING · DEBUGGING", "Chart test pyramid", "h201-test-pyramid",
  "Figure: pure rendering tests at the base, cluster tests at the top.",
  N("Three layers. The base is many fast tests that only render: helm-unittest and lint. The middle validates rendered output against schemas and the API server. The top installs the chart into a real cluster and runs helm test. Each layer asserts something the layer below cannot see.",
    "`helm unittest charts/shipping-service` (30 tests across 6 suites in the reference chart) and then `helm test shipping -n hfd-14`.",
    "the chapter 14 transcript lists the passing suites."));

codeSlide("TESTING · DEBUGGING", "helm-unittest suites", "yaml · tests/",
  code(`
suite: shipping-service deployment
templates:
  - templates/deployment.yaml
tests:
  - it: renders a Deployment with the default image tag from appVersion
    asserts:
      - equal:
          path: spec.template.spec.containers[0].image
          value: shipping-service:0.1.0
  - it: fails when kafka is enabled without a bootstrap address
    set:
      kafka.enabled: true
    asserts:
      - failedTemplate:
          errorPattern: kafka.bootstrap is required
`),
  "Run helm unittest charts/shipping-service; helm unittest -u refreshes snapshot files.",
  N("A helm-unittest suite is YAML beside the chart. Each test renders templates with chosen values and asserts on the output. `failedTemplate` asserts that a `required` or `fail` call fires with the expected message, which tests the guard rails and not only the happy path. Snapshot tests store whole rendered documents; a change shows up as a failed snapshot until it is reviewed and refreshed with `-u`.",
    "`cd examples/14-chart-testing && ./demo.sh offline` for the pass run and the planted snapshot failure.",
    "chapter 14 shows 30 passing tests in 6 suites and the snapshot failure text."));

tableSlide("TESTING · DEBUGGING", "chart-testing and kubeconform",
  [{ code: "ct lint", name: "Chart metadata", purpose: "Chart.yaml schema, yamllint, and helm lint for every ci/*-values.yaml." },
   { code: "ct install", name: "Cluster test", purpose: "Installs into a generated namespace, runs helm test, cleans up." },
   { code: "ct.yaml", name: "Configuration", purpose: "chart-dirs, schema and lint config, version-increment check on or off." },
   { code: "ci/*-values.yaml", name: "Scenarios", purpose: "One values file per configuration worth testing; ct runs each." },
   { code: "kubeconform", name: "Schema check", purpose: "Validates rendered YAML against Kubernetes and CRD schemas, offline." }],
  [2.90, 2.40, 6.79],
  N("Two tools that sit between unit tests and a full install. chart-testing (ct) lints chart metadata and runs each ci/ values file through lint and install. kubeconform validates the rendered manifests against the schema of the Kubernetes version you pin, and against CRD schemas when given a catalog. Unknown Chart.yaml keys are rejected by ct lint, which the example plants as a failure.",
    "`cd examples/14-chart-testing && ./demo.sh offline`, then the no-argument run for `ct install`.",
    "chapter 14 cross-check section shows the expected output of each command."));

codeSlide("TESTING · DEBUGGING", "Chart CI pipeline", "bash · ci",
  code(`
# Stage 1: static checks, no cluster, every push
[host]$ helm lint --strict charts/shipping-service
[host]$ helm unittest charts/shipping-service
[host]$ helm template shipping charts/shipping-service \\
          -f charts/shipping-service/ci/ci-values.yaml \\
          | kubeconform -strict -summary
[host]$ ct lint --config ct.yaml --all
# Stage 2: install test on a throwaway cluster
[host]$ ct install --charts charts/shipping-service \\
          --helm-extra-args '--timeout 3m'
# Stage 3: publish on a version tag
[host]$ helm package charts/shipping-service --dependency-update -d dist
[host]$ helm push dist/shipping-service-1.0.0.tgz \\
          oci://registry.example.com/charts
`),
  "Run from examples/14-chart-testing. Three stages: static checks on every push, an install test, and publication on a tag.",
  N("The pipeline is the chapter 14 commands in order, with publication from chapter 20 appended. Stage one is cheap and runs on every push. Stage two needs a cluster, so it runs in a job that provisions one. Stage three runs only on a version tag. The same script runs locally, which is the point: the pipeline adds no check a developer cannot run.",
    "`cd examples/14-chart-testing && ./demo.sh` runs stages one and two against minikube.",
    "the pipeline slide itself; every command appears in chapters 14 and 20."));

// ===== SECTION: MULTI-SERVICE ===============================================
divider("02", "Multi-Service Applications", "Compose charts into a platform and share what they have in common.",
  N("Chapters 15 to 18. A notification service and a Kafka cluster join the shipping service, an umbrella chart composes them, a library chart removes the duplicated templates, and a starter turns the result into a golden path for new services.",
    "examples/15-kafka-notification, 16-umbrella, 17-library-chart, 18-starters.", "chapter transcripts for each example."));

codeSlide("MULTI-SERVICE", "Kafka via Strimzi", "yaml · shipping-kafka",
  code(`
# charts/shipping-kafka: the chart declares the Kafka custom resource
spec:
  kafka:
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
# values.yaml: the contract other charts import
exports:
  kafka:
    bootstrap: shipping-kafka-kafka-bootstrap:9092
`),
  "The operator runs the brokers; the chart owns the declaration and exports the bootstrap address.",
  N("An operator owns the brokers and the chart owns the declaration. Strimzi 0.51.0 is installed once per cluster in the strimzi namespace and watches every namespace. The shipping-kafka chart renders the Kafka, KafkaNodePool and KafkaTopic resources. Its `exports.kafka.bootstrap` value is static so that an umbrella can import it into the services that need a broker address.",
    "`cd examples/15-kafka-notification && ./demo.sh`, then `kubectl -n hfd-15 get kafka,kafkanodepool,kafkatopic`.",
    "chapter 15 transcript; the cross-check section shows the expected resources."));

diagramSlide("MULTI-SERVICE", "Umbrella topology", "h201-umbrella",
  "Figure: one umbrella release, four subcharts, two operators outside the release.",
  N("The shipping-platform umbrella declares four dependencies under aliases. Postgres and Kafka values flow into the services through import-values. The operators for Postgres and Kafka are installed once per cluster, outside the release. The umbrella sets the migration hook to post-install because the CloudNativePG Cluster and its credentials Secret are created in the same release, and a pre-install hook would run before they exist.",
    "`cd examples/16-umbrella && ./demo.sh`, then `helm list -n hfd-16`.",
    "chapter 16 shows the rendered release and the rollback-on-failure error text."));

codeSlide("MULTI-SERVICE", "Conditions, tags, alias", "yaml · Chart.yaml",
  code(`
dependencies:
  - name: shipping-service
    alias: shipping
    condition: shipping.enabled
  - name: notification-service
    alias: notification
    tags: [messaging]
  - name: shipping-postgres
    alias: db
    condition: db.enabled
  - name: shipping-kafka
    alias: kafka
    tags: [messaging]
`),
  "condition switches one subchart; a tag switches a group; alias renames it in values and in rendered names.",
  N("Three controls on a dependency. `condition` is a values path that enables or disables one subchart. `tags` group subcharts so one flag, `tags.messaging=false`, removes notification and Kafka together. `alias` lets the same chart appear under a different name in values. When a condition path exists in values it wins over tags. With tags off, also disable the subchart settings that point at Kafka, as `ci/ci-values.yaml` does.",
    "`helm template platform charts/shipping-platform --set tags.messaging=false` and count the Deployments.",
    "chapter 16 transcript shows both renders."));

leadSlide("MULTI-SERVICE", "Globals and import-values",
  [{ lead: "global", text: "one values subtree every subchart can read: environment, otlpEndpoint, imageRegistry." },
   { lead: "import-values", text: "copies a subchart's exports into the parent or a sibling's values at render time." },
   { lead: "Static exports", text: "an exports block is a constant, so it must match the Cluster name and Kafka clusterName it describes." },
   { lead: "Override trap", text: "a key the subchart defaults in its own values.yaml cannot be overridden by an import; leave it unset." }],
  N("Global values and imports are the two ways data crosses subchart boundaries. Globals flow downward from the umbrella. Imports flow from a subchart's exports to the parent. The trap is precedence: an imported value cannot replace a key the importing subchart already defaults, which is why postgres.host, postgres.existingSecret and kafka.bootstrap carry no default in the service charts.",
    "`helm template platform charts/shipping-platform | grep -n KAFKA_BOOTSTRAP` shows the imported address in the notification Deployment.",
    "chapter 16 section 'Two traps' shows the stale value that a default would leave behind."));

tableSlide("MULTI-SERVICE", "CRDs and operators",
  [{ code: "crds/ directory", name: "Chart-owned CRDs", purpose: "Applied on first install, skipped on upgrade, never deleted. Inspect with helm show crds." },
   { code: "templates/", name: "CRD as a template", purpose: "Upgraded with the release; uninstall deletes the CRD and every custom resource." },
   { code: "Operator chart", name: "Operator-owned CRDs", purpose: "The operator installs its CRDs; the application chart ships only custom resources." },
   { code: "fail guard", name: "Readable failure", purpose: "Template stops with a clear message when the required API is not served." }],
  [2.90, 2.60, 6.59],
  N("Four ways a chart relates to a CRD. The reference charts use the third and fourth: CloudNativePG and Strimzi own their CRDs, and the application charts ship Cluster and Kafka resources and refuse to render if the API is missing. A CRD placed in templates/ is deleted on uninstall together with every custom resource of that kind, which is rarely intended.",
    "`cd examples/10-crds-operators && ./demo.sh offline`; the cluster run prints the CRD's managed fields.",
    "chapter 10 transcript with the planted guard failure."));

codeSlide("MULTI-SERVICE", "Capabilities guards", "go template",
  code(`
{{- if and .Values.requireOperator
      (not (.Capabilities.APIVersions.Has "postgresql.cnpg.io/v1")) }}
{{- fail "shipping-postgres needs the CloudNativePG operator: ..." }}
{{- end }}

# templates/route.yaml renders only where the API exists
{{- if and .Values.route.enabled
      (.Capabilities.APIVersions.Has "route.openshift.io/v1") }}
...
{{- end }}

# Offline there is no cluster to ask: supply the API yourself
[host]$ helm template platform charts/shipping-platform -n hfd-ocp \\
          --api-versions route.openshift.io/v1
[host]$ helm template platform charts/shipping-platform -n hfd-ocp
`),
  "Has asks the cluster at install time; helm template needs --api-versions (examples/27-openshift-crc).",
  N("`.Capabilities.APIVersions.Has` reports which APIs the target cluster serves. The first guard turns a missing operator into a message that names the fix instead of an opaque apply error. The second makes a Route render only on OpenShift, so the same umbrella installs on minikube unchanged. Offline, `helm template` has no cluster, so `--api-versions` supplies the answer; without it the Route is absent, and the example asserts both outcomes.",
    "`cd examples/27-openshift-crc && ./demo.sh offline` shows the Route with and without the flag.",
    "chapters 10 and 27 carry both outputs."));

diagramSlide("MULTI-SERVICE", "Library charts", "h201-library-charts",
  "Figure: two service charts include templates from pc-lib; rendered output stays identical.",
  N("pc-lib is a chart with `type: library`. It holds the Deployment, Service, probe, security-context and OpenTelemetry templates as named templates. The service charts include them with a dict of arguments. The refactor reduced notification-service templates from 224 lines to 16 and shipping-service from 295 to 87, and a diff of `helm template` before and after confirms identical manifests. A library chart cannot be installed on its own.",
    "`cd examples/17-library-chart && ./demo.sh` prints the line counts and the identical-output check.",
    "chapter 17 transcript with the line counts."));

codeSlide("MULTI-SERVICE", "Starters and golden paths", "bash · helm create",
  code(`
# A starter is a chart directory; <CHARTNAME> becomes the new name
[host]$ helm create --starter pc-fastapi charts/inventory-service
[host]$ helm dependency build charts/inventory-service
[host]$ helm lint --strict charts/inventory-service
[host]$ helm template inventory charts/inventory-service \\
          | kubeconform -strict -summary
[host]$ helm upgrade --install inventory charts/inventory-service \\
          -n hfd-18 --create-namespace
[host]$ helm test inventory -n hfd-18
# Starters live in HELM_DATA_HOME/starters or at an absolute path
`),
  "Run from examples/18-starters. The starter is the first commit; the library, schema and ci/ values carry the guardrails.",
  N("A golden path is the supported route to a working service. The starter supplies the first commit, pc-lib supplies behavior, and the schema and ci/ values supply the guardrails. `helm create --starter` copies the starter and replaces `<CHARTNAME>`; it also rewrites Chart.yaml, so the pc-lib dependency ships as a snippet to append. Version the starter and record which version a service was built from, and measure the path by how many teams stay on it.",
    "`cd examples/18-starters && ./demo.sh`; it generates a service and runs it through lint, kubeconform, install and helm test.",
    "chapter 18 transcript."));

// ===== SECTION: DISTRIBUTION ================================================
divider("03", "Distribution", "Version, publish, verify and sign charts.",
  N("Chapters 19 to 21. Chart versions have rules, repositories come in two forms, OCI registries are the current default, and there are two independent signature mechanisms.",
    "examples/19-packaging-repos, 20-oci, 21-signing.", "chapter transcripts."));

codeSlide("DISTRIBUTION", "SemVer versus appVersion", "yaml · Chart.yaml",
  code(`
version: 1.0.0        # the chart: templates, values keys, dependencies
appVersion: "0.1.0"   # the application the chart deploys; default image tag

# CI stamps both without editing the file
[host]$ helm package charts/shipping-service \\
          --version 1.0.1 --app-version 0.1.1 -d .work/repo
# Pre-releases are valid SemVer and hidden from search until --devel
[host]$ helm package charts/shipping-service --version 1.1.0-rc.1 -d .work/repo
[host]$ helm search repo hfd-local --devel
`),
  "Bump major for a removed or changed values key, minor for additions, patch for fixes.",
  N("Two numbers that move independently. `version` is SemVer for the chart: major when a values key a consumer sets disappears or changes meaning, minor for an added template or optional value, patch for a fix. `appVersion` describes the software inside and is the default image tag. Helm's version parser is lenient and accepts 1.0 or v1.0.2; use three-part numbers without a v so ordering, ranges and tooling behave.",
    "`cd examples/19-packaging-repos && ./demo.sh`.",
    "chapter 19 shows the packaged chart rendering image shipping-service:0.1.1."));

tableSlide("DISTRIBUTION", "Repos versus OCI",
  [{ code: "Classic repo", name: "index.yaml over HTTP", purpose: "helm repo add, update, search repo; helm repo index builds the index; any static host works." },
   { code: "OCI registry", name: "Charts as artifacts", purpose: "helm push and pull oci://; no helm repo add and no index.yaml; tags carry the version." },
   { code: "Search", name: "Discovery", purpose: "helm search repo works on classic repos only; registries are browsed with their own tooling." },
   { code: "Digests", name: "Immutability", purpose: "OCI installs accept @sha256:<digest>; a tag can move, a digest cannot." },
   { code: "Auth", name: "Credentials", purpose: "helm registry login for OCI; repo credentials flags for classic repos." }],
  [2.40, 2.90, 6.79],
  N("Classic repositories are an index.yaml plus tarballs served over HTTP, built with `helm repo index`. OCI registries store the chart as an artifact, so push, pull and install use oci:// references and the tag is the version. OCI adds digest pinning, which is why the promotion workflow later in this deck records digests. The Helm 4 OCI behavior, including install by digest and changes to `helm registry`, is documented on helm.sh/docs.",
    "`cd examples/19-packaging-repos && ./demo.sh` for a classic repo, then `cd ../20-oci && ./demo.sh`.",
    "chapters 19 and 20 transcripts."));

diagramSlide("DISTRIBUTION", "Push and pull with OCI", "h201-oci-flow",
  "Figure: package, push, optionally sign, then pull or install by tag or digest.",
  N("The OCI flow end to end. `helm package` builds the tarball, `helm push` sends it to oci://host/charts, and the registry stores the chart under its version tag. Signatures live beside it as separate artifacts. Installs accept a tag or a manifest digest. A local registry on plain HTTP needs `--plain-http`, which the example uses with a registry container on 127.0.0.1:5001.",
    "`cd examples/20-oci && ./demo.sh` and `curl -s http://127.0.0.1:5001/v2/charts/shipping-service/tags/list`.",
    "chapter 20 transcript; it shows the HTTP-to-HTTPS error that --plain-http removes."));

codeSlide("DISTRIBUTION", "Provenance files", "bash · helm package --sign",
  code(`
# Sign at package time; the key must come from a secret keyring file
[host]$ helm package charts/shipping-service --dependency-update --sign \\
          --key "HFD Throwaway Signer" --keyring .work/keys/secring.gpg \\
          -d .work/signed
# Verify the tarball against its .prov file
[host]$ helm verify .work/signed/shipping-service-1.0.0.tgz
# Verify while pulling from an OCI registry
[host]$ helm pull oci://127.0.0.1:5001/signed/shipping-service \\
          --version 1.0.0 --plain-http --verify -d .work/pull
`),
  "From examples/21-signing. A .prov file holds a PGP signature over the chart's hash; tampering fails verification.",
  N("Helm's native provenance is a PGP signature. `helm package --sign` writes a .prov file next to the tarball containing the chart metadata and its sha256, signed with the key. `helm verify` recomputes the hash and checks the signature. In the example a modified tarball fails with a sha256 mismatch. Keys here are throwaway keys in a project-local GNUPGHOME; production keys belong in a managed keyring or hardware token.",
    "`cd examples/21-signing && ./demo.sh`, which also shows the tamper failure.",
    "chapter 21 transcript with the 'Chart Hash Verified' output and the mismatch error."));

codeSlide("DISTRIBUTION", "Cosign for OCI charts", "bash · cosign",
  code(`
# A second mechanism: sign the OCI manifest digest, not the tarball
[host]$ cosign sign --key .work/cosign/cosign.key --yes --allow-http-registry \\
          --use-signing-config=false --tlog-upload=false \\
          127.0.0.1:5001/signed/shipping-service@sha256:<digest>
[host]$ cosign verify --key .work/cosign/cosign.pub --allow-http-registry \\
          --insecure-ignore-tlog \\
          127.0.0.1:5001/signed/shipping-service@sha256:<digest>
# Keyless signing and the transparency log are the default in production:
# omit --key, --use-signing-config=false and --tlog-upload=false
`),
  "The flags that disable the transparency log exist for a local HTTP registry only.",
  N("Two signatures cover two things. The .prov file covers the chart tarball as a PGP signature that Helm verifies. cosign signs the OCI manifest digest in the registry, so it covers whatever the registry serves under that digest. They are independent and can be used together. cosign 3.1.3 needs extra flags for an HTTP registry and no transparency log; those flags are scaffolding for the local example and are dropped in a real registry with keyless signing.",
    "`cd examples/21-signing && ./demo.sh`; the last block runs cosign sign and verify, then the missing-signature failure.",
    "chapter 21 transcript with the 'no signatures found' error."));

// ===== SECTION: EXTENDING HELM ==============================================
divider("04", "Extending Helm", "Plugins in Helm 4: types, runtimes and post-renderers.",
  N("Chapters 22 and 23. Helm 4 redesigned the plugin system around typed plugins and a sandboxed Wasm runtime, and made post-renderers plugins. Both are Helm-4-changed topics; the authoritative sources are helm.sh/docs and HIP-0026.",
    "examples/22-plugins and 23-post-renderers.", "chapter transcripts; the plugins directory holds the sources."));

tableSlide("EXTENDING HELM", "Helm 4 plugin types",
  [{ code: "cli/v1", name: "Command plugin", purpose: "Adds a subcommand: helm shipping-env, helm wasm-hello." },
   { code: "getter/v1", name: "Download plugin", purpose: "Fetches charts from a new kind of location." },
   { code: "postrenderer/v1", name: "Post-renderer", purpose: "Rewrites rendered manifests; selected with --post-renderer NAME." },
   { code: "subprocess", name: "Runtime", purpose: "Helm runs runtimeConfig.platformCommand with the user's permissions." },
   { code: "extism/v1", name: "Runtime", purpose: "Helm runs plugin.wasm in a sandbox with memory and time limits." }],
  [2.90, 2.40, 6.79],
  N("A plugin has a type, which says what Helm uses it for, and a runtime, which says how Helm runs it. The plugin.yaml uses apiVersion v1. `helm plugin install` verifies provenance by default; installing from a git URL needs `--verify=false`, and installing from a local directory is a development install. Design reference: HIP-0026 and the plugins overview on helm.sh/docs.",
    "`cd examples/22-plugins && ./demo.sh`; it runs `helm plugin list` showing TYPE and APIVERSION columns.",
    "chapter 22 transcript."));

codeSlide("EXTENDING HELM", "Wasm plugin manifest", "yaml · plugin.yaml",
  code(`
apiVersion: v1
type: cli/v1
name: wasm-hello
version: 0.1.0
runtime: extism/v1
runtimeConfig:
  memory:
    maxPages: 256
  timeout: 5000
`),
  "The runtime field selects the sandbox; memory and time limits live in the plugin's own configuration.",
  N("The Wasm runtime is the reason for the redesign. The module is sandboxed, with memory and time limits set in the plugin's own configuration, so it holds fewer permissions than a subprocess plugin. `runtime: extism/v1` tells Helm to load plugin.wasm into the Extism runtime instead of running a platform command.",
    "`cd examples/22-plugins && ./demo.sh` runs `helm wasm-hello Helm4`; the committed plugin.wasm means no Go toolchain is needed.",
    "chapter 22 transcript with the greeting output."));

codeSlide("EXTENDING HELM", "Wasm plugin entry point", "go and bash",
  code(`
// main.go: the exported entry point
//go:wasmexport helm_plugin_main
func helmPluginMain() uint32 { ...; return 0 }

# build the module Helm loads as plugin.wasm
[host]$ GOOS=wasip1 GOARCH=wasm go build \\
          -buildmode=c-shared -o plugin.wasm .

# run it: helm wasm-hello Helm4
`),
  "Output: Hello, Helm4! (from a Wasm Helm plugin). The module runs inside Helm's Extism runtime.",
  N("The entry point is the exported `helm_plugin_main`; input and output are JSON through the Extism PDK, and the plugin returns an empty JSON object on success. The example builds with Go targeting wasip1 and the resulting plugin.wasm sits beside plugin.yaml.",
    "`cd examples/22-plugins && ./demo.sh` prints the greeting.",
    "chapter 22 transcript with the greeting output."));

diagramSlide("EXTENDING HELM", "Post-renderer plugins", "h201-post-renderer",
  "Figure: rendered YAML goes to a plugin on stdin and comes back modified on stdout.",
  N("A post-renderer receives the rendered manifests on stdin and writes the modified manifests to stdout before Helm applies them. In Helm 4 a post-renderer is a plugin of type postrenderer/v1, selected by name; a path to an executable is rejected. The example plugin runs kustomize to add a label to every object and an annotation to Deployments. Use one when you need a change the chart's templates do not expose and you do not own the chart.",
    "`cd examples/23-post-renderers && ./demo.sh`; it runs `helm template ... --post-renderer kustomize-postrender`.",
    "chapter 23 transcript with the labeled output and the path-rejection error."));

// ===== SECTION: DELIVERY ====================================================
divider("05", "Delivery", "Promote across environments, drive releases from Git, and observe them.",
  N("Chapters 24 to 26. Environments are values layers plus pins, Helmfile is optional glue, Argo CD changes who runs the release, and the library chart carries telemetry configuration to every service.",
    "examples/24-environments, 25-gitops-argocd, 26-observability.", "chapter transcripts."));

diagramSlide("DELIVERY", "Environment promotion", "h201-env-promotion",
  "Figure: one chart build, three environments, each a values layer plus a pins file.",
  N("An environment is a set of values files, not a copy of the chart. The base values.yaml is shared; values-dev, values-stage and values-prod hold the differences; a pins file per environment records the chart version and image tag or digest. Promotion is a reviewed change to the next environment's pins file. The same chart build moves through every environment.",
    "`cd examples/24-environments && ./demo.sh offline` renders all three environments; `./demo.sh` installs one.",
    "chapter 24 transcript with the rendered diffs between environments."));

codeSlide("DELIVERY", "Helmfile, optional", "yaml · helmfile.yaml",
  code(`
helmDefaults:
  wait: true
  timeout: 600
  createNamespace: true
  rollbackOnFailure: true      # Helm 4 flag
releases:
  - name: platform
    namespace: hfd-24-prod
    chart: ./charts/shipping-platform
    version: 1.0.0             # the chart pin: one reviewed line per environment
    labels:
      env: prod
    values:
      - charts/shipping-platform/values-prod.yaml
      - pins/prod.yaml
`),
  "helmfile -l env=prod template --skip-deps renders one environment; Helmfile adds no new Helm flags.",
  N("Helmfile declares the releases for every environment in one file. Its `rollbackOnFailure` maps to Helm 4's `--rollback-on-failure`, and Helmfile refuses it on Helm 3. It is optional: the same promotion works with plain helm commands and a script. The `version:` line is enforced only for charts from a repository or OCI registry; for a local path it is documentation.",
    "`cd examples/24-environments && ./demo.sh offline`, which also runs `helmfile -l env=prod template --skip-deps`.",
    "the equivalent `helm template platform charts/shipping-platform -f values-prod.yaml -f pins/prod.yaml` from chapter 24."));

diagramSlide("DELIVERY", "GitOps with Argo CD", "h201-gitops",
  "Figure: Argo CD renders the chart with helm template and applies the result itself.",
  N("Argo CD does not run `helm install`. Its repo server renders the chart with `helm template` and its controller applies and reconciles the output. The consequences: no release Secret, so `helm list` shows nothing; Helm hooks are mapped to Argo sync phases; and `--wait` has no counterpart, so health comes from Argo's own checks. The Application points at the chart, a version and a valuesObject. Argo CD is installed from its Helm chart with Dex and notifications disabled for the demo.",
    "`cd examples/25-gitops-argocd && ./demo.sh offline`; the cluster run installs Argo CD in namespace argocd and syncs the chart from the registry addon.",
    "chapter 25 transcript with the sync status."));

tableSlide("DELIVERY", "Hooks versus sync waves",
  [{ code: "post-install hook", name: "PostSync phase", purpose: "The migration Job runs after every non-hook resource is Healthy." },
   { code: "hook-weight", name: "sync-wave on hooks", purpose: "helm.sh/hook-weight becomes argocd.argoproj.io/sync-wave; lower runs first." },
   { code: "no weight", name: "Wave 0 default", purpose: "Regular resources carry wave 0; annotate them to order them." },
   { code: "Scope", name: "Weights versus waves", purpose: "Hook weights order hooks within one phase; waves order everything across the sync." },
   { code: "--wait", name: "No equivalent", purpose: "Readiness probes decide Healthy; the PostSync hook waits on them." }],
  [2.70, 2.60, 6.79],
  N("How Helm's ordering maps onto Argo CD. The umbrella's migration Job is post-install and post-upgrade, which Argo treats as PostSync: it runs after every regular resource is Healthy, so the shipping pods must become Ready first. That is the same ordering `--wait` enforced under Helm. Within a phase, order comes from weights and waves; the two mechanisms look alike but differ in scope.",
    "`cd examples/25-gitops-argocd && ./demo.sh` and `kubectl -n hfd-25 get deploy,job,svc`.",
    "chapter 25 section 'Sync waves and hook weights'."));

codeSlide("DELIVERY", "Observability via pc-lib", "go template · _otel.tpl",
  code(`
{{- define "pc-lib.otelEnv" -}}
{{- $global := default (dict) .Values.global -}}
{{- $endpoint := default (default "" $global.otlpEndpoint) .Values.otel.endpoint -}}
- name: OTEL_SDK_DISABLED
  value: {{ if $endpoint }}"false"{{ else }}"true"{{ end }}
{{- if $endpoint }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ $endpoint | quote }}
{{- end }}
# umbrella values.yaml
global:
  otlpEndpoint: http://otel-collector.observability.svc.cluster.local:4318
`),
  "One endpoint on the umbrella; an empty endpoint disables the SDK so the chart runs without a collector.",
  N("The library chart turns telemetry configuration into one helper. Every service includes `pc-lib.otelEnv`, which reads `global.otlpEndpoint` and renders the OTEL_* environment variables, including service name and resource attributes. An empty endpoint renders OTEL_SDK_DISABLED=true, so the same chart works with no collector. The umbrella also ships the Grafana dashboard as a ConfigMap that the Grafana sidecar loads.",
    "`cd examples/26-observability && ./demo.sh offline`, then `kubectl -n hfd-26 exec deploy/platform-shipping -- env`.",
    "chapter 26 transcript with the rendered env block."));

diagramSlide("DELIVERY", "Telemetry path to LGTM", "h201-telemetry-path",
  "Figure: services export OTLP to the collector; Tempo, Loki and Mimir feed Grafana.",
  N("The path a request's telemetry takes. Both services export OTLP to the OpenTelemetry Collector in the observability namespace, which fans out traces to Tempo, logs to Loki and metrics to Mimir. Grafana reads all three and loads the chart's dashboard from a labeled ConfigMap. A trace crosses Kafka: the dispatch span in shipping links to the consume span in notification. A TraceQL query on `resource.service.name = \"platform-shipping\"` finds it.",
    "Grafana at 127.0.0.1:3000 after `scripts/tunnel.sh`; run the TraceQL query from chapter 26 and open the dispatch trace.",
    "chapter 26 transcript lists the spans of one dispatch trace."));

// ===== SECTION: OPENSHIFT ===================================================
divider("06", "OpenShift", "Run the same umbrella chart on OpenShift Local.",
  N("Chapter 27. The same umbrella chart installs on OpenShift Local (CRC) with an override values file. The appendix was verified on OpenShift Local 2.64.0 (OpenShift 4.22.14) on 2026-10-08: the full profile with CloudNativePG and either Strimzi 1.2.0 or Streams for Apache Kafka 3.2.1 from OperatorHub, and the minimal profile, all passing verify-crc.sh. The two Kafka operators own the same CRDs, so a cluster runs one of them. The Developer console Helm view was set up against the published repository; the console's own catalog listing was not opened.",
    "`cd examples/27-openshift-crc && ./demo.sh offline` anywhere; `PROFILE=full ./verify-crc.sh` on a CRC host.",
    "the offline render plus the chapter text; the verify-crc.sh PASS lines from the 2026-10-08 CRC run in the chapter."));

leadSlide("OPENSHIFT", "SCCs and arbitrary UIDs",
  [{ lead: "restricted-v2", text: "the default Security Context Constraint assigns each pod a UID from the project's range and sets the group to 0." },
   { lead: "runAsUser fails", text: "a manifest that asks for a specific UID, such as 1001, is rejected at admission." },
   { lead: "pc-lib avoids it", text: "renders runAsNonRoot, no privilege escalation, dropped capabilities and RuntimeDefault seccomp, and never emits runAsUser or fsGroup." },
   { lead: "Group-0 files", text: "the image makes its files group-0 readable, so the assigned UID, near 1000650000, still runs the container." }],
  N("The one place a chart written for minikube can fail on OpenShift without a template error. The reference charts avoid it by construction: no runAsUser, no fsGroup. The Containerfile's USER 1001:0 is only a default, replaced by the project's assigned UID. On CRC every pod, the operator-managed ones included, carried `openshift.io/scc: restricted-v2`, and `id` inside the services showed uid=1000650000 gid=0, not 1001; the root filesystem stayed read-only and the app ran. verify-crc.sh checks both.",
    "`./verify-crc.sh` on a CRC host prints PASS or FAIL for the SCC annotation and the UID check; `oc exec deploy/platform-shipping -- id` shows it directly.",
    "the rendered Deployment from `helm template` shows no runAsUser; the `id` output from the CRC run in the chapter."));

codeSlide("OPENSHIFT", "OpenShift overrides", "bash and yaml · helm",
  code(`
# Same chart as minikube, with the OpenShift overrides
[crc-host]$ helm upgrade --install platform charts/shipping-platform -n hfd-ocp \\
          -f values-openshift.yaml -f values-openshift-minimal.yaml \\
          --wait --rollback-on-failure
# values-openshift.yaml
global:
  environment: openshift
  imageRegistry: image-registry.openshift-image-registry.svc:5000/hfd-ocp
shipping:
  service:
    type: ClusterIP
`),
  "From examples/27-openshift-crc. Routes replace NodePorts; images come from the internal registry.",
  N("The OpenShift overrides switch Services to ClusterIP, point images at the internal registry and enable the Route template gated on `route.openshift.io/v1`. A Route is OpenShift's native entry point, served by the cluster router with edge TLS termination and a redirect from HTTP. On OpenShift Local 2.64.0 (OpenShift 4.22.14) the Route host was generated as platform-shipping-hfd-ocp.apps-crc.testing, `/api/info` returned 200 and plain HTTP redirected with 302.",
    "`cd examples/27-openshift-crc && ./demo.sh offline` for the Route render; on CRC, `./verify-crc.sh`.",
    "the offline render; the OpenShift Container Platform documentation for Routes."));

codeSlide("OPENSHIFT", "Console chart repository", "yaml · console",
  code(`
# Developer console: expose a chart repository to one project
apiVersion: helm.openshift.io/v1beta1
kind: ProjectHelmChartRepository
metadata:
  name: hfd-charts
  namespace: hfd-ocp
spec:
  connectionConfig:
    url: https://patterncatalyst.github.io/helm-for-developers/charts
`),
  "The console installs charts from a repository registered per project; the URL is this site's published chart repository, a classic index.yaml plus packaged archives.",
  N("A `ProjectHelmChartRepository` makes a chart repository visible in the Developer console's Helm catalog for one project. On OpenShift Local 2.64.0 the resource was accepted with the published URL, the console pod read the index (HTTP 200) and `helm search repo` listed all six charts. The console's catalog listing needs a browser login and was not opened.",
    "`oc get projecthelmchartrepository -n hfd-ocp` on a CRC host; open Developer, Helm, Create to see the catalog.",
    "the YAML on this slide and the chapter 27 section on the Developer console."));

// ===== TAKEAWAYS =============================================================
leadSlide("201 · SUMMARY", "Takeaways",
  [{ lead: "Test in layers", text: "lint and unit tests on every push, kubeconform and server dry-run next, ct install on a real cluster last." },
   { lead: "Compose with intent", text: "an umbrella for the platform, a library chart for shared templates, a starter for the golden path." },
   { lead: "Ship by digest", text: "OCI registries, SemVer with appVersion kept separate, .prov or cosign signatures." },
   { lead: "Extend through plugins", text: "typed plugins and Wasm in Helm 4; post-renderers are plugins only." },
   { lead: "Choose who runs the release", text: "helm directly, Helmfile, or Argo CD, each with different hook and wait semantics." }],
  N("Five points. If the audience keeps one: every check in this deck can run from the command line before CI, and every release step has a Helm-native form even when a GitOps tool drives it. Next steps are the chapter exercises, the cheat sheet that follows, and the reading list.",
    "return to the tutorial site's chapter list.", "the cheat sheet slide."), { fontSize: 18 });

// ===== APPENDIX: CHEAT SHEET ================================================
tableSlide("APPENDIX · REFERENCE", "Cheat sheet",
  [{ code: "helm lint --strict", name: "Static check", purpose: "Schema, YAML and deprecated-API failures without a cluster." },
   { code: "helm unittest CHART", name: "Unit tests", purpose: "Render-only tests; -u refreshes snapshots." },
   { code: "helm diff upgrade", name: "Change preview", purpose: "Compare a pending upgrade with the live release." },
   { code: "helm package --sign", name: "Package and sign", purpose: "Writes the .tgz and a .prov file; helm verify checks it." },
   { code: "helm push / pull", name: "OCI transport", purpose: "oci:// references; add --plain-http for a local HTTP registry." },
   { code: "helm plugin install", name: "Plugins", purpose: "Verifies provenance by default; helm plugin list shows TYPE." },
   { code: "--post-renderer NAME", name: "Post-render", purpose: "Names a postrenderer/v1 plugin; arguments via --post-renderer-args." },
   { code: "--api-versions", name: "Offline capabilities", purpose: "Supplies APIs to helm template, for example route.openshift.io/v1." }],
  [3.30, 2.30, 6.49],
  N("A reference page to keep open in another window. It lists the commands that matter most from chapters 13 to 27; the full cheat sheet is chapter 29 on the tutorial site, including the Helm 3 to Helm 4 flag map in chapter 28.",
    "`helm <command> --help` from .tools/bin after `source scripts/env.sh` for any flag in doubt.",
    "chapter 29."), 0.56, [15, 14, 14]);

// ===== APPENDIX: READING LIST ===============================================
{
  const s = S();
  addContentTitle(s, "APPENDIX · REFERENCE", "Reading list");
  addTwoColBullets(s,
    [{ text: "Books", options: { bullet: false, bold: true } },
     "Butcher, Farina, Dolitsky, Learning Helm (O'Reilly, 2021)",
     "Block, Dewey, Managing Kubernetes Resources Using Helm (Packt, 2022)",
     "Ibryam, Huss, Kubernetes Patterns (O'Reilly, 2023)",
     "Burns et al., Kubernetes: Up and Running (O'Reilly, 2022)",
     "Muschko, Certified Kubernetes Application Developer (CKAD) Study Guide (O'Reilly, 2024)"],
    ["Denniss, Kubernetes for Developers (Manning, 2024)",
     "Yuen et al., GitOps and Kubernetes (Manning, 2021)",
     "Salatino, Platform Engineering on Kubernetes (Manning, 2024)",
     "Oliver et al., Effective Platform Engineering (Manning, 2025)",
     { text: "Official sources", options: { bullet: false, bold: true } },
     "helm.sh/docs, Helm 4 overview, changelog and release notes",
     "Helm Improvement Proposals, including HIP-0026 for plugins",
     "OpenShift Local and OpenShift documentation"],
    { fontSize: 14 });
  addNotes(s, N("The nine books the tutorial cites, and the official sources. Books are cited for concepts Helm 4 left unchanged: chart anatomy, templating, Kubernetes objects, GitOps and platform ideas. Anything Helm 4 changed, including flags, plugins, post-renderers, OCI and server-side apply, comes from helm.sh/docs, the release notes and the HIPs, because the two Helm books were written for Helm 3.",
    "chapter 30 on the tutorial site, which gives each book's scope and ISBN.",
    "chapter 30."));
}

pres.writeFile({ fileName: OUT }).then((f) => H.finalizePptx(f).then(() => console.log("wrote", f, "slides:", pageNum)));
