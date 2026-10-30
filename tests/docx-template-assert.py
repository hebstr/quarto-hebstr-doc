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
    ("(a) First column.", "ImageCaption", "CaptionedFigure", None),
    ("(b) Second column.", "ImageCaption", "CaptionedFigure", None),
    ("Figure\xa06. Column caption.", "ImageCaption", None, None),
    ("Table\xa01. A Markdown table caption.", "TableCaption", None, None),
    ("Table\xa02. A gt table caption.", "TableCaptionTitle", None, "TableCaptionSubtitle"),
    ("Annexe\xa01. An annexe caption.", "TableCaption", None, None),
]
LAYOUT_ROW = "::: {layout-ncol=2}"
TITLE_BLOCK = (
    ("Title", "DOCX template probe"),
    ("Subtitle", "Reference document and float captions"),
    ("Author", "hebstr"),
)
FOOTNOTE = "A footnote."
CALLOUT_BORDER_SZ = "24"
CALLOUT_ICON_EMU = ("152400", "152400")
CALLOUT_EXEMPTED = "A callout carrying an identifier, which keeps the table Quarto builds."
CALLOUT_IDENTIFIED = "{#nte-x "
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
    "fig-columns",
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

# Two shapes are read in the source because no output-side condition can read
# their removal as a probe change. A flattened layout row and two ordinary
# body-level figures render alike, which is what docx-layout-flatten.lua is for
# and what cost tests/docx-cell.sh its own coverage once; and an identifier
# dropped from a callout flattens it, which the conditions below would report as
# a guard that no longer holds, the opposite diagnosis.
source = probe.read_text(encoding="utf-8")
if LAYOUT_ROW not in source:
    failures.append(
        "the staged probe carries no layout row, so docx-layout-flatten.lua is exercised by nothing"
    )
identified = CALLOUT_IDENTIFIED in source
if not identified:
    failures.append(
        "the staged probe carries no identified callout, so the identifier guard of"
        " docx-callout-flatten.lua is exercised by nothing"
    )

for cell in root.iter(W + "tc"):
    inner = blocks(cell)
    if inner and inner[-1].tag == W + "tbl":
        failures.append(
            "a w:tc ends on a w:tbl, so a float wrapper docx-caption.lua did not lift and"
            " Word crushes what that cell holds; the refusal to open is check_cells in"
            " scripts/check-docx.R, which counts the closing paragraph this one steps over"
        )

# Hyphenation is document-wide in settings.xml and suppressed per style, so it
# is resolved along basedOn: body prose only, nothing inherited from Normal.
styles = {
    s.get(W + "styleId"): s
    for s in ET.fromstring(package.read("word/styles.xml")).iter(W + "style")
}


def inherited_attr(style_id, path, attr):
    while style_id in styles:
        node = styles[style_id].find(path)
        if node is not None and node.get(W + attr) is not None:
            return node.get(W + attr)
        based = styles[style_id].find(W + "basedOn")
        style_id = None if based is None else based.get(W + "val")
    return None


def inherited(style_id, path):
    while style_id in styles:
        node = styles[style_id].find(path)
        if node is not None:
            return node
        based = styles[style_id].find(W + "basedOn")
        style_id = None if based is None else based.get(W + "val")
    return None


# A toggle property carrying w:val="0" is off, which is the form Word writes
# when a style checkbox is cleared and the form this template already uses on
# Subtitle and BodyText, so presence is never the question.
def toggled_on(node):
    return node is not None and node.get(W + "val") not in ("0", "false", "off")


def hyphenates(style_id):
    return not toggled_on(inherited(style_id, f"{W}pPr/{W}suppressAutoHyphens"))


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
    if toggled_on(inherited(style_id, path)) != wanted:
        article = "no" if wanted else "a"
        failures.append(
            f"{style_id} resolves to {article} {path.rsplit('}', 1)[1]}, so {consequence}"
        )

# The size above is all these styles inherit; what each one exists to carry is a
# spacing of its own, and for a subtitle the bold-off against the bold Caption
# it descends from. Word resolves w:before and w:after one by one, so a style
# declaring only one of them takes the other from the style it is based on.
for style_id, attr, wanted_twips in (
    ("ListItem", "before", "120"),
    ("ListItem", "after", "120"),
    ("TableCaptionTitle", "after", "0"),
    ("ImageCaptionTitle", "after", "0"),
):
    value = inherited_attr(style_id, f"{W}pPr/{W}spacing", attr)
    if value != wanted_twips:
        failures.append(
            f"{style_id} resolves to a spacing {attr} of {value}, not {wanted_twips} twips,"
            " so it renders like the style it is based on"
        )

