"""diagrams.py - Helm 201 deck scenes (SVG + Excalidraw; PNG via build_diagrams.py)."""
from dgen import Scene, PALETTE

W, H = 1240, 600


def debug_ladder():
    s = Scene("h201-debug-ladder", W, 490)
    s.panel(30, 60, 640, 330)
    s.panel(690, 60, 520, 330)
    s.label(50, 92, "No cluster needed", size=15, weight="bold", color=PALETTE["platform"])
    s.label(710, 92, "API server needed", size=15, weight="bold", color=PALETTE["govern"])
    rungs = [
        ("1 Lint", ["lint --strict"], "platform", 45),
        ("2 Render", ["template --debug"], "platform", 195),
        ("3 Schema", ["kubeconform"], "platform", 345),
        ("4 Local diff", ["diff local"], "platform", 495),
        ("5 Dry run", ["--dry-run=server"], "govern", 705),
        ("6 Live diff", ["diff upgrade"], "govern", 855),
        ("7 Manifest", ["get manifest"], "govern", 1005),
    ]
    for i, (t, ln, k, x) in enumerate(rungs):
        s.box(x, 150, 135, 90, t, ln, kind=k)
        if i not in (3, 6):
            s.arrow(x + 135, 195, x + 150, 195, kind="neutral")
    s.arrow(630, 195, 705, 195, kind="neutral")
    s.label(45, 290, "Catches: schema violations, template errors,", size=14)
    s.label(45, 310, "invalid YAML, deprecated APIs, wrong field types.", size=14)
    s.label(710, 290, "Catches: admission, defaulting, unknown kinds,", size=14)
    s.label(710, 310, "drift from the live release.", size=14)
    s.label(45, 360, "Cheap and fast: run on every commit", size=14, color=PALETTE["muted"])
    s.label(710, 360, "Needs credentials: run in a gated stage", size=14, color=PALETTE["muted"])
    s.label(620, 450, "A fault that slips past one rung is usually caught by the next.", size=15, anchor="middle", color=PALETTE["neutral"])
    s.write()


def test_pyramid():
    s = Scene("h201-test-pyramid", W, 510)
    cx = 520
    layers = [
        (360, 60, "helm test, ct install", ["real cluster, real pods"], "rest"),
        (600, 190, "kubeconform, --dry-run=server", ["schemas and API admission"], "govern"),
        (840, 320, "helm-unittest, helm lint --strict", ["pure rendering, no cluster"], "platform"),
    ]
    for w, y, t, ln, k in layers:
        s.box(cx - w / 2, y, w, 100, t, ln, kind=k)
    s.arrow(985, 400, 985, 100, kind="neutral")
    s.label(1000, 110, "Fewer, slower,", size=14)
    s.label(1000, 128, "closer to prod", size=14)
    s.label(1000, 390, "Many, fast,", size=14)
    s.label(1000, 408, "run on every save", size=14)
    s.label(cx, 470, "Each layer asserts something the layer below cannot see.", size=15, anchor="middle", color=PALETTE["neutral"])
    s.write()


def umbrella():
    s = Scene("h201-umbrella", W, 550)
    s.panel(30, 40, 1180, 350)
    s.label(50, 70, "shipping-platform: umbrella chart, release name platform", size=15, weight="bold", color=PALETTE["rest"])
    s.box(60, 100, 240, 80, "shipping-service", ["alias: shipping", "condition: shipping.enabled"], kind="svc")
    s.box(380, 100, 240, 80, "notification-service", ["alias: notification", "tags: [messaging]"], kind="svc")
    s.box(60, 250, 240, 80, "shipping-postgres", ["alias: db", "condition: db.enabled"], kind="data")
    s.box(380, 250, 240, 80, "shipping-kafka", ["alias: kafka", "tags: [messaging]"], kind="data")
    s.arrow(180, 250, 180, 180, kind="data", dashed=True)
    s.label(190, 220, "import-values", size=13, color=PALETTE["data"])
    s.arrow(500, 250, 500, 180, kind="data", dashed=True)
    s.label(510, 220, "import-values", size=13, color=PALETTE["data"])
    s.arrow(400, 250, 290, 180, kind="data", dashed=True)
    s.label(660, 120, "global: environment, otlpEndpoint,", size=14, color=PALETTE["neutral"])
    s.label(660, 142, "imageRegistry reach every subchart.", size=14, color=PALETTE["neutral"])
    s.label(660, 190, "--set tags.messaging=false drops", size=14, color=PALETTE["neutral"])
    s.label(660, 212, "notification and kafka in one flag.", size=14, color=PALETTE["neutral"])
    s.label(660, 260, "import-values cannot override a key", size=14, color=PALETTE["danger"])
    s.label(660, 282, "the subchart defaults in its own values.yaml.", size=14, color=PALETTE["danger"])
    s.box(60, 450, 240, 80, "CloudNativePG", ["operator, cnpg-system"], kind="platform")
    s.box(380, 450, 240, 80, "Strimzi", ["operator, strimzi"], kind="platform")
    s.arrow(180, 450, 180, 330, kind="platform")
    s.arrow(500, 450, 500, 330, kind="platform")
    s.label(190, 400, "runs the Cluster CR", size=13, color=PALETTE["platform"])
    s.label(510, 400, "runs the Kafka CR", size=13, color=PALETTE["platform"])
    s.label(660, 480, "The chart declares the custom resources;", size=14)
    s.label(660, 502, "operators installed once per cluster run them.", size=14)
    s.write()


