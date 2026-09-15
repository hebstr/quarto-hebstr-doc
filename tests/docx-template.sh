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

# Caption position, nesting and bookmarks are structural, hence the parsed
# tree rather than the markup. A table float must sit at body level: Word
# crushes a table nested in the one-cell wrapper Quarto builds for a float.
python3 - "$rendered" <<'PY'
import sys
import zipfile
import xml.etree.ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
CAPTION_STYLES = ("TableCaption", "ImageCaption", "TableCaptionTitle", "ImageCaptionTitle")
SUBTITLE_STYLES = ("TableCaptionSubtitle", "ImageCaptionSubtitle")
EXPECTED = [
    ("Figure", "ImageCaptionTitle", "CaptionedFigure", "ImageCaptionSubtitle"),
    ("Figure", "TableCaption", "Figure", None),
    ("Table", "TableCaption", None, None),
    ("Table", "TableCaptionTitle", None, "TableCaptionSubtitle"),
    ("Annexe", "TableCaption", None, None),
]
EXPECTED_ANCHORS = {"fig-bottom", "fig-top", "tbl-md", "tbl-gt", "anx-probe"}


def style(paragraph):
    node = paragraph.find(f"{W}pPr/{W}pStyle")
    return None if node is None else node.get(W + "val")


def has_drawing(paragraph):
    return next(paragraph.iter(W + "drawing"), None) is not None


def is_content(block):
    return block.tag == W + "tbl" or has_drawing(block)


# The 1 pt paragraph docx-cell-paragraph.lua appends to a raw table holds no
# run, and must not hide the table it closes.
def blocks(parent):
    return [
        b
        for b in parent
        if b.tag == W + "tbl" or (b.tag == W + "p" and next(b.iter(W + "r"), None) is not None)
    ]


root = ET.fromstring(zipfile.ZipFile(sys.argv[1]).read("word/document.xml"))
parents = {child: parent for parent in root.iter() for child in parent}
failures = []
found = []

for cell in root.iter(W + "tc"):
    inner = blocks(cell)
    if inner and inner[-1].tag == W + "tbl":
        failures.append("a table ends a table cell, still nested in its float wrapper")

# Hyphenation is document-wide in settings.xml and suppressed per style, so it
# is resolved along basedOn: body prose only, nothing inherited from Normal.
styles = {s.get(W + "styleId"): s for s in ET.fromstring(zipfile.ZipFile(sys.argv[1]).read("word/styles.xml")).iter(W + "style")}


def hyphenates(style_id):
    while style_id in styles:
        node = styles[style_id].find(f"{W}pPr/{W}suppressAutoHyphens")
        if node is not None:
            return node.get(W + "val") in ("0", "false", "off")
        based = styles[style_id].find(W + "basedOn")
        style_id = None if based is None else based.get(W + "val")
    return True


for style_id, wanted_hyphens in (
    ("BodyText", True),
    ("FirstParagraph", True),
    ("Normal", False),
    ("Compact", False),
    ("Heading1", False),
    ("ImageCaption", False),
    ("FootnoteText", False),
):
    if hyphenates(style_id) != wanted_hyphens:
        failures.append(f"{style_id} {'hyphenates' if not wanted_hyphens else 'does not hyphenate'}, body prose alone should")

missing_toc = [f"TOC{level}" for level in range(1, 10) if f"TOC{level}" not in styles]
if missing_toc:
    failures.append(f"the template defines no {', '.join(missing_toc)} style, so those entries fall back to Normal")

update = ET.fromstring(zipfile.ZipFile(sys.argv[1]).read("word/settings.xml")).find(W + "updateFields")
if update is None or update.get(W + "val") not in ("true", "1", "on"):
    failures.append("settings.xml does not ask Word to update fields on open, so the table of contents opens empty")

children = list(root.find(W + "body"))
toc = next((i for i, el in enumerate(children) if el.tag == W + "sdt"), None)
if toc is None:
    failures.append("no table of contents in the output, which the format turns on")
