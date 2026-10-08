"""Shared fixtures. Tests run the app in memory mode; no database or Kafka needed."""
from __future__ import annotations

from contextlib import asynccontextmanager

import pytest
from httpx import ASGITransport, AsyncClient

from app.config import Settings
from app.main import create_app


class FakePublisher:
    def __init__(self) -> None:
        self.dispatched = []

    async def publish_dispatched(self, shipment) -> None:
        self.dispatched.append(shipment)

    async def close(self) -> None:
        pass


@pytest.fixture
def publisher() -> FakePublisher:
    return FakePublisher()


@pytest.fixture
def make_client(publisher):
    """Return a factory: `async with make_client(api_token="x") as client`."""

    @asynccontextmanager
    async def factory(**overrides):
        app = create_app(Settings(shipping_storage="memory", **overrides), publisher=publisher)
        # Run the lifespan so app.state is populated, as under uvicorn.
        async with app.router.lifespan_context(app):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                yield client

    return factory
