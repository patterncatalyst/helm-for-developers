// deck.js - "Helm for Developers" - 101 (charts, values, templates, releases with Helm 4).
// Red Hat house style, 16:9. Chapters 02-12 of the tutorial.
// Build: NODE_PATH=$(npm root -g) node deck.js
"use strict";

const H = require("./deck-helpers.js");
const {
  COLOR, FONT, W, PNG, ASSETS,
  newDeck, addFooter, addContentTitle, addTwoColBullets,
  addStatusTable, addCaption, addCodeSlide, addSectionDivider, addNotes,
} = H;

const OUT = "Helm-101-r1.0.pptx";
const REV = "r1.0";

const pres = newDeck();
pres.title = "Helm for Developers 101";
let pageNum = 0;

function S() { const s = pres.addSlide(); pageNum += 1; addFooter(s, pageNum); return s; }
function divider(code, title, subtitle, notes) {
  const s = pres.addSlide(); pageNum += 1; addSectionDivider(s, code, title, subtitle); addNotes(s, notes);
}
// Code block text: template literal, one slide line per source line.
function L(text) { return text.replace(/^\n/, "").replace(/\s+$/, "").split("\n"); }

// ---- bold-lead bullets ------------------------------------------------------
function leadBullets(slide, items, opts = {}) {
  const x = opts.x ?? 0.62, y = opts.y ?? 1.95, w = opts.w ?? 12.09, h = opts.h ?? 4.7;
  const fontSize = opts.fontSize ?? 17;
  const runs = [];
  items.forEach((b) => {
    const para = {
      fontFace: FONT.body, fontSize,
      bullet: { code: "25CF", indent: 18 }, indentLevel: 0,
      paraSpaceBefore: 4, paraSpaceAfter: 13,
    };
    if (b.lead) {
      runs.push({ text: b.lead, options: { ...para, bold: true, color: COLOR.ink } });
      runs.push({ text: (b.sep === undefined ? ": " : b.sep) + b.text, options: { fontFace: FONT.body, fontSize, color: COLOR.body, breakLine: true } });
    } else {
      runs.push({ text: b.text, options: { ...para, color: COLOR.body, breakLine: true } });
    }
  });
  slide.addText(runs, { x, y, w, h, valign: "top", margin: 0, lineSpacingMultiple: 1.12 });
}

function leadSlide(eyebrow, title, items, notes, opts) {
  const s = S(); addContentTitle(s, eyebrow, title); leadBullets(s, items, opts || {}); addNotes(s, notes); return s;
}

// code on the left, bold-lead bullets on the right
function codeBulletsSlide(eyebrow, title, lang, code, caption, items, notes, opts = {}) {
  const s = S();
  const cw = opts.codeW ?? 7.0;
  const fs = opts.fontSize ?? 11;
  const co = { w: cw, fontSize: fs };
  if (opts.autoH) {
    co.h = Math.min(4.65, Math.max(2.0, code.length * fs * 0.0215 + 0.55));
    addCodeSlide(s, eyebrow, title, lang, code, null, co);
    addCaption(s, caption, 1.85 + co.h + 0.08);
  } else {
    addCodeSlide(s, eyebrow, title, lang, code, caption, co);
  }
  const bx = 0.62 + cw + 0.35;
  leadBullets(s, items, { x: bx, y: 1.95, w: W - 0.62 - bx, h: 4.5, fontSize: opts.bulletSize ?? 14 });
  addNotes(s, notes);
  return s;
}

function codeSlide(eyebrow, title, lang, code, caption, notes, opts = {}) {
  const s = S();
  addCodeSlide(s, eyebrow, title, lang, code, caption, opts);
  addNotes(s, notes);
  return s;
}

// diagram on its own, one-line caption
function diagramSlide(eyebrow, title, png, caption, notes) {
  const s = S();
  addContentTitle(s, eyebrow, title);
  const w = 12.09, h = 4.55, x = 0.62, y = 1.85;
  s.addImage({ path: `${PNG}/${png}.png`, x, y, w, h, sizing: { type: "contain", w, h } });
  addCaption(s, caption, 6.50);
  addNotes(s, notes);
  return s;
}

function tableSlide(eyebrow, title, rows, colW, notes, opts = {}) {
  const s = S();
  addContentTitle(s, eyebrow, title);
  addStatusTable(s, rows, { colW, rowH: opts.rowH ?? 0.62, h: opts.h ?? rows.length * (opts.rowH ?? 0.62) });
  if (opts.caption) addCaption(s, opts.caption, opts.captionY ?? 6.50);
  addNotes(s, notes);
  return s;
}

// ===== COVER ===================================================================
{
  const s = pres.addSlide(); pageNum += 1;
  s.background = { color: COLOR.white };
  try { s.addImage({ path: `${ASSETS}/cover-panel.png`, x: 0, y: 0, w: W, h: 7.5 }); } catch (e) {}
  s.addText("HELM FOR DEVELOPERS · 101", { x: 6.00, y: 1.98, w: 6.90, h: 0.34,
    fontFace: FONT.title, fontSize: 14, bold: true, color: COLOR.red, charSpacing: 5, align: "left", valign: "middle" });
  s.addText([{ text: "Helm for", options: { breakLine: true } },
             { text: "Developers 101" }], {
    x: 5.95, y: 2.42, w: 6.95, h: 2.20, fontFace: FONT.title, fontSize: 50, bold: true, color: COLOR.ink, align: "left", valign: "top" });
  s.addText("Charts, values, templates, releases with Helm 4",
    { x: 6.00, y: 4.85, w: 6.80, h: 0.80, fontFace: FONT.body, fontSize: 18, italic: true, color: COLOR.caption, align: "left", valign: "top" });
  s.addText(REV, { x: 11.85, y: 6.10, w: 0.95, h: 0.30, fontFace: FONT.mono, fontSize: 11, color: COLOR.caption, align: "right", valign: "middle" });
  try { s.addImage({ path: `${ASSETS}/logo-candidate-2.png`, x: 11.10, y: 6.78, w: 1.55, h: 0.37 }); } catch (e) {}
  addNotes(s, "What it shows: the first of two decks that accompany the Helm for Developers tutorial. The 101 covers chapters 02 through 12: what a chart and a release are, the values and template languages, configuration and secrets, dependencies, hooks, and the commands that keep a release safe. Every command targets Helm 4.3.0. What to show: nothing yet. The lab is the minikube profile helm4dev from examples/01-lab-setup, and source scripts/env.sh puts the project's Helm 4 first on PATH so the global Helm 3 is never touched. Fallback: every example has a ./demo.sh offline mode that needs no cluster, so the template and lint steps in this deck can all be replayed on a laptop without minikube. The 201 deck continues with testing, multi-service charts, distribution, plugins and delivery.");
}

