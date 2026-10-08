import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import generate_diagram as g
g.OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "diagrams")

# Figure 6.1 - render pipeline
bands = [{"x": 20, "y": 20, "w": 300, "h": 250, "label": "inputs"}]
nodes = [
    {"x": 40, "y": 50, "w": 260, "h": 50, "style": "box", "lines": [".Values", "chart defaults + -f + --set"]},
    {"x": 40, "y": 112, "w": 260, "h": 50, "style": "box", "lines": [".Release  .Chart", "name, namespace, version"]},
    {"x": 40, "y": 174, "w": 260, "h": 50, "style": "sub", "lines": [".Capabilities  .Files", "cluster API versions, chart files"]},
    {"x": 380, "y": 90, "w": 190, "h": 110, "style": "ink", "lines": ["Go template engine", "Sprig functions", "include, tpl, required"]},
    {"x": 640, "y": 50, "w": 200, "h": 56, "style": "accent", "lines": ["YAML documents", "one per template file"]},
    {"x": 640, "y": 140, "w": 200, "h": 56, "style": "info", "lines": ["YAML parse + API check", "manifest validation"]},
    {"x": 640, "y": 226, "w": 200, "h": 56, "style": "box", "lines": ["API server", "install or upgrade"]},
]
edges = [
    {"x1": 300, "y1": 75, "x2": 380, "y2": 120},
    {"x1": 300, "y1": 137, "x2": 380, "y2": 145},
    {"x1": 300, "y1": 199, "x2": 380, "y2": 170},
    {"x1": 570, "y1": 130, "x2": 640, "y2": 80, "amber": True},
    {"x1": 740, "y1": 106, "x2": 740, "y2": 140},
    {"x1": 740, "y1": 196, "x2": 740, "y2": 226},
]
notes = [{"x": 475, "y": 250, "text": "helm template stops after the YAML step", "anchor": "middle", "size": 12, "color": "#555555"}]
g.emit("06-render-pipeline", 870, 300, bands, nodes, edges, notes)
