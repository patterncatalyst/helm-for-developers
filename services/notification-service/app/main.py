"""notification-service entrypoint: `uvicorn app.main:app`."""
from __future__ import annotations

import asyncio
import contextlib
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, status

from app.config import Settings
from app.consumer import ConsumerFactory, NotificationStore, consume
from pcobs import kafka
from pcobs import logging as pclog
from pcobs import otel


def create_app(settings: Settings | None = None, consumer_factory: ConsumerFactory | None = None) -> FastAPI:
    """Build the app. Tests pass a fake consumer factory."""
    settings = settings or Settings()
    store = NotificationStore()

    async def kafka_consumer():
        return await kafka.make_consumer(
            settings.kafka_bootstrap, settings.kafka_topic_dispatched, settings.kafka_group_id
        )

    factory = consumer_factory or kafka_consumer

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        task = asyncio.create_task(consume(store, factory))
        yield
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task

    app = FastAPI(title=settings.service_name, version=settings.service_version, lifespan=lifespan)
    app.state.store = store

    @app.get("/health", tags=["ops"])
    async def health() -> dict[str, str]:
        """Liveness: the process answers."""
        return {"status": "ok", "service": settings.service_name}

    @app.get("/healthz", tags=["ops"])
    async def healthz() -> dict[str, str]:
        """Readiness: the Kafka consumer is connected."""
        if not store.consumer_started:
            raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "consumer not started")
        return {"status": "ready", "service": settings.service_name}

    @app.get("/api/notifications", tags=["notifications"])
    async def notifications() -> list[dict]:
        """The last 50 events received, newest first."""
        return store.latest()

    return app


def _build() -> FastAPI:
    settings = Settings()
    pclog.configure(settings.log_level)
    otel.setup(settings.service_name, settings.service_version, settings.deploy_env)
    app = create_app(settings)
    otel.instrument_fastapi(app)
    return app


app = _build()
