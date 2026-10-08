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

`unverified`. `./demo.sh offline` passes on the authoring machine. The live repo install and the NodePort response are for the S7 sweep.
