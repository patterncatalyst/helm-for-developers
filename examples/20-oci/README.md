# 20 - OCI registries

The same `shipping-service` 1.0.0 package pushed to and pulled from OCI registries: an anonymous registry on 127.0.0.1:5001, an htpasswd registry on 127.0.0.1:5002, and (optionally) the minikube registry addon.

## Run

```bash
./demo.sh offline          # lint, template + kubeconform, unittest, package (no registry, no cluster)
./demo.sh                  # starts hfd-registry and hfd-registry-auth containers, push/show/pull, login, OCI dependency, install by digest into hfd-20
ENGINE=podman ./demo.sh    # use podman instead of docker
REGISTRY_ADDON=1 ./demo.sh # also push to the registry addon through scripts/tunnel.sh start registry
./demo.sh clean            # uninstall, remove both containers, delete .work/
```

The registries use plain HTTP, so every command that talks to them carries `--plain-http`.

## What to look for

- Running `helm push` without `--plain-http` fails with "server gave HTTP response to HTTPS client".
- The registry catalog lists `charts/shipping-service` with tag `1.0.0`.
- `sha256sum` of the pulled `.tgz` is the chart-layer digest; the digest `helm push` prints is the manifest digest.
- `helm pull ...@sha256:<manifest digest>` and `helm install ...@sha256:<manifest digest>` pin the exact artifact.
- `helm dependency update --plain-http` fetches `pc-lib` from `oci://127.0.0.1:5001/charts`.

## Verification status

`unverified`. `./demo.sh offline` passes. The registry flow ran locally during authoring; the cluster install by digest and the registry addon path are for the S7 sweep.
