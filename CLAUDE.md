# CLAUDE.md

Guidance for AI assistants working in this repository. Project conventions are in `CONTRIBUTING.md`; read its "House style" section first. The plan for the current iteration is `_plans/r1-plan.md`.

## What this is

A Jekyll/GitHub Pages tutorial, "Helm for Developers", in the lgtm-jekyll house style. Content: `_docs/NN-*.md` (chapters 00 to 30), `_parts/*.md` (nine parts), `examples/NN-slug/` (runnable snapshots), `charts/` (golden chart set), `services/` (Python 3.14 FastAPI services, 3.15-ready), `plugins/`, `presentation/` (Helm 101 and 201 decks), `scripts/`.

## Rules

- A chapter's `part:` must equal a `_parts` `part_name` exactly. Part orders are 0 to 8.
- Run `source scripts/env.sh` before any Helm command. Helm 4 lives in `.tools/`; never use or modify the global Helm 3.
- Check every Helm command and flag against `helm <cmd> --help` from Helm 4. Do not write `--atomic`, `helm upgrade --force`, or a path to `--post-renderer` outside the migration appendix.
- Cite books only for concepts Helm 4 left unchanged. Helm-4-changed topics cite helm.sh/docs, the release notes or HIPs.
- Never mark a claim `verified` from a clean exit. Promote only with an evidence file recording the observed effect.
- Write in the lgtm-professional-voice register. The banned vocabulary list is in `CONTRIBUTING.md`.
- Wrap literal `{{ }}` in `{% raw %}...{% endraw %}`. `_plans/*.md` use `render_with_liquid: false`.
- Commits follow Conventional Commits with `§NN`, `demo-NN` or `r1.0` scopes. No AI attribution trailers. Do not push or add a remote without the owner's confirmation.
- Do not touch the `datamesh` minikube profile; this project uses `helm4dev`.

## Commands

```bash
bundle exec jekyll serve --baseurl ""
scripts/validate-site.sh
```
