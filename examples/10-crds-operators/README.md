# 10-crds-operators

Snapshot after chapter 10: the chapter 09 charts plus a demo CRD in `crds/` and an operator guard.

```
shipping-service/crds/shippingroute.yaml        ShippingRoute CRD (shipping.patterncatalyst.io/v1alpha1)
shipping-postgres/templates/cluster.yaml        guard: fail when postgresql.cnpg.io/v1 is not served
shipping-postgres/tests/guard_test.yaml         helm-unittest cases for the guard (capabilities.apiVersions)
shippingroute-v2.crd.yaml                       the CRD with one extra field (spec.priority), outside the chart
shippingroute-sample.yaml                       a ShippingRoute object
```

## Run it

```bash
./demo.sh offline   # lint, template --include-crds, guard fails then passes, unit tests, kubeconform
./demo.sh           # live: install, upgrade with a changed CRD, kubectl apply, uninstall
./demo.sh clean     # also deletes the CRD, which helm uninstall never does
```

The live run uses memory mode, so it needs no operator.

## What to look for

- Rendering omits `crds/` unless `--include-crds` is given.
- The guard error names the missing API and the three ways out.
- After `helm upgrade` with the v2 CRD the `spec` properties still lack `priority`. After `kubectl apply` they include it.
- After `helm uninstall` the CRD and the `ShippingRoute` object still exist.

## Verification status

`verified` on 2026-10-08 (`_plans/evidence/10-crds-operators.txt`): `helm upgrade` left the CRD unchanged, `kubectl apply` updated it without a conflict and added `kubectl-client-side-apply` to `managedFields`, `helm uninstall` kept the CRD and the sample object, the lint guard printed `level=INFO msg="funcMap fail"` with 0 failures, and the guard passed on a cluster with the CNPG operator.