// ===== AGENDA ==================================================================
{
  const s = S();
  addContentTitle(s, "101 · SCOPE", "Session agenda");
  addTwoColBullets(s,
    ["Why Helm: YAML sprawl, and what Helm 4 changed", "Core concepts: chart, release, repository, values", "First chart: anatomy, install, upgrade, rollback", "Values: precedence, override flags, schema"],
    ["Templates: Sprig, flow control, named templates", "Config, data, hooks: checksums, secrets, Postgres, migrations", "Safe releases: wait, rollback, server-side apply", "Verification: lint, template, dry-run"]);
  addNotes(s, "What it shows: the seven sections of the 101 in order. Each section maps to one to three tutorial chapters: Why Helm and Core concepts to chapters 02 and 03, First chart to chapter 04, Values to chapter 05, Templates to chapters 06 and 07, Config, data, hooks to chapters 08 through 11, and Safe releases to chapter 12. What to show: nothing live in this slide. Fallback: the chapter list in _docs/00-outline.md carries the same structure with durations. The running example throughout is the shipping service, a FastAPI application that every chart in the tutorial packages. The 101 ends with a flag map for readers migrating scripts from Helm 3.");
}

// ===== WHY HELM ================================================================
divider("01", "Why Helm", "Raw manifests do not scale across environments.",
  "What it shows: the opening section. Chapters 02 and 03 set the problem before any chart is written. What to show: nothing. Fallback: none needed. The argument is short: the same three Kubernetes objects are needed in every environment, they differ in a handful of values, and copying files is the only tool plain kubectl offers for that difference.");

diagramSlide("WHY HELM · THE PROBLEM", "YAML across environments", "h101-yaml-sprawl",
  "Three environments from raw manifests mean nine files; a chart reduces them to one template and three overrides.",
  "What it shows: the shipping service as a ConfigMap, a Deployment and a Service. Deploying it to dev, stage and prod by copying and editing those three files gives nine files that must stay in step. A fix to the probe path has to be made in three places, and a typo in one copy produces a Service that selects nothing. The right half is the destination: one chart with templates and three small values files that hold only the differences. What to show: examples/03-raw-manifests, run ./demo.sh offline, which validates the manifests with kubeconform and needs no cluster. Fallback: the observed output block in chapter 03 and the evidence file _plans/evidence/03-raw-manifests.txt. The concrete list of things that differ per environment (replicas, log level, resources, image tag) becomes the values interface in the values section.");

leadSlide("WHY HELM · THE TOOL", "Package and release manager",
  [{ lead: "A chart is a versioned package", text: "Chart.yaml metadata, default values.yaml and a templates/ directory of Go templates that render to Kubernetes manifests." },
   { lead: "A release is a named installation", text: "one chart installed into one namespace under a name you choose; the same chart installed twice is two releases." },
   { lead: "Helm records every change", text: "each install, upgrade and rollback writes a revision, which is what makes history and rollback possible." },
   { lead: "Helm is a command-line client", text: "nothing runs in the cluster on its behalf; the client renders locally and talks to the API server." }],
  "What it shows: the two jobs Helm does. As a package manager it versions, parameterizes and distributes a set of Kubernetes objects. As a release manager it tracks what was installed, with which values, and can return to an earlier state. What to show: examples/02-helm-tour, which installs the public podinfo chart from oci://ghcr.io/stefanprodan/charts/podinfo at the pinned version 6.15.0 and follows it through list, status, get values and uninstall. Fallback: the observed output in chapter 02 and _plans/evidence/02-helm-tour.txt, or ./demo.sh offline, which runs helm show chart and helm template without a cluster. Point out that the version is always pinned: without --version, Helm takes the newest tag and output stops matching the chapter.");

tableSlide("WHY HELM · HELM 4", "Helm 4 at a glance",
  [{ code: "Apply", name: "Server-side apply", purpose: "Default for new releases; upgrades follow the method the previous revision used" },
   { code: "Failure", name: "--rollback-on-failure", purpose: "Replaces Helm 3's atomic flag; implies --wait=watcher" },
   { code: "Wait", name: "kstatus watcher", purpose: "--wait takes watcher, hookOnly or legacy; a bare --wait means watcher" },
   { code: "Plugins", name: "Typed, optional Wasm", purpose: "cli/v1, getter/v1 and postrenderer/v1; subprocess or Wasm runtime" },
   { code: "Post-renderers", name: "Plugins only", purpose: "The flag takes a plugin name; a bare executable path is rejected" },
   { code: "Charts", name: "apiVersion v2 unchanged", purpose: "Chart API v3 is experimental; existing charts install without edits" }],
  [2.40, 3.00, 6.69],
  "What it shows: the six behaviors of Helm 4 that this deck depends on. Server-side apply, the kstatus-based wait and the renamed rollback flag affect every install and upgrade command; the plugin system and post-renderer change matter in the 201. Charts themselves did not change: a chart with apiVersion v2 installs with Helm 4 unchanged, and the podinfo chart used in chapter 02 is even a v1 chart. What to show: helm install --help from the project binary, filtered to the wait and server-side flags: source scripts/env.sh and run helm install --help. Fallback: the Helm 3 to 4 table at the end of chapter 02, which lists the official source for each row (the Helm 4 overview at helm.sh/docs/overview, HIP-0022 for the wait, HIP-0023 for server-side apply, HIP-0026 for plugins). Helm 3 receives bug fixes until July 8th 2026 and security fixes until November 11th 2026.");

