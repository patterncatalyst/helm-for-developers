---
title: "Kafka and the notification service"
order: 15
part: "Multi-service applications"
description: "Add a Strimzi Kafka cluster as a chart of custom resources and a second application chart that consumes the shipment.dispatched event."
duration: 40 minutes
---

Until now one chart owned one workload. This chapter adds the second half of the application: a `shipping-kafka` chart that declares a Kafka cluster for the Strimzi operator, and a `notification-service` chart that consumes the `ShipmentDispatched` events shipping-service publishes. Three charts, three releases, and one address that has to match across them. That manual wiring is the problem the next chapter solves.

The code is in `examples/15-kafka-notification/`. The `demo.sh` there installs and runs it; its `README.md` covers what it does and how to drive it.

{% include excalidraw.html
   file="15-event-flow"
   alt="Diagram: shipping-service produces to the shipment.dispatched topic and notification-service consumes it; below, the shipping-kafka chart declares a Kafka, a KafkaNodePool and a KafkaTopic for the Strimzi operator"
   caption="Figure 15.1 — The dispatch event path and the three Strimzi resources behind the topic" %}

## An operator owns the brokers, the chart owns the declaration

The Strimzi operator (version 1.2.0, installed into the `strimzi` namespace by `scripts/platform/setup-kafka-operator.sh`) watches `Kafka`, `KafkaNodePool` and `KafkaTopic` resources and turns them into broker pods and topics. The application chart does not ship the operator. It ships the three custom resources, the same split chapter 10 drew for CloudNativePG. This is the Operator pattern: a controller reconciles a declared resource toward running state, so the chart stays a few dozen lines of YAML.

The chart renders `kafka.strimzi.io/v1`, which Strimzi 1.x serves. A value, `strimzi.apiVersion`, switches to `kafka.strimzi.io/v1beta2` for an operator older than 0.49; that path also emits the `strimzi.io/node-pools` and `strimzi.io/kraft` annotations those versions need.

## Three releases, three names

With separate releases the object names follow the fullname rule from chapter 7: `<release>-<chart>` unless the release name already contains the chart name. The demo uses release names `kafka`, `notification` and `shipping`, so the workloads are `notification-notification-service` and `shipping-shipping-service`. The Kafka resources are named by values instead (`shipping-kafka`, `dual`, `shipment.dispatched`) because other charts and the operator address them by name, not by release.

| Release | Chart | Creates | Needs from another release |
|---|---|---|---|
| `kafka` | `shipping-kafka` | `Kafka`, `KafkaNodePool`, `KafkaTopic` | Strimzi operator |
| `notification` | `notification-service` | Deployment, Service, ConfigMap | `kafka.bootstrap` |
| `shipping` | `shipping-service` | Deployment, Service, ConfigMap, Secret | `kafka.bootstrap`, `kafka.enabled` |

The last column is the weak point. Both application charts take the broker address as a value, and nothing checks that it names a Service that exists. A typo installs cleanly and fails at runtime: the shipping producer cannot connect, and the notification pod stays out of the Service because its consumer never starts.

## How the code works

**The Kafka cluster.** `templates/kafka.yaml` declares one internal plaintext listener and replication settings taken from values:

```yaml
spec:
  kafka:
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    config:
      offsets.topic.replication.factor: 1
      min.insync.replicas: 1
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

Replication factor and minimum in-sync replicas are 1 because the dev cluster has one broker; the stage and prod values files in chapter 24 raise them to 3 and 2. The `entityOperator.topicOperator` block matters: without it Strimzi never reconciles the `KafkaTopic`, and the topic does not exist until a producer auto-creates it.

**The node pool.** `templates/nodepool.yaml` is a `KafkaNodePool` named `dual` with `roles: [controller, broker]`: one KRaft node doing both jobs. It carries the label `strimzi.io/cluster: shipping-kafka`, which is how a pool attaches to its `Kafka`. Storage is `ephemeral` by default and `jbod` with a `persistent-claim` volume when `storage.type` says so.

**Dev-only sizing.** `values.yaml` asks for 200m CPU and 768Mi memory (limit 1536Mi) for the single node and uses ephemeral storage, so topic data disappears when the broker pod is rescheduled. That suits the lab, where the topic is re-created from the chart on every install. The `persistent-claim` branch of the node pool template exists for the stage and prod overrides, where `storage.size` becomes a PersistentVolumeClaim per node and `deleteClaim: true` removes it on uninstall. Check the data on a cluster before pointing such a values file at it.

**The topic.** `templates/topic.yaml` declares `shipment.dispatched` with the same cluster label, so one value (`clusterName`) must agree in three places. The chart also exports the address other charts need:

```yaml
exports:
  kafka:
    bootstrap: shipping-kafka-kafka-bootstrap:9092
