#!/usr/bin/env python3
"""Chapter 23 diagram: where a postrenderer/v1 plugin sits in the render pipeline."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import generate_diagram as g
g.OUT = os.path.join(ROOT, "assets", "diagrams")

bands = [{"x": 20, "y": 20, "w": 880, "h": 265, "label": "helm template / install / upgrade", "fill": "#fafafa"}]
nodes = [
    {"x": 40, "y": 70, "w": 150, "h": 70, "style": "box", "lines": ["Chart + values", "templates render"]},
    {"x": 240, "y": 70, "w": 150, "h": 70, "style": "box", "lines": ["Rendered YAML", "all objects, one stream"]},
    {"x": 440, "y": 60, "w": 200, "h": 90, "style": "accent", "lines": ["kustomize-postrender", "postrenderer/v1", "stdin to stdout"]},
    {"x": 690, "y": 70, "w": 190, "h": 70, "style": "box", "lines": ["Modified YAML", "labels, annotation"]},
    {"x": 440, "y": 200, "w": 200, "h": 50, "style": "info", "lines": ["kubectl kustomize", "labels + JSON patch"]},
]
edges = [
    {"x1": 190, "y1": 105, "x2": 240, "y2": 105},
    {"x1": 390, "y1": 105, "x2": 440, "y2": 105, "amber": True, "label": "stdin", "lx": 0, "ly": -8},
    {"x1": 640, "y1": 105, "x2": 690, "y2": 105, "amber": True, "label": "stdout", "lx": 0, "ly": -8},
    {"x1": 500, "y1": 150, "x2": 500, "y2": 200},
    {"x1": 580, "y1": 200, "x2": 580, "y2": 150},
]
notes = [{"x": 785, "y": 195, "text": "install or upgrade: stored in the release", "anchor": "middle", "size": 11, "color": "#555555"},
         {"x": 785, "y": 212, "text": "template: printed to stdout", "anchor": "middle", "size": 11, "color": "#555555"}]
g.emit("23-post-render-pipeline", 920, 300, bands, nodes, edges, notes)
