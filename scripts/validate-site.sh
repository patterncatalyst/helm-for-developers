#!/usr/bin/env bash
#
# validate-site.sh - static checks that need no Jekyll or Ruby.
#
#   1. front matter of _docs/*.md and _parts/*.md parses as YAML
#   2. every chapter's `part:` equals a `part_name` in _parts/*.md
#   3. no stray `{{` in _docs/*.md outside {% raw %} blocks, `relative_url`
#      filters and {% include %} tags
#   4. assets/diagrams/*.svg are well-formed XML and *.excalidraw are valid JSON
#   5. bash -n passes on every examples/*/demo.sh
#   6. every excalidraw.html include has a non-empty alt and a caption that
#      starts with "Figure"
#
# ROOT_DIR overrides the repo root. An empty tree passes. Exit 1 on any failure.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ROOT_DIR:-$(cd "$HERE/.." && pwd)}"
cd "$ROOT" || exit 1
fail=0

# Checks 1-4 and 6 in Python (stdlib + PyYAML). -I: ignore the cwd and env for imports.
python3 -I - "$ROOT" <<'PY' || fail=1
import glob, json, os, re, sys
import xml.dom.minidom as minidom
try:
    import yaml
except ImportError:
    print("validate-site: PyYAML is required (python3 -m pip install pyyaml)"); sys.exit(1)

root = sys.argv[1]
os.chdir(root)
errors = []

def front_matter(path):
    text = open(path, encoding="utf-8").read()
    if not text.startswith("---"):
        return None, text
    parts = text.split("---", 2)
    if len(parts) < 3:
        raise ValueError("unterminated front matter")
    return yaml.safe_load(parts[1]) or {}, parts[2]

# 1. front matter
fm = {}
for p in sorted(glob.glob("_docs/*.md") + glob.glob("_parts/*.md")):
    try:
        meta, body = front_matter(p)
        if meta is None:
            errors.append(f"{p}: no front matter")
        else:
            fm[p] = (meta, body)
    except Exception as e:
        errors.append(f"{p}: front matter does not parse: {e}")
print(f"front matter: {len(fm)} files parsed")

# 2. part matches a part_name
part_names = {m.get("part_name") for p, (m, _) in fm.items() if p.startswith("_parts/")}
for p, (m, _) in fm.items():
    if not p.startswith("_docs/"):
        continue
    part = m.get("part")
    if part is None:
        if not os.path.basename(p).startswith("00-"):
            errors.append(f"{p}: missing `part:`")
    elif part not in part_names:
        errors.append(f"{p}: part {part!r} matches no _parts part_name {sorted(x for x in part_names if x)}")

# 3. stray {{ outside raw blocks / relative_url / include tags
for p, (_, body) in fm.items():
    if not p.startswith("_docs/"):
        continue
    body = re.sub(r"\{%-?\s*raw\s*-?%\}.*?\{%-?\s*endraw\s*-?%\}", "", body, flags=re.S)
    body = re.sub(r"\{%-?\s*include\b.*?-?%\}", "", body, flags=re.S)
    for n, line in enumerate(body.splitlines(), 1):
        if "{{" in line and "relative_url" not in line:
            errors.append(f"{p}: stray '{{{{' in body: {line.strip()[:80]}")

# 4. diagrams parse
svgs = sorted(glob.glob("assets/diagrams/*.svg"))
for f in svgs:
    try:
        minidom.parse(f)
    except Exception as e:
        errors.append(f"{f}: SVG not well-formed: {e}")
exc = sorted(glob.glob("assets/diagrams/*.excalidraw"))
for f in exc:
    try:
        json.load(open(f, encoding="utf-8"))
    except Exception as e:
        errors.append(f"{f}: Excalidraw JSON invalid: {e}")
print(f"diagrams: {len(svgs)} svg, {len(exc)} excalidraw parsed")

# 6. includes have alt and a Figure caption
inc_re = re.compile(r"\{%-?\s*include\s+excalidraw\.html(.*?)-?%\}", re.S)
n_inc = 0
for p, (_, body) in fm.items():
    if not p.startswith("_docs/"):
        continue
    for m in inc_re.finditer(body):
        n_inc += 1
        args = m.group(1)
        line = body[: m.start()].count("\n") + 1
        alt = re.search(r'\balt\s*=\s*"([^"]*)"', args)
        cap = re.search(r'\bcaption\s*=\s*"([^"]*)"', args)
        if not alt or not alt.group(1).strip():
            errors.append(f"{p}: include near body line {line} has no/empty alt text")
        if not cap or not cap.group(1).strip().startswith("Figure"):
            errors.append(f"{p}: include near body line {line} caption must start with 'Figure'")
        if re.search(r'\bfile\s*=\s*"([^"]+)"', args):
            f = re.search(r'\bfile\s*=\s*"([^"]+)"', args).group(1)
            for ext in ("svg", "excalidraw"):
                if not os.path.exists(f"assets/diagrams/{f}.{ext}"):
                    print(f"WARN: {p}: include references missing assets/diagrams/{f}.{ext}")
print(f"includes: {n_inc} checked")

for e in errors:
    print("FAIL:", e)
sys.exit(1 if errors else 0)
PY

# 5. bash -n on demo scripts
n=0
for d in examples/*/demo.sh; do
    [[ -f "$d" ]] || continue
    n=$((n + 1))
    bash -n "$d" || { echo "FAIL: bash -n $d"; fail=1; }
done
echo "demo.sh: $n scripts syntax-checked"

if (( fail )); then echo "validate-site: FAILED"; exit 1; fi
echo "validate-site: OK"
