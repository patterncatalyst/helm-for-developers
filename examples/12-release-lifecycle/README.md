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
9. Adopt a pre-existing ConfigMap with `--take-ownership --force-conflicts`.
10. `--force-replace` (needs `--server-side=false`).
11. The final `helm history`.

## Verification status

`verified` on 2026-10-08 (`_plans/evidence/12-release-lifecycle.txt`): all eleven steps ran end to end. Step 9 needs `--force-conflicts` with `--take-ownership` when another field manager owns differing fields (after adoption only the `meta.helm.sh` annotations were captured, not the label, the replaced data or `managedFields`), and step 10 needs `--server-side=false`. Re-run on r1.1 on 2026-10-08 on the recreated helm4dev profile; this chapter makes no host requests, so only the cluster changed, and the behaviour above held. `demo.sh` step 6 piped `helm get ... | head` under `pipefail`, which could abort the run with exit 141; it now uses `sed -n`.
