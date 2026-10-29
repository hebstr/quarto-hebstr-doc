#!/usr/bin/env python3
"""Assert on a rendered DOCX what template.dotx and the docx filters owe a Word reader.

Caption position, nesting and bookmarks are structural, hence the parsed tree rather
than the markup. A float must sit at body level: Pandoc cuts the one-cell wrapper
Quarto builds for it out of its own nominal width, so Word crushes a table nested in
it and clips an image at the cell edge.

Every expected value here belongs to tests/docx-template-probe.qmd, so this asserts
that probe and no other document; scripts/check-docx.R is the half that reads any
DOCX. Both arguments are required, the second being the staged probe, whose own shape
one condition reads.

Usage: python3 tests/docx-template-assert.py <file.docx> <staged-probe.qmd>
"""

import sys
import xml.etree.ElementTree as ET
import zipfile
from collections import Counter
from pathlib import Path

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
WP = "{http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing}"
CAPTION_STYLES = ("TableCaption", "ImageCaption", "TableCaptionTitle", "ImageCaptionTitle")
SUBTITLE_STYLES = ("TableCaptionSubtitle", "ImageCaptionSubtitle")
EXPECTED = [
    ("Figure\xa01. Bottom caption", "ImageCaptionTitle", "CaptionedFigure", "ImageCaptionSubtitle"),
    ("Figure\xa02. Top caption.", "TableCaption", "Figure", None),
    ("(a) First panel.", "ImageCaption", "CaptionedFigure", None),
    ("(b) Second panel.", "ImageCaption", "CaptionedFigure", None),
    ("Figure\xa03. Panel caption", "ImageCaptionTitle", None, "ImageCaptionSubtitle"),
    ("Figure\xa04. Left of a layout row.", "ImageCaption", "CaptionedFigure", None),
    ("Figure\xa05. Right of a layout row.", "ImageCaption", "CaptionedFigure", None),
    ("Table\xa01. A Markdown table caption.", "TableCaption", None, None),
    ("Table\xa02. A gt table caption.", "TableCaptionTitle", None, "TableCaptionSubtitle"),
    ("Annexe\xa01. An annexe caption.", "TableCaption", None, None),
]
LAYOUT_ROW = "::: {layout-ncol=2}"
CALLOUT_BORDER_SZ = "24"
CALLOUT_ICON_EMU = ("152400", "152400")
CALLOUT_EXEMPTED = "A callout carrying an identifier, which keeps the table Quarto builds."
CALLOUT_FLOW = (
    ("A callout titled by a heading", True),
    ("A callout with no body at all", True),
    (
        "Its body paragraph, which comes out as ordinary prose once the callout is flattened.",
        False,
    ),
    (
        "An untitled callout, whose content opens the flattened block with no bold paragraph"
        " above it.",
        False,
    ),
)
EXPECTED_ANCHORS = {
    "fig-bottom",
    "fig-top",
    "fig-panels",
    "fig-left",
    "fig-right",
    "tbl-md",
    "tbl-gt",
    "anx-probe",
    "ref-hebstr2026",
}

if len(sys.argv) != 3:
    print(__doc__.strip().splitlines()[-1], file=sys.stderr)
    sys.exit(2)

rendered, probe = Path(sys.argv[1]), Path(sys.argv[2])
package = zipfile.ZipFile(rendered)


def text(element):
    return "".join(t.text or "" for t in element.iter(W + "t"))


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


root = ET.fromstring(package.read("word/document.xml"))
parents = {child: parent for parent in root.iter() for child in parent}
failures = []
found = []

# The layout row is the one shape of the probe whose removal nothing below can
# see: a flattened row and two ordinary body-level figures render alike, which
# is what docx-layout-flatten.lua is for, and what cost tests/docx-cell.sh its
# own coverage once.
if LAYOUT_ROW not in probe.read_text(encoding="utf-8"):
    failures.append(
        "the staged probe carries no layout row, so docx-layout-flatten.lua is exercised by nothing"
    )

for cell in root.iter(W + "tc"):
    inner = blocks(cell)
    if inner and inner[-1].tag == W + "tbl":
        failures.append(
            "a w:tc ends on a w:tbl, which Word refuses to open;"
            " a float wrapper docx-caption.lua did not lift is the likely cause"
        )

# Hyphenation is document-wide in settings.xml and suppressed per style, so it
# is resolved along basedOn: body prose only, nothing inherited from Normal.
styles = {
    s.get(W + "styleId"): s
    for s in ET.fromstring(package.read("word/styles.xml")).iter(W + "style")
}


