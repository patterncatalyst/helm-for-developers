# 11-hooks-migrations

Snapshot after chapter 11: the chapter 10 charts plus the schema migration Job as a Helm hook and an optional `post-upgrade` warm hook.

```
shipping-service/templates/migration-job.yaml   hook Job: python -m app.migrate
shipping-service/templates/warm-job.yaml        post-upgrade hook, off by default (warm.enabled)
values-postgres.yaml                            post-install,post-upgrade hooks, readiness on /health
```

## Run it

```bash
./demo.sh offline     # lint, template, unit tests, kubeconform
./demo.sh             # live: install with --wait, show events and schema_migrations, upgrade with the warm hook
./demo.sh deadlock    # reproduce the hooks-versus-readiness deadlock (90 s timeout, ends in failure)
./demo.sh preinstall  # reproduce a pre-install hook against an in-release database (90 s timeout)
./demo.sh clean
```

## What to look for

- The Job is deleted when it succeeds (`hook-succeeded`), so `kubectl get jobs` is empty afterwards. Events and `shipping.schema_migrations` show it ran.
- `helm get hooks shipping -n hfd-11` prints the Job manifest with its annotations.
- `deadlock` ends with `context deadline exceeded` because `/healthz` needs the migrated tables and a post-install hook starts only after `--wait` sees the Deployment ready.
- `preinstall` leaves the hook Job unable to start: the `shipping-postgres-app` Secret does not exist before the main resources are created.

## Verification status

`verified` on 2026-10-08 (`_plans/evidence/11-hooks-migrations.txt`): The post-install migration succeeded under `--wait`, the Job was deleted on success and `shipping.schema_migrations` held versions 1 and 2, the warm hook ran after the migration, `deadlock` failed with `context deadline exceeded` and no Job, and `preinstall` failed with `secret "shipping-postgres-app" not found` (evidence also in `_plans/evidence/11-hooks-migrations-deadlock.txt` and `-preinstall.txt`). Re-run on r1.1 with published NodePorts on 2026-10-08 (helm4dev recreated with `HFD_NODE_PORTS`, host requests at `http://127.0.0.1:30080`, no tunnel); the behaviour above held.