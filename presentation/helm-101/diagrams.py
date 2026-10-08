"""
diagrams.py - Helm 101 deck diagrams (SVG + Excalidraw + PNG).

Scene ids use the h101-* prefix. Colors follow the deck: svc=blue (clients,
workloads), rest=red (Helm itself), data=purple (release state), platform=teal
(cluster/registry), govern=amber (policy, hooks), danger=deep red (failure).
"""
from dgen import Scene, PALETTE


# ---------------------------------------------------------------------------
# 1 - YAML sprawl vs one chart
# ---------------------------------------------------------------------------
def h101_yaml_sprawl():
    s = Scene("h101-yaml-sprawl", 1240, 560,
              title="Raw manifests versus one chart",
              subtitle="Three environments: nine files to keep in step, or one template and three small override files")
    # left: sprawl
    s.panel(40, 110, 540, 400)
    s.label(310, 140, "Raw manifests", size=15, weight="bold", anchor="middle", color=PALETTE["danger"])
    envs = ["dev/", "stage/", "prod/"]
    for i, e in enumerate(envs):
        x = 52 + i * 174
        s.box(x, 175, 166, 40, e, kind="danger", mono=True)
        for j, f in enumerate(["configmap.yaml", "deployment.yaml", "service.yaml"]):
            s.box(x, 235 + j * 52, 166, 40, f, kind="neutral", mono=True)
    s.label(310, 440, "9 files, copied and edited per environment", size=13, anchor="middle", color=PALETTE["neutral"])
    s.label(310, 464, "A fix in one file must be repeated in two more", size=13, anchor="middle", color=PALETTE["neutral"])
    # right: chart
    s.panel(600, 110, 600, 400)
    s.label(900, 140, "One chart", size=15, weight="bold", anchor="middle", color=PALETTE["platform"])
    s.box(608, 175, 584, 100, "shipping-service/", ["Chart.yaml  values.yaml", "templates/ configmap, deployment, service"], kind="rest", mono=True)
    for i, f in enumerate(["values-dev.yaml", "values-stage.yaml", "values-prod.yaml"]):
        x = 608 + i * 197
        s.box(x, 335, 190, 44, f, kind="govern", mono=True)
        s.arrow(x + 95, 335, 900, 275, kind="neutral")
    s.label(900, 440, "3 override files hold only the differences", size=13, anchor="middle", color=PALETTE["neutral"])
    s.label(900, 464, "helm install -f values-prod.yaml", size=13, anchor="middle", mono=True, color=PALETTE["neutral"])
    s.write()


# ---------------------------------------------------------------------------
# 2 - client-only architecture
# ---------------------------------------------------------------------------
def h101_client_architecture():
    s = Scene("h101-client-architecture", 1240, 520,
              title="Helm 4 is a client",
              subtitle="No server component: the release record is a Secret in the release namespace")
    s.box(40, 170, 280, 130, "OCI registry", ["ghcr.io/stefanprodan/charts", "podinfo:6.15.0"], kind="platform")
    s.box(480, 150, 280, 170, "Helm 4 client", ["merge values, render templates", "validate, apply, record", "content cache on disk"], kind="rest")
    s.panel(880, 110, 330, 330)
    s.label(1045, 140, "Kubernetes cluster", size=14, weight="bold", anchor="middle", color=PALETTE["neutral"])
    s.box(910, 165, 270, 80, "Rendered objects", ["Deployment, Service, ConfigMap"], kind="svc")
    s.box(910, 280, 270, 100, "Release Secret", ["sh.helm.release.v1.podinfo.v1", "chart, values, manifest, status"], kind="data", mono=False)
    s.arrow(320, 235, 480, 235, kind="neutral", label="helm pull")
    s.arrow(760, 210, 910, 210, kind="neutral", label="server-side apply", label_offset=-10)
    s.arrow(760, 300, 910, 300, kind="neutral", label="record", label_offset=-8)
    s.label(620, 400, "helm list reads the Secrets", size=13, anchor="middle", color=PALETTE["neutral"])
    s.label(620, 424, "so any machine with access sees the releases", size=13, anchor="middle", color=PALETTE["neutral"])
    s.write()


