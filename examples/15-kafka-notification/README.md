# 15 Kafka and the notification service

Snapshot for chapter 15 (`_docs/15-kafka-and-notification.md`). Three charts, installed as three releases into namespace `hfd-15`:

| Chart | Release | Role |
|---|---|---|
| `charts/shipping-kafka` | `kafka` | Strimzi `Kafka`, `KafkaNodePool`, `KafkaTopic` on `kafka.strimzi.io/v1` |
| `charts/notification-service` | `notification` | Kafka consumer, `GET /api/notifications` |
| `charts/shipping-service` | `shipping` | Producer; `kafka.enabled=true` in `values/shipping-dev.yaml` |

Chart versions are `0.15.0`. Both service charts still carry their own copy of the naming, label, probe and security helpers; chapter 17 moves them into `pc-lib`.

## Run

    [host]$ ./demo.sh offline   # lint, helm unittest, template, kubeconform with the CRDs-catalog
    [host]$ ./demo.sh           # offline checks, build images, install, dispatch a shipment, read the notification
    [host]$ ./demo.sh clean

The full run needs the helm4dev cluster with the Strimzi operator (`scripts/platform/bootstrap.sh`). It reaches the services through `scripts/tunnel.sh` on `127.0.0.1:8080` and `127.0.0.1:8081`.

## Verification status

unverified. A live run must confirm: the three releases install in order, the dispatched `shipmentId` appears in `/api/notifications`, shipping restarts a few times while Kafka starts and then settles, and `helm test` passes for both services.
