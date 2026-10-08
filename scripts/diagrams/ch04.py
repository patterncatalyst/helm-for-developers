import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import generate_diagram as g
g.OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "diagrams")

# Figure 4.1 - chart directory to rendered manifests
bands = [{"x": 20, "y": 20, "w": 330, "h": 330, "label": "shipping-service/ (the chart)"},
         {"x": 560, "y": 20, "w": 310, "h": 330, "label": "Kubernetes API server"}]
nodes = [
    {"x": 40, "y": 55, "w": 290, "h": 56, "style": "box", "lines": ["Chart.yaml", "name, version 0.4.0, appVersion 0.1.0"]},
    {"x": 40, "y": 125, "w": 290, "h": 56, "style": "box", "lines": ["values.yaml", "replicaCount, image, service"]},
    {"x": 40, "y": 195, "w": 290, "h": 56, "style": "accent", "lines": ["templates/", "deployment, service, configmap"]},
    {"x": 40, "y": 265, "w": 290, "h": 56, "style": "muted", "lines": [".helmignore", "files left out of the package"]},
    {"x": 400, "y": 125, "w": 130, "h": 130, "style": "ink", "lines": ["helm", "render +", "install"]},
    {"x": 580, "y": 60, "w": 270, "h": 60, "style": "box", "lines": ["Deployment, Service, ConfigMap", "owned by release shipping"]},
    {"x": 580, "y": 150, "w": 270, "h": 60, "style": "info", "lines": ["Secret sh.helm.release.v1.shipping.v1", "the release record (revision 1)"]},
]
edges = [
    {"x1": 330, "y1": 83, "x2": 400, "y2": 170, "amber": False},
    {"x1": 330, "y1": 153, "x2": 400, "y2": 190},
    {"x1": 330, "y1": 223, "x2": 400, "y2": 210, "amber": True},
    {"x1": 530, "y1": 170, "x2": 580, "y2": 90, "amber": True},
    {"x1": 530, "y1": 210, "x2": 580, "y2": 180},
]
notes = [{"x": 715, "y": 260, "text": "Release state lives in the cluster,", "anchor": "middle", "size": 12, "color": "#555555"},
         {"x": 715, "y": 278, "text": "next to the workload. No server component.", "anchor": "middle", "size": 12, "color": "#555555"}]
g.emit("04-chart-anatomy", 890, 370, bands, nodes, edges, notes)

# Figure 4.2 - release revisions
nodes = []
edges = []
labels = [("1", "install", "replicas 1", "superseded"), ("2", "upgrade", "replicas 2", "superseded"), ("3", "rollback to 1", "replicas 1", "deployed")]
for i, (rev, act, det, st) in enumerate(labels):
    x = 40 + i * 290
    nodes.append({"x": x, "y": 60, "w": 220, "h": 90, "style": "accent" if st == "deployed" else "box",
                  "lines": [f"revision {rev}", act, det + ", " + st]})
    nodes.append({"x": x, "y": 200, "w": 220, "h": 50, "style": "info", "lines": [f"sh.helm.release.v1.shipping.v{rev}", "Secret, type helm.sh/release.v1"]})
    edges.append({"x1": x + 110, "y1": 150, "x2": x + 110, "y2": 200, "dashed": True})
    if i < 2:
        edges.append({"x1": x + 220, "y1": 105, "x2": x + 290, "y2": 105, "amber": True, "label": "helm upgrade" if i == 0 else "helm rollback 1", "ly": -10})
notes = [{"x": 460, "y": 290, "text": "A rollback writes a new revision with the old content; history only grows (default cap 10 per release).", "anchor": "middle", "size": 12, "color": "#555555"}]
g.emit("04-release-revisions", 920, 310, [], nodes, edges, notes)