# ---------------------------------------------------------------------------
# 3 - revisions
# ---------------------------------------------------------------------------
def h101_revisions():
    s = Scene("h101-revisions", 1240, 520,
              title="Release revisions",
              subtitle="Every install, upgrade and rollback writes one revision; a rollback adds a revision and rewinds nothing")
    xs = [60, 460, 860]
    cmds = ["helm install", "helm upgrade --set replicaCount=2", "helm rollback shipping 1"]
    desc = ["Install complete", "Upgrade complete", "Rollback to 1: the contents of revision 1"]
    kinds = ["rest", "rest", "govern"]
    for i, x in enumerate(xs):
        s.label(x + 160, 130, cmds[i], size=13, anchor="middle", mono=True, color=PALETTE["neutral"])
        s.box(x, 160, 320, 90, "revision %d" % (i + 1), [desc[i]], kind=kinds[i])
        s.box(x, 300, 320, 70, "sh.helm.release.v1.shipping.v%d" % (i + 1), kind="data", mono=True)
        s.arrow(x + 160, 250, x + 160, 300, kind="neutral")
    s.arrow(380, 205, 460, 205, kind="neutral")
    s.arrow(780, 205, 860, 205, kind="neutral")
    s.panel(60, 410, 1120, 70)
    s.label(620, 440, "helm history lists 1 superseded, 2 superseded, 3 deployed", size=13, anchor="middle", color=PALETTE["neutral"])
    s.label(620, 462, "--history-max (default 10) prunes the oldest", size=13, anchor="middle", color=PALETTE["neutral"])
    s.write()


# ---------------------------------------------------------------------------
# 4 - values precedence
# ---------------------------------------------------------------------------
def h101_values_precedence():
    s = Scene("h101-values-precedence", 1240, 520,
              title="Values precedence",
              subtitle="Lowest priority on the left; maps merge key by key, lists and scalars are replaced whole")
    items = [
        ("values.yaml", ["chart defaults"], "neutral"),
        ("-f values-prod.yaml", ["files, left to right"], "svc"),
        ("--set and variants", ["--set-string, --set-json,", "--set-file, --set-literal"], "govern"),
    ]
    xs = [40, 330, 620]
    for (t, ln, k), x in zip(items, xs):
        s.box(x, 170, 230, 100, t, ln, kind=k, mono=True)
    s.arrow(270, 220, 330, 220, kind="neutral")
    s.arrow(560, 220, 620, 220, kind="neutral")
    s.label(155, 310, "priority 1", size=12, anchor="middle", color=PALETTE["muted"])
    s.label(445, 310, "priority 2", size=12, anchor="middle", color=PALETTE["muted"])
    s.label(735, 310, "priority 3", size=12, anchor="middle", color=PALETTE["muted"])
    s.box(920, 130, 280, 90, ".Values", ["one merged map"], kind="rest", mono=True)
    s.box(920, 270, 280, 90, "values.schema.json", ["validates the merged map"], kind="platform", mono=True)
    s.arrow(850, 220, 920, 190, kind="neutral")
    s.arrow(1060, 220, 1060, 270, kind="neutral")
    s.panel(40, 380, 1160, 100)
    s.label(60, 415, "--set replicaCount=5 beats replicaCount: 3 in values-prod.yaml", size=13, mono=True, color=PALETTE["neutral"])
    s.label(60, 445, "-f values-prod.yaml -f values-dev.yaml: the later file wins", size=13, mono=True, color=PALETTE["neutral"])
    s.write()