// ===== CORE CONCEPTS ===========================================================
divider("02", "Core concepts", "The four nouns and where release state lives.",
  "What it shows: chart, release, repository and values, then the architecture that connects them. What to show: nothing. Fallback: none needed. This section is chapter 02 content; the nouns defined here are reused in every later slide.");

leadSlide("CORE CONCEPTS · VOCABULARY", "Chart, release, repository, values",
  [{ lead: "Chart", text: "the package: metadata, defaults and templates. Identified by a name and a SemVer version." },
   { lead: "Release", text: "one installation of a chart in one namespace. Release names are limited to 53 characters." },
   { lead: "Repository or registry", text: "where charts are stored. Classic repositories serve an index.yaml over HTTP; OCI registries store a chart as an artifact." },
   { lead: "Values", text: "the inputs that customize a chart. Defaults ship in values.yaml; you override them per release." }],
  "What it shows: the four terms in the order a reader meets them. A chart is inert until installed; installing it under a name creates a release; the chart came from a repository or registry; and values are the parameters that make one chart usable in several environments. What to show: helm show chart and helm show values against the podinfo chart: in examples/02-helm-tour, ./demo.sh offline prints Chart.yaml and fails the demo unless version 6.15.0 is present. Fallback: chapter 02, section What Helm is. Chapters 19 and 20 in the 201 cover repositories and OCI in depth, so this deck only names them.");

diagramSlide("CORE CONCEPTS · ARCHITECTURE", "Client-only architecture", "h101-client-architecture",
  "The client pulls, renders and applies; the release record is a Secret named sh.helm.release.v1.<release>.v<N>.",
  "What it shows: Helm as a pure client. When you run helm install, the client pulls the chart from the registry, merges the values, renders the templates locally, sends the objects to the API server and records the result as a Secret in the release namespace. There is no server and no in-cluster component. Because the record is a Secret, helm list works from any machine with access to the namespace. The HELM_DRIVER variable selects the backend: secret is the default, configmap and sql are the alternatives, memory stores nothing. What to show: in examples/02-helm-tour after ./demo.sh, run kubectl get secret -l owner=helm -n hfd-02 to see the one release record. Fallback: chapter 02, Build run observe section. Release data can contain secret values, so limit who can read Secrets in the namespace.");

// ===== FIRST CHART =============================================================
divider("03", "First chart", "Anatomy, install, upgrade, rollback.",
  "What it shows: chapter 04. The three raw manifests from chapter 03 become one chart. What to show: examples/04-first-chart. ./demo.sh offline lints and renders the chart without a cluster. Fallback: observed output in chapter 04 for helm lint and helm template --show-only templates/service.yaml.");

codeBulletsSlide("FIRST CHART · LAYOUT", "Chart anatomy", "tree",
  L(`
shipping-service/
  Chart.yaml        # required: name, version, appVersion
  values.yaml       # defaults read through .Values
  .helmignore       # files left out of the package
  templates/
    configmap.yaml
    deployment.yaml
    service.yaml
`),
  "examples/04-first-chart/shipping-service",
  [{ lead: "Chart.yaml", text: "the only required file besides templates/." },
   { lead: "values.yaml", text: "defaults, read by templates as .Values." },
   { lead: "templates/", text: "Go templates; Helm renders each file to YAML." },
   { lead: ".helmignore", text: "gitignore syntax; /tests/ with a leading slash matches only the top-level directory." }],
  "What it shows: the smallest useful chart, built by hand from the chapter 03 manifests. helm create generates a larger scaffold (service account, HPA, ingress, HTTPRoute, test pod), which is a reference and too much to start from. The hand-built chart replaces only what must change per release. What to show: in examples/04-first-chart, ./demo.sh offline prints the generated helm create file list so the two layouts can be compared. Fallback: chapter 04, section helm create and a lean chart. The .helmignore entry is /tests/ with a leading slash because an unanchored tests/ would also match templates/tests/, which the 201 relies on.", { fontSize: 12, autoH: true });

codeBulletsSlide("FIRST CHART · METADATA", "Chart metadata fields", "yaml",
  L(`
apiVersion: v2
name: shipping-service
type: application
version: 0.4.0
appVersion: "0.1.0"
`),
  "examples/04-first-chart/shipping-service/Chart.yaml",
  [{ lead: "apiVersion: v2", text: "the chart format Helm 4 uses; v3 is not released." },
   { lead: "type", text: "application is installable; library is not (201)." },
   { lead: "version", text: "identifies the chart package, SemVer. A template fix bumps it." },
   { lead: "appVersion", text: "identifies the application. A new image bumps it. Quoted, so 1.10 stays a string." }],
  "What it shows: the five fields every chart needs. version and appVersion move independently: a template fix bumps the chart version, a new image bumps appVersion, and the image tag in values.yaml defaults to .Chart.AppVersion so the two never need a second edit. In the tutorial the chart version follows the chapter number (0.4.0) until chapter 19, which releases 1.0.0. What to show: helm show chart ./shipping-service from examples/04-first-chart. Fallback: chapter 04, How the code works. apiVersion is quoted nowhere because it is a plain string; appVersion is quoted because an unquoted 1.10 would be read as the number 1.1.", { fontSize: 14, autoH: true });

diagramSlide("FIRST CHART · LIFECYCLE", "Install, upgrade, rollback", "h101-revisions",
  "Each command writes one revision Secret; the rollback in revision 3 carries the contents of revision 1.",
  "What it shows: three commands and the revisions they create. Install writes revision 1, an upgrade with replicaCount=2 writes revision 2, and helm rollback shipping 1 writes revision 3 with the contents of revision 1. A rollback does not rewind the counter. What to show: examples/04-first-chart, ./demo.sh, which installs into hfd-04, upgrades with --reuse-values and --set replicaCount=2, then rolls back; helm history shipping -n hfd-04 lists the three revisions. Fallback: chapter 04, section Install, upgrade, roll back, which shows the command list; or kubectl get secrets -l owner=helm to show the stored revisions. The script form helm upgrade --install is the one to use in automation, because the same command serves the first release and every later one.");

