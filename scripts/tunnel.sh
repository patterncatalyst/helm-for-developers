#!/usr/bin/env bash
#
# tunnel.sh - SSH tunnels from the host to NodePort services on the helm4dev
# node. Replaces kubectl port-forward with long-lived connections that survive
# idle timeouts (ServerAliveInterval) and fail loudly on a busy local port.
#
#   scripts/tunnel.sh                    start every tunnel
#   scripts/tunnel.sh start shipping     start named tunnels only
#   scripts/tunnel.sh status             show which tunnels are alive
#   scripts/tunnel.sh stop               stop all tunnels started by this script
#
# Port map (local -> NodePort on the node):
#   shipping      8080 -> 30080
#   notification  8081 -> 30081
#   grafana       3000 -> 30300
#   argocd        8443 -> 30443
#   registry      5000 -> 5000    (registry addon hostPort; started only when named,
#                                  used by `scripts/build-images.sh push`)
#
# Use 127.0.0.1 in URLs. Only the helm4dev profile is used.

set -uo pipefail
# shellcheck source=env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh" || exit 1

PROFILE="helm4dev"
PIDFILE="$HFD_ROOT/.tools/tunnel.pids"
ALL_DEFAULT=(shipping notification grafana argocd)

# name -> "local node"
row() {
    case "$1" in
        shipping)     echo "8080 30080" ;;
        notification) echo "8081 30081" ;;
        grafana)      echo "3000 30300" ;;
        argocd)       echo "8443 30443" ;;
        registry)     echo "5000 5000" ;;
        *) return 1 ;;
    esac
}

info() { printf '    %s\n' "$1"; }
ok()   { printf '    ok: %s\n' "$1"; }
err()  { printf '    ERROR: %s\n' "$1" >&2; }

ssh_params() {
    SSH_KEY="$(minikube ssh-key -p "$PROFILE" 2>/dev/null)" || return 1
    local driver; driver="$(docker ps -a --filter "name=^${PROFILE}$" --format '{{.Names}}' 2>/dev/null)"
    [[ "$driver" == "$PROFILE" ]] || return 1
    SSH_PORT="$(docker port "$PROFILE" 22/tcp 2>/dev/null | head -1 | cut -d: -f2)"
    [[ -n "$SSH_KEY" && -n "$SSH_PORT" ]]
}

alive() { kill -0 "$1" 2>/dev/null; }

do_stop() {
    [[ -f "$PIDFILE" ]] || { info "no pidfile; nothing to stop"; return 0; }
    local n=0 pid name
    while IFS='|' read -r pid name _; do
        if alive "$pid"; then kill "$pid" 2>/dev/null && n=$((n + 1)); info "stopped $name (pid $pid)"; fi
    done < "$PIDFILE"
    rm -f "$PIDFILE"
    info "stopped $n tunnel(s)"
}

do_status() {
    [[ -f "$PIDFILE" ]] || { info "no tunnels tracked"; return 0; }
    local pid name lp
    while IFS='|' read -r pid name lp; do
        if alive "$pid"; then ok "$(printf '%-13s http://127.0.0.1:%s (pid %s)' "$name" "$lp" "$pid")"
        else err "$name dead (pid $pid)"; fi
    done < "$PIDFILE"
}

start_one() {
    local name="$1" r lp np pid
    r="$(row "$name")" || { err "unknown tunnel: $name"; return 2; }
    read -r lp np <<<"$r"
    if [[ -f "$PIDFILE" ]] && grep -q "^[0-9]*|${name}|" "$PIDFILE"; then
        pid="$(grep "^[0-9]*|${name}|" "$PIDFILE" | head -1 | cut -d'|' -f1)"
        if alive "$pid"; then ok "$name already up on 127.0.0.1:$lp"; return 0; fi
        sed -i "/^[0-9]*|${name}|/d" "$PIDFILE"
    fi
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes \
        -i "$SSH_KEY" -p "$SSH_PORT" -L "127.0.0.1:${lp}:127.0.0.1:${np}" \
        -N -f docker@127.0.0.1 2>/dev/null \
        || { err "$name: could not bind 127.0.0.1:$lp (port in use?)"; return 1; }
    pid="$(pgrep -n -f "ssh .*-L 127.0.0.1:${lp}:127.0.0.1:${np}" || true)"
    [[ -n "$pid" ]] && printf '%s|%s|%s\n' "$pid" "$name" "$lp" >> "$PIDFILE"
    ok "$(printf '%-13s 127.0.0.1:%s -> node:%s' "$name" "$lp" "$np")"
}

cmd="${1:-start}"
case "$cmd" in
    stop)    do_stop; exit 0 ;;
    status)  do_status; exit 0 ;;
    -h|--help) sed -n '3,22p' "${BASH_SOURCE[0]}"; exit 0 ;;
    start)   shift || true ;;
    shipping|notification|grafana|argocd|registry) ;;   # bare names start those tunnels
    *) err "unknown command: $cmd"; exit 2 ;;
esac

names=("$@")
[[ ${#names[@]} -eq 0 ]] && names=("${ALL_DEFAULT[@]}")

minikube status -p "$PROFILE" >/dev/null 2>&1 \
    || { err "profile $PROFILE is not running. Start it: scripts/platform/setup-profile.sh"; exit 1; }
ssh_params || { err "could not resolve the SSH key/port for $PROFILE (docker driver required)"; exit 1; }

mkdir -p "$(dirname "$PIDFILE")"; touch "$PIDFILE"
rc=0
for n in "${names[@]}"; do start_one "$n" || rc=1; done
info "stop with: scripts/tunnel.sh stop"
exit $rc
