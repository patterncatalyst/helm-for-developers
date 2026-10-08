"""API models. JSON uses camelCase to match the ShipmentDto of the Java original."""
from __future__ import annotations

from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class ShipmentStatus(StrEnum):
    PENDING = "PENDING"
    DISPATCHED = "DISPATCHED"
    CANCELLED = "CANCELLED"


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class ShipmentCreate(CamelModel):
    order_id: int
    address: str = Field(min_length=1, max_length=255)


class Shipment(CamelModel):
    id: int
    order_id: int
    address: str
    status: ShipmentStatus
    created_at: datetime
