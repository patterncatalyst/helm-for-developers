# 21 - Provenance and signing

Signing the `shipping-service` 1.0.0 package two ways: a Helm provenance file (`.prov`, PGP) and a cosign key-pair signature on the OCI artifact. All keys are throwaway.

## Run

```bash
./demo.sh offline   # lint, template + kubeconform, unittest (no keys, no registry, no cluster)
./demo.sh           # GPG key in .tools/gnupg, helm package --sign, helm verify, OCI push, helm pull --verify, cosign sign/verify, tamper checks, install --verify into hfd-21
./demo.sh clean     # uninstall, remove the registry container, delete the throwaway GPG key and .work/
```

## What to look for

- `helm package --sign` against the default `pubring.kbx` fails with "provided key is not a private key"; the legacy `secring.gpg` export works.
- Running `helm verify` prints the signer, the key fingerprint and `Chart Hash Verified`; a tampered archive fails with `sha256 sum does not match`.
- The pushed manifest has a provenance layer next to the chart layer.
- `cosign verify` succeeds by digest, fails with `no signatures found` after a different chart is pushed to the same tag, and still succeeds for the original digest.
- Keyless signing (Fulcio/Rekor) is described in the chapter and not run.

## Verification status

`unverified`. `./demo.sh offline` passes. The signing, push, verify and tamper steps ran locally during authoring; the install with `--verify` is for the S7 sweep.
