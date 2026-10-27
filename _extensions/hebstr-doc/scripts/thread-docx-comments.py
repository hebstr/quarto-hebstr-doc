#!/usr/bin/env python3
"""Thread the Word comments of a rendered DOCX, which no writer can do.

`filters/collab-comments.lua` turns every entry of a comment thread into a Word
comment of its own, all anchored on one span: the opening comment's markers come
first and its replies follow in chronological order, opening and closing alike.
Word reads that order as a thread only once the package carries
`word/commentsExtended.xml`, whose `w15:commentEx` elements key on the
`w14:paraId` of a comment's last paragraph, and no AST construct sets a
paragraph attribute. Pandoc has no notion of the part at all, so the linkage can
only be written after the zip is closed.

A consuming project therefore wires this script as a `post-render` entry:

    project:
      post-render:
        - _extensions/hebstr/hebstr-doc/scripts/thread-docx-comments.py

Quarto runs a `.py` entry under `python3` from the project directory and names
the rendered outputs in `QUARTO_PROJECT_OUTPUT_FILES`, or in the file
`QUARTO_USE_FILE_FOR_PROJECT_OUTPUT_FILES` points at. Paths given as arguments
override both, which is how the script is driven by hand.

The threading is derived from the document rather than carried in a sidecar:
consecutive `w:commentRangeStart` elements share one anchor, so the first of
such a run is the thread's opening and the rest are its replies. That is sound
because the filter refuses two distinct comments on one span, under
`overlapping rendered selection`, so an identical anchor can only come from one
thread.

The pass is idempotent: an existing `w14:paraId` is reused, and the part, its
content-type override and its relationship are added only when absent.
"""

import os
import re
import sys
import zipfile
from pathlib import Path
from xml.dom import minidom
from xml.parsers.expat import ExpatError

W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
W14_NS = "http://schemas.microsoft.com/office/word/2010/wordml"
W15_NS = "http://schemas.microsoft.com/office/word/2012/wordml"
MC_NS = "http://schemas.openxmlformats.org/markup-compatibility/2006"

COMMENTS_PART = "word/comments.xml"
DOCUMENT_PART = "word/document.xml"
RELS_PART = "word/_rels/document.xml.rels"
TYPES_PART = "[Content_Types].xml"
EXTENDED_PART = "word/commentsExtended.xml"

EXTENDED_RELATIONSHIP = "http://schemas.microsoft.com/office/2011/relationships/commentsExtended"
EXTENDED_CONTENT_TYPE = (
    "application/vnd.openxmlformats-officedocument.wordprocessingml.commentsExtended+xml"
)

PARA_ID_CEILING = 0x7FFFFFFF


def say(message):
    print(f"[thread-docx-comments] {message}")


def complain(message):
    print(f"[thread-docx-comments] {message}", file=sys.stderr)


def targets(argv):
    """The DOCX outputs to thread, as Quarto names them or as arguments give them."""
    if argv:
        return [Path(value) for value in argv], None
    listing = os.environ.get("QUARTO_USE_FILE_FOR_PROJECT_OUTPUT_FILES")
    if listing:
        raw = Path(listing).read_text(encoding="utf-8")
    else:
        raw = os.environ.get("QUARTO_PROJECT_OUTPUT_FILES")
        if raw is None:
            return None, (
                "no output file to read: pass a .docx path, or wire this script as a "
                "Quarto post-render entry"
            )
    files = [Path(line.strip()) for line in raw.splitlines() if line.strip()]
    return [file for file in files if file.suffix.lower() == ".docx"], None


def prefix_for(root, uri):
    """The prefix the element binds to a namespace, or None when it binds none."""
    attributes = root.attributes
    for index in range(attributes.length):
        attribute = attributes.item(index)
        if attribute.value != uri:
            continue
        if attribute.name == "xmlns":
            return ""
        if attribute.name.startswith("xmlns:"):
            return attribute.name.partition(":")[2]
    return None


def ensure_prefix(root, uri, preferred):
    existing = prefix_for(root, uri)
    if existing:
        return existing
    root.setAttribute(f"xmlns:{preferred}", uri)
    return preferred


def ignore_prefix(root, prefix):
    """Declare a prefix ignorable, as Word does for every extension namespace."""
    marker = prefix_for(root, MC_NS) or ensure_prefix(root, MC_NS, "mc")
    name = f"{marker}:Ignorable"
    tokens = root.getAttribute(name).split()
    if prefix not in tokens:
        tokens.append(prefix)
        root.setAttribute(name, " ".join(tokens))


def element_children(node, tag):
    return [
        child
        for child in node.childNodes
        if child.nodeType == child.ELEMENT_NODE and child.tagName == tag
    ]


def para_id(seed, taken):
    """An 8-hex paragraph identifier, derived from the seed and free in the part."""
    hashed = 0x811C9DC5
    for byte in seed.encode("utf-8"):
        hashed = ((hashed ^ byte) * 0x01000193) & 0xFFFFFFFF
    value = (hashed & PARA_ID_CEILING) or 1
    while f"{value:08X}" in taken:
        value = value % PARA_ID_CEILING + 1
    return f"{value:08X}"


def comment_runs(document, prefix):
    """The comment ids of each run of consecutive `w:commentRangeStart` elements."""
    start_tag = f"{prefix}:commentRangeStart"
    runs = []

    def visit(node):
        run = []
        for child in node.childNodes:
            if child.nodeType != child.ELEMENT_NODE:
                continue
            if child.tagName == start_tag:
                run.append(child.getAttribute(f"{prefix}:id"))
                continue
            if run:
                runs.append(run)
                run = []
            visit(child)
        if run:
            runs.append(run)

    visit(document.documentElement)
    return runs


