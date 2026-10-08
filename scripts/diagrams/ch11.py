"""Chapter 11 diagram: hook timeline and the --wait deadlock."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import generate_diagram as g

g.OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "diagrams")

g.emit(
    "11-hook-timeline", 940, 380,
    bands=[
        {"x": 20, "y": 20, "w": 900, "h": 140, "label": "Option A: pre-install hook (database must already exist)", "fill": "#fafafa"},
        {"x": 20, "y": 180, "w": 900, "h": 180, "label": "Option B: post-install hook (database created by this release)", "fill": "#fafafa"},
    ],
    nodes=[
        {"x": 50, "y": 70, "w": 190, "h": 70, "style": "accent",
         "lines": ["pre-install hook", "Job: python -m app.migrate"]},
        {"x": 290, "y": 70, "w": 190, "h": 70, "style": "box",
         "lines": ["Release resources", "Deployment, Service, ..."]},
        {"x": 530, "y": 70, "w": 190, "h": 70, "style": "muted",
         "lines": ["Release stored", "status deployed"]},
        {"x": 740, "y": 70, "w": 150, "h": 70, "style": "ghost",
         "lines": ["Fails on a fresh", "in-release database"]},
        {"x": 50, "y": 230, "w": 190, "h": 70, "style": "box",
         "lines": ["Release resources", "Cluster, Deployment, ..."]},
        {"x": 290, "y": 230, "w": 190, "h": 70, "style": "box",
         "lines": ["--wait: all ready?", "readiness probe on /healthz"]},
        {"x": 530, "y": 230, "w": 190, "h": 70, "style": "accent",
         "lines": ["post-install hook", "Job: python -m app.migrate"]},
        {"x": 740, "y": 230, "w": 150, "h": 70, "style": "ghost",
         "lines": ["Deadlock if /healthz", "needs the tables"]},
    ],
    edges=[
        {"x1": 240, "y1": 105, "x2": 290, "y2": 105, "amber": True, "label": "waits for Job", "lx": 0, "ly": -10},
        {"x1": 480, "y1": 105, "x2": 530, "y2": 105},
        {"x1": 720, "y1": 105, "x2": 740, "y2": 105, "dashed": True},
        {"x1": 240, "y1": 265, "x2": 290, "y2": 265},
        {"x1": 480, "y1": 265, "x2": 530, "y2": 265, "amber": True, "label": "only when ready", "lx": 0, "ly": -10},
        {"x1": 720, "y1": 265, "x2": 740, "y2": 265, "dashed": True},
    ],
    notes=[
        {"x": 470, "y": 335, "text": "the probe never passes until the hook runs, and the hook never runs until the probe passes", "anchor": "middle", "size": 12, "color": "#555555"},
    ],
)