def inherited(style_id, path):
    while style_id in styles:
        node = styles[style_id].find(path)
        if node is not None:
            return node
        based = styles[style_id].find(W + "basedOn")
        style_id = None if based is None else based.get(W + "val")
    return None


def hyphenates(style_id):
    node = inherited(style_id, f"{W}pPr/{W}suppressAutoHyphens")
    return True if node is None else node.get(W + "val") in ("0", "false", "off")


for style_id, wanted_hyphens in (
    ("BodyText", True),
    ("FirstParagraph", True),
    ("Normal", False),
    ("Compact", False),
    ("Heading1", False),
    ("ImageCaption", False),
    ("FootnoteText", False),
):
    if style_id not in styles:
        failures.append(
            f"the template defines no {style_id} style,"
            " so its hyphenation reads as inherited from nothing"
        )
    elif hyphenates(style_id) != wanted_hyphens:
        failures.append(
            f"{style_id} {'hyphenates' if not wanted_hyphens else 'does not hyphenate'},"
            " body prose alone should"
        )

# A loose list item and the bibliography carry no size of their own, so both
# would fall through Normal to the 12 pt of the document defaults.
for style_id, wanted_sz in (
    ("BodyText", "22"),
    ("Compact", "22"),
    ("ListItem", "22"),
    ("Bibliography", "18"),
):
    node = inherited(style_id, f"{W}rPr/{W}sz")
    if node is None or node.get(W + "val") != wanted_sz:
        resolved = "no size" if node is None else f"{node.get(W + 'val')} half-points"
        failures.append(f"{style_id} resolves to {resolved}, not {wanted_sz}")

# A level-1 heading opens a page of its own, which is what makes the paragraph
# docx-toc-break.lua inserts a no-op in a body opening on one; keepNext is what
# holds a caption title to the subtitle under it.
for style_id, path, wanted, consequence in (
    (
        "Heading1",
        f"{W}pPr/{W}pageBreakBefore",
        True,
        "a level-1 heading no longer opens its own page",
    ),
    ("Heading2", f"{W}pPr/{W}pageBreakBefore", False, "a level-2 heading opens a page of its own"),
    (
        "TOCHeading",
        f"{W}pPr/{W}pageBreakBefore",
        True,
        "the table of contents no longer opens its own page",
    ),
    (
        "TableCaptionTitle",
        f"{W}pPr/{W}keepNext",
        True,
        "a page break can fall between a caption and its subtitle",
    ),
    (
        "ImageCaptionTitle",
        f"{W}pPr/{W}keepNext",
        True,
        "a page break can fall between a caption and its subtitle",
    ),
):
    if (inherited(style_id, path) is not None) != wanted:
        article = "no" if wanted else "a"
        failures.append(
            f"{style_id} resolves to {article} {path.rsplit('}', 1)[1]}, so {consequence}"
        )

# The size above is all these styles inherit; what each one exists to carry is a
# spacing of its own, and for a subtitle the bold-off against the bold Caption
# it descends from.
for style_id, attr, wanted_twips in (
    ("ListItem", "before", "120"),
    ("ListItem", "after", "120"),
    ("TableCaptionTitle", "after", "0"),
    ("ImageCaptionTitle", "after", "0"),
):
    node = inherited(style_id, f"{W}pPr/{W}spacing")
    value = None if node is None else node.get(W + attr)
    if value != wanted_twips:
        failures.append(
            f"{style_id} resolves to a spacing {attr} of {value}, not {wanted_twips} twips,"
            " so it renders like the style it is based on"
        )

for style_id in SUBTITLE_STYLES:
    node = inherited(style_id, f"{W}rPr/{W}b")
    if node is None or node.get(W + "val") not in ("0", "false", "off"):
        failures.append(
            f"{style_id} does not turn off the bold of Caption, so the subtitle renders bold"
        )

missing_toc = [f"TOC{level}" for level in range(1, 10) if f"TOC{level}" not in styles]
if missing_toc:
    failures.append(
        f"the template defines no {', '.join(missing_toc)} style,"
        " so those entries fall back to Normal"
    )

update = ET.fromstring(package.read("word/settings.xml")).find(W + "updateFields")
if update is None or update.get(W + "val") not in ("true", "1", "on"):
    failures.append(
        "settings.xml does not ask Word to update fields on open,"
        " so the table of contents opens empty"
    )

children = root.findall(f"{W}body/*")
toc = next((i for i, el in enumerate(children) if el.tag == W + "sdt"), None)
if toc is None:
    failures.append("no table of contents in the output, which the format turns on")
