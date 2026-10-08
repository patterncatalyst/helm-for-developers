#!/usr/bin/env python3
"""Chapter 21 diagram: two trust chains over the same chart (PGP .prov and cosign)."""
import os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import generate_diagram as g
g.OUT = os.path.join(ROOT, "assets", "diagrams")

g.emit(
    "21-trust-chain", 980, 400,
    bands=[
        {"x": 20, "y": 20, "w": 940, "h": 170, "label": "Chain 1: Helm provenance (PGP), covers the .tgz bytes"},
        {"x": 20, "y": 210, "w": 940, "h": 170, "label": "Chain 2: cosign (key pair), covers the registry manifest digest"},
    ],
    nodes=[
        {"x": 40, "y": 60, "w": 190, "h": 80, "style": "box", "lines": ["shipping-service-1.0.0.tgz", "sha256:f8d507..."]},
        {"x": 280, "y": 60, "w": 190, "h": 80, "style": "accent", "lines": ["helm package --sign", "legacy secring.gpg"]},
        {"x": 520, "y": 60, "w": 190, "h": 80, "style": "info", "lines": [".tgz.prov", "Chart.yaml + files: sha256"]},
        {"x": 760, "y": 60, "w": 180, "h": 80, "style": "ink", "lines": ["helm verify / --verify", "pubring.kbx or .gpg"]},
        {"x": 40, "y": 250, "w": 190, "h": 80, "style": "box", "lines": ["oci://127.0.0.1:5001/signed", "manifest sha256:..."]},
        {"x": 280, "y": 250, "w": 190, "h": 80, "style": "accent", "lines": ["cosign sign --key", "cosign.key, by digest"]},
        {"x": 520, "y": 250, "w": 190, "h": 80, "style": "info", "lines": ["signature artifact", "tag sha256-<digest>"]},
        {"x": 760, "y": 250, "w": 180, "h": 80, "style": "ink", "lines": ["cosign verify --key", "cosign.pub"]},
    ],
    edges=[
        {"x1": 230, "y1": 100, "x2": 280, "y2": 100},
        {"x1": 470, "y1": 100, "x2": 520, "y2": 100},
        {"x1": 710, "y1": 100, "x2": 760, "y2": 100},
        {"x1": 230, "y1": 290, "x2": 280, "y2": 290},
        {"x1": 470, "y1": 290, "x2": 520, "y2": 290},
        {"x1": 710, "y1": 290, "x2": 760, "y2": 290},
    ],
    notes=[{"x": 490, "y": 200, "text": "helm push uploads the .prov as a layer of the same artifact the cosign signature then points at", "anchor": "middle", "size": 11}],
)
