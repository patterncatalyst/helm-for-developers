#!/usr/bin/env bash
#
# build-images.sh - build the two service images into the helm4dev cluster.
#
#   scripts/build-images.sh                      build both images into the profile
#   scripts/build-images.sh push                 build, then also push to the registry addon
#   scripts/build-images.sh [push] shipping-service      one image only
#
# Both images come from services/Containerfile with --build-arg SERVICE=<name>
# and the build context services/. Tag: 0.1.0 (the chart appVersion).
#   build: shipping-service:0.1.0, notification-service:0.1.0 (visible to the node as
#          docker.io/library/<name>:0.1.0, so chart value `image.repository: <name>` works)
#   push:  additionally localhost:5000/<name>:0.1.0 in the registry addon, reached
#          through an SSH tunnel to the node (scripts/tunnel.sh registry)
#
# BUILD_ENGINE selects the builder: docker (default when available), podman, or
# minikube (`minikube image build`, builds inside the node). docker and podman
# builds are copied into the profile with `minikube image load`.
# Push mode prefers podman when it is installed: a Docker daemon that runs in a VM
# (Docker Desktop) cannot reach the host-side registry tunnel on 127.0.0.1:5000.
# Set BUILD_ENGINE=docker to override.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$HERE/env.sh"

PROFILE="helm4dev"
TAG="0.1.0"
ALL=(shipping-service notification-service)
CONTEXT="$HFD_ROOT/services"
CONTAINERFILE="$CONTEXT/Containerfile"

MODE="build"
if [[ "${1:-}" == "push" ]]; then MODE="push"; shift; elif [[ "${1:-}" == "build" ]]; then shift; fi
SERVICES=("$@"); [[ ${#SERVICES[@]} -eq 0 ]] && SERVICES=("${ALL[@]}")
for s in "${SERVICES[@]}"; do
    case "$s" in shipping-service|notification-service) ;; *) echo "ERROR: unknown service: $s" >&2; exit 2 ;; esac
done

[[ -f "$CONTAINERFILE" ]] || { echo "ERROR: $CONTAINERFILE not found" >&2; exit 1; }
command -v minikube >/dev/null || { echo "ERROR: minikube not on PATH" >&2; exit 1; }
minikube status -p "$PROFILE" >/dev/null 2>&1 \
    || { echo "ERROR: profile $PROFILE is not running (scripts/platform/setup-profile.sh)" >&2; exit 1; }

ENGINE="${BUILD_ENGINE:-}"
if [[ -z "$ENGINE" ]]; then
    if [[ "$MODE" == "push" ]] && command -v podman >/dev/null 2>&1; then ENGINE=podman
    elif command -v docker >/dev/null 2>&1; then ENGINE=docker
    elif command -v podman >/dev/null 2>&1; then ENGINE=podman
    else ENGINE=minikube; fi
fi
printf '==> engine=%s mode=%s tag=%s\n' "$ENGINE" "$MODE" "$TAG"

for svc in "${SERVICES[@]}"; do
    printf '\n==> %s:%s\n' "$svc" "$TAG"
    case "$ENGINE" in
        docker|podman)
            "$ENGINE" build -f "$CONTAINERFILE" --build-arg "SERVICE=$svc" -t "$svc:$TAG" "$CONTEXT"
            minikube -p "$PROFILE" image load "$svc:$TAG"
            ;;
        minikube)
            minikube -p "$PROFILE" image build -f "$CONTAINERFILE" -t "$svc:$TAG" \
                --build-opt="build-arg=SERVICE=$svc" "$CONTEXT"
            ;;
        *) echo "ERROR: BUILD_ENGINE must be docker, podman or minikube" >&2; exit 2 ;;
    esac
done

if [[ "$MODE" == "push" ]]; then
    [[ "$ENGINE" == "minikube" ]] && { echo "ERROR: push mode needs BUILD_ENGINE=docker or podman" >&2; exit 2; }
    if [[ "$ENGINE" == "docker" ]] && ! command -v podman >/dev/null 2>&1; then
        echo "note: a Docker daemon in a VM cannot reach localhost:5000; install podman or use Docker Engine on Linux" >&2
    fi
    printf '\n==> push to the registry addon (localhost:5000 via SSH tunnel)\n'
    "$HERE/tunnel.sh" registry
    for svc in "${SERVICES[@]}"; do
        "$ENGINE" tag "$svc:$TAG" "localhost:5000/$svc:$TAG"
        if [[ "$ENGINE" == "podman" ]]; then
            podman push --tls-verify=false "localhost:5000/$svc:$TAG"
        else
            docker push "localhost:5000/$svc:$TAG"
        fi
    done
    printf '    pushed: %s\n' "${SERVICES[@]/#/localhost:5000/}"
fi

printf '\n==> images in the profile:\n'
minikube -p "$PROFILE" image ls 2>/dev/null | grep -E 'shipping-service|notification-service' || true