else:
    heading = "".join(text(p) for p in children[toc].iter(W + "p") if style(p) == "TOCHeading")
    if heading != "Table of contents":
        failures.append(
            f"table of contents titled {heading!r}, not the language's toc-title-document"
        )
    first = next((el for el in children[toc + 1 :] if el.tag in (W + "p", W + "tbl")), None)
    if first is None or not any(br.get(W + "type") == "page" for br in first.iter(W + "br")):
        failures.append(
            "no page break after the table of contents, so filters/docx-toc-break.lua no longer"
            " runs; the body still opens on a page of its own here, Heading1 carrying its own"
            " pageBreakBefore"
        )

# Pandoc skips its own body style wherever the paragraph already carries
# properties, so a loose list item reaches the output numbered and styleless
# unless filters/docx-list-style.lua names its style.
items = Counter(style(p) for p in root.iter(W + "p") if p.find(f"{W}pPr/{W}numPr") is not None)
if items[None]:
    failures.append(
        f"{items[None]} numbered paragraph(s) carry no style,"
        " so they take the document default size"
    )
if (items["ListItem"], items["Compact"]) != (2, 2):
    failures.append(
        f"list items found {dict(items)}, expected 2 under ListItem and 2 under Compact"
    )
if not any(style(p) == "Bibliography" for p in root.iter(W + "p")):
    failures.append(
        "no Bibliography paragraph in the output, so the citation reached no reference list"
    )


# Both branches of Quarto's callout renderer wrap the callout in a table whose
# left border is 3 pt, and the simple one pulls the 16 pt type icon into
# word/media; the probe's six figures are the only other drawings. One of each
# is owed, by the callout the identifier guard exempts, and that count is what
# keeps the two values below from being satisfied by an upstream change to
# either of them.
def left_border(tbl):
    node = tbl.find(f"{W}tblPr/{W}tblBorders/{W}left")
    return None if node is None else node.get(W + "sz")


borders = [t for t in root.iter(W + "tbl") if left_border(t) == CALLOUT_BORDER_SZ]
if len(borders) != 1:
    failures.append(
        f"{len(borders)} table(s) carry the callout left border,"
        " expected the one of the exempted callout"
    )


def extent(drawing):
    node = next(drawing.iter(WP + "extent"), None)
    return None if node is None else (node.get("cx"), node.get("cy"))


icons = [d for d in root.iter(W + "drawing") if extent(d) == CALLOUT_ICON_EMU]
if len(icons) != 1:
    failures.append(
        f"{len(icons)} callout icon(s) reach word/media, expected the one of the exempted callout"
    )

exempted = next((p for p in root.iter(W + "p") if text(p) == CALLOUT_EXEMPTED), None)
if exempted is None:
    failures.append(
        f"{CALLOUT_EXEMPTED!r}: the probe no longer carries"
        " the callout the identifier guard exempts"
    )
elif parents[exempted].tag == W + "body":
    failures.append(
        f"{CALLOUT_EXEMPTED!r}: an exempted callout reached body level,"
        " so the guard no longer holds"
    )

# Without this the two conditions above pass on a probe that lost its callouts,
# and without the bodies the three of them pass on a flatten that lost its
# content pass-through.
for wanted_text, bold in CALLOUT_FLOW:
    kind = "title" if bold else "body"
    para = next((p for p in root.iter(W + "p") if text(p) == wanted_text), None)
    if para is None:
        failures.append(
            f"{wanted_text!r}: no paragraph carries that callout {kind},"
            f" so either the probe exercises no callout or the flatten dropped its {kind}"
        )
    elif parents[para].tag != W + "body":
        failures.append(
            f"{wanted_text!r}: callout {kind} in {parents[para].tag.removeprefix(W)},"
            " not at body level"
        )
    elif (next(para.iter(W + "b"), None) is not None) != bold:
        failures.append(
            f"{wanted_text!r}: callout {kind} carries {'no bold run' if bold else 'a bold run'},"
            " against the weight the flatten gives it"
        )

bookmarks = {name for b in root.iter(W + "bookmarkStart") if (name := b.get(W + "name"))}
anchors = {anchor for h in root.iter(W + "hyperlink") if (anchor := h.get(W + "anchor"))}
for anchor in sorted(anchors - bookmarks):
    failures.append(f"cross-reference to {anchor} resolves to no bookmark")
if anchors != EXPECTED_ANCHORS:
    failures.append(
        f"cross-references found {sorted(anchors)}, expected {sorted(EXPECTED_ANCHORS)}"
    )


