#!/usr/bin/env python3
"""Chapter 22 diagram: plugin types and runtimes, and how `helm <name>` dispatches."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import generate_diagram as g
g.OUT = os.path.join(ROOT, "assets", "diagrams")

bands = [
    {"x": 20, "y": 20, "w": 250, "h": 300, "label": "plugin directory", "fill": "#fafafa"},
    {"x": 330, "y": 20, "w": 250, "h": 300, "label": "Helm 4 plugin loader", "fill": "#fafafa"},
    {"x": 640, "y": 20, "w": 250, "h": 300, "label": "runtime", "fill": "#fafafa"},
]
nodes = [
    {"x": 40, "y": 70, "w": 210, "h": 70, "style": "accent", "lines": ["plugin.yaml", "apiVersion v1, type, name", "runtime, runtimeConfig"]},
    {"x": 40, "y": 190, "w": 210, "h": 80, "style": "sub", "lines": ["entry point", "shipping-env.sh (subprocess)", "plugin.wasm (extism/v1)"]},
    {"x": 350, "y": 90, "w": 210, "h": 150, "style": "box", "lines": ["reads plugin.yaml", "cli/v1: helm NAME ...", "postrenderer/v1: --post-renderer NAME", "getter/v1: chart downloads"]},
    {"x": 660, "y": 60, "w": 210, "h": 90, "style": "box", "lines": ["subprocess", "platformCommand, args,", "HELM_* env vars"]},
    {"x": 660, "y": 190, "w": 210, "h": 90, "style": "box", "lines": ["extism/v1 (Wasm)", "helm_plugin_main, JSON in/out,", "memory and timeout limits"]},
]
edges = [
    {"x1": 250, "y1": 105, "x2": 350, "y2": 130},
    {"x1": 250, "y1": 230, "x2": 350, "y2": 200},
    {"x1": 560, "y1": 130, "x2": 660, "y2": 105, "amber": True},
    {"x1": 560, "y1": 200, "x2": 660, "y2": 235, "amber": True},
]
g.emit("22-plugin-types", 910, 340, bands, nodes, edges, [])
