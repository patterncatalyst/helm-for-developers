---
title: "Appendix: Further reading"
order: 30
part: "Appendices"
description: "The nine books this tutorial cites, with what each is good for and where its coverage stops, plus the official Helm 4 and OpenShift sources."
duration: 10 minutes
---

This page collects every book cited in the tutorial, one line each, and the official sources for everything Helm 4 changed. The split follows one rule. Books are cited for concepts Helm 4 left unchanged. Anything Helm 4 changed, which is most of what the command line does, comes from the official documentation.

## Scope of the Helm books

Two books are about Helm itself, and both were written for Helm 3. *Learning Helm* and *Managing Kubernetes Resources Using Helm* teach chart anatomy, values, templating, helpers, dependencies and library charts well, and those parts apply to Helm 4 unchanged. They predate Helm 4's flags and behavior, so do not use them for `--rollback-on-failure`, `--force-replace`, server-side apply, the kstatus wait, plugins, post-renderers, OCI commands or `helm registry login`. Use [chapter 28](28-appendix-helm3-to-helm4.md) and the official sources below for those. *Managing Kubernetes Resources Using Helm* is also cited here for chart-testing and Argo CD concepts, not for commands.

The *CKAD Study Guide* has a Helm section written for Helm 3, which is not cited. Its `securityContext` and probe material is cited. *Kubernetes: Up and Running* is cited for Kubernetes objects and not for its Helm section.

## Books

- Matt Butcher, Matt Farina, Josh Dolitsky, *Learning Helm* (O'Reilly, 2021), ISBN 9781492083641. Used here for: chart anatomy, values, templating, helpers, dependencies, library charts, hooks and the repository concept.
- Andrew Block, Austin Dewey, *Managing Kubernetes Resources Using Helm* (Packt, 2022), ISBN 9781803242897. Used here for: templating, dependencies, chart-testing concepts and Argo CD concepts.
- Bilgin Ibryam, Roland Huß, *Kubernetes Patterns* (O'Reilly, 2023), ISBN 9781098131678. Used here for: the Health Probe, Predictable Demands, Managed Lifecycle, Configuration Resource and Immutable Configuration patterns.
- Brendan Burns et al., *Kubernetes: Up and Running* (O'Reilly, 2022), ISBN 9781098110192. Used here for: Deployments, Services and ConfigMaps.
- Benjamin Muschko, *Certified Kubernetes Application Developer (CKAD) Study Guide* (O'Reilly, 2024), ISBN 9781098152857. Used here for: securityContext settings and probes.
- William Denniss, *Kubernetes for Developers* (Manning, 2024), ISBN 9781617297175. Used here for: containerizing an application and configuring probes.
- Billy Yuen et al., *GitOps and Kubernetes* (Manning, 2021), ISBN 9781617297274. Used here for: GitOps principles.
- Mauricio Salatino, *Platform Engineering on Kubernetes* (Manning, 2024), ISBN 9781617299322. Used here for: platform thinking, golden paths and GitOps delivery.
- Oliver et al., *Effective Platform Engineering* (Manning, 2025), ISBN 9781633436497. Used here for: platform as a product and golden paths.

The two GitOps and platform books pair with chapters 17, 18, 24 and 25. *GitOps and Kubernetes* predates the current Argo CD CLI and release line, so take principles from it and command details from the Argo CD documentation.

## Official sources

Helm 4:

- [Helm documentation](https://helm.sh/docs/): command reference, chart template guide, best practices.
- [Helm 4 overview](https://helm.sh/docs/overview/): breaking changes, renamed flags, new features.
- [Helm changelog](https://helm.sh/docs/changelog/): per-release changes through 4.3.0.
- [Path to Releasing Helm v4](https://helm.sh/blog/path-to-helm-v4/): the release plan.
- [Helm v4.0.0 release notes](https://github.com/helm/helm/releases/tag/v4.0.0) and the v4.1.0 to v4.3.0 releases on [github.com/helm/helm](https://github.com/helm/helm/releases).
- [Helm Improvement Proposals](https://github.com/helm/community/tree/main/hips), including [HIP-0026](https://github.com/helm/community/blob/main/hips/hip-0026.md) for the plugin system.
- [Example Helm 4 plugins](https://github.com/scottrigby/h4-example-plugins): Wasm plugin examples linked from the overview.

OpenShift:

- [OpenShift Local](https://developers.redhat.com/products/openshift-local/overview) and the [CRC documentation](https://crc.dev/docs/introducing/).
- [OpenShift Container Platform documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/latest): security context constraints, Routes, the internal registry.

## Where each topic is taught

| Topic | Chapters |
|---|---|
| Chart anatomy, values, templates, helpers | 04 to 07 |
| Dependencies, operators, hooks | 09 to 11 |
| Release lifecycle, debugging, testing | 12 to 14 |
| Umbrella and library charts, starters | 16 to 18 |
| Packaging, OCI, signing | 19 to 21 |
| Plugins and post-renderers | 22, 23 |
| Promotion, GitOps, observability | 24 to 26 |
| OpenShift | 27 |
| Helm 3 to Helm 4 | 28 |

---

*Verification status: <span class="status status--unverified">unverified</span>. The identifiers, titles and publication years match the book decision table in `CONTRIBUTING.md`. The author lists were written from memory of the covers and should be checked against each publisher's page.*
