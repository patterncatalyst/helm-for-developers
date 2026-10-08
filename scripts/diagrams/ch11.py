"""Chapter 11 diagram: hook timeline and the --wait deadlock."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import generate_diagram as g

g.OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "diagrams")

g.emit(
    "11-hook-timeline", 1000, 440,
    bands=[
        {"x": 20, "y": 20, "w": 960, "h": 195, "label": "Option A: pre-install hook (database must already exist)", "fill": "#fafafa"},
        {"x": 20, "y": 235, "w": 960, "h": 185, "label": "Option B: post-install hook (database created by this release)", "fill": "#fafafa"},
    ],
    nodes=[
        {"x": 50, "y": 50, "w": 180, "h": 70, "style": "accent",
         "lines": ["pre-install hook", "Job: python -m app.migrate"]},
        {"x": 330, "y": 50, "w": 180, "h": 70, "style": "box",
         "lines": ["Release resources", "Deployment, Service, ..."]},
        {"x": 610, "y": 50, "w": 180, "h": 70, "style": "muted",
         "lines": ["Release stored", "status deployed"]},
        {"x": 50, "y": 150, "w": 280, "h": 50, "style": "ghost",
         "lines": ["Hook fails: release aborted", "database created by this release does not exist yet"]},
        {"x": 50, "y": 275, "w": 180, "h": 70, "style": "box",
         "lines": ["Release resources", "Cluster, Deployment, ..."]},
        {"x": 330, "y": 275, "w": 180, "h": 70, "style": "box",
         "lines": ["--wait: all ready?", "readiness probe on /healthz"]},
        {"x": 610, "y": 275, "w": 180, "h": 70, "style": "accent",
         "lines": ["post-install hook", "Job: python -m app.migrate"]},
        {"x": 815, "y": 275, "w": 155, "h": 70, "style": "ghost",
         "lines": ["Deadlock", "if /healthz needs the tables"]},
    ],
    edges=[
        {"x1": 230, "y1": 85, "x2": 330, "y2": 85, "amber": True, "label": "waits for Job", "lx": 0, "ly": -10},
        {"x1": 510, "y1": 85, "x2": 610, "y2": 85},
        {"x1": 140, "y1": 120, "x2": 140, "y2": 150, "dashed": True},
        {"x1": 230, "y1": 310, "x2": 330, "y2": 310},
        {"x1": 510, "y1": 310, "x2": 610, "y2": 310, "amber": True, "label": "only when ready", "lx": 0, "ly": -10},
        {"x1": 790, "y1": 310, "x2": 815, "y2": 310, "dashed": True},
    ],
    notes=[
        {"x": 500, "y": 395, "text": "the probe never passes until the hook runs, and the hook never runs until the probe passes", "anchor": "middle", "size": 12, "color": "#555555"},
    ],
)
