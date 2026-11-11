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

<table class="bib bib--books">
  <colgroup><col style="width:62%"><col style="width:24%"><col style="width:14%"></colgroup>
  <thead><tr><th>Title</th><th>Author(s)</th><th>Year</th></tr></thead>
  <tbody>
    <tr><td><a href="https://www.oreilly.com/library/view/-/9781492083641/" rel="noopener"><em>Learning Helm</em></a><br><small>O'Reilly. Chart anatomy, values, templating, helpers, dependencies, library charts, hooks, repositories</small></td><td>Matt Butcher, Matt Farina, Josh Dolitsky</td><td>2021</td></tr>
    <tr><td><a href="https://www.packtpub.com/en-us/product/managing-kubernetes-resources-using-helm-9781803242897" rel="noopener"><em>Managing Kubernetes Resources Using Helm</em>, 2nd ed.</a><br><small>Packt. Templating, dependencies, chart-testing, Argo CD</small></td><td>Andrew Block, Austin Dewey</td><td>2022</td></tr>
    <tr><td><a href="https://www.oreilly.com/library/view/-/9781098131678/" rel="noopener"><em>Kubernetes Patterns</em>, 2nd ed.</a><br><small>O'Reilly. Health Probe, Predictable Demands, Managed Lifecycle, Configuration Resource, Immutable Configuration</small></td><td>Bilgin Ibryam, Roland Huß</td><td>2023</td></tr>
    <tr><td><a href="https://www.oreilly.com/library/view/-/9781098110192/" rel="noopener"><em>Kubernetes: Up and Running</em>, 3rd ed.</a><br><small>O'Reilly. Deployments, Services, ConfigMaps</small></td><td>Brendan Burns, Joe Beda, Kelsey Hightower, Lachlan Evenson</td><td>2022</td></tr>
    <tr><td><a href="https://www.oreilly.com/library/view/-/9781098152857/" rel="noopener"><em>Certified Kubernetes Application Developer (CKAD) Study Guide</em>, 2nd ed.</a><br><small>O'Reilly. securityContext settings and probes</small></td><td>Benjamin Muschko</td><td>2024</td></tr>
    <tr><td><a href="https://www.manning.com/books/kubernetes-for-developers" rel="noopener"><em>Kubernetes for Developers</em></a><br><small>Manning. Containerizing an application, configuring probes</small></td><td>William Denniss</td><td>2024</td></tr>
    <tr><td><a href="https://www.manning.com/books/gitops-and-kubernetes" rel="noopener"><em>GitOps and Kubernetes</em></a><br><small>Manning. GitOps principles</small></td><td>Billy Yuen, Alexander Matyushentsev, Todd Ekenstam, Jesse Suen</td><td>2021</td></tr>
    <tr><td><a href="https://www.manning.com/books/platform-engineering-on-kubernetes" rel="noopener"><em>Platform Engineering on Kubernetes</em></a><br><small>Manning. Platform thinking, golden paths, GitOps delivery</small></td><td>Mauricio Salatino</td><td>2024</td></tr>
    <tr><td><a href="https://www.manning.com/books/effective-platform-engineering" rel="noopener"><em>Effective Platform Engineering</em></a><br><small>Manning. Platform as a product, golden paths</small></td><td>Grzegorz Oliver and contributors</td><td>2025</td></tr>
  </tbody>
</table>

## Primary documentation

<table class="bib">
  <colgroup><col style="width:40%"><col style="width:60%"></colgroup>
  <thead><tr><th>Source</th><th>Used for</th></tr></thead>
  <tbody>
    <tr><td><a href="https://helm.sh/docs/" rel="noopener">Helm documentation</a></td><td>Command reference, chart template guide, best practices</td></tr>
    <tr><td><a href="https://helm.sh/docs/overview/" rel="noopener">Helm 4 overview</a></td><td>Breaking changes, renamed flags, new features</td></tr>
    <tr><td><a href="https://helm.sh/docs/changelog/" rel="noopener">Helm changelog</a></td><td>Per-release changes through 4.3.0</td></tr>
    <tr><td><a href="https://github.com/helm/community/tree/main/hips" rel="noopener">Helm Improvement Proposals</a></td><td>The plugin system (HIP-0026) and other design decisions</td></tr>
    <tr><td><a href="https://github.com/helm/helm/releases" rel="noopener">Helm releases</a></td><td>v4.0.0 through v4.3.0 release notes</td></tr>
    <tr><td><a href="https://crc.dev/docs/introducing/" rel="noopener">OpenShift Local (CRC)</a></td><td>The OpenShift Local appendix</td></tr>
    <tr><td><a href="https://docs.redhat.com/en/documentation/openshift_container_platform/latest" rel="noopener">OpenShift Container Platform docs</a></td><td>Security context constraints, Routes, the internal registry</td></tr>
  </tbody>
</table>

These titles inform this site's coverage and rigor only. Nothing in these
chapters or the runnable examples copies text or code from them.
