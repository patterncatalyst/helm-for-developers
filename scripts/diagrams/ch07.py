import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import generate_diagram as g
g.OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "diagrams")

# Figure 7.1 - named templates
bands = [{"x": 20, "y": 20, "w": 330, "h": 330, "label": "templates/_helpers.tpl (renders no output)"}]
nodes = [
    {"x": 40, "y": 55, "w": 290, "h": 52, "style": "box", "lines": ["shipping-service.name", "chart name, overridable"]},
    {"x": 40, "y": 120, "w": 290, "h": 52, "style": "box", "lines": ["shipping-service.fullname", "release-chart, truncated to 63"]},
    {"x": 40, "y": 185, "w": 290, "h": 52, "style": "accent", "lines": ["shipping-service.selectorLabels", "name + instance, immutable"]},
    {"x": 40, "y": 250, "w": 290, "h": 52, "style": "accent", "lines": ["shipping-service.labels", "selectorLabels + chart, version, managed-by"]},
    {"x": 520, "y": 60, "w": 220, "h": 56, "style": "info", "lines": ["configmap.yaml", "name, labels"]},
    {"x": 520, "y": 140, "w": 220, "h": 56, "style": "info", "lines": ["service.yaml", "name, labels, selector"]},
    {"x": 520, "y": 220, "w": 220, "h": 56, "style": "info", "lines": ["deployment.yaml", "name, labels, selector, pod labels"]},
]
edges = [
    {"x1": 330, "y1": 146, "x2": 520, "y2": 88, "amber": True, "label": "include", "lx": 10, "ly": -4},
    {"x1": 330, "y1": 146, "x2": 520, "y2": 168, "amber": True},
    {"x1": 330, "y1": 146, "x2": 520, "y2": 248, "amber": True},
    {"x1": 330, "y1": 276, "x2": 520, "y2": 100},
    {"x1": 330, "y1": 211, "x2": 520, "y2": 180},
]
g.emit("07-named-templates", 780, 370, bands, nodes, edges, [])
