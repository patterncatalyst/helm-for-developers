"""Apply migrations/V*.sql to the service schema: `python -m app.migrate`.

Each file runs once, in version order, inside its own transaction. Applied
versions are recorded in <schema>.schema_migrations, so running it again is a
no-op. The Helm chart runs this as a pre-install/pre-upgrade hook Job.
"""
from __future__ import annotations

import asyncio
import logging
import re
import sys
from pathlib import Path

import asyncpg

from app.config import Settings

log = logging.getLogger("migrate")

MIGRATIONS_DIR = Path(__file__).resolve().parent.parent / "migrations"
_VERSION = re.compile(r"^V(\d+)__.+\.sql$")
_LOCK_ID = 727_001  # advisory lock so two Jobs cannot migrate at once


def discover(directory: Path) -> list[tuple[int, Path]]:
    """Return (version, path) pairs sorted by version."""
    found = [(int(m.group(1)), p) for p in directory.glob("V*.sql") if (m := _VERSION.match(p.name))]
    return sorted(found)


async def migrate(conn, schema: str, directory: Path = MIGRATIONS_DIR) -> list[int]:
    """Apply pending migrations on `conn` and return the versions applied."""
    await conn.execute("SELECT pg_advisory_lock($1)", _LOCK_ID)
    try:
        await conn.execute(f'CREATE SCHEMA IF NOT EXISTS "{schema}"')
        await conn.execute(
            f'CREATE TABLE IF NOT EXISTS "{schema}".schema_migrations ('
            "version INT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now())"
        )
        done = {r["version"] for r in await conn.fetch(f'SELECT version FROM "{schema}".schema_migrations')}
        applied: list[int] = []
        for version, path in discover(directory):
            if version in done:
                continue
            async with conn.transaction():
                await conn.execute(f'SET LOCAL search_path TO "{schema}"')
                await conn.execute(path.read_text())
                await conn.execute(f'INSERT INTO "{schema}".schema_migrations (version) VALUES ($1)', version)
            log.info("applied %s", path.name)
            applied.append(version)
        if not applied:
            log.info("schema %s is up to date", schema)
        return applied
    finally:
        await conn.execute("SELECT pg_advisory_unlock($1)", _LOCK_ID)


async def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(message)s")
    settings = Settings()
    conn = await asyncpg.connect(settings.dsn)
    try:
        await migrate(conn, settings.pg_schema)
    finally:
        await conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