def library_charts():
    s = Scene("h201-library-charts", W, 530)
    s.box(40, 120, 260, 90, "shipping-service", ["87 lines of templates", "was 295"], kind="svc")
    s.box(40, 290, 260, 90, "notification-service", ["16 lines of templates", "was 224"], kind="svc")
    s.box(450, 190, 300, 120, "pc-lib", ["type: library", "deployment, service, otelEnv,", "fullname, probes, securityContext"], kind="govern")
    s.box(900, 190, 300, 120, "Rendered manifests", ["identical to the pre-refactor", "output (diff verified)"], kind="platform")
    s.arrow(300, 165, 450, 235, kind="neutral", label="include", label_offset=-8, label_dx=8)
    s.arrow(300, 335, 450, 270, kind="neutral", label="include", label_offset=18, label_dx=8)
    s.arrow(750, 250, 900, 250, kind="neutral", label="helm template")
    s.code_block(450, 380, 750, 130, ["dependencies:", "\u00a0\u00a0- name: pc-lib", "\u00a0\u00a0\u00a0\u00a0version: 0.17.0", "\u00a0\u00a0\u00a0\u00a0repository: file://../pc-lib"], lang="yaml")
    s.label(40, 440, "A library chart renders nothing alone:", size=14, color=PALETTE["danger"])
    s.label(40, 466, "helm install fails with", size=14, color=PALETTE["danger"])
    s.label(40, 492, "'library charts are not installable'.", size=14, color=PALETTE["danger"])
    s.write()


def oci_flow():
    s = Scene("h201-oci-flow", W, 490)
    s.box(30, 90, 190, 80, "helm package", ["shipping-service-1.0.0.tgz"], kind="neutral")
    s.box(290, 90, 190, 80, "helm push", ["oci://host/charts"], kind="neutral")
    s.box(550, 60, 290, 310, "OCI registry", ["one repository, several artifacts"], kind="data")
    s.box(575, 130, 240, 62, "charts/shipping-service", ["tag 1.0.0, sha256:..."], kind="data")
    s.box(575, 208, 240, 62, "cosign signature", ["tag sha256-....sig"], kind="govern")
    s.box(575, 288, 240, 52, "chart .prov (optional)", [], kind="govern")
    s.box(910, 60, 290, 80, "helm pull / show", ["--version 1.0.0 or @sha256:..."], kind="neutral")
    s.box(910, 210, 290, 80, "helm upgrade --install", ["from oci://...@sha256:..."], kind="svc")
    s.box(910, 360, 290, 80, "Cluster", ["release Secret, revision 1"], kind="platform")
    s.arrow(220, 130, 290, 130, kind="neutral")
    s.arrow(480, 130, 550, 130, kind="neutral", label="push", label_offset=-10)
    s.arrow(840, 100, 910, 100, kind="neutral")
    s.arrow(840, 250, 910, 250, kind="neutral")
    s.arrow(1055, 290, 1055, 360, kind="neutral")
    s.box(290, 230, 190, 70, "cosign sign", ["key over the digest"], kind="govern")
    s.arrow(480, 265, 575, 240, kind="govern")
    s.label(40, 430, "Pin by digest: a tag can move, a digest cannot.", size=15, color=PALETTE["neutral"])
    s.label(40, 462, "Local registry on plain HTTP needs --plain-http.", size=14, color=PALETTE["muted"])
    s.write()


def post_renderer():
    s = Scene("h201-post-renderer", W, 530)
    s.box(30, 190, 210, 100, "helm template", ["or install, upgrade", "--post-renderer NAME"], kind="neutral")
    s.box(320, 190, 210, 100, "Rendered YAML", ["all manifests, one stream"], kind="svc")
    s.box(610, 160, 300, 160, "Plugin: postrenderer/v1", ["reads stdin", "kustomize edit, patches, labels", "writes stdout"], kind="govern")
    s.box(990, 190, 210, 100, "Modified YAML", ["labels, annotations added"], kind="svc")
    s.arrow(240, 240, 320, 240, kind="neutral")
    s.arrow(530, 240, 610, 240, kind="neutral", label="stdin", label_offset=-10)
    s.arrow(910, 240, 990, 240, kind="neutral", label="stdout", label_offset=-10)
    s.box(990, 380, 210, 80, "Kubernetes API", ["server-side apply"], kind="platform")
    s.arrow(1095, 290, 1095, 380, kind="platform")
    s.panel(30, 380, 900, 130)
    s.label(50, 412, "Helm 4: post-renderers are plugins only; a bare executable path is rejected.", size=14)
    s.label(50, 438, "Extra arguments go through --post-renderer-args.", size=14)
    s.label(50, 464, "The chart stays untouched: use it for a change you do not own the templates for.", size=14)
    s.write()