codeSlide("FIRST CHART · STORAGE", "Release history and storage", "bash",
  L(`
[host]$ helm history shipping -n hfd-04
[host]$ helm get values shipping -n hfd-04 --all
[host]$ helm get manifest shipping -n hfd-04
[host]$ kubectl -n hfd-04 get secrets -l owner=helm
# one Secret per revision, type helm.sh/release.v1
# sh.helm.release.v1.shipping.v1, .v2, .v3
[host]$ helm uninstall shipping -n hfd-04 --keep-history
[host]$ helm list -n hfd-04 --uninstalled
# --history-max (default 10) prunes the oldest revisions on upgrade
`),
  "examples/04-first-chart, examples/12-release-lifecycle",
  "What it shows: the read side of a release. helm history lists revisions, helm get values prints the user-supplied values (--all adds the merged result), helm get manifest prints the rendered objects stored in the latest revision, and kubectl shows the Secrets behind them. The Secret holds the chart, merged values, manifest and status, gzipped and base64-encoded. Uninstall removes the Secrets with the workload; --keep-history leaves the release listed as uninstalled. What to show: examples/12-release-lifecycle, ./demo.sh steps 5 through 7, which read the history, run each helm get subcommand and decode the newest release Secret with base64 -d, base64 -d and gunzip. Fallback: chapter 12, section Revisions live in Secrets. Only one revision per release is deployed at a time.");

// ===== VALUES ==================================================================
divider("04", "Values", "The chart's public interface.",
  "What it shows: chapter 05. values.yaml is treated as an API: designed, documented and validated. What to show: examples/05-values, ./demo.sh offline. Fallback: observed output in chapter 05 for the schema rejection and the two precedence renders.");

diagramSlide("VALUES · MERGE ORDER", "Values precedence", "h101-values-precedence",
  "Chart defaults, then each -f file in order, then --set flags; the schema validates the merged result.",
  "What it shows: how Helm builds the single .Values map. The chart's values.yaml is the base, each -f or --values file merges over it from left to right, and the --set family wins over every file. Maps merge key by key; lists and scalars are replaced whole, so overriding one entry of imagePullSecrets means supplying the full list. After the merge, values.schema.json validates the result before any template runs. What to show: examples/05-values, ./demo.sh offline, which renders replicas: 5 for values-prod.yaml plus --set replicaCount=5, and LOG_LEVEL: DEBUG when values-dev.yaml is passed last. Fallback: the two helm template commands in chapter 05, section Precedence. On upgrade, previous flags are forgotten unless the same -f files are passed again or --reuse-values or --reset-then-reuse-values is used.");

codeSlide("VALUES · COMMAND LINE", "Override flags", "bash",
  L(`
[host]$ helm template shipping examples/05-values/shipping-service -f examples/05-values/values-prod.yaml --set replicaCount=5
# --set guesses types: true, integers and null convert; commas separate keys
[host]$ helm template shipping examples/05-values/shipping-service --set-string image.tag=12345
# --set-string forces a string; --set image.tag=12345 fails the schema (got number, want string)
[host]$ helm template shipping examples/05-values/shipping-service --set-json 'resources={"limits":{"memory":"1Gi"}}'
# --set-json takes a JSON value for a map or list
[host]$ helm template shipping examples/05-values/shipping-service --set-file config.defaultCarrier=carrier.txt
# --set-file uses the file content, trailing newline included
[host]$ helm template shipping examples/05-values/shipping-service --set-literal config.defaultCarrier=ACME,Post
# --set-literal keeps commas: renders "ACME,Post"
`),
  "examples/05-values/demo.sh",
  "What it shows: the five ways to set a value from the command line and how each types its input. --set guesses, so a comma in a value breaks it (--set config.defaultCarrier=ACME,Post fails with key Post has no value). --set-string forces a string, which matters for an image tag such as 12345. --set-json passes structured data. --set-file reads a file. --set-literal keeps commas and special characters verbatim. What to show: run the first command from examples/05-values and then the --set-string variant with the unquoted --set, to see the schema reject the number. Fallback: chapter 05, section Precedence, which lists the five variants with the observed error text. For repeatable deployments, prefer -f files committed to Git and treat --set as the exception.",
  { fontSize: 10 });

codeBulletsSlide("VALUES · VALIDATION", "Values schema", "json",
  L(`
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "replicaCount": {"type": "integer", "minimum": 0},
    "image": {
      "type": "object",
      "properties": {
        "pullPolicy": {"enum": ["Always", "IfNotPresent", "Never"]}
      }
    },
    "service": {
      "properties": {
        "nodePort": {"type": ["integer", "null"],
                     "minimum": 30000, "maximum": 32767}
      }
    }
  }
}
`),
  "examples/05-values/shipping-service/values.schema.json (abridged)",
  [{ lead: "Runs on the merged values", text: "install, upgrade, template and lint, before any template renders." },
   { lead: "additionalProperties: false", text: "a misspelled key fails instead of being ignored." },
   { lead: "enum, minimum, maximum", text: "close sets and ranges, such as the NodePort range." },
   { lead: "Strict by design", text: "a new value needs a schema entry in the same commit." }],
  "What it shows: an abridged values.schema.json. Helm checks the schema after all values are merged and before any template runs, on install, upgrade, template and lint. With additionalProperties false at the top level, a typo such as replicas for replicaCount fails with a path into the values. The type array integer-or-null is how a nullable default is expressed. The draft-07 declaration follows the Helm charts documentation; Helm 4.3.0 also accepted a 2020-12 declaration when linted locally. What to show: examples/05-values, ./demo.sh offline, which proves the schema rejects both a wrong type and an unknown key. Fallback: the error block in chapter 05 Build run observe. Cross-check: helm lint with --skip-schema-validation passes a bad value, which shows the schema is the only guard.",
  { codeW: 7.2 });

// ===== TEMPLATES ===============================================================
divider("05", "Templates", "Go templates, Sprig and named templates.",
  "What it shows: chapters 06 and 07. A template is a program whose output happens to be YAML, so whitespace is part of its logic. What to show: examples/06-templates and examples/07-helpers-notes, ./demo.sh offline in each. Fallback: the observed output blocks in each chapter.");

