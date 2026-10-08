#!/usr/bin/env python3
"""Chapter 16 diagram: umbrella chart topology with aliases, conditions, tags and imported values."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import generate_diagram as g
g.OUT = os.path.join(ROOT, "assets", "diagrams")

bands = [
    {"x": 20, "y": 20, "w": 940, "h": 410, "label": "shipping-platform (release platform)", "fill": "#fafafa"},
]
nodes = [
    {"x": 290, "y": 60, "w": 400, "h": 50, "style": "ink", "lines": ["global: environment, otlpEndpoint, imageRegistry"]},
    {"x": 50, "y": 150, "w": 220, "h": 70, "style": "accent", "lines": ["shipping", "condition: shipping.enabled"]},
    {"x": 710, "y": 150, "w": 220, "h": 70, "style": "accent", "lines": ["notification", "tags: messaging"]},
    {"x": 50, "y": 290, "w": 220, "h": 70, "style": "info", "lines": ["db (shipping-postgres)", "condition: db.enabled"]},
    {"x": 380, "y": 290, "w": 220, "h": 70, "style": "info", "lines": ["kafka (shipping-kafka)", "tags: messaging"]},
    {"x": 710, "y": 290, "w": 220, "h": 70, "style": "ghost", "lines": ["Install order", "is not dependency order"]},
]
edges = [
    {"x1": 380, "y1": 110, "x2": 200, "y2": 150, "dashed": True},
    {"x1": 600, "y1": 110, "x2": 780, "y2": 150, "dashed": True},
    {"x1": 160, "y1": 290, "x2": 160, "y2": 220, "label": "import-values: host, Secret", "amber": True, "lx": 70, "ly": 0},
    {"x1": 440, "y1": 290, "x2": 270, "y2": 200, "label": "bootstrap", "amber": True, "lx": -10, "ly": -4},
    {"x1": 540, "y1": 290, "x2": 710, "y2": 200, "label": "bootstrap", "amber": True, "lx": 10, "ly": -4},
]
notes = [
    {"x": 490, "y": 400, "text": "Dashed: global values flow to every subchart. Helm applies all rendered resources together; ordering comes from hooks and readiness.", "anchor": "middle", "size": 12, "color": "#888888"},
]
g.emit("16-umbrella-topology", 980, 450, bands, nodes, edges, notes)
