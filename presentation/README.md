# Presentation decks

Two Red Hat-branded 16:9 decks accompany the tutorial. Both are built with `pptxgenjs` from a `deck.js` and use the `lgtm-presentation` house style.

| Deck | Directory | Chapters | Output |
|---|---|---|---|
| Helm for Developers 101 | `helm-101/` | 02 to 12 | `helm-101/Helm-101-r1.0.pptx` |
| Helm for Developers 201 | `helm-201/` | 13 to 27 | `helm-201/Helm-201-r1.0.pptx` |

Each directory holds `deck.js`, `deck-helpers.js`, `assets/` (brand images), `diagrams.py` plus `dgen.py` (diagram scenes), `build_diagrams.py`, and the generated `diagrams/` (SVG and Excalidraw sources) and `png/` (what the deck embeds).

## Prerequisites

- Node.js and `pptxgenjs` installed globally (the decks were built with 4.0.1). Run `export NODE_PATH=$(npm root -g)` so `require("pptxgenjs")` resolves.
- Python 3 with `cairosvg`, in a virtual environment at `presentation/.venv` (gitignored): `python3 -m venv presentation/.venv && presentation/.venv/bin/pip install cairosvg python-pptx`. `python-pptx` is only needed for the notes-count check.
- LibreOffice (`soffice`) and poppler (`pdftoppm`) for the optional render check.
- Red Hat Display, Red Hat Text and Red Hat Mono fonts for exact rendering. Without them PowerPoint and LibreOffice substitute fallback faces and line breaks can shift.

## Build

Run from the repository root. Regenerate the diagram PNGs first only when `diagrams.py` changed.

```bash
export NODE_PATH=$(npm root -g)
for deck in helm-101 helm-201; do
  (cd presentation/$deck \
    && ../.venv/bin/python build_diagrams.py \
    && node deck.js)
done
```

`build_diagrams.py` writes SVG and `.excalidraw` files to `diagrams/` and renders PNGs to `png/` with `cairosvg`. `deck.js` writes the `.pptx` next to itself; the output name is a relative path set in the `OUT` constant.

## Check

```bash
# slide count and speaker-note count must match
presentation/.venv/bin/python -c "
from pptx import Presentation
p = Presentation('presentation/helm-101/Helm-101-r1.0.pptx')
print(len(p.slides), sum(1 for s in p.slides if s.has_notes_slide and s.notes_slide.notes_text_frame.text.strip()))"

# render to PDF and look at individual pages
soffice --headless --convert-to pdf --outdir /tmp/deck-qa presentation/helm-101/Helm-101-r1.0.pptx
pdftoppm -png -r 60 -f 1 -l 1 /tmp/deck-qa/Helm-101-r1.0.pdf /tmp/deck-qa/pg

# command and syntax gates (the decks are in scope of both)
source scripts/env.sh
scripts/check-helm-commands.sh
scripts/forbidden-syntax.sh
```

Code slides write each `helm` command on its own line starting with `[host]$ helm` so `scripts/check-helm-commands.sh` can validate it against Helm 4 `--help`. The one slide that shows Helm 3 flags, the migration flag map at the end of the 101, marks each such line with a `<!-- helm3-reference -->` comment, which both scripts skip.

## Editing

- Slide titles are two to five word concept noun phrases. Put file names and commands in the one-line caption under a code box.
- Every slide carries speaker notes in the order "What it shows", "What to show" (an `examples/NN` command), "Fallback".
- Bump `OUT` and `REV` in `deck.js` together when the revision changes.
- Edit diagrams in `diagrams.py` and rebuild. Do not hand-edit a generated SVG or its `.excalidraw` pair.
