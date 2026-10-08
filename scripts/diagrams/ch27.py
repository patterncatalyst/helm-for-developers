#!/usr/bin/env python3
"""Chapter 27 diagrams: the OpenShift Local deployment path and the Route gate."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import generate_diagram as g
g.OUT = os.path.join(ROOT, "assets", "diagrams")

# 27-openshift-deploy: host -> registry -> release -> pods, plus Route in front.
g.emit("27-openshift-deploy", 980, 400,
    bands=[
        {"x": 20, "y": 40, "w": 230, "h": 320, "label": "CRC host", "fill": "#fafafa"},
        {"x": 280, "y": 40, "w": 680, "h": 320, "label": "OpenShift Local cluster, project hfd-ocp", "fill": "#fafafa"},
    ],
    nodes=[
        {"x": 40, "y": 80, "w": 190, "h": 62, "style": "box", "lines": ["podman build + push", "default-route, oc whoami -t"]},
        {"x": 40, "y": 190, "w": 190, "h": 62, "style": "accent", "lines": ["helm upgrade --install", "-f values-openshift.yaml"]},
        {"x": 40, "y": 285, "w": 190, "h": 52, "style": "sub", "lines": ["curl -k https://<route>", "/api/info"]},
        {"x": 310, "y": 80, "w": 200, "h": 62, "style": "info", "lines": ["Internal registry", "hfd-ocp/shipping-service:0.1.0"]},
        {"x": 310, "y": 190, "w": 200, "h": 62, "style": "accent", "lines": ["Release platform", "Secrets sh.helm.release.v1"]},
        {"x": 560, "y": 285, "w": 170, "h": 52, "style": "box", "lines": ["Route", "edge TLS, Redirect"]},
        {"x": 760, "y": 285, "w": 170, "h": 52, "style": "box", "lines": ["Service", "ClusterIP, port http"]},
        {"x": 700, "y": 80, "w": 240, "h": 110, "style": "ink", "lines": ["Pods", "SCC restricted-v2", "UID from project range", "GID 0, no runAsUser"]},
    ],
    edges=[
        {"x1": 230, "y1": 111, "x2": 310, "y2": 111, "label": "push", "lx": 0, "ly": -8},
        {"x1": 230, "y1": 221, "x2": 310, "y2": 221, "label": "install"},
        {"x1": 510, "y1": 111, "x2": 700, "y2": 111, "label": "image pull", "amber": True, "lx": 0, "ly": -8},
        {"x1": 510, "y1": 221, "x2": 760, "y2": 190, "label": "creates"},
        {"x1": 230, "y1": 311, "x2": 560, "y2": 311, "dashed": True, "label": "HTTPS", "lx": 0, "ly": -8},
        {"x1": 730, "y1": 311, "x2": 760, "y2": 311},
        {"x1": 845, "y1": 285, "x2": 845, "y2": 190},
    ],
    notes=[{"x": 490, "y": 385, "text": "Routes render only where route.openshift.io/v1 is served", "anchor": "middle", "size": 12, "color": "#555555"}])