# ---------------------------------------------------------------------------
# 5 - subchart and operator
# ---------------------------------------------------------------------------
def h101_subchart_tree():
    s = Scene("h101-subchart-tree", 1240, 560,
              title="Postgres through a subchart",
              subtitle="The operator creates the credentials; the parent chart only references them")
    s.box(40, 150, 300, 130, "shipping-service", ["parent chart", "dependencies: shipping-postgres"], kind="rest", mono=True)
    s.box(40, 360, 300, 110, "shipping-postgres", ["subchart in charts/", "renders one Cluster"], kind="platform", mono=True)
    s.arrow(190, 360, 190, 280, kind="neutral", label="import-values", label_offset=4, label_dx=12)
    s.box(480, 130, 300, 100, "Deployment", ["PG_HOST = shipping-postgres-rw", "PG_PASSWORD from secretKeyRef"], kind="svc")
    s.box(480, 360, 300, 110, "Cluster (CNPG)", ["postgresql.cnpg.io/v1"], kind="data", mono=True)
    s.box(880, 130, 300, 100, "Secret shipping-postgres-app", ["dbname, username, password"], kind="data")
    s.box(880, 360, 300, 110, "CloudNativePG operator", ["installed once per cluster"], kind="platform")
    s.arrow(340, 180, 480, 180, kind="neutral", label="renders", label_offset=-8)
    s.arrow(340, 415, 480, 415, kind="neutral", label="renders", label_offset=-8)
    s.arrow(880, 180, 780, 180, kind="neutral", label="secretKeyRef", label_offset=-8)
    s.arrow(880, 415, 780, 415, kind="neutral", label="reconciles", label_offset=-8)
    s.arrow(1030, 360, 1030, 230, kind="neutral", label="creates", label_offset=4, label_dx=12)
    s.write()


# ---------------------------------------------------------------------------
# 6 - hook timeline
# ---------------------------------------------------------------------------
def h101_hook_timeline():
    s = Scene("h101-hook-timeline", 1240, 600,
              title="Where the migration hook runs",
              subtitle="Placement decides whether a fresh install completes")
    # option A
    s.label(40, 125, "A  pre-install,pre-upgrade", size=15, weight="bold", color=PALETTE["neutral"], mono=True)
    s.box(40, 150, 240, 80, "Migration Job", ["runs first"], kind="govern")
    s.box(340, 150, 260, 80, "Cluster + Secret", ["created by the same release"], kind="data")
    s.box(660, 150, 240, 80, "Deployment", ["waits for readiness"], kind="svc")
    s.arrow(280, 190, 340, 190, kind="neutral")
    s.arrow(600, 190, 660, 190, kind="neutral")
    s.label(960, 175, "Job pod references a Secret that", size=13, color=PALETTE["danger"])
    s.label(960, 197, "does not exist yet: it never starts", size=13, color=PALETTE["danger"])
    # option B
    s.label(40, 305, "B  post-install,post-upgrade with --wait", size=15, weight="bold", color=PALETTE["neutral"], mono=True)
    s.box(40, 330, 240, 80, "Resources applied", ["Cluster, Deployment"], kind="svc")
    s.box(340, 330, 260, 80, "Wait for ready", ["kstatus watcher"], kind="platform")
    s.box(660, 330, 240, 80, "Migration Job", ["runs after the wait"], kind="govern")
    s.arrow(280, 370, 340, 370, kind="neutral")
    s.arrow(600, 370, 660, 370, kind="neutral")
    s.label(960, 355, "/healthz needs the tables, so the", size=13, color=PALETTE["danger"])
    s.label(960, 377, "wait never ends: deadlock", size=13, color=PALETTE["danger"])
    s.panel(40, 460, 1160, 100)
    s.label(60, 495, "Fix used in the chart: post-install hook, readiness probe on /health (no database call)", size=13, color=PALETTE["neutral"])
    s.label(60, 523, "pre-install fits an external database that already exists", size=13, color=PALETTE["neutral"])
    s.write()


SCENES = [
    h101_yaml_sprawl,
    h101_client_architecture,
    h101_revisions,
    h101_values_precedence,
    h101_subchart_tree,
    h101_hook_timeline,
]


if __name__ == "__main__":
    for fn in SCENES:
        fn()
        print(f"  built {fn.__name__}")