def env_promotion():
    s = Scene("h201-env-promotion", W, 545)
    s.box(470, 70, 300, 90, "Chart in OCI registry", ["shipping-platform 1.0.0"], kind="data")
    s.panel(40, 220, 1160, 310)
    s.label(60, 482, "Values layers, last file wins", size=15, weight="bold", color=PALETTE["neutral"])
    envs = [("dev", "values-dev.yaml", "pins/dev.yaml"), ("stage", "values-stage.yaml", "pins/stage.yaml"), ("prod", "values-prod.yaml", "pins/prod.yaml")]
    x = 70
    for name, a, b in envs:
        s.box(x, 290, 300, 130, "release in " + name, ["values.yaml (base)", a, b], kind="svc" if name != "prod" else "rest")
        x += 380
    s.arrow(370, 355, 450, 355, kind="govern", label="promote", label_offset=-10)
    s.arrow(750, 355, 830, 355, kind="govern", label="promote", label_offset=-10)
    s.label(60, 504, "Promotion is a pin change: chart version and image digest move from one pins file to the next.", size=14)
    s.arrow(620, 160, 220, 290, kind="neutral")
    s.arrow(620, 160, 600, 290, kind="neutral")
    s.arrow(620, 160, 980, 290, kind="neutral")
    s.write()


def gitops():
    s = Scene("h201-gitops", W, 540)
    s.box(40, 100, 250, 100, "Git or OCI source", ["Application manifest", "chart + valuesObject"], kind="data")
    s.box(400, 80, 340, 160, "Argo CD", ["repo server: helm template", "application controller: sync", "hooks become sync phases"], kind="rest")
    s.box(850, 100, 300, 100, "Cluster", ["live resources"], kind="platform")
    s.arrow(290, 150, 400, 150, kind="neutral", label="watch", label_offset=-10)
    s.arrow(740, 150, 850, 150, kind="neutral", label="apply", label_offset=-10)
    s.arrow(850, 190, 740, 190, kind="neutral", dashed=True)
    s.label(795, 215, "diff", size=13, anchor="middle")
    s.panel(40, 300, 1110, 220)
    s.label(60, 335, "What changes compared with helm install", size=15, weight="bold", color=PALETTE["neutral"])
    s.label(60, 370, "No Helm release Secret: helm list shows nothing for an Argo-managed app.", size=14)
    s.label(60, 400, "Argo renders with helm template and applies the output itself.", size=14)
    s.label(60, 430, "helm.sh/hook-weight maps to argocd.argoproj.io/sync-wave; --wait has no counterpart.", size=14)
    s.label(60, 460, "Drift is reconciled continuously instead of at the next upgrade.", size=14)
    s.write()


def telemetry_path():
    s = Scene("h201-telemetry-path", W, 530)
    s.box(30, 90, 220, 80, "shipping-service", ["OTEL_* from pc-lib"], kind="svc")
    s.box(30, 240, 220, 80, "notification-service", ["OTEL_* from pc-lib"], kind="svc")
    s.box(340, 150, 220, 90, "OTel Collector", ["observability ns", "OTLP :4318"], kind="platform")
    s.box(660, 50, 200, 70, "Tempo", ["traces"], kind="data")
    s.box(660, 150, 200, 70, "Loki", ["logs"], kind="data")
    s.box(660, 250, 200, 70, "Mimir", ["metrics"], kind="data")
    s.box(960, 140, 230, 90, "Grafana", ["dashboard ConfigMap", "loaded by sidecar"], kind="rest")
    s.arrow(250, 130, 340, 185, kind="neutral", label="OTLP", label_offset=-14, label_dx=6)
    s.arrow(250, 280, 340, 215, kind="neutral")
    s.arrow(560, 175, 660, 85, kind="neutral")
    s.arrow(560, 195, 660, 185, kind="neutral")
    s.arrow(560, 215, 660, 285, kind="neutral")
    s.arrow(860, 85, 960, 175, kind="neutral")
    s.arrow(860, 185, 960, 185, kind="neutral")
    s.arrow(860, 285, 960, 205, kind="neutral")
    s.panel(30, 380, 1160, 130)
    s.label(50, 412, "global.otlpEndpoint is set once on the umbrella; pc-lib.otelEnv turns it into env vars for every service.", size=14)
    s.label(50, 440, "Empty endpoint renders OTEL_SDK_DISABLED=true, so the same chart runs without a collector.", size=14)
    s.label(50, 468, "A trace crosses Kafka: the dispatch span in shipping links to the consume span in notification.", size=14)
    s.write()


SCENES = [debug_ladder, test_pyramid, umbrella, library_charts, oci_flow, post_renderer, env_promotion, gitops, telemetry_path]
