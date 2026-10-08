#!/usr/bin/env bash
#
# examples/21-signing/demo.sh
#
#   ./demo.sh           # offline checks, helm package --sign + verify, OCI push, cosign sign + verify, tamper checks
#   ./demo.sh offline   # lint, template + kubeconform, unittest (no keys, no registry, no cluster)
#   ./demo.sh clean     # uninstall, remove the registry container, delete the throwaway GPG key and .work/
#
#   ENGINE=podman ./demo.sh     # container engine for the local registry (default: docker)
#
# Throwaway material only: a GPG key in the project-local $GNUPGHOME (.tools/gnupg) and a cosign key
# pair in .work/cosign. Nothing here is a real signing identity. Registry: 127.0.0.1:5001, plain HTTP.
# Namespace hfd-21, release shipping.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" && cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/env.sh
source "$REPO_ROOT/scripts/env.sh"
# shellcheck source=../../scripts/kube-context.sh
source "$REPO_ROOT/scripts/kube-context.sh"

ENGINE="${ENGINE:-docker}"
NS=hfd-21; REL=shipping
CHART=charts/shipping-service
WORK="$SCRIPT_DIR/.work"
KEYNAME="HFD Throwaway Signer"
REG=127.0.0.1:5001
# A fresh content cache per run: Helm 4 caches downloaded charts and provenance by digest, which would
# let a byte-identical unsigned copy reuse a cached .prov and hide the negative checks below.
export HELM_CACHE_HOME="$WORK/helm-cache"
step() { printf '\n== %s\n' "$*"; }

offline() {
    step "dependency build"
    helm dependency build "$CHART"
    step "lint --strict"
    helm lint "$CHART" --strict
    step "template | kubeconform"
    helm template "$REL" "$CHART" | kubeconform -strict -summary -ignore-missing-schemas
    step "unittest"
    helm unittest "$CHART"
}

make_gpg_key() {
    step "throwaway GPG key in $GNUPGHOME"
    mkdir -p "$WORK/keys"
    if ! gpg --list-secret-keys "$KEYNAME" >/dev/null 2>&1; then
        cat >"$WORK/keys/params" <<PARAMS
%no-protection
Key-Type: RSA
Key-Length: 3072
Name-Real: $KEYNAME
Name-Email: signer@hfd.invalid
Expire-Date: 0
%commit
PARAMS
        gpg --batch --gen-key "$WORK/keys/params"
    fi
    # gpg 2 stores keys in pubring.kbx and private-keys-v1.d; helm package --sign reads the legacy format.
    gpg --export-secret-keys >"$WORK/keys/secring.gpg"
    gpg --export >"$WORK/keys/pubring.gpg"
}

sign_and_verify() {
    step "helm package --sign against the default (kbx) keyring fails"
    mkdir -p "$WORK/signed"
    helm package "$CHART" --dependency-update --sign --key "$KEYNAME" -d "$WORK/signed" || true
    step "helm package --sign with the legacy keyring"
    helm package "$CHART" --dependency-update --sign --key "$KEYNAME" --keyring "$WORK/keys/secring.gpg" -d "$WORK/signed"
    ls "$WORK/signed"
    sed -n '/^files:/,/^-----BEGIN PGP SIGNATURE/p' "$WORK/signed/shipping-service-1.0.0.tgz.prov"
    step "helm verify"
    helm verify "$WORK/signed/shipping-service-1.0.0.tgz"
    step "tamper: change one value inside the archive, keep the old .prov"
    rm -rf "$WORK/bad"; mkdir -p "$WORK/bad/x"
    cp "$WORK/signed"/shipping-service-1.0.0.tgz* "$WORK/bad/"
    tar xzf "$WORK/bad/shipping-service-1.0.0.tgz" -C "$WORK/bad/x"
    sed -i 's/ACME-Post/EVIL-Post/' "$WORK/bad/x/shipping-service/values.yaml"
    tar czf "$WORK/bad/shipping-service-1.0.0.tgz" -C "$WORK/bad/x" shipping-service
    if helm verify "$WORK/bad/shipping-service-1.0.0.tgz"; then echo "UNEXPECTED: tampered chart verified" >&2; exit 1; fi
}

start_registry() {
    if ! curl -fs "http://$REG/v2/" >/dev/null 2>&1; then
        step "start local registry ($ENGINE)"
        "$ENGINE" rm -f hfd-registry >/dev/null 2>&1 || true
        "$ENGINE" run -d --name hfd-registry -p 127.0.0.1:5001:5000 docker.io/library/registry:2 >/dev/null
        for i in $(seq 1 30); do curl -fs "http://$REG/v2/" >/dev/null && break; sleep 1; done
    fi
}

