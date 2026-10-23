---
title: "Bibliography"
layout: plan
permalink: /bibliography/
description: "The books and primary documentation this site's coverage and rigor draw on: nothing here is reproduced from them."
---

This site's chapter arc and level of rigor draw on a small set of books on Helm,
Kubernetes, and platform engineering, plus the Helm project's own documentation.
They're reference works, not sources: no text or code from any of them is
reproduced here. Where a topic is useful to you, these are where to go deeper.
Books are cited for concepts Helm 4 left unchanged; Helm-4-changed topics cite
the Helm docs, release notes, or HIPs below.

## Books

| Title | Author(s) | Publisher | Year | Focus |
|---|---|---|---|---|
| [*Learning Helm*](https://www.oreilly.com/library/view/-/9781492083641/) | Matt Butcher, Matt Farina, Josh Dolitsky | O'Reilly | 2021 | Chart anatomy, values, templating, helpers, dependencies, library charts, hooks, repositories |
| [*Managing Kubernetes Resources Using Helm*, 2nd ed.](https://www.packtpub.com/en-us/product/managing-kubernetes-resources-using-helm-9781803242897) | Andrew Block, Austin Dewey | Packt | 2022 | Templating, dependencies, chart-testing, Argo CD |
| [*Kubernetes Patterns*, 2nd ed.](https://www.oreilly.com/library/view/-/9781098131678/) | Bilgin Ibryam, Roland Huß | O'Reilly | 2023 | Health Probe, Predictable Demands, Managed Lifecycle, Configuration Resource, Immutable Configuration |
| [*Kubernetes: Up and Running*, 3rd ed.](https://www.oreilly.com/library/view/-/9781098110192/) | Brendan Burns, Joe Beda, Kelsey Hightower, Lachlan Evenson | O'Reilly | 2022 | Deployments, Services, ConfigMaps |
| [*Certified Kubernetes Application Developer (CKAD) Study Guide*, 2nd ed.](https://www.oreilly.com/library/view/-/9781098152857/) | Benjamin Muschko | O'Reilly | 2024 | securityContext settings and probes |
| [*Kubernetes for Developers*](https://www.manning.com/books/kubernetes-for-developers) | William Denniss | Manning | 2024 | Containerizing an application, configuring probes |
| [*GitOps and Kubernetes*](https://www.manning.com/books/gitops-and-kubernetes) | Billy Yuen, Alexander Matyushentsev, Todd Ekenstam, Jesse Suen | Manning | 2021 | GitOps principles |
| [*Platform Engineering on Kubernetes*](https://www.manning.com/books/platform-engineering-on-kubernetes) | Mauricio Salatino | Manning | 2024 | Platform thinking, golden paths, GitOps delivery |
| [*Effective Platform Engineering*](https://www.manning.com/books/effective-platform-engineering) | Grzegorz Oliver and contributors | Manning | 2025 | Platform as a product, golden paths |

## Primary documentation

| Source | Link | Used for |
|---|---|---|
| Helm documentation | [helm.sh/docs](https://helm.sh/docs/) | Command reference, chart template guide, best practices |
| Helm 4 overview | [helm.sh/docs/overview](https://helm.sh/docs/overview/) | Breaking changes, renamed flags, new features |
| Helm changelog | [helm.sh/docs/changelog](https://helm.sh/docs/changelog/) | Per-release changes through 4.3.0 |
| Helm Improvement Proposals | [helm/community/hips](https://github.com/helm/community/tree/main/hips) | The plugin system (HIP-0026) and other design decisions |
| Helm releases | [github.com/helm/helm/releases](https://github.com/helm/helm/releases) | v4.0.0 through v4.3.0 release notes |
| OpenShift Local (CRC) | [crc.dev/docs](https://crc.dev/docs/introducing/) | The OpenShift Local appendix |
| OpenShift Container Platform docs | [docs.redhat.com](https://docs.redhat.com/en/documentation/openshift_container_platform/latest) | Security context constraints, Routes, the internal registry |

These titles inform this site's coverage and rigor only. Nothing in these
chapters or the runnable examples copies text or code from them.
