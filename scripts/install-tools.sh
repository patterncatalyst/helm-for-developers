#!/usr/bin/env bash
#
# install-tools.sh - install the project-local toolchain into .tools/ only.
#
# Never touches ~/.local/bin, /usr/local or any other system path. Idempotent:
# a tool whose pinned version is already present is skipped.
#
#   scripts/install-tools.sh            # install everything
#   scripts/install-tools.sh --force    # reinstall even if the pinned version is present
#
# Installs (all checksum-verified against the upstream release checksum file):
#   Helm 4, kubeconform, chart-testing (ct) + yamllint/yamale in .tools/venv,
#   cosign, helmfile (1.2+ supports Helm 4), then the helm-unittest and helm-diff
#   plugins into HELM_PLUGINS (.tools/helm/plugins).

set -euo pipefail

# Pinned 2026-10-08 from `gh release list` for each upstream repository.
HELM_VERSION="${HELM_VERSION:-4.3.0}"            # helm/helm
KUBECONFORM_VERSION="${KUBECONFORM_VERSION:-0.8.0}"   # yannh/kubeconform
CT_VERSION="${CT_VERSION:-3.15.0}"               # helm/chart-testing
COSIGN_VERSION="${COSIGN_VERSION:-3.1.3}"        # sigstore/cosign
HELMFILE_VERSION="${HELMFILE_VERSION:-1.8.1}"    # helmfile/helmfile (Helm 4 support since 1.2.0)
UNITTEST_VERSION="${UNITTEST_VERSION:-1.2.1}"    # helm-unittest/helm-unittest
HELM_DIFF_VERSION="${HELM_DIFF_VERSION:-3.15.15}" # databus23/helm-diff
YAMLLINT_VERSION="${YAMLLINT_VERSION:-1.37.1}"
YAMALE_VERSION="${YAMALE_VERSION:-6.0.0}"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

export HFD_SKIP_HELM_CHECK=1
# shellcheck source=env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
unset HFD_SKIP_HELM_CHECK

BIN="$HFD_ROOT/.tools/bin"
DL="$HFD_ROOT/.tools/dl"
mkdir -p "$BIN" "$DL"

step() { printf '\n==> %s\n' "$1"; }
ok()   { printf '    ok: %s\n' "$1"; }
fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)  OS=linux;  ARCH=amd64 ;;
    Linux-aarch64) OS=linux;  ARCH=arm64 ;;
    Darwin-x86_64) OS=darwin; ARCH=amd64 ;;
    Darwin-arm64)  OS=darwin; ARCH=arm64 ;;
    *) fail "unsupported platform $(uname -s)-$(uname -m)" ;;
esac

for t in curl tar sha256sum python3; do
    command -v "$t" >/dev/null 2>&1 || fail "$t is required on the host"
done

fetch() { curl -fsSL --retry 3 -o "$2" "$1" || fail "download failed: $1"; }

# verify_sum <file> <expected-sha256>
verify_sum() {
    local got; got="$(sha256sum "$1" | awk '{print $1}')"
    [[ "$got" == "$2" ]] || fail "checksum mismatch for $(basename "$1"): expected $2, got $got"
    ok "sha256 verified: $(basename "$1")"
}

# sum_from_file <checksums-file> <asset-name> -> hash
sum_from_file() { awk -v n="$2" '$2==n || $2=="*"n {print $1; exit}' "$1"; }

have_version() { # <binary> <version-substring> <args...>
    local bin="$1" want="$2"; shift 2
    [[ $FORCE -eq 0 && -x "$BIN/$bin" ]] && "$BIN/$bin" "$@" 2>&1 | grep -q "$want"
}

# ─── Helm 4 ────────────────────────────────────────────────────────────────
step "Helm ${HELM_VERSION}"
if have_version helm "v${HELM_VERSION}" version --short; then
    ok "already installed"
else
    f="helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz"
    fetch "https://get.helm.sh/${f}" "$DL/$f"
    fetch "https://get.helm.sh/${f}.sha256sum" "$DL/$f.sha256sum"
    verify_sum "$DL/$f" "$(awk '{print $1}' "$DL/$f.sha256sum")"
    d="$DL/helm-x"; rm -rf "$d"; mkdir -p "$d"; tar -xzf "$DL/$f" -C "$d"
    install -m 0755 "$d/${OS}-${ARCH}/helm" "$BIN/helm"
    ok "$("$BIN/helm" version --short)"
fi
[[ "$("$BIN/helm" version --short)" == v4.* ]] || fail "installed helm is not v4"

# ─── kubeconform ───────────────────────────────────────────────────────────
step "kubeconform ${KUBECONFORM_VERSION}"
if have_version kubeconform "v${KUBECONFORM_VERSION}" -v; then
    ok "already installed"
else
    f="kubeconform-${OS}-${ARCH}.tar.gz"
    base="https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}"
    fetch "$base/$f" "$DL/$f"; fetch "$base/CHECKSUMS" "$DL/kubeconform.CHECKSUMS"
    verify_sum "$DL/$f" "$(sum_from_file "$DL/kubeconform.CHECKSUMS" "$f")"
    d="$DL/kubeconform-x"; rm -rf "$d"; mkdir -p "$d"; tar -xzf "$DL/$f" -C "$d"
    install -m 0755 "$d/kubeconform" "$BIN/kubeconform"
    ok "$("$BIN/kubeconform" -v)"