oci_signed() {
    step "helm push uploads the .prov as a second layer"
    helm push "$WORK/signed/shipping-service-1.0.0.tgz" "oci://$REG/signed" --plain-http | tee "$WORK/push.txt"
    DIGEST="$(awk '/^Digest:/ {print $2}' "$WORK/push.txt")"
    curl -s -H 'Accept: application/vnd.oci.image.manifest.v1+json' "http://$REG/v2/signed/shipping-service/manifests/1.0.0" \
        | python3 -c 'import json,sys; [print(l["mediaType"]) for l in json.load(sys.stdin)["layers"]]'
    step "helm pull --verify"
    mkdir -p "$WORK/pull"
    helm pull "oci://$REG/signed/shipping-service" --version 1.0.0 --plain-http --verify -d "$WORK/pull"
    step "an unsigned chart in the same registry is refused by --verify"
    mkdir -p "$WORK/unsigned"
    helm package "$CHART" --version 1.0.5 -d "$WORK/unsigned"
    helm push "$WORK/unsigned/shipping-service-1.0.5.tgz" "oci://$REG/unsigned" --plain-http
    if helm pull "oci://$REG/unsigned/shipping-service" --version 1.0.5 --plain-http --verify -d "$WORK/pull"; then
        echo "UNEXPECTED: unsigned chart verified" >&2; exit 1
    fi
}

cosign_flow() {
    step "cosign: key pair, sign by digest, verify"
    mkdir -p "$WORK/cosign"
    ( cd "$WORK/cosign" && COSIGN_PASSWORD="" cosign generate-key-pair )
    REF="$REG/signed/shipping-service"
    COSIGN_PASSWORD="" cosign sign --key "$WORK/cosign/cosign.key" --yes --allow-http-registry \
        --use-signing-config=false --tlog-upload=false "$REF@$DIGEST"
    cosign verify --key "$WORK/cosign/cosign.pub" --allow-http-registry --insecure-ignore-tlog "$REF@$DIGEST"
    step "tamper the tag: push different content to 1.0.0"
    helm push "$WORK/bad/shipping-service-1.0.0.tgz" "oci://$REG/signed" --plain-http
    if cosign verify --key "$WORK/cosign/cosign.pub" --allow-http-registry --insecure-ignore-tlog "$REF:1.0.0"; then
        echo "UNEXPECTED: moved tag verified" >&2; exit 1
    fi
    if helm pull "oci://$REG/signed/shipping-service" --version 1.0.0 --plain-http --verify -d "$WORK/pull"; then
        echo "UNEXPECTED: moved tag passed helm --verify" >&2; exit 1
    fi
    step "the original digest still verifies"
    cosign verify --key "$WORK/cosign/cosign.pub" --allow-http-registry --insecure-ignore-tlog "$REF@$DIGEST"
}

cluster_install() {
    step "install with --verify (re-push the good chart first so tag 1.0.0 is signed again)"
    helm push "$WORK/signed/shipping-service-1.0.0.tgz" "oci://$REG/signed" --plain-http
    helm upgrade --install "$REL" "oci://$REG/signed/shipping-service" --version 1.0.0 --plain-http --verify \
        -n "$NS" --create-namespace --set service.type=NodePort --set service.nodePort=30080 --wait --rollback-on-failure
    helm list -n "$NS"
}

cache_caveat() {
    step "content cache: a byte-identical unsigned copy passes install --verify only while the cache holds the .prov"
    mkdir -p "$WORK/copy" "$WORK/pull-copy"
    cp "$WORK/signed/shipping-service-1.0.0.tgz" "$WORK/copy/"   # the .prov stays behind
    helm push "$WORK/copy/shipping-service-1.0.0.tgz" "oci://$REG/unsigned-copy" --plain-http | grep -E '^(Pushed|Digest)'
    local ref="oci://$REG/unsigned-copy/shipping-service"
    echo "pull --verify, warm cache (expected: fails):"
    helm pull "$ref" --version 1.0.0 --plain-http --verify -d "$WORK/pull-copy" 2>&1 | grep -E '^Error' || true
    echo "install --verify, warm cache (expected: passes):"
    helm install probe "$ref" --version 1.0.0 --plain-http --verify -n "$NS" --dry-run=client 2>&1 | grep -E '^(Error|STATUS)' || true
    echo "install --verify, empty cache (expected: fails):"
    HELM_CACHE_HOME="$WORK/empty-cache" helm install probe "$ref" --version 1.0.0 --plain-http --verify -n "$NS" --dry-run=client 2>&1 | grep -E '^(Error|STATUS)' || true
}

clean() {
    helm uninstall "$REL" -n "$NS" 2>/dev/null || true
    kubectl delete namespace "$NS" --ignore-not-found --wait=false
    "$ENGINE" rm -f hfd-registry >/dev/null 2>&1 || true
    fpr="$(gpg --list-secret-keys --with-colons "$KEYNAME" 2>/dev/null | awk -F: '/^fpr:/ {print $10; exit}')"
    [ -n "$fpr" ] && gpg --batch --yes --delete-secret-and-public-key "$fpr" 2>/dev/null || true
    rm -rf "$WORK"
    rm -f "$CHART"/charts/*.tgz
}

case "${1:-}" in
    offline) offline ;;
    clean) clean ;;
    "")
        offline; make_gpg_key; sign_and_verify; start_registry; oci_signed; cosign_flow; cluster_install; cache_caveat
        echo "The registry stays up for inspection. Run ./demo.sh clean to remove it, the throwaway GPG key and .work/." ;;
    *) echo "usage: $0 [offline|clean]" >&2; exit 2 ;;
esac