# docx-caption.lua resets a centred wrapper column to AlignDefault and moves
# the centring onto the image's own style, so what aligns a figure, a caption or
# the body prose resolves along basedOn or nowhere, and no condition above reads
# a paragraph's resolved alignment.
for style_id, wanted_jc in (
    ("Figure", "center"),
    ("CaptionedFigure", "center"),
    ("TableCaption", "center"),
    ("ImageCaption", None),
    ("BodyText", "both"),
):
    node = inherited(style_id, f"{W}pPr/{W}jc")
    resolved = None if node is None else node.get(W + "val")
    if resolved != wanted_jc:
        failures.append(
            f"{style_id} resolves to an alignment of {resolved}, not {wanted_jc},"
            " so Word lays its paragraphs out otherwise"
        )

for style_id in (*SUBTITLE_STYLES, "Subtitle"):
    node = inherited(style_id, f"{W}rPr/{W}b")
    if node is None or toggled_on(node):
        failures.append(
            f"{style_id} does not turn off the bold of the style it is based on, so it renders bold"
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

# The title block and the footnote are the probe's only call on the Title,
# Subtitle, Author and FootnoteText styles, and scripts/check-docx.R resolves
# those through the parts it reads rather than requiring either shape, so
# dropping one from the probe would cost that coverage with nothing to see.
opening = [el for el in children if el.tag == W + "p"][: len(TITLE_BLOCK)]
if tuple((style(p), text(p)) for p in opening) != TITLE_BLOCK:
    failures.append(
        f"the body opens on {[(style(p), text(p)) for p in opening]},"
        f" not on the probe's title block {list(TITLE_BLOCK)}"
    )

if "word/footnotes.xml" in package.namelist():
    notes = ET.fromstring(package.read("word/footnotes.xml"))
    footnoted = any(
        style(p) == "FootnoteText" and text(p).strip() == FOOTNOTE for p in notes.iter(W + "p")
    )
else:
    footnoted = False
if not footnoted:
    failures.append(
        f"no FootnoteText paragraph reading {FOOTNOTE!r} in word/footnotes.xml, so the probe"
        " carries no footnote and the style it resolves through that part is unexercised"
    )

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
# left border is 3 pt, and the simple one pulls the 16 px type icon into
# word/media, 152400 EMU on each side at any dpi, Quarto scaling the pixel size
# by dpi/96 and Pandoc dividing it back; the probe's figures measure otherwise.
# One of each
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
        f"{len(icons)} drawing(s) of the callout icon extent in the body,"
        " expected the one of the exempted callout"
    )

exempted = next((p for p in root.iter(W + "p") if text(p) == CALLOUT_EXEMPTED), None)
if exempted is None:
    failures.append(
        f"{CALLOUT_EXEMPTED!r}: the probe no longer carries"
        " the callout the identifier guard exempts"
    )
elif identified and parents[exempted].tag == W + "body":
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


# Quarto keeps a table for the row of a sub-float, and Pandoc writes that row's
# column alignment as a direct w:jc on every paragraph of its cells, where it
# outranks ImageCaption and CaptionedFigure: docx-caption.lua clears it. The
# one-cell wrapper of a float is lifted out instead, so a caption nested in one
# of those stays a failure below.
# Own rows and own cells throughout: a one-cell wrapper holding a nested table
# answers an iter() over descendants, which would excuse the very nesting the
# condition below is there to catch.
def subfloat_cells_of(tbl):
    wide = [row for row in tbl.findall(f"{W}tr") if len(row.findall(f"{W}tc")) > 1]
    cells = [cell for row in wide for cell in row.findall(f"{W}tc")]
    if any(style(p) in CAPTION_STYLES for cell in cells for p in cell.findall(f"{W}p")):
        return cells
    return []


rows = {t: cells for t in root.iter(W + "tbl") if (cells := subfloat_cells_of(t))}
subfloat_cells = {cell for cells in rows.values() for cell in cells}
if len(rows) != 1:
    failures.append(
        f"{len(rows)} sub-float row(s) survive as a table, expected the one the probe lays out"
        " in columns, which is the only shape reaching the filter's column alignment reset"
    )
aligned = [
    p
    for cell in subfloat_cells
    for p in cell.findall(f"{W}p")
    if p.find(f"{W}pPr/{W}jc") is not None
]
if aligned:
    failures.append(
        f"{len(aligned)} paragraph(s) of a sub-float row carry a direct alignment,"
        " which outranks their caption and figure styles"
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

    if parent.tag != W + "body" and parent not in subfloat_cells:
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
