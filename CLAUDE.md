# CLAUDE.md

Guidance for AI assistants working in this repository. Project conventions are in `CONTRIBUTING.md`; read its "House style" section first. The plan for the current iteration is `_plans/r1-plan.md`.

## What this is

A Jekyll/GitHub Pages tutorial, "Helm for Developers", in the lgtm-jekyll house style. Content: `_docs/NN-*.md` (chapters 00 to 30), `_parts/*.md` (nine parts), `examples/NN-slug/` (runnable snapshots), `charts/` (golden chart set), `services/` (Python 3.14 FastAPI services, 3.15-ready), `plugins/`, `presentation/` (Helm 101 and 201 decks), `scripts/`.

## Rules

- A chapter's `part:` must equal a `_parts` `part_name` exactly. Part orders are 0 to 8.
- Run `source scripts/env.sh` before any Helm command. Helm 4 lives in `.tools/`; never use or modify the global Helm 3.
- Check every Helm command and flag against `helm <cmd> --help` from Helm 4. Do not write `--atomic`, `helm upgrade --force`, or a path to `--post-renderer` outside the migration appendix.
- Cite books only for concepts Helm 4 left unchanged. Helm-4-changed topics cite helm.sh/docs, the release notes or HIPs.
- Never mark a claim `verified` from a clean exit. Record the observed effect in an evidence file under `_plans/evidence/` and summarize it in `_plans/verification-log.md`. The reader-facing chapters carry a `## Build, run, observe` section (the example's real commands), not a `*Verification status: …*` footer.
- Write in the lgtm-professional-voice register. The banned vocabulary list is in `CONTRIBUTING.md`.
- Wrap literal `{{ }}` in `{% raw %}...{% endraw %}`. `_plans/*.md` use `render_with_liquid: false`.
- Commits follow Conventional Commits with `§NN`, `demo-NN` or `r1.0` scopes. No AI attribution trailers. Do not push or add a remote without the owner's confirmation.
- Host access is NodePorts published at profile creation (`minikube start --ports=127.0.0.1:<p>:<p>`, loopback only, never 0.0.0.0; `HFD_NODE_PORTS` in `scripts/platform/lib.sh`); host port = NodePort. Never use SSH tunnels, `kubectl port-forward` or `minikube tunnel` (they disconnect). Adding a port means recreating the profile. <!-- forbidden-ok -->
- Do not touch the `datamesh` minikube profile; this project uses `helm4dev`.

## Commands

```bash
bundle exec jekyll serve --baseurl ""
scripts/validate-site.sh
```

## Publishing rule: nothing identifies the machine or its owner

The repo is public, so no tracked file may name the development machine, its owner or anything that helps locate or attack it later:

- No absolute home-directory path (the Linux or macOS home tree), no account name, no hostname. Write `<repo>/...` or `~/...` (`~/.kube/config`, `~/.minikube/...`).
- No laptop model (DMI `product_name` is `redacted`), no CPU model or model number. The CPU is a class ("Intel 8-core/16-thread laptop CPU").
- No host kernel build number or build date: give `major.minor` and the preempt model.
- No `/etc/machine-id`, DMI serial or UUID, MAC or IP address, `root=UUID=` or `BOOT_IMAGE`.
- Captured output is scrubbed before it is committed: `python3 scripts/host_ids.py filter < raw.log > evidence.txt`, or `host_ids.py scrub <dir>` on a directory. Helm and kubectl print absolute paths (`helm package`, `helm env`, `make` directory lines), so evidence files need it.
- `python3 scripts/host_ids.py check` runs in CI (`host-ids` workflow) and fails the build on a hit.
- `.host-scrub.toml` holds the exemptions. Prefer `[allow_match]` (a public value, matched wherever it appears: a container image default account, a distribution kernel pin) over `[allow]` (whole files by path). The one path allow is `Chart.yaml`, whose `maintainers[].email` is the project's published contact address. Never put this machine's own values in that file.
