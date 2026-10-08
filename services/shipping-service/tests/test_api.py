from __future__ import annotations

NEW = {"orderId": 42, "address": "1 Analytical Engine Way, London"}


async def test_health(make_client):
    async with make_client() as client:
        resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok", "service": "shipping-service"}


async def test_healthz_ready_in_memory_mode(make_client):
    async with make_client() as client:
        assert (await client.get("/healthz")).status_code == 200


async def test_info_reflects_environment(make_client):
    async with make_client(
        service_version="9.9.9",
        deploy_env="stage",
        shipping_default_carrier="ZOOM",
        kafka_enabled=False,
    ) as client:
        body = (await client.get("/api/info")).json()
    assert body == {
        "service": "shipping-service",
        "version": "9.9.9",
        "environment": "stage",
        "defaultCarrier": "ZOOM",
        "storage": "memory",
        "kafkaEnabled": False,
    }


async def test_create_then_get(make_client):
    async with make_client() as client:
        created = await client.post("/api/shipments", json=NEW)
        assert created.status_code == 201
        body = created.json()
        assert body["status"] == "PENDING"
        assert body["orderId"] == 42
        fetched = await client.get(f"/api/shipments/{body['id']}")
    assert fetched.status_code == 200
    assert fetched.json() == body


async def test_list_by_order(make_client):
    async with make_client() as client:
        await client.post("/api/shipments", json=NEW)
        hit = await client.get("/api/shipments", params={"orderId": 42})
        miss = await client.get("/api/shipments", params={"orderId": 7})
    assert [s["orderId"] for s in hit.json()] == [42]
    assert miss.json() == []


async def test_list_requires_order_id(make_client):
    async with make_client() as client:
        resp = await client.get("/api/shipments")
    assert resp.status_code == 400


async def test_get_missing_is_404(make_client):
    async with make_client() as client:
        assert (await client.get("/api/shipments/999")).status_code == 404


async def test_invalid_body_is_rejected(make_client):
    async with make_client() as client:
        resp = await client.post("/api/shipments", json={"orderId": 1, "address": ""})
    assert resp.status_code == 422


async def test_duplicate_order_is_conflict(make_client):
    async with make_client() as client:
        await client.post("/api/shipments", json=NEW)
        resp = await client.post("/api/shipments", json=NEW)
    assert resp.status_code == 409


async def test_token_required_when_configured(make_client):
    async with make_client(api_token="s3cret") as client:
        assert (await client.post("/api/shipments", json=NEW)).status_code == 401
        bad = await client.post("/api/shipments", json=NEW, headers={"Authorization": "Bearer nope"})
        assert bad.status_code == 401
        ok = await client.post("/api/shipments", json=NEW, headers={"Authorization": "Bearer s3cret"})
        assert ok.status_code == 201
        # reads stay open
        assert (await client.get("/api/shipments/1")).status_code == 200


async def test_no_token_needed_when_unset(make_client):
    async with make_client() as client:
        assert (await client.post("/api/shipments", json=NEW)).status_code == 201
