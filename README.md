# Helm for Developers

![License](https://img.shields.io/badge/license-Apache%202.0-blue)
![Helm](https://img.shields.io/badge/Helm-4.3-0f1689)
![Python](https://img.shields.io/badge/Python-3.15-3776ab)

A chapter-by-chapter tutorial for Helm 4, written for application developers. One fixed Python 3.15 / FastAPI application, a shipping service that publishes events to a notification service through Kafka and stores data in Postgres, goes from raw manifests to a chart, an umbrella chart, a library chart, a signed OCI artifact and an Argo CD deployment.

**[Read the tutorial](https://patterncatalyst.github.io/helm-for-developers/)**

## What you get

- 31 chapters in nine parts (`_docs/`), from a lab setup to OpenShift Local.
- 27 runnable examples (`examples/NN-slug/`), each a self-contained snapshot of the charts at that step, with a `demo.sh` that supports `offline` and `clean`.
- Two services (`services/`) built once on UBI 10, and a reference chart set (`charts/`) that the examples are derived from.
- Three Helm 4 plugins (`plugins/`): a subprocess CLI plugin, a post-renderer plugin and a Wasm plugin.
- Two slide decks (`presentation/`): Helm 101 and Helm 201.

## Requirements

- Linux with Podman or Docker, and minikube (12 GB RAM and 8 CPUs for the full lab).
- Python is not required on the host; the services build in containers.
- Helm 4 is installed into `.tools/` by `scripts/install-tools.sh`. Your global Helm is not touched.

## Quick start

```bash
source scripts/env.sh
scripts/install-tools.sh
```

Then follow chapter 01 to bring up the `helm4dev` minikube profile.

## Build the site locally

```bash
bundle install
bundle exec jekyll serve --baseurl ""
```

Open <http://127.0.0.1:4000/>.

## Status

Pre-release (r1.0 in progress). Chapter footers record whether each example has been verified against a live cluster. The OpenShift Local appendix has not been run on the authoring machine.

## License

Apache License 2.0. See [LICENSE](LICENSE).
