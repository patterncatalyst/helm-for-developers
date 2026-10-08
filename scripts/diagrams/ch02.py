#!/usr/bin/env python3
"""Chapter 2 diagram: Helm is a client; state lives in the cluster. Run from the repo root."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import generate_diagram as g

g.OUT = "assets/diagrams"

W, H = 1040, 380
bands = [
    dict(x=20, y=20, w=300, h=340, label="OCI registry (ghcr.io)", fill="#fafafa"),
    dict(x=370, y=20, w=300, h=340, label="Your machine", fill="#fafafa"),
    dict(x=720, y=20, w=300, h=340, label="Kubernetes cluster", fill="#fafafa"),
]
nodes = [
    dict(x=40, y=60, w=260, h=70, style="box", lines=["Chart artifact", "podinfo 6.15.0, pinned by tag"]),
    dict(x=40, y=160, w=260, h=60, style="muted", lines=["Chart.yaml, values.yaml", "templates/"]),

    dict(x=390, y=60, w=260, h=70, style="accent", lines=["helm 4.3.0 (client only)", "no server component in the cluster"]),
    dict(x=390, y=160, w=260, h=60, style="sub", lines=["values and --set", "your overrides"]),
    dict(x=390, y=250, w=260, h=60, style="sub", lines=["content cache", "HELM_CACHE_HOME"]),

    dict(x=740, y=60, w=260, h=70, style="box", lines=["Rendered objects", "Service, Deployment, test pods"]),
    dict(x=740, y=160, w=260, h=70, style="info", lines=["Release record", "Secret sh.helm.release.v1.NAME.vN"]),
    dict(x=740, y=260, w=260, h=60, style="sub", lines=["Namespace hfd-02", "release scope"]),
]
edges = [
    dict(x1=300, y1=95, x2=390, y2=95, label="1. pull", ly=-8),
    dict(x1=650, y1=95, x2=740, y2=95, amber=True, label="2. apply", ly=-8),
    dict(x1=650, y1=195, x2=740, y2=195, dashed=True, label="3. record", ly=-8),
    dict(x1=170, y1=130, x2=170, y2=160, dashed=True),
]
g.emit("02-helm-architecture", W, H, bands=bands, nodes=nodes, edges=edges)
