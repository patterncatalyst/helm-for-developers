# 09-postgres-subchart

Snapshot of the `shipping-service` chart after chapter 09: the chart from chapter 08 (ConfigMap, Secret, Deployment, Service, checksum rollout) plus a `shipping-postgres` subchart. The subchart renders a CloudNativePG `Cluster`. A `condition` switches it on, and `import-values` wires the service to the database host and the operator-generated `shipping-postgres-app` Secret.

```
shipping-service/       parent chart, version 0.9.0, depends on ../shipping-postgres
shipping-postgres/      subchart: CNPG Cluster, exports.postgres for import-values
values-postgres.yaml    switches the subchart on and sets config.storage=postgres
demo.sh
```

The templates are inlined (no library chart yet; that is chapter 17).

## Run it

```bash
./demo.sh offline   # dependency build, lint, template (both modes), helm-unittest, kubeconform
./demo.sh           # live: installs release "shipping" in namespace hfd-09, migrates by hand, calls the API
./demo.sh clean
```

The live run needs the helm4dev cluster with the CloudNativePG operator (`scripts/platform/bootstrap.sh`) and the images from `scripts/build-images.sh`. It binds NodePort 30080, so uninstall any other release that uses it first. Host access goes through `scripts/tunnel.sh` at `http://127.0.0.1:8080`.

## What to look for

- `helm dependency list` reports the subchart as `ok`; `Chart.lock` pins it.
- Rendering without `-f values-postgres.yaml` gives three objects; with it, four (the `Cluster` is added).
- `PG_HOST` is `shipping-postgres-rw` and `PG_PASSWORD` comes from `secretKeyRef` `shipping-postgres-app`, none of it typed into the parent values.
- Lint does not resolve `import-values`, so the postgres lint run passes `--set postgres.host=...`.
- The schema is not migrated yet. The demo runs `python -m app.migrate` by hand inside the app container; chapter 11 turns that into a hook.

## Verification status

`unverified`. A live run must confirm: the CNPG `Cluster` becomes healthy under `--wait`, the app pod starts against it, the manual migration succeeds, and `POST /api/shipments` returns 201 with the row stored in Postgres.
