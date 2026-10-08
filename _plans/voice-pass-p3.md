# Voice pass, partition p3

Scope: _docs/21-30, examples/21-27 READMEs and CHECKLIST, root README, CONTRIBUTING, services/charts/plugins/presentation READMEs.

Before: 26 hits (11 CONTRIBUTING, 6 chapter 27, rest single hits). Ban-tier: 4 lines, all CONTRIBUTING.md:87.
After: ban-tier 4 lines, all CONTRIBUTING.md:87 (justified survivor). Watch-tier survivors are legitimate: minikube as the literal environment, "easy to find in logs" (ch. 28), "silently" in a rule about never applying a fallback silently, "Two signatures, two things covered" (ch. 21 heading, names the concept).

Justified survivor: CONTRIBUTING.md:87 is the banned-vocabulary rule itself; the words are the data.

Rewrites:
- "golden charts" -> "reference charts" (README.md, ch. 24/25/27, examples 24/25/26/27); "The golden run" -> "The reference run" (ch. 26). Evidence paths such as golden-06-tempo-trace.txt unchanged. "golden paths" (platform-engineering concept, ch. 30 citations) kept.
- examples/22-plugins: "the S7 run did" -> "a live run did" (leaked step id).
- ch. 27: "...disagrees with the manifest, and that is the point." -> "...disagrees with the manifest."
- ch. 28: "New flags worth knowing:" -> "New flags:".

No fenced code, inline code, front matter or footer evidence changed. validate-site, check-helm-commands, forbidden-syntax exit 0.