codeBulletsSlide("TEMPLATES · SYNTAX", "Go templates and Sprig", "yaml",
  L(`
{{- $fullname := printf "%s-%s" .Release.Name .Chart.Name -}}
{{- $image := printf "%s:%s"
      (required "image.repository is required" .Values.image.repository)
      (.Values.image.tag | default .Chart.AppVersion) -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $fullname }}
  labels:
    log-level: {{ .Values.config.logLevel | quote }}
`),
  "examples/06-templates/shipping-service/templates/deployment.yaml",
  [{ lead: ".Values, .Release, .Chart", text: "built-in objects; also .Capabilities, .Template and .Files." },
   { lead: "Pipelines", text: "a | f is f applied to a; quote, default and printf come from Sprig." },
   { lead: "Variables", text: "declared with := and read as $name." },
   { lead: "Whitespace", text: "{{- and -}} trim newlines; the file still starts with apiVersion." }],
  "What it shows: the top of the chapter 06 Deployment template. Everything inside double braces is evaluated against a context, written dot. $fullname removes the four repeated name expressions from chapter 04. printf builds the image reference. The pipeline .Values.image.tag | default .Chart.AppVersion means: use the tag, or the application version when the tag is empty. Sprig supplies default, quote, trunc, trimSuffix, printf, sha256sum and b64enc; Helm adds toYaml, fromYaml, include, tpl, required and lookup. What to show: helm template shipping examples/06-templates/shipping-service -n hfd-06 --show-only templates/deployment.yaml. Fallback: chapter 06, section Pipelines, whitespace and flow control. Whitespace is literal: a misplaced space in YAML changes the meaning, and helm template --debug prints the output even when it is not valid YAML.",
  { codeW: 7.2 });

codeSlide("TEMPLATES · CONTROL", "Flow control and scope", "yaml",
  L(`
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 8 }}      # inside with, dot is the list
{{- end }}

{{- with .Values.podAnnotations }}
annotations:
  {{- range $key, $value := . }}
  {{ $key | quote }}: {{ tpl $value $ | quote }}   # $ is always the root context
  {{- end }}
{{- end }}

{{- if and (eq .Values.service.type "NodePort") .Values.service.nodePort }}
nodePort: {{ .Values.service.nodePort }}
{{- end }}
`),
  "examples/06-templates/shipping-service/templates (deployment.yaml, service.yaml)",
  "What it shows: the three flow-control actions, each closed by end. if runs a block when the condition is truthy; empty strings, 0, false, null, empty maps and empty lists are false. with runs the block only for a non-empty value and rebinds dot to it, so an empty imagePullSecrets list removes the whole key. range loops over a list or, with $key, $value :=, over a map. Inside with and range, dot is rebound, so $ reaches the root context. What to show: helm template shipping examples/06-templates/shipping-service -n hfd-06 -f examples/06-templates/values-dev.yaml --show-only templates/deployment.yaml, then the same command without -f: the first renders the annotations and env blocks, the second has neither. Fallback: chapter 06, Build run observe. A nodePort set while the type is ClusterIP would be rejected by the API server, which is why service.yaml drops it.",
  { fontSize: 14 });

codeBulletsSlide("TEMPLATES · REUSE", "Named templates", "yaml",
  L(`
{{/* _helpers.tpl */}}
{{- define "shipping-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shipping-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shipping-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* call site, in any template */}}
  labels:
    {{- include "shipping-service.labels" . | nindent 4 }}
`),
  "examples/07-helpers-notes/shipping-service/templates/_helpers.tpl",
  [{ lead: "define ... end", text: "a global name; prefix it with the chart name." },
   { lead: "include", text: "returns a string, so it pipes to nindent, quote or trunc." },
   { lead: "template", text: "inserts output directly and cannot be piped; use include." },
   { lead: "Pass the context", text: "the trailing dot; omit it and .Release fails." }],
  "What it shows: a named template defined once and included from every manifest. Files that begin with an underscore are loaded as libraries and never rendered as manifests. Names are global across the chart and its subcharts, so the convention is chartname.helper; two charts defining fullname would silently overwrite each other. The pattern include ... | nindent 4 is the idiom for a multi-line helper: the helper emits unindented lines and the call site picks the depth. Selector labels stay minimal and stable because a Deployment's selector cannot change after creation; the full recommended label set goes on metadata and pod templates. What to show: helm template shipping examples/07-helpers-notes/shipping-service --show-only templates/service.yaml, and the offline assertions in ./demo.sh offline for the fullname cases. Fallback: chapter 07, section Named templates. The fullname helper handles nameOverride, fullnameOverride and a release name that already contains the chart name.",
  { codeW: 7.3 });

tableSlide("TEMPLATES · FUNCTIONS", "tpl, required, fail, lookup",
  [{ code: "tpl", name: "Render a string", purpose: "tpl $value $ evaluates a value as a template; apply it only to values the operator controls" },
   { code: "required", name: "Stop on empty", purpose: "required \"image.repository is required\" .Values.image.repository aborts with your message" },
   { code: "fail", name: "Reject a combination", purpose: "Unconditional abort, used inside an if to reject invalid combinations of values" },
   { code: "lookup", name: "Read the cluster", purpose: "Returns an empty map under helm template and --dry-run=client; works with --dry-run=server" }],
  [1.90, 2.80, 7.39],
  "What it shows: four functions that go beyond string formatting. tpl renders a value string as a template with a chosen context: in values-dev.yaml a pod annotation can refer to the release name and namespace. Because it evaluates arbitrary template text, never feed it untrusted input. required returns the value or aborts rendering with a message; the schema catches an empty image.repository first, so to see required fire you skip the schema with --skip-schema-validation. fail is the unconditional version. lookup queries the live cluster during rendering and is the reason a chart can render differently offline than in a real install. What to show: examples/06-templates, ./demo.sh offline, which asserts the behavior of required, tpl and with. Fallback: the observed Error: execution error text in chapter 06. Chapter 08 uses lookup to keep a generated Secret stable; the 201 returns to its limits under Argo CD, which renders with helm template.",
  { rowH: 0.78 });

