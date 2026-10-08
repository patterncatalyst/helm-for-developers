"""Kafka consumer loop and the in-memory buffer behind GET /api/notifications."""
from __future__ import annotations

import asyncio
import logging
from collections import deque
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime
from typing import Any

from opentelemetry import trace

from pcobs.propagation import extract_context

log = logging.getLogger(__name__)
tracer = trace.get_tracer("notification-service")

BUFFER_SIZE = 50
RETRY_SECONDS = 5.0

# Given nothing, returns a started consumer. Tests substitute a fake.
ConsumerFactory = Callable[[], Awaitable[Any]]


class NotificationStore:
    """Keeps the last BUFFER_SIZE notifications, newest first."""

    def __init__(self, size: int = BUFFER_SIZE) -> None:
        self._items: deque[dict[str, Any]] = deque(maxlen=size)
        self.consumer_started = False

    def add(self, item: dict[str, Any]) -> None:
        self._items.appendleft(item)

    def latest(self) -> list[dict[str, Any]]:
        return list(self._items)


async def handle(store: NotificationStore, message) -> None:
    """Record one record, continuing the producer's trace."""
    with tracer.start_as_current_span("process shipment.dispatched", context=extract_context(message.headers)):
        event = message.value
        log.info("shipment %s for order %s dispatched", event.get("shipmentId"), event.get("orderId"))
        store.add(
            {
                "receivedAt": datetime.now(UTC).isoformat(),
                "topic": message.topic,
                "partition": message.partition,
                "offset": message.offset,
                "event": event,
            }
        )


async def consume(store: NotificationStore, factory: ConsumerFactory, retry_seconds: float = RETRY_SECONDS) -> None:
    """Connect, read until cancelled, reconnect on failure.

    Readiness (`consumer_started`) is true only while a consumer is connected, so
    the pod is held out of the Service until Kafka is reachable.
    """
    while True:
        consumer = None
        try:
            consumer = await factory()
            store.consumer_started = True
            async for message in consumer:
                await handle(store, message)
            return  # the iterator ended (a fake consumer, or a clean stop)
        except asyncio.CancelledError:
            raise
        except Exception:
            store.consumer_started = False
            log.exception("consumer failed, retrying in %.0fs", retry_seconds)
            await asyncio.sleep(retry_seconds)
        finally:
            store.consumer_started = False
            if consumer is not None:
                await consumer.stop()
