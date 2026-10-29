#!/usr/bin/env bash

# Renders tests/docx-template-probe.qmd to DOCX and hands the output to the two
# assertion scripts: scripts/check-docx.R, which reads what any DOCX owes a
# Word reader, then tests/docx-template-assert.py, which reads what this probe
# owes template.dotx, filters/docx-caption.lua, filters/docx-list-style.lua,
# filters/docx-layout-flatten.lua, filters/docx-callout-flatten.lua,
# filters/docx-cell-paragraph.lua and filters/docx-toc-break.lua.
# The Lua suite proves the filter restyles a caption handed to it; it cannot
# prove a caption ever reaches it. That rests on two undocumented Quarto
# behaviours: floats are rendered before the post-render stage, and their
# caption opens on a raw `<w:pPr>` naming `ImageCaption`. A change to either
# leaves the render green while every caption falls back to that raw paragraph.
# The probe is staged at the repo root because extension lookup does not walk
# up out of `tests/` in the absence of a `_quarto.yml`, and it is handed to the
# python assertions too, one condition reading the probe's own shape.

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
python3 "${repo_root}/tests/docx-template-assert.py" "$rendered" "$staged"
