"""Chapter 09 diagram: the shipping-service chart with its shipping-postgres subchart."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import generate_diagram as g

g.OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "diagrams")

g.emit(
    "09-subchart-tree", 920, 430,
    bands=[
        {"x": 20, "y": 20, "w": 560, "h": 390, "label": "Release shipping (one helm upgrade --install)", "fill": "#fafafa"},
        {"x": 600, "y": 20, "w": 300, "h": 390, "label": "In the cluster", "fill": "#fafafa"},
    ],
    nodes=[
        {"x": 50, "y": 60, "w": 200, "h": 70, "style": "accent",
         "lines": ["shipping-service", "Chart.yaml: dependencies", "condition: shipping-postgres.enabled"]},
        {"x": 330, "y": 60, "w": 210, "h": 70, "style": "info",
         "lines": ["shipping-postgres", "file://../shipping-postgres", "templates/cluster.yaml"]},
        {"x": 50, "y": 190, "w": 200, "h": 70, "style": "box",
         "lines": ["Parent values", "postgres.host   (no default)", "postgres.existingSecret"]},
        {"x": 330, "y": 190, "w": 210, "h": 70, "style": "box",
         "lines": ["Child values: exports", "postgres.host: shipping-postgres-rw", "existingSecret: shipping-postgres-app"]},
        {"x": 50, "y": 320, "w": 200, "h": 70, "style": "sub",
         "lines": ["Deployment", "env PG_HOST, PG_PASSWORD", "password read from the Secret"]},
        {"x": 330, "y": 320, "w": 210, "h": 70, "style": "sub",
         "lines": ["Cluster", "CNPG custom resource", "rendered by the subchart"]},
        {"x": 630, "y": 60, "w": 240, "h": 70, "style": "muted",
         "lines": ["CloudNativePG operator", "installed once per cluster"]},
        {"x": 630, "y": 190, "w": 240, "h": 70, "style": "box",
         "lines": ["Service shipping-postgres-rw", "Secret shipping-postgres-app"]},
        {"x": 630, "y": 320, "w": 240, "h": 70, "style": "box",
         "lines": ["Pod shipping-postgres-1", "database shipping"]},
    ],
    edges=[
        {"x1": 250, "y1": 95, "x2": 330, "y2": 95, "label": "depends on", "lx": 0, "ly": -10, "amber": True},
        {"x1": 330, "y1": 225, "x2": 250, "y2": 225, "label": "import-values", "lx": 0, "ly": -10, "amber": True},
        {"x1": 435, "y1": 130, "x2": 435, "y2": 190, "dashed": True},
        {"x1": 150, "y1": 260, "x2": 150, "y2": 320, "label": "env", "lx": 18, "ly": 0},
        {"x1": 435, "y1": 260, "x2": 435, "y2": 320},
        {"x1": 540, "y1": 355, "x2": 630, "y2": 355, "label": "creates", "lx": 0, "ly": -10},
        {"x1": 750, "y1": 130, "x2": 750, "y2": 190, "label": "reconciles", "lx": 30, "ly": 0, "dashed": True},
        {"x1": 750, "y1": 260, "x2": 750, "y2": 320},
    ],
    notes=[],
)
