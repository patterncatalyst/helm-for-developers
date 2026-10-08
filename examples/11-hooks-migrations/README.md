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

`unverified`. A live run must confirm the successful post-install migration, the warm hook ordering after the migration (weight 0 before 10), and the exact failure of both `deadlock` and `preinstall`.
