# Services

Two small FastAPI services share one image recipe. They are the application the Helm charts in this tutorial deploy.

| Service | Role | Port |
|---|---|---|
| `shipping-service` | REST API, Postgres storage (or memory), Kafka producer | 8080 |
| `notification-service` | Kafka consumer, `GET /api/notifications` | 8080 |

`common/pcobs` holds the shared OpenTelemetry, JSON logging and Kafka helpers.

## Build and test

```
[host]$ podman build -f services/Containerfile --build-arg SERVICE=shipping-service --target test services/
[host]$ podman build -f services/Containerfile --build-arg SERVICE=shipping-service -t shipping-service:0.1.0 services/
[host]$ podman build -f services/Containerfile --build-arg SERVICE=notification-service -t notification-service:0.1.0 services/
```

The `test` target runs pytest during the build. Tests need no database or broker: shipping runs in memory mode, notification uses a fake consumer, and the migration runner is tested against a fake connection.

## Run locally

```
[host]$ podman run --rm -p 8080:8080 -e SHIPPING_STORAGE=memory shipping-service:0.1.0
```

With `SHIPPING_STORAGE=postgres`, run `python -m app.migrate` first (the chart does it in a pre-install hook). Until the tables exist, `/healthz` returns 503.

## Python version decision

Checked 2026-10-08, the day before the scheduled 3.15.0 GA:

- `uv python install 3.15.0` fails in the builder: `No download found for request: cpython-3.15.0-linux-x86_64-gnu`. `uv python list --all-versions` (uv 0.12.23) offers only `3.15.0rc3`.
- cp315 wheels: `pydantic-core 2.49.0` and `asyncpg 0.32.0` publish them. `aiokafka 0.14.0` does not (pip resolves only a `0.0.1` pure-Python stub for 3.15). The cp314 wheels exist for all three.

Decision: **fallback F1, Python 3.14** (resolves to 3.14.8), same build. The release candidate was not used. The image reports `3.14.8`.

To move to 3.15 once GA is published in uv and aiokafka ships cp315 wheels, change `ARG PYTHON_VERSION` in `Containerfile` to `3.15.0` and the `requires-python` lower bounds are already compatible. Nothing else changes.

The base images are `registry.access.redhat.com/ubi10/ubi-minimal` (builder and runtime) with CPython from uv. UBI 10 has no Python image and the Docker Hub `python` images are not used.

## Notes

- Runtime user is `1001:0`, with no `runAsUser` needed in charts. The image also starts under an arbitrary uid (checked with `--user 54321:0`; rootless podman maps only 65536 ids, so OpenShift-sized uids cannot be tried locally). Nothing writes to the root filesystem, so `--read-only` works.
- Dependencies are pinned in each `pyproject.toml`; `uv pip install` resolves the rest.
- `POST /api/shipments` returns 409 when the order already has a shipment (unique `order_id`, migration V2).
- Write endpoints (`POST /api/shipments`, `POST /api/shipments/{id}/dispatch`) require the bearer token when `API_TOKEN` is set; reads stay open.
