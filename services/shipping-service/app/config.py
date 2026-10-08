"""Service configuration, read from environment variables.

Every setting maps to an upper-case variable of the same name (PG_HOST,
KAFKA_ENABLED, ...). The Helm chart sets them through a ConfigMap and a Secret.
"""
from __future__ import annotations

from typing import Literal

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Identity, reported by /api/info
    service_name: str = "shipping-service"
    service_version: str = "0.1.0"
    deploy_env: str = "local"
    log_level: str = "INFO"

    shipping_default_carrier: str = "ACME"
    shipping_storage: Literal["memory", "postgres"] = "memory"

    # Postgres (used only when shipping_storage=postgres)
    pg_host: str = "127.0.0.1"
    pg_port: int = 5432
    pg_database: str = "shipping"
    pg_user: str = "shipping"
    pg_password: str = ""
    pg_schema: str = "shipping"

    # Kafka (used only when kafka_enabled=true)
    kafka_enabled: bool = False
    kafka_bootstrap: str = "localhost:9092"
    kafka_topic_dispatched: str = "shipment.dispatched"

    # When set, write endpoints require "Authorization: Bearer <api_token>"
    api_token: str = ""

    @property
    def dsn(self) -> str:
        return (
            f"postgresql://{self.pg_user}:{self.pg_password}"
            f"@{self.pg_host}:{self.pg_port}/{self.pg_database}"
        )
