#!/usr/bin/env bash

# Asserts that a raw OOXML table leaves no table cell open in a real
# `quarto render`.
# Word requires the last block-level element of a `w:tc` to be a `w:p` and
# refuses to open a document where one is missing, naming no usable location;
# LibreOffice converts the same file without complaint, so no render on a Linux
# machine reports the breach. The Lua suite proves the filter appends the
# paragraph to a block handed to it; it cannot prove the block ever reaches the
# filter, the wiring under `docx:` and the `post-quarto` stage both standing in
# between, and it loads the filter by its own hardcoded path.
# The probe is staged at the repo root because extension lookup does not walk
# up out of `tests/` in the absence of a `_quarto.yml`.

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

# python3 is preinstalled on ubuntu-latest. The rule is structural rather than
# lexical, a cell being able to end on a table nested at any depth, so it is
# read off the parsed tree rather than matched on the markup.
python3 - "$rendered" <<'PY'
import sys
import zipfile
import xml.etree.ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"

root = ET.fromstring(zipfile.ZipFile(sys.argv[1]).read("word/document.xml"))
tables = len(list(root.iter(W + "tbl")))
open_cells = [
    tc
    for tc in root.iter(W + "tc")
    if (blocks := [k for k in tc if k.tag in (W + "p", W + "tbl")])
    and blocks[-1].tag != W + "p"
]

if not tables:
    print("FAIL  the probe rendered no table at all, so it asserts nothing", file=sys.stderr)
    sys.exit(1)

if open_cells:
    print(
        f"FAIL  {len(open_cells)} of {tables} w:tbl leave a w:tc ending on a table.\n"
        "Word refuses such a document with \"an ambiguous cell mapping was\n"
        "encountered\". The raw OOXML block no longer reaches\n"
        "filters/docx-cell-paragraph.lua, or no longer matches its anchor.",
        file=sys.stderr,
    )
    sys.exit(1)

print(f"ok    {tables} w:tbl, every w:tc closed by a w:p")
PY
