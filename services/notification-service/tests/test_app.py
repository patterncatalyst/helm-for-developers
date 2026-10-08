"""Tests use a fake consumer, so no Kafka broker is needed."""
from __future__ import annotations

import asyncio
from dataclasses import dataclass, field

import pytest
from httpx import ASGITransport, AsyncClient

from app.config import Settings
from app.consumer import NotificationStore, consume, handle
from app.main import create_app


@dataclass
class FakeMessage:
    value: dict
    topic: str = "shipment.dispatched"
    partition: int = 0
    offset: int = 0
    headers: list = field(default_factory=list)


class FakeConsumer:
    """Yields the given messages, then blocks like a real consumer would."""

    def __init__(self, messages):
        self._messages = messages
        self.stopped = False

    def __aiter__(self):
        return self._iterate()

    async def _iterate(self):
        for message in self._messages:
            yield message
        await asyncio.Event().wait()

    async def stop(self):
        self.stopped = True


def event(n: int) -> dict:
    return {"orderId": n, "shipmentId": n, "address": "x", "status": "DISPATCHED", "occurredAt": "2026-01-01T00:00:00Z"}


async def eventually(predicate, timeout=2.0):
    for _ in range(int(timeout / 0.01)):
        if predicate():
            return
        await asyncio.sleep(0.01)
    raise AssertionError("condition not met in time")


@pytest.fixture
async def client_with(request):
    messages = getattr(request, "param", [])
    consumer = FakeConsumer(messages)

    async def factory():
        return consumer

    app = create_app(Settings(), consumer_factory=factory)
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            yield client, app, consumer


async def test_health_is_always_ok(client_with):
    client, _, _ = client_with
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["service"] == "notification-service"


async def test_healthz_follows_consumer_state(client_with):
    client, app, _ = client_with
    await eventually(lambda: app.state.store.consumer_started)
    assert (await client.get("/healthz")).status_code == 200


async def test_healthz_503_before_consumer_connects():
    async def never_connects():
        await asyncio.Event().wait()

    app = create_app(Settings(), consumer_factory=never_connects)
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            assert (await client.get("/healthz")).status_code == 503


@pytest.mark.parametrize("client_with", [[FakeMessage(event(1), offset=0), FakeMessage(event(2), offset=1)]], indirect=True)
async def test_consumed_events_are_listed_newest_first(client_with):
    client, app, _ = client_with
    await eventually(lambda: len(app.state.store.latest()) == 2)
    body = (await client.get("/api/notifications")).json()
    assert [n["event"]["orderId"] for n in body] == [2, 1]
    assert body[0]["offset"] == 1
    assert body[0]["topic"] == "shipment.dispatched"


async def test_buffer_keeps_only_last_50():
    store = NotificationStore()
    for n in range(60):
        await handle(store, FakeMessage(event(n), offset=n))
    items = store.latest()
    assert len(items) == 50
    assert items[0]["event"]["orderId"] == 59
    assert items[-1]["event"]["orderId"] == 10


async def test_consume_retries_after_connection_failure():
    store = NotificationStore()
    attempts = 0

    async def flaky():
        nonlocal attempts
        attempts += 1
        if attempts == 1:
            raise ConnectionError("broker down")
        return FakeConsumer([FakeMessage(event(5))])

    task = asyncio.create_task(consume(store, flaky, retry_seconds=0.01))
    await eventually(lambda: len(store.latest()) == 1)
    task.cancel()
    assert attempts == 2
