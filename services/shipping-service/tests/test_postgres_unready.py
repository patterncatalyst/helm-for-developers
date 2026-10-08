from __future__ import annotations

from app.config import Settings
from app.repository import PostgresRepository


async def test_postgres_repo_reports_not_ready_when_db_is_down():
    # Port 1 refuses connections; the service must stay up and report not ready.
    repo = PostgresRepository(Settings(shipping_storage="postgres", pg_host="127.0.0.1", pg_port=1))
    assert await repo.ready() is False
    await repo.close()
