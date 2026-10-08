import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import generate_diagram as g
g.OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "diagrams")

# Figure 5.1 - values precedence
nodes = [
    {"x": 20, "y": 60, "w": 170, "h": 80, "style": "muted", "lines": ["values.yaml", "chart defaults", "lowest"]},
    {"x": 215, "y": 60, "w": 170, "h": 80, "style": "box", "lines": ["-f values-dev.yaml", "first file"]},
    {"x": 410, "y": 60, "w": 170, "h": 80, "style": "box", "lines": ["-f values-prod.yaml", "later file wins"]},
    {"x": 605, "y": 60, "w": 170, "h": 80, "style": "accent", "lines": ["--set, --set-string", "--set-file, --set-json", "highest"]},
    {"x": 215, "y": 220, "w": 360, "h": 70, "style": "ink", "lines": [".Values", "merged map handed to the templates"]},
    {"x": 620, "y": 220, "w": 155, "h": 70, "style": "info", "lines": ["values.schema.json", "validates the result"]},
]
edges = [
    {"x1": 190, "y1": 100, "x2": 215, "y2": 100, "amber": True},
    {"x1": 385, "y1": 100, "x2": 410, "y2": 100, "amber": True},
    {"x1": 580, "y1": 100, "x2": 605, "y2": 100, "amber": True},
    {"x1": 105, "y1": 140, "x2": 260, "y2": 220},
    {"x1": 300, "y1": 140, "x2": 340, "y2": 220},
    {"x1": 495, "y1": 140, "x2": 450, "y2": 220},
    {"x1": 690, "y1": 140, "x2": 540, "y2": 220},
    {"x1": 575, "y1": 255, "x2": 620, "y2": 255, "dashed": True},
]
notes = [{"x": 400, "y": 30, "text": "Maps merge key by key; lists and scalars are replaced whole", "anchor": "middle", "size": 13, "color": "#555555"}]
g.emit("05-values-precedence", 800, 320, [], nodes, edges, notes)
