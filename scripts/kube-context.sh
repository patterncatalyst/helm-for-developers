#!/usr/bin/env bash
#
# kube-context.sh - pin every kubectl and Helm call in a minikube demo to helm4dev.
# Source it after scripts/env.sh; do not execute it.
#
#   source scripts/kube-context.sh
#
# The current kubectl context (a CRC session, another minikube profile, anything) never
# decides where a demo acts. This file:
#   - exports HELM_KUBECONTEXT=helm4dev, which every `helm` call and every Helm plugin
#     (helm-secrets, helm-diff) reads, and HELMFILE_KUBE_CONTEXT for helmfile;
#   - defines a `kubectl` shell function that adds --context helm4dev, and exports it so
#     child bash scripts (build-images.sh, setup scripts) inherit it;
#   - defines a `curl` shell function that prints each URL it requests to stderr
#     ("    curl -> http://127.0.0.1:30080/api/info"), so a transcript shows the host
#     address and port that answered; stdout, and so every captured value, is unchanged;
#   - defines hfd_pinned_kubeconfig <file> for tools that run kubectl themselves (ct).
# Chapter 27 targets OpenShift Local and does not source this file.

export HELM_KUBECONTEXT="helm4dev"
export HELMFILE_KUBE_CONTEXT="helm4dev"

kubectl() { command kubectl --context "$HELM_KUBECONTEXT" "$@"; }
[ -n "${BASH_VERSION:-}" ] && export -f kubectl

curl() {
    local a
    for a in "$@"; do
        case "$a" in http://*|https://*|127.0.0.1:*) printf '    curl -> %s\n' "$a" >&2 ;; esac
    done
    command curl "$@"
}
[ -n "${BASH_VERSION:-}" ] && export -f curl

# Write a kubeconfig that holds only the helm4dev context, as the current context.
hfd_pinned_kubeconfig() {
    command kubectl config view --minify --flatten --context "$HELM_KUBECONTEXT" > "$1"
    chmod 600 "$1"
}
