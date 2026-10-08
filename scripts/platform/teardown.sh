#!/usr/bin/env bash
#
# teardown.sh - delete the helm4dev minikube profile and everything in it.
# Only the helm4dev profile is ever deleted; pass --yes to skip the prompt.

set -euo pipefail
# shellcheck source=lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_tools minikube

if [[ "${1:-}" != "--yes" ]]; then
    printf 'About to delete minikube profile "%s": cluster, images, volumes. Continue? [y/N] ' "$PROFILE"
    read -r answer
    [[ "$answer" =~ ^[Yy] ]] || { printf 'Aborted.\n'; exit 1; }
fi
minikube delete -p "$PROFILE"
printf 'Profile %s deleted.\n' "$PROFILE"
