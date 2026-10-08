from __future__ import annotations

from datetime import datetime

from app.events import dispatched_event
from app.models import Shipment, ShipmentStatus

NEW = {"orderId": 42, "address": "1 Analytical Engine Way, London"}


async def test_dispatch_sets_status_and_publishes_once(make_client, publisher):
    async with make_client() as client:
        shipment_id = (await client.post("/api/shipments", json=NEW)).json()["id"]
        first = await client.post(f"/api/shipments/{shipment_id}/dispatch")
        second = await client.post(f"/api/shipments/{shipment_id}/dispatch")
    assert first.status_code == 200
    assert first.json()["status"] == "DISPATCHED"
    assert second.json()["status"] == "DISPATCHED"
    assert len(publisher.dispatched) == 1


async def test_dispatch_missing_is_404(make_client):
    async with make_client() as client:
        assert (await client.post("/api/shipments/5/dispatch")).status_code == 404


def test_event_payload_matches_shipment_dispatched_contract():
    shipment = Shipment(
        id=7, order_id=42, address="x", status=ShipmentStatus.DISPATCHED, created_at=datetime.now()
    )
    event = dispatched_event(shipment)
    # Field names of ShipmentDispatched.java: orderId, shipmentId, address, status, occurredAt
    assert set(event) == {"orderId", "shipmentId", "address", "status", "occurredAt"}
    assert event["orderId"] == 42
    assert event["shipmentId"] == 7
    assert event["status"] == "DISPATCHED"
    datetime.fromisoformat(event["occurredAt"])
