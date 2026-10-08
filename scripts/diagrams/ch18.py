#!/usr/bin/env python3
"""Chapter 18 diagram: from starter to a buildable chart."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import generate_diagram as g
g.OUT = os.path.join(ROOT, "assets", "diagrams")

bands = [
    {"x": 20, "y": 20, "w": 940, "h": 330, "label": "helm create --starter pc-fastapi charts/inventory-service", "fill": "#fafafa"},
]
nodes = [
    {"x": 50, "y": 70, "w": 230, "h": 90, "style": "info", "lines": ["$HELM_DATA_HOME/starters/", "pc-fastapi", "templates, values, schema, ci"]},
    {"x": 375, "y": 70, "w": 230, "h": 90, "style": "accent", "lines": ["charts/inventory-service", "Chart.yaml rewritten by Helm", "<CHARTNAME> replaced"]},
    {"x": 700, "y": 70, "w": 230, "h": 90, "style": "box", "lines": ["pc-lib-dependency.yaml", "dependencies: pc-lib", "ships beside Chart.yaml"]},
    {"x": 375, "y": 230, "w": 230, "h": 70, "style": "accent", "lines": ["Chart.yaml with dependencies", "after cat ... >> Chart.yaml"]},
    {"x": 700, "y": 230, "w": 230, "h": 70, "style": "ink", "lines": ["helm dependency build", "charts/pc-lib-0.18.0.tgz"]},
]
edges = [
    {"x1": 280, "y1": 115, "x2": 375, "y2": 115, "label": "copy", "amber": True},
    {"x1": 605, "y1": 115, "x2": 700, "y2": 115, "label": "also copied"},
    {"x1": 815, "y1": 160, "x2": 605, "y2": 250, "label": "append", "amber": True, "lx": 20, "ly": -10},
    {"x1": 605, "y1": 265, "x2": 700, "y2": 265, "amber": True},
]
notes = []
g.emit("18-starter-flow", 980, 370, bands, nodes, edges, notes)
