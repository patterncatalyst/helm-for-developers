#!/usr/bin/env python3
"""Chapter 15 diagram: the shipment.dispatched event flow and the resources the Kafka chart owns."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import generate_diagram as g
g.OUT = os.path.join(ROOT, "assets", "diagrams")

bands = [
    {"x": 20, "y": 20, "w": 940, "h": 150, "label": "event path (namespace hfd-15)", "fill": "#fafafa"},
    {"x": 20, "y": 200, "w": 940, "h": 150, "label": "shipping-kafka chart (kafka.strimzi.io/v1)", "fill": "#fafafa"},
]
nodes = [
    {"x": 50, "y": 70, "w": 220, "h": 70, "style": "accent", "lines": ["shipping-service", "POST /api/shipments/{id}/dispatch"]},
    {"x": 380, "y": 70, "w": 200, "h": 70, "style": "info", "lines": ["topic shipment.dispatched", "ShipmentDispatched JSON"]},
    {"x": 690, "y": 70, "w": 240, "h": 70, "style": "accent", "lines": ["notification-service", "consumer group notification-service"]},
    {"x": 50, "y": 250, "w": 220, "h": 70, "style": "box", "lines": ["Kafka shipping-kafka", "KRaft, plain listener 9092"]},
    {"x": 380, "y": 250, "w": 200, "h": 70, "style": "box", "lines": ["KafkaNodePool dual", "roles: controller, broker"]},
    {"x": 690, "y": 250, "w": 240, "h": 70, "style": "box", "lines": ["KafkaTopic", "created by the entity operator"]},
]
edges = [
    {"x1": 270, "y1": 105, "x2": 380, "y2": 105, "label": "produce", "amber": True},
    {"x1": 580, "y1": 105, "x2": 690, "y2": 105, "label": "consume", "amber": True},
    {"x1": 270, "y1": 285, "x2": 380, "y2": 285, "label": "members"},
    {"x1": 580, "y1": 285, "x2": 690, "y2": 285, "label": "declares"},
    {"x1": 810, "y1": 250, "x2": 480, "y2": 140, "label": "topic exists once reconciled", "dashed": True, "lx": 40, "ly": -6},
]
notes = [
    {"x": 490, "y": 375, "text": "The Strimzi operator (namespace strimzi) reconciles these three resources into broker pods.", "anchor": "middle", "size": 12, "color": "#888888"},
]
g.emit("15-event-flow", 980, 395, bands, nodes, edges, notes)
