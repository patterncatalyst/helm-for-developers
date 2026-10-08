import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import generate_diagram as g
g.OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "diagrams")

# Figure 8.1 - where the API_TOKEN Secret can come from
nodes = [
    {"x": 20, "y": 30, "w": 230, "h": 70, "style": "box", "lines": ["Chart-created Secret", "auth.token or auth.generate", "in the release record"]},
    {"x": 20, "y": 120, "w": 230, "h": 70, "style": "accent", "lines": ["existingSecret", "you create it; chart only", "references it"]},
    {"x": 20, "y": 210, "w": 230, "h": 70, "style": "info", "lines": ["External Secrets Operator", "syncs from a vault into", "a Secret"]},
    {"x": 20, "y": 300, "w": 230, "h": 70, "style": "info", "lines": ["Sealed Secrets", "encrypted SealedSecret in Git,", "controller decrypts"]},
    {"x": 20, "y": 390, "w": 230, "h": 70, "style": "sub", "lines": ["SOPS / helm-secrets", "encrypted values files;", "Helm 4 support unchecked"]},
    {"x": 420, "y": 150, "w": 190, "h": 120, "style": "ink", "lines": ["Secret in namespace", "key api-token"]},
    {"x": 700, "y": 150, "w": 170, "h": 120, "style": "box", "lines": ["Deployment", "env API_TOKEN", "secretKeyRef"]},
]
edges = [
    {"x1": 250, "y1": 65, "x2": 420, "y2": 190},
    {"x1": 250, "y1": 155, "x2": 420, "y2": 210, "amber": True},
    {"x1": 250, "y1": 245, "x2": 420, "y2": 225, "dashed": True},
    {"x1": 250, "y1": 335, "x2": 420, "y2": 250, "dashed": True},
    {"x1": 250, "y1": 425, "x2": 420, "y2": 265, "dashed": True},
    {"x1": 610, "y1": 210, "x2": 700, "y2": 210, "amber": True},
]
notes = [{"x": 335, "y": 480, "text": "Solid: handled by the chart. Dashed: produced outside the chart.", "anchor": "middle", "size": 12, "color": "#555555"}]
g.emit("08-secrets-options", 890, 500, [], nodes, edges, notes)
