"""Chapter 12 diagram: upgrade failure paths."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import generate_diagram as g

g.OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "diagrams")

g.emit(
    "12-upgrade-failure-paths", 960, 470,
    bands=[
        {"x": 20, "y": 20, "w": 920, "h": 430, "label": "helm upgrade", "fill": "#fafafa"},
    ],
    nodes=[
        {"x": 50, "y": 60, "w": 190, "h": 70, "style": "box",
         "lines": ["Render and apply", "server-side apply, hooks"]},
        {"x": 290, "y": 60, "w": 210, "h": 70, "style": "box",
         "lines": ["Wait", "--wait=watcher | hookOnly | legacy"]},
        {"x": 550, "y": 60, "w": 160, "h": 70, "style": "info",
         "lines": ["Ready in --timeout", "revision deployed"]},
        {"x": 760, "y": 60, "w": 150, "h": 70, "style": "muted",
         "lines": ["Old revision", "superseded"]},
        {"x": 300, "y": 190, "w": 190, "h": 70, "style": "accent",
         "lines": ["Timeout or error", "revision failed"]},
        {"x": 50, "y": 190, "w": 190, "h": 70, "style": "sub",
         "lines": ["Conflict", "--force-conflicts"]},
        {"x": 50, "y": 340, "w": 190, "h": 70, "style": "box",
         "lines": ["--cleanup-on-fail", "delete new objects only"]},
        {"x": 300, "y": 340, "w": 190, "h": 70, "style": "box",
         "lines": ["--rollback-on-failure", "new revision from last good"]},
        {"x": 550, "y": 340, "w": 160, "h": 70, "style": "ink",
         "lines": ["helm rollback N", "manual, same result"]},
        {"x": 760, "y": 340, "w": 150, "h": 70, "style": "muted",
         "lines": ["--history-max", "prunes old revisions"]},
    ],
    edges=[
        {"x1": 240, "y1": 95, "x2": 290, "y2": 95},
        {"x1": 500, "y1": 95, "x2": 550, "y2": 95, "label": "ok", "lx": 0, "ly": -8},
        {"x1": 710, "y1": 95, "x2": 760, "y2": 95},
        {"x1": 395, "y1": 130, "x2": 395, "y2": 190, "amber": True, "label": "not ready", "lx": 34, "ly": 0},
        {"x1": 145, "y1": 130, "x2": 145, "y2": 190, "dashed": True, "label": "at apply", "lx": 30, "ly": 0},
        {"x1": 345, "y1": 260, "x2": 145, "y2": 340, "amber": True},
        {"x1": 395, "y1": 260, "x2": 395, "y2": 340, "amber": True},
        {"x1": 490, "y1": 375, "x2": 550, "y2": 375, "dashed": True},
        {"x1": 710, "y1": 375, "x2": 760, "y2": 375, "dashed": True},
    ],
    notes=[],
)
