#!/usr/bin/env python3
"""Chapter 0 diagram: the build-up arc. Run from the repo root."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import generate_diagram as g

g.OUT = "assets/diagrams"

W, H = 1040, 420
bands = [
    dict(x=20, y=20, w=1000, h=110, label="Parts 1 to 3: from manifests to a tested chart", fill="#fafafa"),
    dict(x=20, y=150, w=1000, h=110, label="Parts 4 and 5: multi-service charts, then packaging (read right to left)", fill="#fafafa"),
    dict(x=20, y=280, w=1000, h=120, label="Parts 5 to 7: registry, trust, extension, delivery", fill="#fafafa"),
]
nodes = [
    dict(x=40, y=52, w=210, h=64, style="muted", lines=["Raw manifests", "ch03: the problem"]),
    dict(x=290, y=52, w=210, h=64, style="box", lines=["shipping-service chart", "ch04 to ch08"]),
    dict(x=540, y=52, w=210, h=64, style="box", lines=["+ Postgres subchart, CRDs", "ch09, ch10"]),
    dict(x=790, y=52, w=210, h=64, style="accent", lines=["Hooks, lifecycle, tests", "ch11 to ch14"]),

    dict(x=790, y=182, w=210, h=64, style="box", lines=["+ Kafka, notification", "ch15"]),
    dict(x=540, y=182, w=210, h=64, style="box", lines=["Umbrella chart", "ch16"]),
    dict(x=290, y=182, w=210, h=64, style="box", lines=["Library chart, starter", "ch17, ch18"]),
    dict(x=40, y=182, w=210, h=64, style="accent", lines=["Version 1.0.0 package", "ch19"]),

    dict(x=40, y=322, w=210, h=64, style="box", lines=["OCI registry", "ch20"]),
    dict(x=290, y=322, w=210, h=64, style="box", lines=["Signed artifact", "ch21: .prov, cosign"]),
    dict(x=540, y=322, w=210, h=64, style="box", lines=["Plugins, post-renderers", "ch22, ch23"]),
    dict(x=790, y=322, w=210, h=64, style="ink", lines=["Environments, Argo CD", "ch24 to ch26"]),
]
edges = [
    dict(x1=250, y1=84, x2=290, y2=84), dict(x1=500, y1=84, x2=540, y2=84), dict(x1=750, y1=84, x2=790, y2=84),
    dict(x1=790, y1=214, x2=750, y2=214), dict(x1=540, y1=214, x2=500, y2=214), dict(x1=290, y1=214, x2=250, y2=214),
    dict(x1=250, y1=354, x2=290, y2=354), dict(x1=500, y1=354, x2=540, y2=354), dict(x1=750, y1=354, x2=790, y2=354),
    dict(x1=895, y1=116, x2=895, y2=182, amber=True),
    dict(x1=145, y1=246, x2=145, y2=322, amber=True),
]
g.emit("00-build-up-arc", W, H, bands=bands, nodes=nodes, edges=edges)