else:
    heading = "".join(
        t.text or "" for p in children[toc].iter(W + "p") if style(p) == "TOCHeading" for t in p.iter(W + "t")
    )
    if heading != "Table of contents":
        failures.append(f"table of contents titled {heading!r}, not the language's toc-title-document")
    first = next((el for el in children[toc + 1 :] if el.tag in (W + "p", W + "tbl")), None)
    if first is None or not any(br.get(W + "type") == "page" for br in first.iter(W + "br")):
        failures.append("the body does not open on a new page after the table of contents")

bookmarks = {b.get(W + "name") for b in root.iter(W + "bookmarkStart")}
anchors = {h.get(W + "anchor") for h in root.iter(W + "hyperlink") if h.get(W + "anchor")}
for anchor in sorted(anchors - bookmarks):
    failures.append(f"cross-reference to {anchor} resolves to no bookmark")
if anchors != EXPECTED_ANCHORS:
    failures.append(f"cross-references found {sorted(anchors)}, expected {sorted(EXPECTED_ANCHORS)}")

for caption in root.iter(W + "p"):
    if style(caption) not in CAPTION_STYLES:
        continue
    parent = parents[caption]
    full = blocks(parent)
    following = full[full.index(caption) + 1] if full.index(caption) + 1 < len(full) else None
    subtitle = following if following is not None and style(following) in SUBTITLE_STYLES else None
    siblings = [b for b in full if style(b) not in SUBTITLE_STYLES]
    i = siblings.index(caption)
    label = "".join(t.text or "" for t in caption.iter(W + "t")).split("\xa0")[0]
    after = siblings[i + 1] if i + 1 < len(siblings) else None
    before = siblings[i - 1] if i > 0 else None
    if after is not None and is_content(after):
        top, content = True, after
    elif before is not None and is_content(before):
        top, content = False, before
    else:
        failures.append(f"{label}: a caption with no figure or table beside it")
        continue

    wanted = "TableCaption" if top else "ImageCaption"
    image = style(content) if content.tag == W + "p" else None
    found.append((label, style(caption), image, None if subtitle is None else style(subtitle)))

    if content.tag == W + "tbl" and parent.tag != W + "body":
        failures.append(f"{label}: table float nested in {parent.tag.removeprefix(W)}, not at body level")
    titled = wanted + ("Title" if subtitle is not None else "")
    if style(caption) != titled:
        failures.append(f"{label}: caption {'above' if top else 'below'} its content is {style(caption)}, not {titled}")
    if len(caption.findall(W + "pPr")) != 1:
        failures.append(f"{label}: caption carries {len(caption.findall(W + 'pPr'))} w:pPr, Word expects one")
    if caption.find(f"{W}pPr/{W}jc") is not None:
        failures.append(f"{label}: caption carries a direct alignment, which overrides its style")
    if next(caption.iter(W + "br"), None) is not None:
        failures.append(f"{label}: caption carries a line break, the subtitle belongs in its own paragraph")
    if subtitle is not None:
        text = "".join(t.text or "" for t in subtitle.iter(W + "t"))
        if style(subtitle) != wanted + "Subtitle":
            failures.append(f"{label}: subtitle under a {style(caption)} is {style(subtitle)}")
        if text != text.strip():
            failures.append(f"{label}: subtitle {text!r} keeps the blanks around the break")
        if len(subtitle.findall(W + "pPr")) != 1 or subtitle.find(f"{W}pPr/{W}jc") is not None:
            failures.append(f"{label}: subtitle carries a second w:pPr or a direct alignment")

if found != EXPECTED:
    failures.append(f"captions found {found}, expected {EXPECTED}")

if failures:
    print("FAIL  " + "\nFAIL  ".join(failures), file=sys.stderr)
    print(
        "      The float Quarto renders no longer reaches\n"
        "      filters/docx-caption.lua, or no longer matches what it reads.",
        file=sys.stderr,
    )
    sys.exit(1)

print(
    f"ok    {len(found)} float captions styled by position, subtitle on its own line,"
    f" table floats at body level, {len(anchors)} cross-references resolved"
)
PY
