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
FACES = [
    ('"Luciole"', "400", "Luciole-Regular.woff2"),
    ('"Luciole"', "700", "Luciole-Bold.woff2"),
]
FONTS = "_extensions/hebstr-doc/fonts"
EXPECTED = [(family, weight) for family, weight, _ in FACES]

SETUP_CHUNK = re.compile(r"^```\{[^}]*\}\n(.*?)^```", re.M | re.S)
SETUP_LABEL = re.compile(r"^#\|\s*label:\s*setup\s*$", re.M)
SETUP_DISABLED = re.compile(r"^#\|\s*eval:\s*false\s*$", re.M)
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

fonts = Path(__file__).resolve().parent.parent / FONTS
owed = {
    f"{family} {weight}": (
        filename,
        base64.b64encode((fonts / filename).read_bytes()).decode("ascii"),
    )
    for family, weight, filename in FACES
    if (fonts / filename).is_file()
}
absent = [filename for _, _, filename in FACES if not (fonts / filename).is_file()]
if absent:
    source_failures.append(f"the extension no longer ships {absent}")

setup = next((b for b in SETUP_CHUNK.findall(source) if SETUP_LABEL.search(b)), None)
if setup is None:
    source_failures.append("the source carries no chunk labelled setup")
elif not any(line.lstrip().startswith(SOURCE_CALL) for line in setup.splitlines()):
    source_failures.append(f"the setup chunk no longer runs {SOURCE_CALL}")
elif SETUP_DISABLED.search(setup):
    source_failures.append("the setup chunk carries eval: false")

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

    if [(f, w) for f, w, _ in faces] != EXPECTED:
        render_failures.append(
            f"figure {n} embeds {[(f, w) for f, w, _ in faces]}, expected {EXPECTED}"
        )

    payload_problems = []
    for family, weight, payloads in faces:
        face = owed.get(f"{family} {weight}")
        if len(payloads) != 1:
            payload_problems.append(f"{family} {weight} carries {len(payloads)} woff2 data URIs")
        elif face is not None and payloads[0] != face[1]:
            payload_problems.append(
                f"{family} {weight} carries {len(payloads[0])} characters that are not {face[0]}"
            )
    if payload_problems:
        render_failures.append(f"figure {n}: " + ", ".join(payload_problems))

    embedded = {f for f, _, _ in faces}
    families = {f.strip() for f in FAMILY.findall(svg)}
    if not families <= embedded:
        render_failures.append(
            f"figure {n} names {sorted(families - embedded)} with no face embedded"
        )


source_checks = 2
render_checks = 1 + 3 * FIGURES
failures = source_failures + render_failures

if failures:
    print("FAIL  " + "\nFAIL  ".join(failures), file=sys.stderr)
    if source_failures:
        print(
            f"\n      {len(failures)} of {source_checks + render_checks} assertions failed,"
            f" {len(source_failures)} of them on the source: the\n"
            "      setup chunk no longer runs fonts/register.R, or the extension no longer"
            "\n      ships a face it embeds. The first is the production failure"
            " of 2026-08-01 itself.",
            file=sys.stderr,
        )
    elif not figures:
        print(
            f"\n      no figure was read at all, so {render_checks - 1} of {render_checks}"
            " render assertions never\n      ran. Either the"
            ' `<img src="data:image/svg+xml;base64,` shape of an inlined\n'
            "      figure moved, or the document stopped drawing through the svglite device"
            "\n      the format sets.",
            file=sys.stderr,
        )
    else:
        print(
            f"\n      {len(render_failures)} of {render_checks} render assertions failed."
            " Read each FAIL line: every\n"
            "      figure missing both faces means the setup chunk no longer runs or the"
            "\n      knitr `dev` hook no longer fires, one figure missing them means that"
            "\n      chunk's own options, a payload that is not the file it names means the"
            "\n      data URI of fonts/register.R moved, and a family with no face behind it"
            "\n      means the registration did not reach the device.",
            file=sys.stderr,
        )
    sys.exit(1)

print(
    f"ok    {len(figures)} figures each embedding {len(FACES)} woff2 faces,"
    " every family embedded, and the source still sourcing register.R"
)