# A float bookmark bounds what a caption may pair with, and a caption met on
# the way is another float's: the one closing a panel float is the caption of
# the group, which no single image sits beside.
def flow(parent):
    return [
        b
        for b in parent
        if b.tag in (W + "tbl", W + "bookmarkStart")
        or (b.tag == W + "p" and next(b.iter(W + "r"), None) is not None)
    ]


def neighbour(seq, start, step):
    i = start + step
    while 0 <= i < len(seq):
        el = seq[i]
        if el.tag == W + "bookmarkStart":
            return None
        if style(el) in SUBTITLE_STYLES:
            i += step
            continue
        if style(el) in CAPTION_STYLES:
            return "caption"
        return el if is_content(el) else None
    return None


for caption in root.iter(W + "p"):
    if style(caption) not in CAPTION_STYLES:
        continue
    parent = parents[caption]
    full = blocks(parent)
    following = full[full.index(caption) + 1] if full.index(caption) + 1 < len(full) else None
    subtitle = following if following is not None and style(following) in SUBTITLE_STYLES else None
    seq = flow(parent)
    i = seq.index(caption)
    label = text(caption)
    before, after = neighbour(seq, i, -1), neighbour(seq, i, 1)
    if before is not None and before != "caption":
        top, content = False, before
    elif after is not None and after != "caption":
        top, content = True, after
    elif before == "caption":
        top, content = False, None
    else:
        failures.append(f"{label}: a caption with no figure or table beside it")
        continue

    wanted = "TableCaption" if top else "ImageCaption"
    image = style(content) if content is not None and content.tag == W + "p" else None
    found.append((label, style(caption), image, None if subtitle is None else style(subtitle)))

    if parent.tag != W + "body":
        failures.append(f"{label}: float nested in {parent.tag.removeprefix(W)}, not at body level")
    titled = wanted + ("Title" if subtitle is not None else "")
    if style(caption) != titled:
        position = "above" if top else "below"
        failures.append(
            f"{label}: caption {position} its content is {style(caption)}, not {titled}"
        )
    if len(caption.findall(W + "pPr")) != 1:
        failures.append(
            f"{label}: caption carries {len(caption.findall(W + 'pPr'))} w:pPr, Word expects one"
        )
    if caption.find(f"{W}pPr/{W}jc") is not None:
        failures.append(f"{label}: caption carries a direct alignment, which overrides its style")
    if next(caption.iter(W + "br"), None) is not None:
        failures.append(
            f"{label}: caption carries a line break, the subtitle belongs in its own paragraph"
        )
    if subtitle is not None:
        subtitle_text = text(subtitle)
        if style(subtitle) != wanted + "Subtitle":
            failures.append(f"{label}: subtitle under a {style(caption)} is {style(subtitle)}")
        if subtitle_text != subtitle_text.strip():
            failures.append(
                f"{label}: subtitle {subtitle_text!r} keeps the blanks around the break"
            )
        if len(subtitle.findall(W + "pPr")) != 1 or subtitle.find(f"{W}pPr/{W}jc") is not None:
            failures.append(f"{label}: subtitle carries a second w:pPr or a direct alignment")

if found != EXPECTED:
    i = next(
        (
            n
            for n in range(max(len(found), len(EXPECTED)))
            if found[n : n + 1] != EXPECTED[n : n + 1]
        ),
        0,
    )
    failures.append(
        f"caption {i} is {found[i : i + 1]}, expected {EXPECTED[i : i + 1]}"
        f" ({len(found)} captions found, {len(EXPECTED)} expected)"
    )

if failures:
    print("FAIL  " + "\nFAIL  ".join(failures), file=sys.stderr)
    print(
        "      A style, a size, a spacing or a page break is template.dotx's;\n"
        "      a caption, a list item, a layout row or a callout belongs to\n"
        "      filters/docx-caption.lua, filters/docx-list-style.lua,\n"
        "      filters/docx-layout-flatten.lua or\n"
        "      filters/docx-callout-flatten.lua; a cell left open to\n"
        "      filters/docx-cell-paragraph.lua, and the break after the table\n"
        "      of contents to filters/docx-toc-break.lua.",
        file=sys.stderr,
    )
    sys.exit(1)

print(
    f"ok    {len(found)} float captions styled by position, subtitle on its own line,"
    f" floats at body level, {len(anchors)} cross-references resolved,"
    f" {items['ListItem'] + items['Compact']} list items sized by a named style,"
    f" {len(CALLOUT_FLOW)} callout titles and bodies in the flow,"
    f" {len(borders)} identified callout left as the table Quarto builds"
)