codeSlide("TEMPLATES · POST-INSTALL", "Post-install notes", "text",
  L(`
{{ include "pc-lib.fullname" . }} {{ .Chart.AppVersion }} installed as release "{{ .Release.Name }}" in namespace {{ .Release.Namespace }}.
Storage: {{ .Values.config.storage }}

Reach the service:
{{- if eq .Values.service.type "NodePort" }}
  [host]$ minikube -p helm4dev service {{ include "pc-lib.fullname" . }} -n {{ .Release.Namespace }} --url
{{- else }}
  [host]$ kubectl -n {{ .Release.Namespace }} get svc {{ include "pc-lib.fullname" . }}
{{- end }}

Run the chart test:
  [host]$ helm test {{ .Release.Name }} -n {{ .Release.Namespace }}
`),
  "charts/shipping-service/templates/NOTES.txt",
  "What it shows: a NOTES.txt template. It renders with the same context as any template and is printed by helm install and helm upgrade; helm get notes reprints it later. This one branches on service.type so a NodePort release gets the minikube service command and every other type gets kubectl get svc. The file in templates/ is the place for the next command the reader needs. The same context gives access to .Files: .Files.Get returns a chart file as a string, and .Files.Glob with .AsConfig renders files as ConfigMap data. What to show: examples/07-helpers-notes, helm install with --dry-run=client prints the NOTES block, and helm get notes shipping -n hfd-07 after a live install. Fallback: the observed NOTES output in chapter 07. Note that helm template never prints notes.",
  { fontSize: 10 });

// ===== CONFIG, DATA, HOOKS =====================================================
divider("06", "Config, data, hooks", "Rollouts, secrets, dependencies and migrations.",
  "What it shows: chapters 08 through 11. These chapters take the chart from a stateless pod to a service with configuration, a token, a database and a schema migration. What to show: examples/08-config-secrets, examples/09-postgres-subchart, examples/11-hooks-migrations. Fallback: ./demo.sh offline in each directory needs no cluster; the live runs of 09 and 11 need the CloudNativePG operator from scripts/platform/bootstrap.sh.");

codeBulletsSlide("CONFIG · ROLLOUTS", "Config rollouts with checksums", "yaml",
  L(`
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
`),
  "examples/08-config-secrets/shipping-service/templates/deployment.yaml",
  [{ lead: "The problem", text: "a ConfigMap change alters no Deployment field, so pods keep the old environment." },
   { lead: "The fix", text: "hash the rendered ConfigMap into a pod-template annotation; a new hash rolls the pods." },
   { lead: "Deterministic input only", text: "hashing a Secret built with randAlphaNum would roll pods on every render." },
   { lead: "Alternative", text: "immutable ConfigMap with a content hash in its name." }],
  "What it shows: the standard Helm answer to configuration changes that do not restart pods. Kubernetes rolls a Deployment only when its pod template changes, and a ConfigMap update changes nothing in the Deployment. The annotation holds a sha256 of the rendered ConfigMap text; include with a path renders that template file as a string with the current context. An unchanged ConfigMap gives the same hash and no restart. The checksum covers only the ConfigMap: a generated Secret renders differently on every run, so hashing it would defeat the point. What to show: examples/08-config-secrets, ./demo.sh offline asserts that the checksum is stable for equal input and changes with config.logLevel; live, ./demo.sh upgrades the carrier and lists pods before and after. Fallback: the two observed checksum lines in chapter 08. The immutable ConfigMap alternative orphans old objects but guarantees configuration cannot change under a running pod.",
  { codeW: 7.2 });

tableSlide("CONFIG · SECRETS", "Secret management options",
  [{ code: "existingSecret", name: "Nothing in Git", purpose: "Secret created out of band; the chart references the name through secretKeyRef" },
   { code: "External Secrets", name: "ExternalSecret in Git", purpose: "The operator copies from a vault in the cluster; point existingSecret at its target" },
   { code: "Sealed Secrets", name: "Encrypted in Git", purpose: "The controller decrypts in the cluster and produces a Secret the chart references" },
   { code: "SOPS", name: "Encrypted values", purpose: "Client-side helm-secrets plugin; Helm 4 support is not verified in the tutorial" },
   { code: "auth.token", name: "Plain in values", purpose: "Stored in the release record and printed by helm get values; development only" }],
  [2.40, 2.60, 7.09],
  "What it shows: where the plaintext lives for each approach. Chart-created Secrets put the token in values and in the release record, which is acceptable for a lab and not for production. The first three options leave Helm unchanged and rely on existingSecret, which is why the pattern is worth building into every chart. The chart in chapter 08 chooses among three sources with one helper: an existing Secret, a token from values, or a generated token kept stable across upgrades with lookup and dig. SOPS with helm-secrets is a client-side plugin; its README states support for Helm 3.9 and later and does not mention Helm 4, so check its release notes first. What to show: examples/08-config-secrets, ./demo.sh, which drives the API with and without the token and reports 401 without it. Fallback: chapter 08, section Comparing secret management approaches. A generated token also changes on every Argo CD sync because lookup returns nothing under helm template, a point the 201 covers.",
  { rowH: 0.78 });

diagramSlide("DATA · DEPENDENCIES", "Subcharts and the Postgres operator", "h101-subchart-tree",
  "The parent imports the host and Secret name; the operator creates the credentials the Deployment reads.",
  "What it shows: the shipping-service parent chart declares shipping-postgres as a dependency. The subchart renders one CloudNativePG Cluster; the operator, installed once per cluster by the platform team, creates the pod, the shipping-postgres-rw Service and the shipping-postgres-app Secret. import-values copies the exports.postgres block into the parent as postgres.host and postgres.existingSecret, and the Deployment reads PG_USER and PG_PASSWORD through secretKeyRef. The chart never writes a password. The dependency block uses a condition so the default install does not need an operator. What to show: examples/09-postgres-subchart, ./demo.sh offline runs helm dependency build, lints both value sets, renders memory mode (three objects) and postgres mode (four). Fallback: chapter 09, Build run observe. A file:// dependency renders the packaged copy in charts/, so rebuild with helm dependency build after editing the subchart.");

