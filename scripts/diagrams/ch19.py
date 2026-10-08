#!/usr/bin/env python3
"""Chapter 19 diagram: chart version vs appVersion, from Chart.yaml to a classic repository."""
import os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import generate_diagram as g
g.OUT = os.path.join(ROOT, "assets", "diagrams")

g.emit(
    "19-semver-chart-vs-app", 980, 360,
    bands=[
        {"x": 20, "y": 20, "w": 300, "h": 320, "label": "Chart.yaml (source)"},
        {"x": 350, "y": 20, "w": 290, "h": 320, "label": "helm package"},
        {"x": 670, "y": 20, "w": 290, "h": 320, "label": "Classic repository (127.0.0.1:8088)"},
    ],
    nodes=[
        {"x": 40, "y": 60, "w": 260, "h": 70, "style": "accent", "lines": ["version: 1.0.0", "the chart: templates + values contract", "--version overrides"]},
        {"x": 40, "y": 160, "w": 260, "h": 70, "style": "info", "lines": ["appVersion: \"0.1.0\"", "the app: image tag default", "--app-version overrides"]},
        {"x": 40, "y": 260, "w": 260, "h": 60, "style": "sub", "lines": ["dependencies: pc-lib 1.0.0", "--dependency-update fills charts/"]},
        {"x": 370, "y": 140, "w": 250, "h": 80, "style": "box", "lines": ["shipping-service-1.0.0.tgz", "file name = chart version", "pc-lib embedded in charts/"]},
        {"x": 690, "y": 60, "w": 250, "h": 70, "style": "box", "lines": ["index.yaml", "version, appVersion, digest, urls", "from: helm repo index --url"]},
        {"x": 690, "y": 160, "w": 250, "h": 60, "style": "sub", "lines": ["shipping-service-1.0.0.tgz", "served by python3 -m http.server"]},
        {"x": 690, "y": 260, "w": 250, "h": 60, "style": "ink", "lines": ["helm repo add / update", "helm search repo --versions"]},
    ],
    edges=[
        {"x1": 300, "y1": 95, "x2": 370, "y2": 165},
        {"x1": 300, "y1": 195, "x2": 370, "y2": 185},
        {"x1": 300, "y1": 290, "x2": 370, "y2": 210},
        {"x1": 620, "y1": 170, "x2": 690, "y2": 190, "amber": True},
        {"x1": 620, "y1": 160, "x2": 690, "y2": 100, "amber": True},
        {"x1": 815, "y1": 220, "x2": 815, "y2": 260, "label": "fetch", "lx": 24},
    ],
)
