#!/usr/bin/env python3
"""Chapter 25 diagram: the GitOps loop with Argo CD rendering Helm. Run from the repo root."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import generate_diagram as g

g.OUT = "assets/diagrams"

W, H = 1040, 400
bands = [
    dict(x=20, y=20, w=1000, h=360, label="Cluster helm4dev", fill="#fafafa"),
]
nodes = [
    dict(x=40, y=60, w=230, h=84, style="box", lines=["Chart source", "OCI: registry addon (primary)", "Git: github.com/... (pending)"]),
    dict(x=40, y=240, w=230, h=84, style="muted", lines=["Operator (you)", "kubectl apply Application", "or merge a pins change"]),
    dict(x=400, y=60, w=240, h=84, style="accent", lines=["argocd-repo-server", "helm template + valueFiles", "+ valuesObject; lookup is empty"]),
    dict(x=400, y=240, w=240, h=84, style="info", lines=["argocd-application-controller", "diff desired vs live", "sync, prune, selfHeal"]),
    dict(x=770, y=60, w=230, h=84, style="box", lines=["Sync phases", "PreSync, Sync, PostSync", "helm hooks map to these"]),
    dict(x=770, y=240, w=230, h=84, style="box", lines=["Namespace hfd-25", "release platform", "umbrella workloads"]),
]
edges = [
    dict(x1=270, y1=102, x2=400, y2=102, label="fetch 1.0.0"),
    dict(x1=520, y1=144, x2=520, y2=240, label="manifests"),
    dict(x1=640, y1=102, x2=770, y2=102, dashed=True),
    dict(x1=640, y1=282, x2=770, y2=282, amber=True, label="apply (SSA)"),
    dict(x1=270, y1=282, x2=400, y2=282),
    dict(x1=885, y1=240, x2=885, y2=144, dashed=True, label="hooks run in order"),
]
g.emit("25-gitops-loop", W, H, bands=bands, nodes=nodes, edges=edges)
