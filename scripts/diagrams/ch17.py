#!/usr/bin/env python3
"""Chapter 17 diagram: one library chart consumed by the service charts."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import generate_diagram as g
g.OUT = os.path.join(ROOT, "assets", "diagrams")

bands = [
    {"x": 20, "y": 20, "w": 940, "h": 150, "label": "pc-lib (type: library)  named templates only, never rendered on its own", "fill": "#fafafa"},
    {"x": 20, "y": 230, "w": 940, "h": 150, "label": "consumers (dependencies: pc-lib, file://../pc-lib)", "fill": "#fafafa"},
]
nodes = [
    {"x": 50, "y": 70, "w": 130, "h": 70, "style": "accent", "lines": ["deployment", "service"]},
    {"x": 200, "y": 70, "w": 130, "h": 70, "style": "accent", "lines": ["labels", "fullname"]},
    {"x": 350, "y": 70, "w": 130, "h": 70, "style": "accent", "lines": ["probes", "image"]},
    {"x": 500, "y": 70, "w": 130, "h": 70, "style": "accent", "lines": ["security", "otelEnv"]},
    {"x": 650, "y": 70, "w": 280, "h": 70, "style": "info", "lines": ["metadataAnnotations", "domain, owner, data-product"]},
    {"x": 50, "y": 280, "w": 260, "h": 70, "style": "box", "lines": ["shipping-service", "env, secrets, migration Job"]},
    {"x": 350, "y": 280, "w": 260, "h": 70, "style": "box", "lines": ["notification-service", "env: KAFKA_BOOTSTRAP"]},
    {"x": 650, "y": 280, "w": 280, "h": 70, "style": "ghost", "lines": ["next service (starter)", "only what is specific to it"]},
]
edges = [
    {"x1": 180, "y1": 170, "x2": 180, "y2": 280, "label": "include", "amber": True},
    {"x1": 480, "y1": 170, "x2": 480, "y2": 280, "label": "include", "amber": True},
    {"x1": 790, "y1": 170, "x2": 790, "y2": 280, "label": "include", "amber": True, "dashed": True},
]
notes = [
    {"x": 490, "y": 405, "text": "Fix a probe or a label once in pc-lib; every consumer picks it up on its next dependency build.", "anchor": "middle", "size": 12, "color": "#888888"},
]
g.emit("17-library-reuse", 980, 425, bands, nodes, edges, notes)
