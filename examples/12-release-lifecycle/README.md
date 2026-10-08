# 12-release-lifecycle

Snapshot after chapter 12: the chapter 11 charts plus an `extras.configMap` toggle that adds a second ConfigMap, so failure and adoption paths have something to act on. `demo.sh` drives one release (memory mode, namespace `hfd-12`) through success, failure, rollback, inspection, field-manager conflicts and adoption.

## Run it

```bash
./demo.sh offline   # lint, template (with and without extras), unit tests, kubeconform
./demo.sh           # live: eleven steps, each printed under a "===" heading
./demo.sh clean
```

## Steps in the live run

1. Install with `--wait` and `--history-max 5`.
2. A good upgrade.
3. A failing upgrade with `--rollback-on-failure`.
4. A failing upgrade that adds a ConfigMap, with `--cleanup-on-fail`.
5. Roll back with `helm rollback`, then `helm status`.
6. `helm get values|manifest|notes|metadata|hooks|all`.
7. Decode the `sh.helm.release.v1.*` Secret by hand.
8. Server-side apply conflict with another field manager, then `--force-conflicts`.
9. Adopt a pre-existing ConfigMap with `--take-ownership`.
10. `--force-replace`.
11. The final `helm history`.

## Verification status

`unverified`. A live run must confirm every step's outcome, in particular: the history rows after steps 3 and 4, that step 4 deletes only the new ConfigMap, the conflict message in step 8, and the refusal then adoption in step 9.
