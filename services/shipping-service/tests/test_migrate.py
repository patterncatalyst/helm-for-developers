"""The runner is tested against a fake connection that mimics the bits of
asyncpg it uses. A real Postgres run happens in the chart's integration tests."""
from __future__ import annotations

from contextlib import asynccontextmanager

from app.migrate import MIGRATIONS_DIR, discover, migrate


class FakeConn:
    def __init__(self) -> None:
        self.versions: list[int] = []
        self.executed: list[str] = []

    async def execute(self, sql: str, *args):
        self.executed.append(sql)
        if "INSERT INTO" in sql and "schema_migrations" in sql:
            self.versions.append(args[0])

    async def fetch(self, sql: str, *args):
        return [{"version": v} for v in self.versions]

    @asynccontextmanager
    async def transaction(self):
        yield


def test_migration_files_are_versioned_in_order():
    versions = [v for v, _ in discover(MIGRATIONS_DIR)]
    assert versions == sorted(versions)
    assert versions[:2] == [1, 2]


async def test_migrate_applies_each_file_once():
    conn = FakeConn()
    first = await migrate(conn, "shipping")
    assert first == [v for v, _ in discover(MIGRATIONS_DIR)]
    count = len(conn.executed)

    second = await migrate(conn, "shipping")
    assert second == []  # idempotent: nothing pending
    # The second run only takes the lock, ensures bookkeeping, and releases it.
    assert not any("CREATE TABLE shipments" in sql for sql in conn.executed[count:])


async def test_migrate_creates_schema_and_scopes_search_path():
    conn = FakeConn()
    await migrate(conn, "shipping")
    assert any(sql.startswith('CREATE SCHEMA IF NOT EXISTS "shipping"') for sql in conn.executed)
    assert any(sql.startswith('SET LOCAL search_path TO "shipping"') for sql in conn.executed)
