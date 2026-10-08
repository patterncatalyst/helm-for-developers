# 19 - Packaging and repositories

Snapshot of `shipping-service` 1.0.0 (appVersion 0.1.0) with the `pc-lib` library chart, packaged with `helm package` and served as a classic chart repository.

## Run

```bash
./demo.sh offline   # lint --strict, template + kubeconform, helm unittest, package, helm repo index (no cluster, no network)
./demo.sh           # offline, then python3 -m http.server on 127.0.0.1:8088, helm repo add/update/search/pull, install into hfd-19
./demo.sh clean     # uninstall, helm repo remove hfd-local, stop the server, delete .work/
```

## What to look for

- Running `helm package` without `--dependency-update` fails on a fresh checkout because `charts/pc-lib-1.0.0.tgz` is not committed.
- `index.yaml` lists `version`, `appVersion`, `digest` and `urls` for each archive; the digest equals `sha256sum` of the `.tgz`.
- The command `helm search repo hfd-local` hides `1.1.0-rc.1` until `--devel` is added.
- `helm upgrade --install ... hfd-local/shipping-service --version 1.0.0` creates a release whose chart is the packaged archive, not the directory.

## Layout

```
charts/shipping-service/   chart at 1.0.0 (dependency: pc-lib via file://../pc-lib)
charts/pc-lib/             library chart 1.0.0
demo.sh
```

## Verification status

`verified` on 2026-10-08 (Helm 4.3.0, minikube `helm4dev`), evidence `_plans/evidence/19-packaging-repos.txt`. The full demo exits 0, the release installs from the local repository, and `/api/info` answers on the published NodePort. Re-run on r1.1 with published NodePorts (bound to 127.0.0.1) on 2026-10-08: `./demo.sh` exited 0 and `./demo.sh clean` removed the namespace; the local repository served the chart and the install from it reached deployed (the demo only prints the `curl http://127.0.0.1:30080/api/info` hint, so that request was not exercised).
