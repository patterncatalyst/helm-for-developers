"""shipping-service entrypoint: `uvicorn app.main:app`."""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.config import Settings
from app.events import KafkaPublisher, NullPublisher, Publisher
from app.repository import Repository, make_repository
from app.routes import router
from pcobs import logging as pclog
from pcobs import otel

log = logging.getLogger(__name__)


def create_app(
    settings: Settings | None = None,
    repo: Repository | None = None,
    publisher: Publisher | None = None,
) -> FastAPI:
    """Build the app. Tests pass their own settings, repository and publisher."""
    settings = settings or Settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.repo = repo or make_repository(settings)
        if publisher is not None:
            app.state.publisher = publisher
        elif settings.kafka_enabled:
            app.state.publisher = await KafkaPublisher.start(
                settings.kafka_bootstrap, settings.kafka_topic_dispatched
            )
        else:
            app.state.publisher = NullPublisher()
        log.info("started: storage=%s kafka=%s", settings.shipping_storage, settings.kafka_enabled)
        yield
        # Managed lifecycle: release connections before the pod exits.
        await app.state.publisher.close()
        await app.state.repo.close()

    app = FastAPI(title=settings.service_name, version=settings.service_version, lifespan=lifespan)
    app.state.settings = settings
    app.include_router(router)
    return app


def _build() -> FastAPI:
    settings = Settings()
    pclog.configure(settings.log_level)
    otel.setup(settings.service_name, settings.service_version, settings.deploy_env)
    app = create_app(settings)
    otel.instrument_fastapi(app)
    return app


app = _build()
