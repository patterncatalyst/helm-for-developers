#!/usr/bin/env bash
#
# build-and-push.sh - build the two service images and push them to the OpenShift
# Local internal registry through its default route.
#
# UNTESTED on the authoring machine; run on the CRC host.
#
#   ./build-and-push.sh              build and push both images
#   ./build-and-push.sh shipping-service     one image only
#
# Needs: oc logged in, podman, the repo's services/ directory. NAMESPACE defaults to hfd-ocp.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
NAMESPACE="${NAMESPACE:-hfd-ocp}"
TAG="0.1.0"
ALL=(shipping-service notification-service)
SERVICES=("$@"); [[ ${#SERVICES[@]} -eq 0 ]] && SERVICES=("${ALL[@]}")

for t in oc podman; do command -v "$t" >/dev/null || { echo "ERROR: $t not on PATH" >&2; exit 1; }; done
oc whoami >/dev/null 2>&1 || { echo "ERROR: not logged in (oc login ...)" >&2; exit 1; }

# 1. Project (idempotent).
oc get project "$NAMESPACE" >/dev/null 2>&1 || oc new-project "$NAMESPACE" >/dev/null
oc project "$NAMESPACE" >/dev/null

# 2. Expose the registry's external route (idempotent merge patch).
oc patch configs.imageregistry.operator.openshift.io/cluster --type=merge -p '{"spec":{"defaultRoute":true}}' >/dev/null
for _ in $(seq 1 30); do
    REG="$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}' 2>/dev/null || true)"
    [[ -n "$REG" ]] && break; sleep 2
done
[[ -n "${REG:-}" ]] || { echo "ERROR: registry default-route did not appear" >&2; exit 1; }
printf '==> registry: %s\n' "$REG"

# 3. Log in with the cluster token. The route uses the cluster CA, so skip TLS verify locally.
podman login --tls-verify=false -u "$(oc whoami)" -p "$(oc whoami -t)" "$REG"

# 4. Build, tag, push. Pushing creates an ImageStream per image in the project.
for svc in "${SERVICES[@]}"; do
    printf '\n==> %s:%s\n' "$svc" "$TAG"
    podman build -f "$REPO_ROOT/services/Containerfile" --build-arg "SERVICE=$svc" -t "$REG/$NAMESPACE/$svc:$TAG" "$REPO_ROOT/services"
    podman push --tls-verify=false "$REG/$NAMESPACE/$svc:$TAG"
done
printf '\n==> image streams in %s:\n' "$NAMESPACE"
oc get imagestream -n "$NAMESPACE"
