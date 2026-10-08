#!/usr/bin/env python3
"""Chapter 14 diagram: the chart test pyramid and where each layer runs."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import generate_diagram as g
g.OUT = os.path.join(ROOT, "assets", "diagrams")

bands = [
    {"x": 20, "y": 20, "w": 940, "h": 400, "label": "chart test pyramid", "fill": "#fafafa"},
]
nodes = [
    {"x": 380, "y": 50, "w": 200, "h": 70, "style": "info", "lines": ["ct install + helm test", "real cluster, seconds to minutes"]},
    {"x": 300, "y": 140, "w": 360, "h": 70, "style": "accent", "lines": ["kubeconform", "rendered manifests against API schemas"]},
    {"x": 220, "y": 230, "w": 520, "h": 70, "style": "box", "lines": ["ct lint", "Chart.yaml schema, yamllint, helm lint on every ci/*-values.yaml"]},
    {"x": 140, "y": 320, "w": 680, "h": 70, "style": "box", "lines": ["helm-unittest", "templates plus values in, assertions out; milliseconds"]},
]
notes = [
    {"x": 600, "y": 90, "text": "manual or nightly job", "anchor": "start", "size": 12, "color": "#2f6db5", "bold": True},
    {"x": 690, "y": 180, "text": "every pull request", "anchor": "start", "size": 12, "color": "#b8650a", "bold": True},
    {"x": 770, "y": 270, "text": "every pull request", "anchor": "start", "size": 12, "color": "#b8650a", "bold": True},
    {"x": 850, "y": 360, "text": "every push", "anchor": "start", "size": 12, "color": "#b8650a", "bold": True},
    {"x": 130, "y": 100, "text": "few, slow", "anchor": "end", "size": 12, "color": "#888888"},
    {"x": 130, "y": 360, "text": "many, fast", "anchor": "end", "size": 12, "color": "#888888"},
]
g.emit("14-test-pyramid", 980, 440, bands, nodes, [], notes)
