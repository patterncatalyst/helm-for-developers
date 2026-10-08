# Contributing

This file records the project conventions. Chapters, examples, scripts and decks all follow it.

## House style

### Project and site

- Project directory: `~/Dev/helm-for-developers`.
- GitHub repository: `patterncatalyst/helm-for-developers`, public.
- `baseurl: "/helm-for-developers"`, `github_username: "patterncatalyst"`, `github_repo: "helm-for-developers"`.
- `brand_emoji: "⎈"` (fall back to "🧭" if the font lacks it).
- Accent color: default amber `#e8870c`.
- License: Apache-2.0.
- Hero eyebrow: "Helm 4 · Python 3.15 · FastAPI · minikube · OpenShift".

### Versions

Pinned and dated 2026-10-08. Re-verify against upstream before each release.

- Helm 4.3.0
- helm-unittest 1.2.1
- helm-diff 3.15.15
- chart-testing 3.15.0
- kubeconform 0.8.0
- cosign 3.1.3
- helmfile: latest 1.x that supports Helm 4, optional
- Argo CD Helm chart: latest stable
- CNPG chart: 0.23.0 in the lgtm-minikube-stack skill; re-verify
- Strimzi 0.51.0
- LGTM chart versions as in `setup-lgtm.sh`
- Python 3.15.0; FastAPI latest; Pydantic, uvicorn, asyncpg, aiokafka and OpenTelemetry versions pinned in `pyproject.toml`

### Tool isolation

`scripts/env.sh` is sourced by every script. It exports:

- `PATH=$REPO/.tools/bin:$PATH`
- `HELM_CONFIG_HOME`, `HELM_CACHE_HOME`, `HELM_DATA_HOME` under `$REPO/.tools/helm/`
- `HELM_PLUGINS=$REPO/.tools/helm/plugins`
- `GNUPGHOME=$REPO/.tools/gnupg`, for throwaway signing keys only
- `MINIKUBE_PROFILE=helm4dev`

It fails if `helm version --short` is not `v4.*`. The global Helm 3.18.3 at `~/.local/bin/helm` is never modified.

### Cluster

- Profile `helm4dev`, `MINIKUBE_DRIVER=docker` by default, containerd runtime, 12g RAM, 8 CPUs.
- Flags: `ENABLE_ISTIO=false ENABLE_KEDA=false ENABLE_KIALI=false ENABLE_POSTGRES=true ENABLE_KAFKA=true ENABLE_LGTM=true`.
- The bootstrap installs operators only. The charts own the Postgres and Kafka custom resources.
- Strimzi runs in namespace `strimzi` with `watchAnyNamespace=true`. CNPG runs in `cnpg-system`. Observability runs in `observability`.
- The registry addon is enabled.
- Each example installs into its own namespace `hfd-NN` with release name `shipping` (or `platform` for the umbrella). `./demo.sh clean` uninstalls it.
- The `datamesh` minikube profile is never touched.

### Host access

NodePort plus `scripts/tunnel.sh`. No `kubectl port-forward`.

| Service | NodePort | Host port |
|---|---|---|
| shipping | 30080 | 8080 |
| notification | 30081 | 8081 |
| grafana | 30300 | 3000 |
| argocd | 30443 | 8443 |

### Images

- `scripts/build-images.sh` builds `shipping-service:0.1.0` and `notification-service:0.1.0` into the profile (`minikube -p helm4dev image build`, or `podman build` plus `minikube image load`).
- `push` mode also pushes to the registry addon as `localhost:5000/<name>:0.1.0`.
- Chart defaults: `image.repository: shipping-service`, tag defaults to `.Chart.AppVersion`, `pullPolicy: IfNotPresent`.

### Chart versions in snapshots

Version `0.<chapter>.0` per chapter snapshot until chapter 19, which releases `1.0.0`. `appVersion: "0.1.0"` throughout. Charts stay `apiVersion: v2`.

### Command conventions

- Prefix `[host]$` for the host, `[crc-host]$` for the CRC machine.
- Commands are single-line.
- Use `127.0.0.1` rather than `localhost` in prose for host URLs.
- Use fully qualified image references.
- Wrap literal `{{ }}` in `{% raw %}...{% endraw %}`.

### Banned vocabulary

Per lgtm-tutorial and lgtm-professional-voice: honest, honestly, a deceptive "lie" (person or process as subject), capstone, simply, seamless, leverage, load-bearing, delve. No Helm 2 terms in instructions: tiller, `helm init`, `requirements.yaml`, `helm serve`. Helm 3 flags that Helm 4 removed or renamed (`--atomic`, `--force`) appear only in `28-appendix-helm3-to-helm4.md` or on lines marked `<!-- helm3-reference -->`.

### Citation line format

One physical line, inside a `## Further reading` section at the end of each chapter, before the verification footer:

```
- <Authors, 60 characters or fewer, or "First Author et al.">, *<Title>* (<Publisher>, <Year>), ISBN <13-digit>. Used here for: <still-valid concepts>.
```

- Do not put an em dash right before the title.
- Write the CKAD title as `*Certified Kubernetes Application Developer (CKAD) Study Guide*`; its hub entry is hand-curated.

