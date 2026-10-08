#!/usr/bin/env bash
#
# env.sh - project-local tool isolation. Source it; do not execute it.
#
#   source scripts/env.sh
#
# Puts the project's Helm 4 toolchain (.tools/bin) first on PATH and points every
# Helm state directory under .tools/helm/, so the global Helm 3 in ~/.local/bin
# and its repos, caches and plugins are never read or modified.
#
# Fails (return 1 when sourced) if `helm version --short` is not v4.*.
# install-tools.sh sets HFD_SKIP_HELM_CHECK=1 for the one run that creates Helm.

if [ -n "${BASH_VERSION:-}" ]; then
    _hfd_self="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
    _hfd_self="${(%):-%x}"
else
    _hfd_self="$0"
fi
HFD_ROOT="$(cd "$(dirname "$_hfd_self")/.." && pwd)"
unset _hfd_self
export HFD_ROOT

export PATH="$HFD_ROOT/.tools/bin:$PATH"
export HELM_CONFIG_HOME="$HFD_ROOT/.tools/helm/config"
export HELM_CACHE_HOME="$HFD_ROOT/.tools/helm/cache"
export HELM_DATA_HOME="$HFD_ROOT/.tools/helm/data"
export HELM_PLUGINS="$HFD_ROOT/.tools/helm/plugins"
export GNUPGHOME="$HFD_ROOT/.tools/gnupg"
export MINIKUBE_PROFILE="helm4dev"

mkdir -p "$HELM_CONFIG_HOME" "$HELM_CACHE_HOME" "$HELM_DATA_HOME" "$HELM_PLUGINS" 2>/dev/null
# Helm 4 puts local-directory plugin installs in $HELM_DATA_HOME/plugins, not
# $HELM_PLUGINS. Point that path at HELM_PLUGINS so both install styles land together.
[ -e "$HELM_DATA_HOME/plugins" ] || ln -s "$HELM_PLUGINS" "$HELM_DATA_HOME/plugins" 2>/dev/null
mkdir -p "$GNUPGHOME" 2>/dev/null && chmod 700 "$GNUPGHOME" 2>/dev/null

if [ "${HFD_SKIP_HELM_CHECK:-0}" != "1" ]; then
    _hfd_hv="$(helm version --short 2>/dev/null || true)"
    case "$_hfd_hv" in
        v4.*) ;;
        *)
            printf 'env.sh: expected Helm v4.*, found "%s" (helm resolves to: %s).\n' \
                "${_hfd_hv:-none}" "$(command -v helm || echo 'not found')" >&2
            printf 'env.sh: run scripts/install-tools.sh to install the project-local toolchain.\n' >&2
            unset _hfd_hv
            return 1 2>/dev/null || exit 1
            ;;
    esac
    unset _hfd_hv
fi