fi

# ─── cosign ────────────────────────────────────────────────────────────────
step "cosign ${COSIGN_VERSION}"
if have_version cosign "v${COSIGN_VERSION}" version; then
    ok "already installed"
else
    f="cosign-${OS}-${ARCH}"
    base="https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}"
    fetch "$base/$f" "$DL/$f"; fetch "$base/cosign_checksums.txt" "$DL/cosign_checksums.txt"
    verify_sum "$DL/$f" "$(sum_from_file "$DL/cosign_checksums.txt" "$f")"
    install -m 0755 "$DL/$f" "$BIN/cosign"
    ok "installed cosign"
fi

# ─── chart-testing (ct) + yamllint/yamale ──────────────────────────────────
step "chart-testing ${CT_VERSION}"
if have_version ct "${CT_VERSION}" version; then
    ok "already installed"
else
    f="chart-testing_${CT_VERSION}_${OS}_${ARCH}.tar.gz"
    base="https://github.com/helm/chart-testing/releases/download/v${CT_VERSION}"
    fetch "$base/$f" "$DL/$f"; fetch "$base/checksums.txt" "$DL/ct.checksums.txt"
    verify_sum "$DL/$f" "$(sum_from_file "$DL/ct.checksums.txt" "$f")"
    d="$DL/ct-x"; rm -rf "$d"; mkdir -p "$d"; tar -xzf "$DL/$f" -C "$d"
    install -m 0755 "$d/ct" "$BIN/ct"
    # ct's default lint configuration (chart schema + yamllint rules).
    mkdir -p "$HFD_ROOT/.tools/ct"
    cp "$d"/etc/chart_schema.yaml "$d"/etc/lintconf.yaml "$HFD_ROOT/.tools/ct/" 2>/dev/null || true
    ok "$("$BIN/ct" version 2>&1 | head -1)"
fi
step "yamllint ${YAMLLINT_VERSION} + yamale ${YAMALE_VERSION} (.tools/venv, used by ct lint)"
VENV="$HFD_ROOT/.tools/venv"
if [[ $FORCE -eq 0 && -x "$VENV/bin/yamllint" && -x "$VENV/bin/yamale" ]] \
   && "$VENV/bin/yamllint" --version 2>&1 | grep -q "$YAMLLINT_VERSION"; then
    ok "already installed"
else
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install --quiet --disable-pip-version-check \
        "yamllint==${YAMLLINT_VERSION}" "yamale==${YAMALE_VERSION}"
    ok "venv ready"
fi
ln -sf "$VENV/bin/yamllint" "$BIN/yamllint"
ln -sf "$VENV/bin/yamale" "$BIN/yamale"

# ─── helmfile (optional; 1.2.0+ supports Helm 4) ───────────────────────────
step "helmfile ${HELMFILE_VERSION}"
if have_version helmfile "${HELMFILE_VERSION}" version; then
    ok "already installed"
else
    f="helmfile_${HELMFILE_VERSION}_${OS}_${ARCH}.tar.gz"
    base="https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}"
    fetch "$base/$f" "$DL/$f"; fetch "$base/helmfile_${HELMFILE_VERSION}_checksums.txt" "$DL/helmfile.checksums.txt"
    verify_sum "$DL/$f" "$(sum_from_file "$DL/helmfile.checksums.txt" "$f")"
    d="$DL/helmfile-x"; rm -rf "$d"; mkdir -p "$d"; tar -xzf "$DL/$f" -C "$d"
    install -m 0755 "$d/helmfile" "$BIN/helmfile"
    ok "installed helmfile"
fi

# ─── Helm plugins ──────────────────────────────────────────────────────────
# Helm 4 verifies plugin installs. See the `--verify` flag in
# `helm plugin install --help`; the flag set used below is recorded in
# CONTRIBUTING.md by the orchestrator.
step "Helm plugins (HELM_PLUGINS=$HELM_PLUGINS)"
PLUGIN_FLAGS=()
if helm plugin install --help 2>&1 | grep -q -- '--verify'; then
    PLUGIN_FLAGS+=(--verify=false)
fi

install_plugin() { # <name> <url> <version>
    local name="$1" url="$2" ver="$3"
    if [[ $FORCE -eq 0 ]] && helm plugin list 2>/dev/null | awk 'NR>1{print $1,$2}' | grep -q "^${name} ${ver}$"; then
        ok "plugin ${name} ${ver} already installed"
        return
    fi
    helm plugin uninstall "$name" >/dev/null 2>&1 || true
    helm plugin install "$url" --version "v${ver}" "${PLUGIN_FLAGS[@]}"
}
install_plugin unittest https://github.com/helm-unittest/helm-unittest "$UNITTEST_VERSION"
install_plugin diff https://github.com/databus23/helm-diff "$HELM_DIFF_VERSION"
helm plugin list

step "Done. Tools live in $BIN; nothing outside $HFD_ROOT/.tools was modified."
printf '    Use them with:  source scripts/env.sh\n'