```

Strimzi names the bootstrap Service `<cluster>-kafka-bootstrap`. `exports` is a plain value; nothing computes it from `clusterName`, so renaming the cluster means editing both. Chapter 16 imports this key.

**The consumer chart.** notification-service has the same shape as shipping-service: ConfigMap, Deployment, Service, schema, tests. Two parts are specific to it. The bootstrap address has no default in `values.yaml`, and the template refuses to render without it:

{% raw %}
```yaml
{{- define "notification-service.env" -}}
- name: KAFKA_BOOTSTRAP
  value: {{ required "kafka.bootstrap is required" .Values.kafka.bootstrap | quote }}
{{ include "notification-service.otelEnv" . }}
{{- end -}}
```
{% endraw %}

`required` fails at render time, so a missing address stops `helm install` before anything reaches the cluster. The consumer group, topic and log level go in the ConfigMap, and a `checksum/config` pod annotation rolls the pods when any of them change (chapter 8).

The readiness probe targets `/healthz`, which the service reports as healthy only while its consumer is connected. A pod with no broker stays Live but is held out of the Service, so `--wait` reflects readiness.

**The configuration both services read.** notification-service renders only what the Python settings class reads: `KAFKA_TOPIC_DISPATCHED`, `KAFKA_GROUP_ID`, `LOG_LEVEL`, `DEPLOY_ENV` and `SERVICE_NAME` in a ConfigMap, and `KAFKA_BOOTSTRAP` in the container env. The consumer group (`notification-service`) is a value so a second consumer chart can read the same topic independently. The values schema sets `additionalProperties: false`, so a misspelled key such as `kafka.bootstrapp` fails `helm lint` instead of being ignored; the unit tests include one that sets an invalid `config.logLevel` and expects the schema error.

**The producer side.** shipping-service gains nothing new in templates. Setting `kafka.enabled: true` and `kafka.bootstrap` in `values/shipping-dev.yaml` adds `KAFKA_ENABLED` to its ConfigMap and `KAFKA_BOOTSTRAP` to its container env.

**What is fragile.** The bootstrap address is typed into two values files and exported a third time. The shipping-service producer is created during application startup, so if the shipping pod starts while the broker pod is still starting, it restarts a few times before it connects. Installed concurrently with a fresh Kafka cluster it restarted 3 times (stable after about 40 seconds); in this chapter's demo it shows 0 restarts, because `kubectl wait` holds back the install until Kafka is Ready. In the full platform run (chapter 16) that took about 50 seconds to settle; the startup probe allows up to 60 seconds and `--wait` holds the release open until it does. Chapter 16 covers what `--wait` can and cannot order.

## Build, run, observe

```bash
cd examples/15-kafka-notification && ./demo.sh
```

The script runs the offline checks, builds both images, then installs three releases into `hfd-15`: `kafka` first, then a `kubectl wait --for=condition=Ready kafka/shipping-kafka` (the chart is custom resources only, so Helm has nothing it can watch), then `notification` and `shipping` with `--wait --rollback-on-failure`. Those flags follow Helm 4 semantics: `--wait` uses the kstatus watcher and `--rollback-on-failure` replaces the Helm 3 rollback flag ([helm upgrade reference](https://helm.sh/docs/helm/helm_upgrade/), [Helm 4 announcement](https://helm.sh/blog/helm-4-released/)).

It then dispatches a shipment through `127.0.0.1:8080` and reads `127.0.0.1:8081/api/notifications`. A notification with the same `shipmentId` shows the event crossed the topic. Without a cluster, `./demo.sh offline` runs lint, 33 unit tests and kubeconform:

```text
Summary: 3 resources found parsing stdin - Valid: 3, Invalid: 0, Errors: 0, Skipped: 0
```

## Cross-check

The offline run validates the Strimzi resources against the datree CRDs-catalog, so a wrong field in `Kafka` fails before any cluster exists. On a cluster, compare the chart with the operator's view:

```bash
kubectl -n hfd-15 get kafka,kafkanodepool,kafkatopic
helm get manifest kafka -n hfd-15 | grep -E '^kind:'
```

The kinds match, and `kafkatopic` shows `READY True` once the entity operator reconciles it. With the `topicOperator` line removed from the `Kafka` resource, the same `KafkaTopic` exists but has an empty `READY` column and no `status`: nothing reconciles it. For the consumer, `kubectl -n hfd-15 logs deploy/notification-notification-service` should show the `shipment ... dispatched` log line for the shipment you created, which confirms the same fact from the pod's side.

## What you learned

- A chart can ship custom resources for an operator without shipping the operator.
- `required` turns a missing cross-chart address into a render-time error.
- Separate releases force you to copy addresses between values files, which the umbrella chart removes.

Chapter 16 combines the four charts into one release.

## Further reading

- [Strimzi overview](https://strimzi.io/docs/operators/latest/overview.html): the Kafka, KafkaNodePool and KafkaTopic resources and the operators that reconcile them.
- Bilgin Ibryam, Roland Huß, *Kubernetes Patterns* (O'Reilly, 2023), ISBN 9781098131678. Used here for: the Operator pattern, a controller reconciling a custom resource.

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/15-kafka-notification.txt`. Observed on Helm 4.3.0, Strimzi 1.2.0 and minikube: the Kafka, KafkaNodePool and KafkaTopic reached Ready on `kafka.strimzi.io/v1`; the dispatched `shipmentId` 1 appeared in `/api/notifications` and in the consumer log; `helm test` passed for both services; a wrong bootstrap address left the new notification pod Running but 0/1 Ready; shipping restarted 3 times when installed concurrently with Kafka and 0 times when installed after it.*
