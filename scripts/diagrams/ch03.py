import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import generate_diagram as g
g.OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "diagrams")

# Figure 3.1 - the same three files copied per environment
bands, nodes, edges, notes = [], [], [], []
envs = [("dev", 20), ("stage", 190), ("prod", 360)]
for name, y in envs:
    bands.append({"x": 230, "y": y, "w": 650, "h": 150, "label": f"copy for {name}"})
    for i, f in enumerate(["configmap.yaml", "deployment.yaml", "service.yaml"]):
        nodes.append({"x": 250 + i * 205, "y": y + 40, "w": 185, "h": 90, "style": "box",
                      "lines": [f, {"configmap.yaml": "carrier, log level, env", "deployment.yaml": "image, replicas, resources", "service.yaml": "type, nodePort"}[f]]})
nodes.insert(0, {"x": 30, "y": 215, "w": 150, "h": 90, "style": "ink", "lines": ["manifests/", "3 files, one env"]})
for k, (name, y) in enumerate(envs):
    e = {"x1": 180, "y1": 260, "x2": 230, "y2": y + 85, "amber": True}
    edges.append(e)
notes.append({"x": 105, "y": 325, "text": "cp -r + edit", "anchor": "middle", "size": 12, "color": "#b8650a", "bold": True})
notes.append({"x": 555, "y": 545, "text": "9 files to keep in step; every field change is edited three times", "anchor": "middle", "size": 13, "color": "#555555"})
g.emit("03-raw-manifest-sprawl", 910, 565, bands, nodes, edges, notes)
