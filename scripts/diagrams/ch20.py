#!/usr/bin/env python3
"""Chapter 20 diagram: the OCI push/pull flow and what a chart artifact contains."""
import os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import generate_diagram as g
g.OUT = os.path.join(ROOT, "assets", "diagrams")

g.emit(
    "20-oci-flow", 980, 380,
    bands=[
        {"x": 20, "y": 20, "w": 250, "h": 340, "label": "Host"},
        {"x": 300, "y": 20, "w": 400, "h": 340, "label": "OCI registry (127.0.0.1:5001, plain HTTP)"},
        {"x": 730, "y": 20, "w": 230, "h": 340, "label": "Consumers"},
    ],
    nodes=[
        {"x": 40, "y": 60, "w": 210, "h": 60, "style": "box", "lines": ["shipping-service-1.0.0.tgz", "helm package output"]},
        {"x": 40, "y": 170, "w": 210, "h": 60, "style": "accent", "lines": ["helm registry login", "credentials in registry/config.json"]},
        {"x": 40, "y": 280, "w": 210, "h": 60, "style": "sub", "lines": ["registry:2 container", "-p 127.0.0.1:5001:5000"]},
        {"x": 320, "y": 60, "w": 360, "h": 70, "style": "box", "lines": ["charts/shipping-service:1.0.0 (tag)", "manifest digest sha256:... (what you pin)"]},
        {"x": 320, "y": 160, "w": 170, "h": 70, "style": "info", "lines": ["config layer", "helm.config.v1+json"]},
        {"x": 510, "y": 160, "w": 170, "h": 70, "style": "info", "lines": ["chart layer", "helm.chart.content.v1 tgz"]},
        {"x": 320, "y": 260, "w": 360, "h": 60, "style": "ghost", "lines": ["optional .prov layer", "added when the .tgz was signed (chapter 21)"]},
        {"x": 750, "y": 60, "w": 190, "h": 60, "style": "box", "lines": ["helm pull / show", "oci://.../shipping-service"]},
        {"x": 750, "y": 160, "w": 190, "h": 60, "style": "ink", "lines": ["helm install", "oci://...@sha256:..."]},
        {"x": 750, "y": 260, "w": 190, "h": 60, "style": "sub", "lines": ["helm dependency update", "repository: oci://..."]},
    ],
    edges=[
        {"x1": 250, "y1": 90, "x2": 320, "y2": 95, "amber": True, "label": "helm push", "ly": -8},
        {"x1": 250, "y1": 200, "x2": 320, "y2": 112, "dashed": True, "label": "authenticates", "lx": -20, "ly": -14},
        {"x1": 250, "y1": 310, "x2": 298, "y2": 310, "dashed": True, "label": "serves", "lx": 0, "ly": -8},
        {"x1": 500, "y1": 130, "x2": 405, "y2": 160},
        {"x1": 600, "y1": 130, "x2": 595, "y2": 160},
        {"x1": 680, "y1": 95, "x2": 750, "y2": 90},
        {"x1": 680, "y1": 110, "x2": 750, "y2": 190},
        {"x1": 680, "y1": 120, "x2": 750, "y2": 285},
    ],
)
