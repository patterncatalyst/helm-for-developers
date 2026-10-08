"""HTTP routes. State (settings, repository, publisher) lives on app.state."""
from __future__ import annotations

import secrets

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, status

from app.models import Shipment, ShipmentCreate, ShipmentStatus
from app.repository import DuplicateOrder

router = APIRouter()


def require_token(request: Request, authorization: str | None = Header(default=None)) -> None:
    """Enforce the bearer token on write endpoints when API_TOKEN is set."""
    expected = request.app.state.settings.api_token
    if not expected:
        return
    supplied = (authorization or "").removeprefix("Bearer ")
    if not secrets.compare_digest(supplied, expected):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "missing or invalid bearer token")


@router.get("/health", tags=["ops"])
async def health(request: Request) -> dict[str, str]:
    """Liveness: the process answers."""
    return {"status": "ok", "service": request.app.state.settings.service_name}


@router.get("/healthz", tags=["ops"])
async def healthz(request: Request) -> dict[str, str]:
    """Readiness: storage is usable (for Postgres, the migration has run)."""
    if not await request.app.state.repo.ready():
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "storage not ready")
    return {"status": "ready", "service": request.app.state.settings.service_name}


@router.get("/api/info", tags=["ops"])
async def info(request: Request) -> dict[str, object]:
    s = request.app.state.settings
    return {
        "service": s.service_name,
        "version": s.service_version,
        "environment": s.deploy_env,
        "defaultCarrier": s.shipping_default_carrier,
        "storage": s.shipping_storage,
        "kafkaEnabled": s.kafka_enabled,
    }


@router.post(
    "/api/shipments",
    response_model=Shipment,
    response_model_by_alias=True,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_token)],
)
async def create_shipment(body: ShipmentCreate, request: Request) -> Shipment:
    try:
        return await request.app.state.repo.create(body.order_id, body.address)
    except DuplicateOrder:
        raise HTTPException(status.HTTP_409_CONFLICT, f"order {body.order_id} already has a shipment")


@router.get("/api/shipments/{shipment_id}", response_model=Shipment, response_model_by_alias=True)
async def get_shipment(shipment_id: int, request: Request) -> Shipment:
    shipment = await request.app.state.repo.get(shipment_id)
    if shipment is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"shipment {shipment_id} not found")
    return shipment


@router.get("/api/shipments", response_model=list[Shipment], response_model_by_alias=True)
async def list_shipments(request: Request, order_id: int | None = Query(default=None, alias="orderId")):
    if order_id is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "query parameter orderId is required")
    return await request.app.state.repo.by_order(order_id)


@router.post(
    "/api/shipments/{shipment_id}/dispatch",
    response_model=Shipment,
    response_model_by_alias=True,
    dependencies=[Depends(require_token)],
)
async def dispatch_shipment(shipment_id: int, request: Request) -> Shipment:
    repo = request.app.state.repo
    shipment = await repo.get(shipment_id)
    if shipment is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"shipment {shipment_id} not found")
    if shipment.status == ShipmentStatus.CANCELLED:
        raise HTTPException(status.HTTP_409_CONFLICT, "cancelled shipments cannot be dispatched")
    if shipment.status == ShipmentStatus.DISPATCHED:
        return shipment  # already dispatched: no second event
    shipment = await repo.mark_dispatched(shipment_id)
    await request.app.state.publisher.publish_dispatched(shipment)
    return shipment
