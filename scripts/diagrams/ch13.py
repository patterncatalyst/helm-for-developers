#!/usr/bin/env python3
"""Chapter 13 diagram: the debug ladder, from checks that need no cluster to checks that do."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import generate_diagram as g
g.OUT = os.path.join(ROOT, "assets", "diagrams")

bands = [
    {"x": 20, "y": 20, "w": 940, "h": 170, "label": "no cluster needed (CI-safe)", "fill": "#fafafa"},
    {"x": 20, "y": 230, "w": 940, "h": 170, "label": "needs a cluster (the API server is the validator)", "fill": "#fafafa"},
]
nodes = [
    {"x": 40, "y": 60, "w": 200, "h": 100, "style": "accent", "lines": ["1. helm lint --strict", "schema errors, YAML errors,", "deprecated APIs"]},
    {"x": 270, "y": 60, "w": 200, "h": 100, "style": "box", "lines": ["2. helm template", "--debug --show-only", "template errors, rendered text"]},
    {"x": 500, "y": 60, "w": 200, "h": 100, "style": "box", "lines": ["3. kubeconform", "field types and names,", "CRs via the CRDs-catalog"]},
    {"x": 730, "y": 60, "w": 210, "h": 100, "style": "box", "lines": ["4. helm diff local", "what a values or", "template change does"]},
    {"x": 40, "y": 270, "w": 270, "h": 100, "style": "info", "lines": ["5. --dry-run=server", "admission, defaulting,", "unknown kinds, immutable fields"]},
    {"x": 355, "y": 270, "w": 270, "h": 100, "style": "info", "lines": ["6. helm diff upgrade", "live release vs new chart", "(manifests Helm stored)"]},
    {"x": 670, "y": 270, "w": 270, "h": 100, "style": "info", "lines": ["7. helm get manifest", "what the cluster was sent,", "feed it back to kubeconform"]},
]
edges = [
    {"x1": 240, "y1": 110, "x2": 270, "y2": 110, "amber": True},
    {"x1": 470, "y1": 110, "x2": 500, "y2": 110, "amber": True},
    {"x1": 700, "y1": 110, "x2": 730, "y2": 110, "amber": True},
    {"x1": 835, "y1": 160, "x2": 300, "y2": 270, "amber": True, "label": "promote the chart"},
    {"x1": 310, "y1": 320, "x2": 355, "y2": 320},
    {"x1": 625, "y1": 320, "x2": 670, "y2": 320},
]
g.emit("13-debug-ladder", 980, 420, bands, nodes, edges, [])
