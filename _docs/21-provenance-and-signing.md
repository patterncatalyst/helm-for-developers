---
title: "Provenance and signing"
order: 21
part: "Distribution and supply chain"
description: "Sign the shipping-service package with a Helm provenance file, verify it on pull and install, then sign the OCI artifact with cosign and watch both checks reject a tampered chart."
duration: 40 minutes
---

A checksum tells you the download arrived intact. It does not tell you who published it. Helm answers the second question with a provenance file, a PGP-signed record of the chart's metadata and archive hash, and the OCI ecosystem answers it with cosign, a signature stored in the registry next to the artifact. This chapter signs the `1.0.0` package both ways with throwaway keys, verifies each, and then tampers with the chart to see the checks fail.

The code is in `examples/21-signing/`. `./demo.sh offline` runs the lint, render and test gates; `./demo.sh` generates the keys, signs, pushes, verifies and tampers. Nothing in it is a real signing identity.

{% include excalidraw.html
   file="21-trust-chain"
   alt="Diagram: two chains over the same chart. Top: the tgz is signed by helm package --sign into a .prov file and checked by helm verify. Bottom: the pushed OCI manifest digest is signed by cosign sign and checked by cosign verify"
   caption="Figure 21.1 — Helm provenance covers the archive bytes; cosign covers the registry manifest digest" %}

## Two signatures, two things covered

The provenance file (`.prov`) is a clear-signed PGP document. It contains the chart's `Chart.yaml` and a `files:` map from the archive name to its SHA-256, and the signature covers all of it. `helm verify` recomputes the archive hash, compares it to the `files:` entry and checks the signature against a public key. It protects the bytes of the `.tgz`, wherever they came from. The Helm [provenance documentation](https://helm.sh/docs/topics/provenance/) describes the format.