def parent_of(runs):
    parents = {}
    for run in runs:
        for reply in run[1:]:
            parents[reply] = run[0]
    return parents


def paragraph_ids(comments, prefix, extension):
    """One paraId per comment, on its last paragraph, written when absent."""
    root = comments.documentElement
    taken = set()
    for paragraph in comments.getElementsByTagName(f"{prefix}:p"):
        existing = paragraph.getAttribute(f"{extension}:paraId")
        if existing:
            taken.add(existing)
    identifiers = {}
    for comment in element_children(root, f"{prefix}:comment"):
        identifier = comment.getAttribute(f"{prefix}:id")
        paragraphs = element_children(comment, f"{prefix}:p") or comment.getElementsByTagName(
            f"{prefix}:p"
        )
        if not paragraphs:
            continue
        last = paragraphs[-1]
        value = last.getAttribute(f"{extension}:paraId")
        if not value:
            value = para_id(identifier, taken)
            last.setAttribute(f"{extension}:paraId", value)
        taken.add(value)
        identifiers[identifier] = value
    return identifiers


def extended_part(identifiers, parents):
    pieces = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        f'<w15:commentsEx xmlns:w15="{W15_NS}">',
    ]
    threaded = 0
    for identifier, value in identifiers.items():
        parent = identifiers.get(parents.get(identifier))
        if parent:
            threaded += 1
            pieces.append(
                f'<w15:commentEx w15:paraId="{value}" w15:paraIdParent="{parent}" w15:done="0"/>'
            )
        else:
            pieces.append(f'<w15:commentEx w15:paraId="{value}" w15:done="0"/>')
    pieces.append("</w15:commentsEx>")
    return "".join(pieces).encode("utf-8"), threaded


def ensure_override(types, part_name, content_type):
    for override in types.getElementsByTagName("Override"):
        if override.getAttribute("PartName") == part_name:
            return False
    override = types.createElement("Override")
    override.setAttribute("PartName", part_name)
    override.setAttribute("ContentType", content_type)
    types.documentElement.appendChild(override)
    return True


def ensure_relationship(rels, relationship_type, target):
    highest = 0
    for relationship in rels.getElementsByTagName("Relationship"):
        if (
            relationship.getAttribute("Type") == relationship_type
            and relationship.getAttribute("Target") == target
        ):
            return False
        numbered = re.fullmatch(r"rId(\d+)", relationship.getAttribute("Id"))
        if numbered:
            highest = max(highest, int(numbered.group(1)))
    relationship = rels.createElement("Relationship")
    relationship.setAttribute("Id", f"rId{highest + 1}")
    relationship.setAttribute("Type", relationship_type)
    relationship.setAttribute("Target", target)
    rels.documentElement.appendChild(relationship)
    return True


def rezip(path, parts):
    pending = dict(parts)
    temporary = path.with_name(path.name + ".threading")
    with (
        zipfile.ZipFile(path) as source,
        zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as target,
    ):
        for item in source.infolist():
            replacement = pending.pop(item.filename, None)
            target.writestr(
                item, source.read(item.filename) if replacement is None else replacement
            )
        for name, data in pending.items():
            target.writestr(name, data)
    temporary.replace(path)


def thread(path):
    with zipfile.ZipFile(path) as package:
        names = set(package.namelist())
        if COMMENTS_PART not in names:
            say(f"{path}: no comment part, left unchanged")
            return
        for required in (DOCUMENT_PART, RELS_PART, TYPES_PART):
            if required not in names:
                complain(f"{path}: {required} is missing, left unchanged")
                return
        comments = minidom.parseString(package.read(COMMENTS_PART))
        document = minidom.parseString(package.read(DOCUMENT_PART))
        types = minidom.parseString(package.read(TYPES_PART))
        rels = minidom.parseString(package.read(RELS_PART))

    prefix = prefix_for(comments.documentElement, W_NS)
    document_prefix = prefix_for(document.documentElement, W_NS)
    if not prefix or not document_prefix:
        complain(f"{path}: WordprocessingML is not bound to a prefix, left unchanged")
        return
    extension = ensure_prefix(comments.documentElement, W14_NS, "w14")
    ignore_prefix(comments.documentElement, extension)

    identifiers = paragraph_ids(comments, prefix, extension)
    if not identifiers:
        say(f"{path}: no comment carries a paragraph, left unchanged")
        return
    parents = parent_of(comment_runs(document, document_prefix))
    extended, threaded = extended_part(identifiers, parents)
    ensure_override(types, f"/{EXTENDED_PART}", EXTENDED_CONTENT_TYPE)
    ensure_relationship(rels, EXTENDED_RELATIONSHIP, "commentsExtended.xml")

    rezip(
        path,
        {
            COMMENTS_PART: comments.toxml(encoding="UTF-8"),
            TYPES_PART: types.toxml(encoding="UTF-8"),
            RELS_PART: rels.toxml(encoding="UTF-8"),
            EXTENDED_PART: extended,
        },
    )
    roots = len({parents[reply] for reply in parents if reply in identifiers})
    say(f"{path}: {len(identifiers)} comments, {threaded} threaded under {roots}")


def main():
    files, failure = targets(sys.argv[1:])
    if failure:
        complain(failure)
        return 1
    if not files:
        say("no DOCX among the rendered outputs, nothing to thread")
        return 0
    for path in files:
        if not path.is_file():
            complain(f"{path}: not a file, left unchanged")
            return 1
        try:
            thread(path)
        except (zipfile.BadZipFile, ExpatError, OSError) as error:
            complain(f"{path}: {error}")
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