### Books and official sources

Books are cited only for concepts Helm 4 left unchanged. Topics Helm 4 changed cite official sources only: helm.sh/docs, the Helm 4 release blog and notes, the GitHub v4.0.0 to v4.3.0 releases, and the HIPs in `github.com/helm/community/tree/main/hips`. The changed topics are `--rollback-on-failure`, `--force-replace`, server-side apply by default, the kstatus `--wait` watcher, the plugin system (types `cli/v1`, `getter/v1`, `postrenderer/v1`; subprocess and Wasm runtimes), post-renderers as plugins, OCI behavior, dry-run and lint flag changes, `--take-ownership`, slog logging, removed or renamed flags, and the chart API v3 status. Confirm every command against `helm <cmd> --help` from `.tools/bin/helm` before writing it.

Chapters 12, 13, 20, 21, 22, 23 and 28 are docs-only and contain no ISBN lines.

| Book | Cite for | Never cite for |
|---|---|---|
| Learning Helm (Butcher, Farina, Dolitsky; O'Reilly 2021; 9781492083641) | Chart anatomy, values, templating, helpers, dependencies, library charts, hooks, repositories concept | Flags and commands, plugins, post-renderers, OCI, SSA, wait, atomic |
| Managing Kubernetes Resources Using Helm, 2nd ed. (Block, Dewey; Packt 2022; 9781803242897) | Templating, dependencies, chart-testing concepts, Argo CD concepts | Same as Learning Helm |
| Kubernetes Patterns, 2nd ed. (Ibryam, Huß; O'Reilly 2023; 9781098131678) | Kubernetes patterns in chapters 03, 08, 09, 10, 11, 15, 26 | Helm behavior |
| Kubernetes: Up and Running, 3rd ed. (Burns et al.; O'Reilly 2022; 9781098110192) | Chapter 03 Kubernetes objects | Its Helm section |
| CKAD Study Guide, 2nd ed. (Muschko; O'Reilly 2024; 9781098152857) | Chapter 03 securityContext and probes | Its Helm 3 exam commands |
| Kubernetes for Developers (Denniss; Manning 2024; 9781617297175) | Chapters 03 and 11 | Helm behavior |
| GitOps and Kubernetes (Yuen et al.; Manning 2021; 9781617297274) | Chapter 25 GitOps principles | Argo CD CLI or version specifics |
| Platform Engineering on Kubernetes (Salatino; Manning 2024; 9781617299322) | Chapters 18, 24, 25 | Helm behavior |
| Effective Platform Engineering (Chankramath et al.; Manning 2025; 9781633436497) | Chapters 17, 18, 24 | Helm behavior |

### Chapter format

- Front matter: `title`, `order`, `part` (exact match to a `_parts` `part_name`), quoted `description`, `duration`.
- Hook paragraph, run-hint line, at least one diagram with alt text and a "Figure NN.x —" caption, concept sections, a full "How the code works" walk of the real template, values or plugin code, Build, run, observe, a Cross-check, What you learned, Further reading, and the verification footer.
- Hands-on chapters run 1,400 to 1,900 words.
- Diagram specs live in `scripts/diagrams/chNN.py` and write `assets/diagrams/NN-*.{svg,excalidraw}`.
- Examples never reference `../../charts`; each snapshot is self-contained.

### Verification discipline

Every claim starts `unverified`. A footer moves to `verified` only with an evidence file in `_plans/evidence/` recording the behavioral observation, not a clean exit. Chapter 27 stays `unverified` and states "untested on the authoring machine".

## Decisions

Recorded 2026-10-08.

1. **Base image.** UBI 10 `ubi-minimal` with uv-installed CPython 3.15.0. Fallbacks: F1 is `PYTHON_VERSION=3.14` with the same build; F2 is `registry.access.redhat.com/ubi9/python-314`. Any fallback is recorded here and in `_plans/reconciliation-plan.md`, never applied silently. No Docker Hub Python base image. Fallback in use: none yet.
2. **Helm 4 location.** Installed project-locally under `.tools/`. The global `~/.local/bin/helm` (3.18.3) is untouched.
3. **Publishing.** Public repository `patterncatalyst/helm-for-developers`, GitHub Pages, hub change through a pull request. Re-confirm before any outward action.
4. **Plan.** Approved; execution started. The full plan is `_plans/r1-plan.md`.

## Commits and branches

Follow `lgtm-github` and its commit conventions: `type(scope): summary`, imperative, 72 characters or fewer.

- Types: `docs`, `site`, `demo`, `ci`, `chore`, `fix`, `feat`, `refactor`, `style`.
- Scopes: `§NN` for chapters, `demo-NN` for examples, `rN.0` for release work.
- No AI attribution trailers in commits, pull requests or PR bodies.
- Work on `feature/*` branches and merge by pull request. `main` stays at the last reviewed state.
- Nothing is pushed and no remote is configured until the owner confirms.

## Validation

```bash
scripts/validate-site.sh
scripts/check-helm-commands.sh
scripts/forbidden-syntax.sh
bundle exec jekyll build
```
