#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Rebuild the DOCX reference document of hebstr-doc from Pandoc's default.

The extension ships template.dotx as a binary, and this script is the recipe
that produces it. It reads the reference.docx bundled with Quarto's Pandoc and
applies counted substitutions only: a pattern that matches zero or several
times aborts the build instead of producing a silently different file.

Usage, from the repository root:

    uv run scripts/build_template.py [output]
    Rscript scripts/check-docx.R _extensions/hebstr-doc/template.dotx

The output defaults to the extension's template.dotx.
"""

import io
import re
import subprocess
import sys
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEFAULT_OUT = REPO / "_extensions" / "hebstr-doc" / "template.dotx"

W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
R_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
BLUE = "1B4377"


def sub1(pattern, repl, text, label, flags=re.S):
    new, n = re.subn(pattern, lambda _: repl, text, flags=flags)
    if n != 1:
        sys.exit(f"{label}: expected 1 match, got {n}")
    return new


def replace_style(styles, style_id, block):
    pattern = r'<w:style\b[^>]*w:styleId="' + re.escape(style_id) + r'"\s*>.*?</w:style>'
    return sub1(pattern, block, styles, f"style {style_id}")


def style(
    kind,
    style_id,
    name,
    *,
    based_on=None,
    next_=None,
    link=None,
    custom=False,
    ppr="",
    rpr="",
    extra="",
):
    attrs = (
        f'w:type="{kind}"' + (' w:customStyle="1"' if custom else "") + f' w:styleId="{style_id}"'
    )
    parts = [f"<w:style {attrs}>", f'<w:name w:val="{name}"/>']
    if based_on:
        parts.append(f'<w:basedOn w:val="{based_on}"/>')
    if next_:
        parts.append(f'<w:next w:val="{next_}"/>')
    if link:
        parts.append(f'<w:link w:val="{link}"/>')
    parts.append(extra)
    parts.append("<w:qFormat/>")
    if ppr:
        parts.append(f"<w:pPr>{ppr}</w:pPr>")
    if rpr:
        parts.append(f"<w:rPr>{rpr}</w:rPr>")
    parts.append("</w:style>")
    return "".join(parts)


def num_pr(ilvl, num_id=1):
    return f'<w:numPr><w:ilvl w:val="{ilvl}"/><w:numId w:val="{num_id}"/></w:numPr>'


def sz(half_points):
    return f'<w:sz w:val="{half_points}"/><w:szCs w:val="{half_points}"/>'


def color(hex_):
    return f'<w:color w:val="{hex_}"/>'


SPACED = 'w:before="200" w:after="0"'

HEADINGS = {
    1: {
        "spacing": 'w:before="480" w:after="320"',
        "ind": None,
        "rpr": "<w:b/><w:bCs/>" + color(BLUE) + sz(32),
    },
    2: {
        "spacing": 'w:before="240" w:after="240"',
        "ind": None,
        "rpr": "<w:b/><w:bCs/>" + color(BLUE) + sz(28),
    },
    3: {
        "spacing": 'w:before="200" w:after="200"',
        "ind": 862,
        "rpr": "<w:b/><w:bCs/>" + color(BLUE) + sz(26),
    },
    4: {
        "spacing": 'w:before="160" w:after="160"',
        "ind": 1009,
        "rpr": "<w:b/><w:bCs/><w:iCs/>" + color(BLUE),
    },
    5: {"spacing": SPACED, "ind": None, "rpr": color(BLUE)},
    6: {"spacing": SPACED, "ind": None, "rpr": "<w:i/><w:iCs/>" + color(BLUE)},
    7: {"spacing": SPACED, "ind": None, "rpr": "<w:i/><w:iCs/>" + color("404040")},
    8: {"spacing": SPACED, "ind": None, "rpr": color("404040") + sz(20)},
    9: {"spacing": SPACED, "ind": None, "rpr": "<w:i/><w:iCs/>" + color("404040") + sz(20)},
}

COMPAT = (
    "<w:compat><w:useFELayout/>"
    + "".join(
        f'<w:compatSetting w:name="{name}" w:uri="http://schemas.microsoft.com/office/word"'
        f' w:val="{val}"/>'
        for name, val in (
            ("compatibilityMode", 15),
            ("overrideTableStyleFontSizeAndJustification", 1),
            ("enableOpenTypeFeatures", 1),
            ("doNotFlipMirrorIndents", 1),
            ("differentiateMultirowTableHeaders", 1),
            ("useWord2013TrackBottomHyphenation", 0),
        )
    )
    + "</w:compat>"
)


def build_styles(styles):
    styles = re.sub(r'\s+w:theme(Color|Shade|Tint)="[^"]*"', "", styles)

    styles = replace_style(
        styles,
        "Normal",
        (
            '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
            '<w:name w:val="Normal"/><w:qFormat/>'
            '<w:pPr><w:spacing w:before="120" w:after="120"/></w:pPr>'
            "</w:style>"
        ),
    )
    styles = replace_style(
        styles,
        "BodyText",
        style(
            "paragraph",
            "BodyText",
            "Body Text",
            based_on="Normal",
            link="BodyTextChar",
            ppr='<w:spacing w:line="360" w:lineRule="auto"/><w:jc w:val="both"/>',
            rpr=sz(22),
        ),
    )
    styles = replace_style(
        styles,
        "BodyTextChar",
        style(
            "character",
            "BodyTextChar",
            "Body Text Char",
            based_on="DefaultParagraphFont",
            link="BodyText",
            custom=True,
            rpr=sz(22),
        ),
    )
    styles = replace_style(
        styles,
        "Compact",
        style(
            "paragraph",
            "Compact",
            "Compact",
            based_on="BodyText",
            custom=True,
            ppr='<w:spacing w:before="36" w:after="36"/><w:jc w:val="left"/>',
        ),
    )

    title_rpr = (
        "<w:b/><w:bCs/>"
        + color(BLUE)
        + '<w:spacing w:val="5"/><w:kern w:val="28"/><w:sz w:val="56"/><w:szCs w:val="48"/>'
    )
    styles = replace_style(
        styles,
        "Title",
        style(
            "paragraph",
            "Title",
            "Title",
            based_on="Normal",
            next_="BodyText",
            link="TitleChar",
            ppr=(
                '<w:spacing w:before="480" w:after="480"/>'
                '<w:contextualSpacing/><w:jc w:val="center"/>'
            ),
            rpr=title_rpr,
        ),
    )
    styles = replace_style(
        styles,
        "TitleChar",
        style(
            "character",
            "TitleChar",
            "Title Char",
            based_on="DefaultParagraphFont",
            link="Title",
            custom=True,
            rpr=title_rpr,
        ),
    )
    styles = replace_style(
        styles,
        "Subtitle",
        style(
            "paragraph",
            "Subtitle",
            "Subtitle",
            based_on="Title",
            next_="BodyText",
            link="SubtitleChar",
            rpr='<w:b w:val="0"/><w:bCs w:val="0"/><w:spacing w:val="0"/><w:kern w:val="0"/>'
            '<w:sz w:val="48"/><w:szCs w:val="28"/>',
        ),
    )
    styles = replace_style(
        styles,
        "SubtitleChar",
        style(
            "character",
            "SubtitleChar",
            "Subtitle Char",
            based_on="DefaultParagraphFont",
            link="Subtitle",
            custom=True,
            rpr=color(BLUE) + '<w:sz w:val="48"/><w:szCs w:val="28"/>',
        ),
    )
    for sid, bold in (("Author", "<w:b/><w:bCs/>"), ("Date", "<w:bCs/>")):
        styles = replace_style(
            styles,
            sid,
            style(
                "paragraph",
                sid,
                sid,
                based_on="Normal",
                next_="BodyText",
                custom=(sid == "Author"),
                ppr='<w:keepNext/><w:keepLines/><w:spacing w:after="60"/><w:jc w:val="center"/>',
                rpr=bold + color("111111") + '<w:sz w:val="32"/>',
            ),
        )

    for level, spec in HEADINGS.items():
        ind = f'<w:ind w:left="{spec["ind"]}" w:hanging="{spec["ind"]}"/>' if spec["ind"] else ""
        numbering = num_pr(level) if level <= 8 else ""
        hidden = "" if level == 1 else '<w:uiPriority w:val="9"/><w:semiHidden/><w:unhideWhenUsed/>'
        styles = replace_style(
            styles,
            f"Heading{level}",
            style(
                "paragraph",
                f"Heading{level}",
                f"heading {level}",
                based_on="Normal",
                next_="BodyText",
                link=f"Heading{level}Char",
                extra=hidden,
                ppr=f"<w:keepNext/><w:keepLines/>{numbering}<w:spacing {spec['spacing']}/>{ind}"
                f'<w:outlineLvl w:val="{level - 1}"/>',
                rpr=spec["rpr"],
            ),
        )
        styles = replace_style(
            styles,
            f"Heading{level}Char",
            style(
                "character",
                f"Heading{level}Char",
                f"Heading {level} Char",
                based_on="DefaultParagraphFont",
                link=f"Heading{level}",
                custom=True,
                rpr=spec["rpr"],
            ),
        )

    styles = replace_style(
        styles,
        "TOCHeading",
        style(
            "paragraph",
            "TOCHeading",
            "TOC Heading",
            based_on="Heading1",
            next_="BodyText",
            extra='<w:uiPriority w:val="39"/><w:unhideWhenUsed/>',
            ppr='<w:pageBreakBefore/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="0"/></w:numPr>'
            '<w:spacing w:before="0" w:after="240"/><w:jc w:val="center"/>'
            '<w:outlineLvl w:val="9"/>',
        ),
    )

    caption_rpr = "<w:b/><w:bCs/>" + color("111111") + sz(20)
    styles = replace_style(
        styles,
        "Caption",
        style(
            "paragraph",
            "Caption",
            "Caption",
            based_on="Normal",
            rpr=caption_rpr,
        ),
    )
    styles = replace_style(
        styles,
        "TableCaption",
        style(
            "paragraph",
            "TableCaption",
            "Table Caption",
            based_on="Caption",
            custom=True,
            ppr='<w:keepNext/><w:jc w:val="center"/>',
        ),
    )
    styles = replace_style(
        styles,
        "ImageCaption",
        style(
            "paragraph",
            "ImageCaption",
            "Image Caption",
            based_on="Caption",
            custom=True,
        ),
    )
    styles = replace_style(
        styles,
        "Figure",
        style(
            "paragraph",
            "Figure",
            "Figure",
            based_on="Normal",
            custom=True,
            ppr='<w:jc w:val="center"/>',
        ),
    )
    styles = replace_style(
        styles,
        "CaptionedFigure",
        style(
            "paragraph",
            "CaptionedFigure",
            "Captioned Figure",
            based_on="Figure",
            custom=True,
            ppr='<w:keepNext/><w:spacing w:before="240" w:after="240"/>',
        ),
    )
    # Body Text Char carries 11 pt, which a link inside a 10 pt caption must not inherit
    styles = replace_style(
        styles,
        "Hyperlink",
        style(
            "character",
            "Hyperlink",
            "Hyperlink",
            based_on="DefaultParagraphFont",
            rpr=color("0000FF") + '<w:u w:val="single"/>',
        ),
    )
    styles = replace_style(
        styles,
        "VerbatimChar",
        style(
            "character",
            "VerbatimChar",
            "Verbatim Char",
            based_on="BodyTextChar",
            custom=True,
            rpr='<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/><w:sz w:val="20"/>',
        ),
    )
    styles = replace_style(
        styles,
        "FootnoteText",
        style(
            "paragraph",
            "FootnoteText",
            "Footnote Text",
            based_on="Normal",
            next_="FootnoteText",
            ppr='<w:spacing w:before="0" w:after="0"/><w:jc w:val="left"/>',
            rpr=sz(20),
        ),
    )
    styles = replace_style(
        styles,
        "Bibliography",
        style(
            "paragraph",
            "Bibliography",
            "Bibliography",
            based_on="Normal",
            next_="Bibliography",
            ppr='<w:tabs><w:tab w:val="left" w:pos="709"/></w:tabs><w:spacing w:after="0"/>'
            '<w:ind w:left="709" w:hanging="709"/>',
        ),
    )

    # A paragraph style, since Word keeps a character style's b val=0 bold in a bold paragraph
    subtitle_rpr = '<w:b w:val="0"/><w:bCs w:val="0"/>' + color("555555") + sz(18)
    added = "".join(
        style(
            "paragraph",
            f"{sid}Subtitle",
            f"{name} Subtitle",
            based_on=sid,
            custom=True,
            ppr='<w:spacing w:before="0"/>',
            rpr=subtitle_rpr,
        )
        for sid, name in (("TableCaption", "Table Caption"), ("ImageCaption", "Image Caption"))
    ) + style(
        "paragraph",
        "Footer",
        "footer",
        based_on="Normal",
        extra='<w:uiPriority w:val="99"/><w:unhideWhenUsed/>',
        ppr='<w:spacing w:before="0" w:after="0"/><w:jc w:val="center"/>',
        rpr=sz(20),
    )
    toc_extra = '<w:uiPriority w:val="39"/><w:unhideWhenUsed/>'
    added += style(
        "paragraph",
        "TOC1",
        "toc 1",
        based_on="Normal",
        next_="Normal",
        extra=toc_extra,
        ppr='<w:tabs><w:tab w:val="left" w:pos="480"/>'
        '<w:tab w:val="right" w:leader="dot" w:pos="9056"/></w:tabs>'
        '<w:spacing w:before="80" w:after="80"/>',
        rpr='<w:b/><w:noProof/><w:sz w:val="22"/>',
    )
    for level, indent in ((2, 238), (3, 482)):
        added += style(
            "paragraph",
            f"TOC{level}",
            f"toc {level}",
            based_on="TOC1",
            next_="Normal",
            extra=toc_extra,
            ppr=f'<w:ind w:left="{indent}"/>',
            rpr='<w:b w:val="0"/>',
        )
    return sub1(r"</w:styles>", added + "</w:styles>", styles, "styles tail")


def build_numbering(numbering):
    levels = [
        '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="none"/><w:suff w:val="nothing"/>'
        '<w:lvlText w:val=""/><w:lvlJc w:val="left"/>'
        '<w:pPr><w:ind w:left="432" w:hanging="432"/></w:pPr></w:lvl>'
    ]
    for ilvl in range(1, 9):
        text = "%1%2" + "".join(f".%{k}" for k in range(3, ilvl + 2))
        indent = 432 + 144 * ilvl
        levels.append(
            f'<w:lvl w:ilvl="{ilvl}"><w:start w:val="1"/><w:numFmt w:val="decimal"/>'
            f'<w:pStyle w:val="Heading{ilvl}"/><w:lvlText w:val="{text}"/><w:lvlJc w:val="left"/>'
            f'<w:pPr><w:ind w:left="{indent}" w:hanging="{indent}"/></w:pPr></w:lvl>'
        )
    abstract = (
        '<w:abstractNum w:abstractNumId="1"><w:nsid w:val="696B7C68"/>'
        '<w:multiLevelType w:val="multilevel"/><w:name w:val="hebstr-doc headings"/>'
        + "".join(levels)
        + "</w:abstractNum>"
    )
    numbering = sub1(
        r'<w:abstractNum w:abstractNumId="990">',
        abstract + '<w:abstractNum w:abstractNumId="990">',
        numbering,
        "numbering abstractNum",
    )
    return sub1(
        r'<w:num w:numId="1000">',
        '<w:num w:numId="1"><w:abstractNumId w:val="1"/></w:num><w:num w:numId="1000">',
        numbering,
        "numbering num",
    )


FOOTER = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    f'<w:ftr xmlns:w="{W_NS}" xmlns:r="{R_NS}"><w:p><w:pPr><w:pStyle w:val="Footer"/></w:pPr>'
    '<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
    '<w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>'
    '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
    "<w:r><w:t>2</w:t></w:r>"
    '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
    "</w:p></w:ftr>"
)

SECT_PR = (
    '<w:sectPr><w:footerReference w:type="default" r:id="rId9"/>'
    '<w:footnotePr><w:numRestart w:val="eachSect"/></w:footnotePr>'
    '<w:pgSz w:w="11900" w:h="16840"/>'
    '<w:pgMar w:top="1417" w:right="1417" w:bottom="1417" w:left="1417"'
    ' w:header="708" w:footer="708" w:gutter="0"/>'
    '<w:cols w:space="708"/><w:titlePg/><w:docGrid w:linePitch="360"/></w:sectPr>'
)


def transform(name, data):
    text = data.decode("utf-8")
    if name == "[Content_Types].xml":
        text = sub1(
            r"wordprocessingml\.document\.main\+xml",
            "wordprocessingml.template.main+xml",
            text,
            "content type",
        )
        text = sub1(
            r"</Types>",
            '<Override PartName="/word/footer1.xml" ContentType='
            '"application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/></Types>',
            text,
            "footer content type",
        )
    elif name == "word/_rels/document.xml.rels":
        text = sub1(
            r"</Relationships>",
            '<Relationship Type="http://schemas.openxmlformats.org/officeDocument/'
            '2006/relationships/footer" Id="rId9" Target="footer1.xml"/></Relationships>',
            text,
            "footer rel",
        )
    elif name == "word/document.xml":
        text = sub1(r"<w:sectPr>.*?</w:sectPr>", SECT_PR, text, "sectPr")
    elif name == "word/styles.xml":
        text = build_styles(text)
    elif name == "word/numbering.xml":
        text = build_numbering(text)
    elif name == "word/settings.xml":
        text = sub1(
            r'(<w:defaultTabStop w:val="720" />)',
            '<w:defaultTabStop w:val="720" />'
            '<w:autoHyphenation w:val="true"/><w:hyphenationZone w:val="425"/>',
            text,
            "autoHyphenation",
        )
        text = sub1(r"<w:rsids>", COMPAT + "<w:rsids>", text, "compat")
    elif name == "word/fontTable.xml":
        for font in ("Aptos", "Aptos Display"):
            text = sub1(
                f'<w:font w:name="{font}">',
                f'<w:font w:name="{font}"><w:altName w:val="Calibri"/>',
                text,
                f"altName {font}",
            )
    elif name == "word/theme/theme1.xml":
        text = sub1(
            r'<a:latin typeface="Aptos Display"',
            '<a:latin typeface="Aptos"',
            text,
            "theme major font",
        )
    return text.encode("utf-8")


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT
    reference = subprocess.run(
        ["quarto", "pandoc", "--print-default-data-file", "reference.docx"],
        check=True,
        capture_output=True,
    ).stdout

    with (
        zipfile.ZipFile(io.BytesIO(reference)) as zin,
        zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zout,
    ):
        names = zin.namelist()
        ordered = ["[Content_Types].xml"] + [n for n in names if n != "[Content_Types].xml"]
        for name in ordered:
            zout.writestr(name, transform(name, zin.read(name)))
        zout.writestr("word/footer1.xml", FOOTER.encode("utf-8"))

    print(f"wrote {out} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
