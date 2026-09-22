#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
probe=${repo_root}/tests/docx-cell-probe.qmd
staged=${repo_root}/docx-cell-probe.qmd
rendered=${repo_root}/docx-cell-probe.docx

cleanup() {
  rm -rf -- "$staged" "$rendered" "${repo_root}/docx-cell-probe_files"
}
trap cleanup EXIT

cp -- "$probe" "$staged"
quarto render "$staged" --to hebstr-doc-docx --quiet

python3 - "$rendered" <<'PY'
import sys
import zipfile
import xml.etree.ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"


def is_closing_paragraph(p):
    size = p.find(f"{W}pPr/{W}rPr/{W}sz")
    return size is not None and size.get(W + "val") == "2" and not list(p.iter(W + "t"))


root = ET.fromstring(zipfile.ZipFile(sys.argv[1]).read("word/document.xml"))
closed = 0
open_cells = 0
for tc in root.iter(W + "tc"):
    blocks = [k for k in tc if k.tag in (W + "p", W + "tbl")]
    if not blocks:
        continue
    if blocks[-1].tag != W + "p":
        open_cells += 1
    elif len(blocks) > 1 and blocks[-2].tag == W + "tbl" and is_closing_paragraph(blocks[-1]):
        closed += 1

if open_cells:
    print(
        f"FAIL  {open_cells} w:tc end on a table.\n"
        "Word refuses such a document with \"an ambiguous cell mapping was\n"
        "encountered\". The raw OOXML block no longer reaches\n"
        "filters/docx-cell-paragraph.lua, or no longer matches its anchor.",
        file=sys.stderr,
    )
    sys.exit(1)

if not closed:
    print(
        "FAIL  no w:tc ends on a table closed by the filter's 1 pt paragraph.\n"
        "The probe no longer places a raw table last in a cell, so it no longer\n"
        "exercises filters/docx-cell-paragraph.lua: find a shape that does.",
        file=sys.stderr,
    )
    sys.exit(1)

print(f"ok    {closed} w:tc closed by filters/docx-cell-paragraph.lua, none left open")
PY
