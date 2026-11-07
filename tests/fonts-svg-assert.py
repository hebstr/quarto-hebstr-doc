#!/usr/bin/env python3
"""Assert on a rendered example.html the fonts fonts/register.R owes a reader.

The figures are inlined as `data:image/svg+xml;base64` under the format's
`embed-resources`, so every render-side condition decodes a data URI rather than
matching the markup: no grep reads those SVGs. A figure is recognised as the `src`
of an `<img>` and never as a bare data URI, the same `embed-resources` inlining the
code-window language icons into the stylesheet the same way. The fallback-name
condition is scoped to the decoded SVG for a mirror reason, Bootstrap's own font
stack naming two of the names and base64 payloads carrying them by chance.

The source-side condition is what the render cannot see: the one production
failure of this file was example.qmd not sourcing it, and a probe sourcing it
itself would have stayed green through that.

Usage: python3 tests/fonts-svg-assert.py <rendered.html> <source.qmd>
"""

import base64
import re
import sys
from pathlib import Path

SOURCE_CALL = 'source("_extensions/hebstr-doc/fonts/register.R")'
FIGURES = 4
FACES = [('"Luciole"', "400"), ('"Luciole"', "700")]
PAYLOAD_FLOOR = 1000
ALLOWED = {'"Luciole"', '"Fira Code"'}
FALLBACKS = ("Liberation", "DejaVu", "Nimbus", "Noto", "Arial", "Helvetica", "sans-serif")

URI = re.compile(r'<img[^>]*\bsrc="data:image/svg\+xml;base64,([A-Za-z0-9+/=]+)"')
FACE = re.compile(r"@font-face\s*\{[^}]*\}")
FAMILY = re.compile(r"font-family:\s*([^;}]*)")
WEIGHT = re.compile(r"font-weight:\s*([^;}]*)")
WOFF2 = re.compile(r'url\("data:font/woff2;base64,([^"]*)"\)')

if len(sys.argv) != 3:
    print(__doc__, file=sys.stderr)
    sys.exit(2)

rendered = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
source = Path(sys.argv[2]).read_text(encoding="utf-8")

source_failures = []
render_failures = []

if SOURCE_CALL not in source:
    source_failures.append(f"the source no longer carries {SOURCE_CALL}")

figures = []
for payload in URI.findall(rendered):
    try:
        figures.append(base64.b64decode(payload).decode("utf-8", "replace"))
    except (ValueError, TypeError) as exc:
        render_failures.append(f"an inlined figure did not decode: {exc}")

if len(figures) != FIGURES:
    render_failures.append(f"{len(figures)} inlined figures, expected {FIGURES}")

for n, svg in enumerate(figures):
    faces = []
    for block in FACE.findall(svg):
        family = FAMILY.search(block)
        weight = WEIGHT.search(block)
        faces.append(
            (
                family.group(1).strip() if family else None,
                weight.group(1).strip() if weight else None,
                WOFF2.findall(block),
            )
        )

    if [(f, w) for f, w, _ in faces] != FACES:
        render_failures.append(
            f"figure {n} embeds {[(f, w) for f, w, _ in faces]}, expected {FACES}"
        )

    for family, weight, payloads in faces:
        if len(payloads) != 1:
            render_failures.append(
                f"figure {n}: {family} {weight} carries {len(payloads)} woff2 data URIs"
            )
        elif len(payloads[0]) < PAYLOAD_FLOOR:
            render_failures.append(
                f"figure {n}: {family} {weight} carries a {len(payloads[0])}-byte payload"
            )

    families = {f.strip() for f in FAMILY.findall(svg)}
    if not families <= ALLOWED:
        render_failures.append(f"figure {n} names {sorted(families - ALLOWED)}")

    fallbacks = [name for name in FALLBACKS if name in svg]
    if fallbacks:
        render_failures.append(f"figure {n} carries the fallback name {fallbacks}")

checks = 1 + 1 + 4 * len(figures)
failures = source_failures + render_failures

if failures:
    print("FAIL  " + "\nFAIL  ".join(failures), file=sys.stderr)
    if source_failures:
        print(
            f"\n      {len(failures)} of {checks} assertions failed,"
            f" {len(source_failures)} of them on the source: it no longer\n"
            "      sources fonts/register.R, which is the production failure"
            " of 2026-08-01 itself.",
            file=sys.stderr,
        )
    else:
        print(
            f"\n      {len(render_failures)} of {checks} render assertions failed."
            " Read each FAIL line: a figure\n"
            "      embedding nothing means the knitr `dev` hook no longer fires or was"
            " replaced,\n      a payload or a format means the data URI of"
            " fonts/register.R moved, and a\n      fallback name means the"
            " registration did not reach the device.",
            file=sys.stderr,
        )
    sys.exit(1)

print(
    f"ok    {len(figures)} figures each embedding {len(FACES)} woff2 faces,"
    " every family theirs, no fallback name, and the source still sourcing register.R"
)
