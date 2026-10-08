#!/usr/bin/env python3
"""Chapter 24 diagram: promotion flow. Run from the repo root."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import generate_diagram as g

g.OUT = "assets/diagrams"

W, H = 1040, 400
bands = [
    dict(x=20, y=20, w=1000, h=110, label="Build once", fill="#fafafa"),
    dict(x=20, y=150, w=1000, h=230, label="Promote by editing pins in Git: one release per environment, one namespace each", fill="#fafafa"),
]
nodes = [
    dict(x=40, y=52, w=220, h=64, style="box", lines=["helm package", "shipping-platform 1.0.0"]),
    dict(x=300, y=52, w=220, h=64, style="box", lines=["helm push", "oci:// registry"]),
    dict(x=560, y=52, w=220, h=64, style="box", lines=["Image build", "tag + sha256 digest"]),
    dict(x=820, y=52, w=180, h=64, style="muted", lines=["No rebuild", "between environments"]),

    dict(x=40, y=190, w=290, h=84, style="info", lines=["dev   (hfd-24-dev)", "values-dev.yaml + pins/dev.yaml", "follows the new version first"]),
    dict(x=375, y=190, w=290, h=84, style="box", lines=["stage   (hfd-24-stage)", "values-stage.yaml + pins/stage.yaml", "version bump, 2 replicas"]),
    dict(x=710, y=190, w=290, h=84, style="accent", lines=["prod   (hfd-24-prod)", "values-prod.yaml + pins/prod.yaml", "version bump, tag@digest"]),
    dict(x=375, y=304, w=290, h=56, style="ghost", lines=["helmfile.yaml", "version: lines are the promotion record"]),
]
edges = [
    dict(x1=260, y1=84, x2=300, y2=84), dict(x1=520, y1=84, x2=560, y2=84),
    dict(x1=330, y1=232, x2=375, y2=232, amber=True, label="promote"),
    dict(x1=665, y1=232, x2=710, y2=232, amber=True, label="promote"),
    dict(x1=410, y1=116, x2=185, y2=190, dashed=True),
    dict(x1=520, y1=304, x2=520, y2=274, dashed=True),
]
g.emit("24-promotion-flow", W, H, bands=bands, nodes=nodes, edges=edges)
