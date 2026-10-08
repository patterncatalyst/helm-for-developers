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

The full run needs the helm4dev cluster with the Strimzi operator (`scripts/platform/bootstrap.sh`). It reaches the services on the published NodePorts `127.0.0.1:30080` and `127.0.0.1:30081`.

## Verification status

`verified` on 2026-10-08 (Helm 4.3.0, Strimzi 1.2.0, minikube `helm4dev`), evidence `_plans/evidence/15-kafka-notification.txt`. The full demo exits 0: the three releases install in order, the dispatched `shipmentId` appears in `/api/notifications`, and `helm test` passes for both services. Shipping shows 0 restarts in the demo (it installs after Kafka is Ready); installed concurrently with Kafka it restarted 3 times.
