"""Shipment storage: an in-memory implementation and a Postgres one.

SHIPPING_STORAGE picks which. Memory needs nothing and is what the early
chapters run; Postgres is the CloudNativePG-backed setup used later.
"""
from __future__ import annotations

import asyncio
import itertools
from datetime import UTC, datetime
from typing import Protocol

import asyncpg

from app.config import Settings
from app.models import Shipment, ShipmentStatus


class DuplicateOrder(Exception):
    """A shipment already exists for this order id."""


class Repository(Protocol):
    async def create(self, order_id: int, address: str) -> Shipment: ...
    async def get(self, shipment_id: int) -> Shipment | None: ...
    async def by_order(self, order_id: int) -> list[Shipment]: ...
    async def mark_dispatched(self, shipment_id: int) -> Shipment | None: ...
    async def ready(self) -> bool: ...
    async def close(self) -> None: ...


class MemoryRepository:
    def __init__(self) -> None:
        self._rows: dict[int, Shipment] = {}
        self._ids = itertools.count(1)

    async def create(self, order_id: int, address: str) -> Shipment:
        if any(s.order_id == order_id for s in self._rows.values()):
            raise DuplicateOrder(order_id)
        shipment = Shipment(
            id=next(self._ids),
            order_id=order_id,
            address=address,
            status=ShipmentStatus.PENDING,
            created_at=datetime.now(UTC),
        )
        self._rows[shipment.id] = shipment
        return shipment

    async def get(self, shipment_id: int) -> Shipment | None:
        return self._rows.get(shipment_id)

    async def by_order(self, order_id: int) -> list[Shipment]:
        return [s for s in self._rows.values() if s.order_id == order_id]

    async def mark_dispatched(self, shipment_id: int) -> Shipment | None:
        shipment = self._rows.get(shipment_id)
        if shipment is None:
            return None
        updated = shipment.model_copy(update={"status": ShipmentStatus.DISPATCHED})
        self._rows[shipment_id] = updated
        return updated

    async def ready(self) -> bool:
        return True

    async def close(self) -> None:
        pass


_COLUMNS = "id, order_id, address, status, created_at"


def _to_shipment(row: asyncpg.Record) -> Shipment:
    return Shipment(**dict(row))


class PostgresRepository:
    """asyncpg-backed storage. The pool is opened lazily, so the service starts
    (and reports not-ready) even if the database is not reachable yet."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._pool: asyncpg.Pool | None = None
        self._lock = asyncio.Lock()

    async def _get_pool(self) -> asyncpg.Pool:
        async with self._lock:
            if self._pool is None:
                self._pool = await asyncpg.create_pool(
                    self._settings.dsn,
                    min_size=1,
                    max_size=5,
                    server_settings={"search_path": self._settings.pg_schema},
                )
            return self._pool

    async def create(self, order_id: int, address: str) -> Shipment:
        pool = await self._get_pool()
        try:
            row = await pool.fetchrow(
                f"INSERT INTO shipments (order_id, address, status) VALUES ($1, $2, 'PENDING') "
                f"RETURNING {_COLUMNS}",
                order_id,
                address,
            )
        except asyncpg.UniqueViolationError as exc:
            raise DuplicateOrder(order_id) from exc
        return _to_shipment(row)

    async def get(self, shipment_id: int) -> Shipment | None:
        pool = await self._get_pool()
        row = await pool.fetchrow(f"SELECT {_COLUMNS} FROM shipments WHERE id = $1", shipment_id)
        return _to_shipment(row) if row else None

    async def by_order(self, order_id: int) -> list[Shipment]:
        pool = await self._get_pool()
        rows = await pool.fetch(f"SELECT {_COLUMNS} FROM shipments WHERE order_id = $1", order_id)
        return [_to_shipment(r) for r in rows]

    async def mark_dispatched(self, shipment_id: int) -> Shipment | None:
        pool = await self._get_pool()
        row = await pool.fetchrow(
            f"UPDATE shipments SET status = 'DISPATCHED' WHERE id = $1 RETURNING {_COLUMNS}",
            shipment_id,
        )
        return _to_shipment(row) if row else None

    async def ready(self) -> bool:
        """True once the database answers and the migration has created the table."""
        try:
            pool = await self._get_pool()
            return await pool.fetchval("SELECT to_regclass('shipments') IS NOT NULL")
        except Exception:
            return False

    async def close(self) -> None:
        if self._pool is not None:
            await self._pool.close()


def make_repository(settings: Settings) -> Repository:
    if settings.shipping_storage == "postgres":
        return PostgresRepository(settings)
    return MemoryRepository()