diagramSlide("DATA · HOOKS", "Migration hooks", "h101-hook-timeline",
  "A pre-install hook cannot start before its Secret exists; a post-install hook waits behind the readiness check.",
  "What it shows: two placements of the migration Job and how each fails on a fresh install. Option A, pre-install, runs before the release resources, so the Job pod references a Secret that the same release has not created yet and waits until the timeout. Option B, post-install with --wait, runs only after the Deployment is ready, but the readiness probe on /healthz needs the tables, so the wait never ends. The chart's fix is the post-install hook with the readiness probe on /health, which does not touch the database. The golden umbrella build hit this deadlock and recorded it in _plans/evidence/golden-01-install-attempt1-deadlock.txt. What to show: examples/11-hooks-migrations, ./demo.sh deadlock and ./demo.sh preinstall each end with a timeout after 90 seconds. Fallback: the Error: release platform failed text in chapter 11. A pre-install hook is correct when the database already exists, for example an external one.");

tableSlide("DATA · HOOK CONTROLS", "Hook weights and policies",
  [{ code: "helm.sh/hook", name: "Phase", purpose: "pre-install, post-install, pre-upgrade, post-upgrade and more; several phases separated by commas" },
   { code: "hook-weight", name: "Order", purpose: "A string holding an integer, ascending within a phase; ties sort by kind, then name" },
   { code: "hook-delete-policy", name: "Cleanup", purpose: "before-hook-creation (default), hook-succeeded, hook-failed" },
   { code: "pre-install", name: "Database exists", purpose: "Runs before the resources; fails when the same release creates the database" },
   { code: "post-install", name: "Needs readiness", purpose: "Runs after --wait; deadlocks when readiness depends on the migration" }],
  [3.00, 2.30, 6.79],
  "What it shows: the three annotations that control a hook and the two placements that matter. A hook is an ordinary manifest in templates/ with a helm.sh/hook annotation; Helm renders it but keeps it out of the release resource list, so helm get manifest omits it and helm get hooks prints it. The chart uses delete policy before-hook-creation,hook-succeeded: the first removes the previous run's Job so the next upgrade can create it again, the second cleans up after success, and omitting hook-failed leaves a failed Job for kubectl logs. A second hook, the warm Job at weight 10, runs after the migration at weight 0. An init container is the alternative for per-pod checks, since a hook runs once per release and not on pod restarts. What to show: helm get hooks shipping -n hfd-11 after ./demo.sh in examples/11-hooks-migrations. Fallback: chapter 11, section How the code works. The Job sets restartPolicy Never with backoffLimit 3 and activeDeadlineSeconds 600.",
  { rowH: 0.78 });

// ===== SAFE RELEASES ===========================================================
divider("07", "Safe releases", "Wait, roll back, verify before applying.",
  "What it shows: chapter 12 and the verification commands from earlier chapters. What to show: examples/12-release-lifecycle, ./demo.sh offline for the unit tests and ./demo.sh for the eleven live steps. Fallback: _plans/evidence/golden-08-negative-control.txt records a failed upgrade rolled back on the golden platform release.");

codeBulletsSlide("SAFE RELEASES · FAILURE", "Wait and rollback-on-failure", "bash",
  L(`
[host]$ helm upgrade shipping examples/12-release-lifecycle/shipping-service -n hfd-12 --set image.tag=doesnotexist --wait --timeout 60s --rollback-on-failure
Error: UPGRADE FAILED: release shipping failed, and has been rolled back
due to rollback-on-failure being set: ... not ready. status: InProgress
[host]$ helm history shipping -n hfd-12
# 4 failed     Upgrade "shipping" failed
# 5 deployed   Rollback to 3
[host]$ helm upgrade shipping examples/12-release-lifecycle/shipping-service -n hfd-12 --cleanup-on-fail --wait
`),
  "examples/12-release-lifecycle/demo.sh, steps 3 and 4",
  [{ lead: "--wait strategies", text: "watcher (kstatus), hookOnly (default without the flag), legacy (Helm 3 polling)." },
   { lead: "--rollback-on-failure", text: "implies watcher; a failed first install is uninstalled." },
   { lead: "--cleanup-on-fail", text: "removes only what the upgrade created; revision stays failed." },
   { lead: "Read the pod next", text: "kstatus reports the Deployment; the cause is on the pod." }],
  "What it shows: a deliberate failure and the two recovery behaviors. Setting image.tag to a tag that does not exist makes the new pod fail to pull; with --wait the upgrade times out, the revision is marked failed, and --rollback-on-failure rolls back to the last successful revision as a new revision. The failed attempt keeps its own revision number, and the rollback is revision 5 with the description Rollback to 3, not a return to 3. The old ReplicaSet kept serving during the whole failure. --timeout bounds each wait and defaults to five minutes; --wait-for-jobs adds Jobs to the wait. What to show: examples/12-release-lifecycle, ./demo.sh steps 3 and 4, then kubectl describe pod, because Helm's message (Pending termination: 1) describes the Deployment and not the cause. Fallback: _plans/evidence/golden-08-negative-control.txt and the observed failure path in chapter 12.",
  { codeW: 7.3, fontSize: 10 });

leadSlide("SAFE RELEASES · APPLY", "Server-side apply",
  [{ lead: "Default for new releases", text: "helm install --server-side is true; upgrade defaults to auto and follows the previous revision's method." },
   { lead: "Field ownership", text: "the API server tracks which manager owns each field, so a kubectl scale or an autoscaler can conflict with Helm." },
   { lead: "--force-conflicts", text: "takes over fields owned by another manager." },
   { lead: "--take-ownership", text: "lets an upgrade adopt resources that lack Helm's ownership annotations; add --force-conflicts when another manager owns differing fields." },
   { lead: "--force-replace", text: "replaces objects client-side; Helm 4.3.0 rejects it with server-side apply, so add --server-side=false." }],
  "What it shows: the Helm 4 apply model. A release created by Helm 3 stays on client-side apply until --server-side is set explicitly on an upgrade. With server-side apply, Helm stops with a conflict when another field manager owns a field it wants to set to a different value. The tutorial's step 8 patches spec.replicas with kubectl patch --field-manager=hfd-demo, so a plain helm upgrade stops, and the --force-conflicts upgrade resolves it. Step 9 shows the refusal to adopt an unowned ConfigMap, then adoption, which on 4.3.0 needs --take-ownership --force-conflicts because the existing fields belong to another manager. Step 10 shows --force-replace rejected under server-side apply and working with --server-side=false. The design is in HIP-0023. What to show: examples/12-release-lifecycle, ./demo.sh steps 8 and 9. Fallback: chapter 12, section Server-side apply, ownership and conflicts. The Helm 3 force spelling remains in Helm 4 with a deprecation warning and is covered in the flag map at the end.");