A cosign signature belongs to the registry. It signs the manifest digest of the pushed artifact and is stored in the same repository as a separate artifact tagged `sha256-<digest>`. It protects the thing you pull from that registry, whatever the content is, and it does not need Helm to understand it. The [cosign documentation](https://docs.sigstore.dev/cosign/signing/signing_with_containers/) covers signing OCI artifacts.

The two are complementary. A `.prov` lets any Helm user check a chart that arrives as a plain file or from a classic repository. A cosign signature lets a registry or admission policy check an artifact without unpacking it.

## How the code works

`demo.sh` is the walk-through. Its functions run in this order.

**The GPG key.** `make_gpg_key` generates an RSA 3072 key in the project-local `GNUPGHOME` (`.tools/gnupg`, set by `env.sh`), from a batch parameter file with `%no-protection` so the demo needs no passphrase. The user ID is `HFD Throwaway Signer`; the clean step deletes the key by fingerprint. Use a passphrase-protected key, ideally on a hardware token, for anything real, and pass it with `--passphrase-file`.

**The legacy keyring.** GnuPG 2 keeps keys in `pubring.kbx` and `private-keys-v1.d/`. `helm package --sign` reads a keyring file, and its default is that `pubring.kbx`, which holds no private keys. The first attempt shows it:

```bash
[host]$ helm package examples/21-signing/charts/shipping-service --dependency-update --sign --key "HFD Throwaway Signer" -d .work/signed
```

```text
Error: provided key is not a private key. Try providing a keyring with secret keys
```

Export a legacy-format keyring and point `--keyring` at it:

```bash
[host]$ gpg --export-secret-keys > .work/keys/secring.gpg
[host]$ helm package examples/21-signing/charts/shipping-service --dependency-update --sign --key "HFD Throwaway Signer" --keyring .work/keys/secring.gpg -d .work/signed
```

`--key` matches the user ID. The command writes `shipping-service-1.0.0.tgz` and `shipping-service-1.0.0.tgz.prov` side by side. Treat `secring.gpg` as the secret it is; the script keeps it under the git-ignored `.work/`.

**The provenance file.** The script prints the part of the `.prov` that matters:

```text
files:
  shipping-service-1.0.0.tgz: sha256:f8d507c0004fb9f9f9c3418e7e2565d01ed00c4f8b05b28c5d2855e8ee90ccbd
```

That value equals the SHA-256 of the archive, the chart-layer digest from chapter 20. The signed text above it is the chart metadata, with the `dependencies:` list included.

**Verify.** Verification needs only public keys, and the default `pubring.kbx` already holds the public half:

```bash
[host]$ helm verify .work/signed/shipping-service-1.0.0.tgz
```

```text
Signed by: HFD Throwaway Signer <signer@hfd.invalid>
Using Key With Fingerprint: 19A1449A6F1689891E99B998C2916464491D113E
Chart Hash Verified: sha256:f8d507c0004fb9f9f9c3418e7e2565d01ed00c4f8b05b28c5d2855e8ee90ccbd
```

Use `--keyring` to verify against a key file a publisher gave you. Verifying a key you have not independently authenticated proves only that the same key signed it; fingerprint distribution is the part no tool does for you.

**Tamper check.** `sign_and_verify` untars the archive, changes `ACME-Post` to `EVIL-Post` in `values.yaml`, repackages with `tar`, and runs `helm verify` against the old `.prov`:

```text
Error: sha256 sum does not match for shipping-service-1.0.0.tgz: "sha256:f8d507c0..." != "sha256:ab39f0ea..."
```

The script treats a successful verify here as a failure and exits.

**Push and pull with provenance.** `helm push` of a signed archive uploads the `.prov` automatically as a second layer, `application/vnd.cncf.helm.chart.provenance.v1.prov`, ahead of the chart layer. Then `--verify` works on the OCI reference:

```bash
[host]$ helm pull oci://127.0.0.1:5001/signed/shipping-service --version 1.0.0 --plain-http --verify -d .work/pull
```

An unsigned chart pushed to the same registry fails with `failed to fetch provenance "oci://127.0.0.1:5001/unsigned/shipping-service:1.0.5.prov"`. `helm install --verify` and `helm upgrade --install --verify` behave the same way, and the last demo step installs the signed chart that way. Helm 4 keeps a content cache for downloaded charts and provenance, keyed by the chart's digest, and `install --verify` consults it. In the 2026-10-08 run a byte-identical copy of the verified chart, pushed to another path with no `.prov` layer, failed `helm pull --verify` but got through `helm install --verify --dry-run=client` (reaching `STATUS: pending-install`) while `HELM_CACHE_HOME` held the cached `.prov`; with an empty cache the same install failed with `failed to fetch provenance`. An unsigned chart with different bytes still failed. The demo sets a fresh `HELM_CACHE_HOME` for that reason, and its last step reproduces the effect. The signature attests to the bytes, which is accurate, but do not read a passing `--verify` as proof about the registry location.

**cosign.** `cosign_flow` makes a key pair with an empty password and signs by digest, not by tag:

```bash
[host]$ cosign sign --key .work/cosign/cosign.key --yes --allow-http-registry --use-signing-config=false --tlog-upload=false 127.0.0.1:5001/signed/shipping-service@sha256:<manifest digest>
[host]$ cosign verify --key .work/cosign/cosign.pub --allow-http-registry --insecure-ignore-tlog 127.0.0.1:5001/signed/shipping-service@sha256:<manifest digest>
```

The extra flags exist because the registry is plain HTTP and the key-pair flow here skips the public transparency log (Rekor); cosign 3.1.3 warns that `--tlog-upload` is deprecated and that skipping tlog verification is insecure. The warnings are accurate for production, where you would leave the log on. The verify output lists the checks and prints the signed payload with the digest it covers.

**Tampering with a tag.** The script pushes the tampered archive to the same tag, `1.0.0`. The tag now points at a new digest:

```text
Error: no signatures found
```

`cosign verify` by tag fails because no signature exists for the new digest, and `helm pull --verify` fails with the hash mismatch from before, since the old `.prov` came along. Verifying the original digest still passes. That is the argument for recording digests: an attacker with push access can move a tag but cannot move a signature.

**Keyless signing** replaces the key pair with a short-lived certificate from Fulcio, issued after an OIDC login, and records the signature in Rekor. It needs internet access and an identity provider, so this chapter does not run it. The Sigstore documentation on [verifying signatures](https://docs.sigstore.dev/cosign/verifying/verify/) explains the identity flags to use when you adopt it.

## Build, run, observe

```bash
[host]$ cd examples/21-signing && ./demo.sh
```

Each negative step is expected to fail, and the script turns an unexpected pass into an error.

## Troubleshooting

Each failure below was observed while writing the demo, and each message points at a different layer.

- **`provided key is not a private key`.** `--keyring` defaulted to `pubring.kbx`, which holds public keys only. Export a legacy secret keyring with `gpg --export-secret-keys` and pass it explicitly.
- **`sha256 sum does not match`.** `helm verify` recomputed the archive hash and found it differs from the `files:` entry in the signed `.prov`. The archive changed after signing, or the `.prov` belongs to a different build. Re-package and re-sign; do not edit the `.prov`.
- **`failed to fetch provenance` on `install --verify` or `pull --verify`.** The registry artifact has no provenance layer, so the chart was pushed unsigned. Push the `.prov` next to the archive. Helm uploads it as the layer `application/vnd.cncf.helm.chart.provenance.v1.prov`, which `curl` against the manifest shows.
- **`no signatures found` from `cosign verify` after a re-push.** A cosign signature binds to a manifest digest, not to a tag. Pushing different content to `1.0.0` creates a new digest with no signature, while the original digest still verifies. Verify by digest, and let admission policy reference digests rather than tags.

A fifth observation matters for CI. A byte-identical unsigned copy of a chart that had already been verified once got through `helm install --verify --dry-run=client` on a machine whose Helm cache still held that chart's `.prov` (it failed `helm pull --verify`, and failed `install --verify` with an empty cache; `./demo.sh` shows all three). The cache is keyed by chart digest, so the signature check is about the bytes, not about what the registry holds at that path. Do not rely on a cached verification as proof that a registry entry is signed. In a CI job, start from an empty `HELM_CACHE_HOME` so each verification reads what the registry holds.

Registries on plain HTTP need extra cosign flags: `--allow-http-registry`, `--use-signing-config=false` and, for a throwaway key without a transparency log, `--tlog-upload=false` when signing and `--insecure-ignore-tlog` when verifying. Production signing against a TLS registry drops the first flag, and keyless signing replaces the key file with an identity token.

## Cross-check

Verify the same artifact two independent ways. `helm pull --verify` checks the PGP signature over the archive hash, and `cosign verify` checks an unrelated key over the manifest digest. `curl` against the manifest shows the provenance layer media type, and `sha256sum` of the pulled archive equals the hash in the `.prov`. Four views agreeing on one artifact is the evidence that the push preserved what you signed.

## What you learned

- `helm package --sign` needs a legacy-format secret keyring with GnuPG 2; `helm verify` and `--verify` need only public keys.
- A `.prov` signs the archive hash; `helm push` uploads it as a layer, and `helm pull --verify` and `install --verify` check it.
- cosign signs the manifest digest of the OCI artifact; verify by digest, because tags move.
- Tampering fails both checks, and Helm's digest-keyed cache can make `install --verify` accept a byte-identical unsigned copy (observed with `--dry-run=client`).

Chapter 22 changes direction and extends Helm itself with plugins.

## Further reading

- Helm documentation, [Helm Provenance and Integrity](https://helm.sh/docs/topics/provenance/).
- Helm documentation, [Use OCI-based registries](https://helm.sh/docs/topics/registries/).
- Sigstore documentation, [Signing containers and OCI artifacts](https://docs.sigstore.dev/cosign/signing/signing_with_containers/) and [self-managed keys](https://docs.sigstore.dev/cosign/key_management/signing_with_self-managed_keys/).
- Sigstore documentation, [Verifying signatures](https://docs.sigstore.dev/cosign/verifying/verify/).

---

*Verification status: <span class="status status--verified">verified</span> on 2026-10-08, evidence `_plans/evidence/21-signing.txt`. Observed on Helm 4.3.0, cosign 3.1.3 and minikube: signing with the default keyring failed, the legacy keyring signed and `helm verify` passed, a tampered archive failed `sha256 sum does not match`, the `.prov` was uploaded as its own layer, `helm pull --verify` and `helm upgrade --install --verify` passed for the signed chart (Ready in `hfd-21`) and failed for an unsigned one, cosign signed and verified by digest and reported `no signatures found` for a moved tag, and the content-cache effect described above was reproduced as a client-side dry run, not a full install, with a warm cache and absent with an empty one. Keyless signing was not run. Re-run on r1.1 with published NodePorts (bound to 127.0.0.1) on 2026-10-08: `./demo.sh` exited 0 and `./demo.sh clean` removed the namespace; the signing flows passed, including the content-cache caveat (the warm-cache `install --verify` passes, the empty-cache one fails).*
