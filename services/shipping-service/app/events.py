"""The shipment.dispatched event: this service's published contract.

Field names match ShipmentDispatched.java in the modernization series:
orderId, shipmentId, address, status, occurredAt.
"""
from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Any, Protocol

from pcobs import kafka

from app.models import Shipment, ShipmentStatus

log = logging.getLogger(__name__)


def dispatched_event(shipment: Shipment) -> dict[str, Any]:
    return {
        "orderId": shipment.order_id,
        "shipmentId": shipment.id,
        "address": shipment.address,
        "status": ShipmentStatus.DISPATCHED.value,
        "occurredAt": datetime.now(UTC).isoformat(),
    }


class Publisher(Protocol):
    async def publish_dispatched(self, shipment: Shipment) -> None: ...
    async def close(self) -> None: ...


class NullPublisher:
    """Used when KAFKA_ENABLED=false: dispatching only changes the status."""

    async def publish_dispatched(self, shipment: Shipment) -> None:
        log.info("kafka disabled, not publishing dispatch of shipment %s", shipment.id)

    async def close(self) -> None:
        pass


class KafkaPublisher:
    def __init__(self, producer, topic: str) -> None:
        self._producer = producer
        self._topic = topic

    @classmethod
    async def start(cls, bootstrap: str, topic: str) -> "KafkaPublisher":
        return cls(await kafka.make_producer(bootstrap), topic)

    async def publish_dispatched(self, shipment: Shipment) -> None:
        await kafka.publish_event(
            self._producer, self._topic, key=str(shipment.order_id), value=dispatched_event(shipment)
        )

    async def close(self) -> None:
        await self._producer.stop()
