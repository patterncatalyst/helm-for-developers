"""Chapter 10 diagram: who owns the CRD, the operator and the custom resources."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import generate_diagram as g

g.OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "diagrams")

g.emit(
    "10-crd-ownership", 920, 440,
    bands=[
        {"x": 20, "y": 20, "w": 880, "h": 120, "label": "Application chart (shipping-service)", "fill": "#fafafa"},
        {"x": 20, "y": 160, "w": 880, "h": 120, "label": "Helm actions on crds/", "fill": "#fafafa"},
        {"x": 20, "y": 300, "w": 880, "h": 120, "label": "Platform (installed by someone else)", "fill": "#fafafa"},
    ],
    nodes=[
        {"x": 50, "y": 55, "w": 240, "h": 65, "style": "accent",
         "lines": ["crds/shippingroute.yaml", "plain YAML, never templated"]},
        {"x": 340, "y": 55, "w": 240, "h": 65, "style": "box",
         "lines": ["templates/", "may contain custom resources"]},
        {"x": 630, "y": 55, "w": 240, "h": 65, "style": "info",
         "lines": ["shipping-postgres guard", "Capabilities.APIVersions.Has + fail"]},
        {"x": 50, "y": 195, "w": 240, "h": 65, "style": "box",
         "lines": ["helm install", "applies the CRD, once"]},
        {"x": 340, "y": 195, "w": 240, "h": 65, "style": "muted",
         "lines": ["helm upgrade", "skips crds/ entirely"]},
        {"x": 630, "y": 195, "w": 200, "h": 65, "style": "muted",
         "lines": ["helm uninstall", "leaves the CRD and its objects"]},
        {"x": 50, "y": 335, "w": 240, "h": 65, "style": "sub",
         "lines": ["CRD in the API server", "owned by the cluster from now on"]},
        {"x": 340, "y": 335, "w": 240, "h": 65, "style": "box",
         "lines": ["kubectl apply -f crds/", "the supported way to change a CRD"]},
        {"x": 630, "y": 335, "w": 240, "h": 65, "style": "ink",
         "lines": ["CloudNativePG operator", "serves postgresql.cnpg.io/v1"]},
    ],
    edges=[
        {"x1": 170, "y1": 120, "x2": 170, "y2": 195, "amber": True},
        {"x1": 170, "y1": 260, "x2": 170, "y2": 335, "amber": True, "label": "creates", "lx": 26, "ly": 0},
        {"x1": 460, "y1": 335, "x2": 460, "y2": 260, "dashed": True},
        {"x1": 855, "y1": 120, "x2": 855, "y2": 335, "dashed": True, "label": "checks the API", "lx": 0, "ly": -79},
    ],
    notes=[],
)
