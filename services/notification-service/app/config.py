"""Service configuration, read from environment variables."""
from __future__ import annotations

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    service_name: str = "notification-service"
    service_version: str = "0.1.0"
    deploy_env: str = "local"
    log_level: str = "INFO"

    kafka_bootstrap: str = "localhost:9092"
    kafka_topic_dispatched: str = "shipment.dispatched"
    kafka_group_id: str = "notification-service"