codeSlide("SAFE RELEASES · VERIFY", "Lint, template, dry-run", "bash",
  L(`
[host]$ helm lint examples/05-values/shipping-service -f examples/05-values/values-prod.yaml
[host]$ helm template shipping examples/05-values/shipping-service -n hfd-05 --show-only templates/deployment.yaml
[host]$ helm template shipping examples/05-values/shipping-service | kubeconform -strict -summary -
# client-side: no cluster, so lookup returns an empty map and the API list is the built-in one
[host]$ helm upgrade --install shipping examples/05-values/shipping-service -n hfd-05 --dry-run=client
# server-side: connects to the cluster, runs lookup and checks CRDs through .Capabilities
[host]$ helm upgrade --install shipping examples/05-values/shipping-service -n hfd-05 --dry-run=server
`),
  "examples/05-values/demo.sh, examples/10-crds-operators/demo.sh",
  "What it shows: four levels of checking before anything changes in the cluster. helm lint renders every template and checks structure and the schema. helm template renders locally and, piped through kubeconform -strict, validates each object against the Kubernetes schemas; custom resources without a schema in the default catalog are skipped and reported in the summary. --dry-run=client renders and prints notes with no cluster connection. --dry-run=server connects, so kinds resolve against the API server, lookup returns live objects and .Capabilities.APIVersions reflects the real cluster. On Helm 4.3.0 it does not schema-validate fields: a string containerPort, an unknown field or a Pod Security violation all pass, so use kubeconform, or kubectl apply --server-side --dry-run=server on helm template output, for that. In Helm 4, --dry-run takes none, client or server. What to show: ./demo.sh offline in examples/05-values and examples/10-crds-operators; the second expects the postgres render to fail without the operator and shows the guard message. Fallback: chapter 10, the operator guard section, and chapter 13 in the 201 for the full debugging ladder. Remember that lint does not resolve import-values.",
  { fontSize: 10 });

leadSlide("NEXT STEPS", "Next: Helm 201",
  [{ lead: "Testing and debugging", text: "the debug ladder, helm diff, helm-unittest, chart-testing, kubeconform and a chart CI pipeline." },
   { lead: "Multi-service applications", text: "Kafka via Strimzi, umbrella charts, globals, library charts and starters." },
   { lead: "Distribution", text: "SemVer for charts, OCI registries, provenance and cosign." },
   { lead: "Extending and delivering", text: "Helm 4 plugins, Wasm, post-renderer plugins, environment promotion and Argo CD." },
   { lead: "OpenShift", text: "security context constraints, arbitrary UIDs, Routes and the Helm console." }],
  "What it shows: what the 201 adds, chapters 13 through 27. The 101 ends with a chart that installs, upgrades, rolls back and migrates its own database. The 201 treats that chart as a golden artifact: it is tested, packaged, signed, extended with plugins and promoted across environments. What to show: the golden charts under charts/ (shipping-service, notification-service, shipping-platform) and _plans/evidence/golden-01-install.txt for the umbrella install. Fallback: _docs/00-outline.md for the chapter list with durations. Keep the cheat sheet in appendix chapter 29 open during the 201; the flag map on the next slide is the 101 equivalent for scripts migrating from Helm 3.");

tableSlide("APPENDIX · MIGRATION", "Helm 3 to 4 flag map",
  [
    { code: "--atomic", name: "--rollback-on-failure", purpose: "install and upgrade; implies --wait=watcher" },  // <!-- helm3-reference -->
    { code: "--force", name: "--force-replace", purpose: "client-side only: needs --server-side=false; both spellings warn" },  // <!-- helm3-reference -->
    { code: "--wait (boolean)", name: "--wait=watcher|hookOnly|legacy", purpose: "A bare --wait means watcher; no flag means hookOnly" },  // <!-- helm3-reference -->
    { code: "--dry-run (boolean)", name: "--dry-run=none|client|server", purpose: "template takes client or server and defaults to client" },  // <!-- helm3-reference -->
    { code: "--post-renderer <exe>", name: "--post-renderer <plugin>", purpose: "A path is rejected; pass a postrenderer/v1 plugin name" },  // <!-- helm3-reference -->
    { code: "registry login oci://host", name: "registry login host", purpose: "Domain name only" },  // <!-- helm3-reference -->
  ],
  [3.30, 4.30, 4.49],
  "What it shows: the renamed and changed flags for readers with existing scripts and CI. This is the only slide in the deck that writes Helm 3 flags, and each such line carries the repository's helm3-reference marker so the forbidden-syntax check accepts it. The old spellings of the rename pair still work in Helm 4 with a deprecation warning, which makes them easy to find in CI logs. Charts themselves are unchanged. What to show: helm install --help and helm upgrade --help from the project binary to confirm each Helm 4 flag. Fallback: chapter 28, the migration appendix, which lists the official source for each row (the Helm 4 overview, the changelog and the v4.0.0 release notes). New flags worth knowing: --server-side, --force-conflicts, --take-ownership, --wait-for-jobs, --skip-schema-validation and --history-max. The first step of a migration is to replace the renamed flags, make --wait explicit, wrap each post-renderer script in a plugin and drop oci:// from registry login.",
  { rowH: 0.66 });

pres.writeFile({ fileName: OUT }).then(() => console.log("wrote " + OUT + " (" + pageNum + " slides)"));
