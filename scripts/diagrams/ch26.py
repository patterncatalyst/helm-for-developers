#!/usr/bin/env python3
"""Chapter 26 diagram: telemetry path. Run from the repo root."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import generate_diagram as g

g.OUT = "assets/diagrams"

W, H = 1040, 440
bands = [
    dict(x=20, y=20, w=300, h=400, label="Namespace hfd-26 (chart)", fill="#fafafa"),
    dict(x=340, y=20, w=680, h=400, label="Namespace observability (platform)", fill="#fafafa"),
]
nodes = [
    dict(x=40, y=60, w=260, h=70, style="box", lines=["platform-shipping", "OTEL_SERVICE_NAME from pc-lib"]),
    dict(x=40, y=170, w=260, h=70, style="box", lines=["Kafka shipment.dispatched", "traceparent header"]),
    dict(x=40, y=280, w=260, h=70, style="box", lines=["platform-notification", "continues the trace"]),
    dict(x=370, y=170, w=220, h=70, style="accent", lines=["OTel Collector", "OTLP HTTP :4318"]),
    dict(x=680, y=60, w=310, h=64, style="box", lines=["Tempo", "TraceQL: span.http.target"]),
    dict(x=680, y=150, w=310, h=64, style="box", lines=["Loki", "logs by service_name"]),
    dict(x=680, y=240, w=310, h=64, style="box", lines=["Mimir", "request-rate metrics"]),
    dict(x=370, y=340, w=620, h=60, style="info", lines=["Grafana + dashboard sidecar", "loads ConfigMaps labelled grafana_dashboard=1 (searchNamespace=ALL)"]),
]
edges = [
    dict(x1=170, y1=130, x2=170, y2=170), dict(x1=170, y1=240, x2=170, y2=280),
    dict(x1=300, y1=95, x2=370, y2=190, amber=True, label="OTLP"),
    dict(x1=300, y1=315, x2=370, y2=225, amber=True),
    dict(x1=590, y1=190, x2=680, y2=95), dict(x1=590, y1=205, x2=680, y2=182), dict(x1=590, y1=220, x2=680, y2=270),
    dict(x1=835, y1=304, x2=835, y2=340, dashed=True),
    dict(x1=170, y1=350, x2=370, y2=370, dashed=True, label="ConfigMap"),
]
g.emit("26-telemetry-path", W, H, bands=bands, nodes=nodes, edges=edges)
