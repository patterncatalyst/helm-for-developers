#!/usr/bin/env python3
"""Chapter 1 diagram: lab topology. Run from the repo root."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import generate_diagram as g

g.OUT = "assets/diagrams"

W, H = 1040, 440
bands = [
    dict(x=20, y=20, w=400, h=400, label="Host: repository checkout", fill="#fafafa"),
    dict(x=470, y=20, w=550, h=400, label="minikube profile helm4dev (docker driver, containerd, 12g, 8 CPUs)", fill="#fafafa"),
    dict(x=490, y=210, w=510, h=190, label="Namespaces", fill="#f4f4f4"),
]
nodes = [
    dict(x=40, y=52, w=360, h=60, style="accent", lines=["scripts/env.sh", "PATH and HELM_*_HOME under .tools/"]),
    dict(x=40, y=140, w=360, h=60, style="box", lines=[".tools/bin", "helm 4.3.0, kubeconform, ct, cosign, helmfile"]),
    dict(x=40, y=228, w=360, h=60, style="sub", lines=[".tools/helm/{config,cache,data,plugins}", "repos, OCI cache, unittest and diff plugins"]),
    dict(x=40, y=316, w=170, h=84, style="muted", lines=["~/.local/bin/helm", "Helm 3, never read", "or modified"]),
    dict(x=230, y=316, w=170, h=84, style="info", lines=["127.0.0.1:<nodePort>", "published with", "minikube --ports"]),

    dict(x=490, y=52, w=230, h=60, style="box", lines=["Kubernetes API server", "helm --kube-context helm4dev"]),
    dict(x=760, y=52, w=240, h=60, style="box", lines=["Registry addon", "127.0.0.1:5000, images 0.1.0"]),
    dict(x=490, y=130, w=230, h=60, style="sub", lines=["Release records", "Secrets sh.helm.release.v1.*"]),
    dict(x=760, y=130, w=240, h=60, style="sub", lines=["Images built by", "scripts/build-images.sh"]),

    dict(x=510, y=244, w=220, h=60, style="box", lines=["cnpg-system, strimzi", "operators only"]),
    dict(x=760, y=244, w=220, h=60, style="box", lines=["observability", "Loki, Grafana, Tempo, Mimir"]),
    dict(x=510, y=322, w=470, h=62, style="accent", lines=["hfd-NN, one per example", "charts create the Postgres and Kafka resources"]),
]
edges = [
    dict(x1=400, y1=82, x2=490, y2=82, label="kubeconfig", ly=-8),
    dict(x1=400, y1=346, x2=470, y2=346, amber=True, label="published NodePort", ly=-8),
    dict(x1=605, y1=112, x2=605, y2=130, dashed=True),
    dict(x1=210, y1=112, x2=210, y2=140, dashed=True),
]
g.emit("01-lab-topology", W, H, bands=bands, nodes=nodes, edges=edges)
