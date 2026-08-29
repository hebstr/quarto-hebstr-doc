#!/usr/bin/env bash

# Asserts that the `anx` crossref type survives a real `quarto render`.
# The Lua suite proves the filter retypes a float handed to it; it cannot prove
# the float ever reaches the filter. Two upstream behaviours stand in between,
# both undocumented: the knitr engine builds a float only from a label matching
# ^#?(fig|tbl)-, which is why the carrier prefix exists, and the FloatRefTarget
# node is mutable at pre-quarto and nowhere later.
# The probe is staged at the repo root because extension lookup does not walk
# up out of `tests/` in the absence of a `_quarto.yml`.

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
probe=${repo_root}/tests/anx-float-probe.qmd
staged=${repo_root}/anx-float-probe.qmd
rendered=${repo_root}/anx-float-probe.html

cleanup() {
  rm -rf -- "$staged" "$rendered" "${repo_root}/anx-float-probe_files"
}
trap cleanup EXIT

cp -- "$probe" "$staged"
quarto render "$staged" --to hebstr-doc-html --quiet

checks=0
failures=0

assert() {
  local mode=$1 needle=$2 why=$3
  checks=$((checks + 1))
  if grep -qF -- "$needle" "$rendered"; then
    found=yes
  else
    found=no
  fi
  if [ "$found" = "$mode" ]; then
    printf 'ok    %s\n' "$why"
  else
    printf 'FAIL  %s: expected %s to be %s\n' "$why" "$needle" \
      "$([ "$mode" = yes ] && printf present || printf absent)" >&2
    failures=$((failures + 1))
  fi
}

# Quarto joins the caption prefix to the number with a non-breaking space.
nbsp=$' '

assert yes 'id="anx-demo"' 'a tbl- carrier loses its prefix'
assert yes 'id="anx-plot"' 'a fig- carrier loses its prefix'
assert yes 'id="anx-manual"' 'a hand-written div keeps its identifier'
assert no 'id="tbl-anx-' 'no carrier identifier survives into the output'
assert no 'id="fig-anx-' 'no carrier identifier survives into the output'

assert yes 'quarto-float quarto-float-anx' 'the float carries the custom type, not tbl or fig'
assert yes "Annexe${nbsp}1. A table annexe." 'the table annexe opens the sequence'
assert yes "Annexe${nbsp}2. A figure annexe." 'the figure annexe shares the counter'
assert yes "Annexe${nbsp}3. A hand-written annexe." 'the hand-written div shares it too'
assert yes "class=\"quarto-xref\">Annexe${nbsp}1</a>" 'a @anx- reference resolves'

if [ "$failures" -ne 0 ]; then
  printf '\n%s of %s assertions failed. The extension rendered, so the float\n' "$failures" "$checks" >&2
  printf 'reached neither the custom crossref type nor its own counter.\n' >&2
  exit 1
fi

printf '\n%s assertions passed.\n' "$checks"
