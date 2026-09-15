#!/usr/bin/env bash

# Asserts, on a real `quarto render` to DOCX, what template.dotx and
# filters/docx-caption.lua owe a Word reader.
# The Lua suite proves the filter restyles a caption handed to it; it cannot
# prove a caption ever reaches it. That rests on two undocumented Quarto
# behaviours: floats are rendered before the post-render stage, and their
# caption opens on a raw `<w:pPr>` naming `ImageCaption`. A change to either
# leaves the render green while every caption falls back to that raw paragraph.
# scripts/check-docx.R then reads the invariants the template carries into the
# output, which Pandoc decides rather than the template.
# The probe is staged at the repo root because extension lookup does not walk
# up out of `tests/` in the absence of a `_quarto.yml`.

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
probe=${repo_root}/tests/docx-template-probe.qmd
staged=${repo_root}/docx-template-probe.qmd
rendered=${repo_root}/docx-template-probe.docx

cleanup() {
  rm -rf -- "$staged" "$rendered" "${repo_root}/docx-template-probe_files"
}
trap cleanup EXIT

cp -- "$probe" "$staged"
quarto render "$staged" --to hebstr-doc-docx --quiet

Rscript "${repo_root}/scripts/check-docx.R" "$rendered"

# The rule is read off the order of blocks inside each float's one-cell
# wrapper, which is structural, hence the parsed tree rather than the markup.
python3 - "$rendered" <<'PY'
import sys
import zipfile
import xml.etree.ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
CAPTION_STYLES = ("TableCaption", "ImageCaption")
EXPECTED = [
    ("Figure", "ImageCaption", "CaptionedFigure"),
    ("Figure", "TableCaption", "Figure"),
    ("Table", "TableCaption", None),
    ("Table", "TableCaption", None),
    ("Annexe", "TableCaption", None),
]


def style(paragraph):
    node = paragraph.find(f"{W}pPr/{W}pStyle")
    return None if node is None else node.get(W + "val")


def has_drawing(paragraph):
    return next(paragraph.iter(W + "drawing"), None) is not None


root = ET.fromstring(zipfile.ZipFile(sys.argv[1]).read("word/document.xml"))
failures = []
found = []

for table in root.iter(W + "tbl"):
    row = table.find(W + "tr")
    cell = None if row is None else row.find(W + "tc")
    if cell is None:
        continue
    blocks = list(cell)
    captions = [
        i for i, b in enumerate(blocks) if b.tag == W + "p" and style(b) in CAPTION_STYLES
    ]
    if not captions:
        continue
    caption = blocks[captions[0]]
    label = "".join(t.text or "" for t in caption.iter(W + "t")).split("\xa0")[0]
    content = [
        i for i, b in enumerate(blocks) if b.tag == W + "tbl" or (b.tag == W + "p" and has_drawing(b))
    ]
    if not content:
        failures.append(f"{label}: a caption with no figure or table beside it")
        continue

    top = captions[0] < content[0]
    wanted = "TableCaption" if top else "ImageCaption"
    image = next((style(blocks[i]) for i in content if blocks[i].tag == W + "p"), None)
    found.append((label, style(caption), image))

    if style(caption) != wanted:
        failures.append(f"{label}: caption {'above' if top else 'below'} its content is {style(caption)}, not {wanted}")
    if len(caption.findall(W + "pPr")) != 1:
        failures.append(f"{label}: caption carries {len(caption.findall(W + 'pPr'))} w:pPr, Word expects one")
    if caption.find(f"{W}pPr/{W}jc") is not None:
        failures.append(f"{label}: caption carries a direct alignment, which overrides its style")
    if len(found) == 1:
        subtitled = next(caption.iter(W + "br"), None) is not None and any(
            r.get(W + "val") == "CaptionSubtitle" for r in caption.iter(W + "rStyle")
        )
        if not subtitled:
            failures.append(f"{label}: the quarto-float-subcaption span did not become a Caption Subtitle line")

if found != EXPECTED:
    failures.append(f"captions found {found}, expected {EXPECTED}")

if failures:
    print("FAIL  " + "\nFAIL  ".join(failures), file=sys.stderr)
    print(
        "      The raw caption Quarto writes no longer reaches\n"
        "      filters/docx-caption.lua, or no longer matches what it reads.",
        file=sys.stderr,
    )
    sys.exit(1)

print(f"ok    {len(found)} float captions styled by position, subtitle on its own line")
PY
