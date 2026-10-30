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
render_log=$(mktemp)

cleanup() {
  rm -rf -- "$staged" "$rendered" "$render_log" "${repo_root}/anx-float-probe_files"
}
trap cleanup EXIT

cp -- "$probe" "$staged"

# The render output goes to a log rather than to the terminal, and `--quiet` is
# not passed: under that flag a failing render prints nothing at all, and a Lua
# error raised late in a filter prints an ERROR line while still exiting 0.
if ! quarto render "$staged" --to hebstr-doc-html >"$render_log" 2>&1; then
  cat -- "$render_log" >&2
  printf 'FAIL  the probe did not render\n' >&2
  exit 1
fi
if grep -q 'ERROR' "$render_log"; then
  cat -- "$render_log" >&2
  printf 'FAIL  the render reported an error and exited 0 anyway\n' >&2
  exit 1
fi

render_checks=0
render_failures=0
source_checks=0
source_failures=0

# A fourth argument reads the staged source instead of the rendered output.
# The two groups are counted apart so the epilogue can tell a probe that no
# longer carries the shape asserted from a property of the render that moved.
assert() {
  local mode=$1 needle=$2 why=$3 file=${4:-$rendered} found
  if [ "$file" = "$rendered" ]; then
    render_checks=$((render_checks + 1))
  else
    source_checks=$((source_checks + 1))
  fi
  if grep -qF -- "$needle" "$file"; then
    found=yes
  else
    found=no
  fi
  if [ "$found" = "$mode" ]; then
    printf 'ok    %s\n' "$why"
  else
    printf 'FAIL  %s: expected %s to be %s\n' "$why" "$needle" \
      "$([ "$mode" = yes ] && printf present || printf absent)" >&2
    if [ "$file" = "$rendered" ]; then
      render_failures=$((render_failures + 1))
    else
      source_failures=$((source_failures + 1))
    fi
  fi
}

# A count rather than a presence, where one of the three annexes answering is
# what a lost filter looks like: the hand-written form needs no filter at all.
assert_count() {
  local needle=$1 want=$2 why=$3 got
  render_checks=$((render_checks + 1))
  got=$(grep -oF -- "$needle" "$rendered" | wc -l) || got=0
  if [ "$got" -eq "$want" ]; then
    printf 'ok    %s\n' "$why"
  else
    printf 'FAIL  %s: expected %s occurrences of %s, found %s\n' "$why" "$want" "$needle" "$got" >&2
    render_failures=$((render_failures + 1))
  fi
}

# Quarto joins the caption prefix to the number with a non-breaking space.
nbsp=$'\U000000a0'

assert yes '#| label: tbl-anx-demo' 'the probe still authors its table annexe on a tbl- carrier' "$staged"
assert yes '#| label: fig-anx-plot' 'the probe still authors its figure annexe on a fig- carrier' "$staged"

assert yes 'id="anx-demo"' 'a tbl- carrier loses its prefix'
assert yes 'id="anx-plot"' 'a fig- carrier loses its prefix'
assert yes 'id="anx-manual"' 'a hand-written div keeps its identifier'
assert no 'id="tbl-anx-' 'no tbl- carrier identifier survives into the output'
assert no 'id="fig-anx-' 'no fig- carrier identifier survives into the output'

assert_count 'quarto-float quarto-float-anx' 3 'all three annexes carry the custom type'
assert no 'quarto-float quarto-float-tbl' 'no annexe falls back to the table type'
assert no 'quarto-float quarto-float-fig' 'no annexe falls back to the figure type'
assert_count 'quarto-float-caption-top' 3 'each annexe caption sits above its content'
assert no 'quarto-float-caption-bottom' 'no annexe caption sits below it'

assert yes "Annexe${nbsp}1. A table annexe." 'the table annexe opens the sequence'
assert yes "Annexe${nbsp}2. A figure annexe." 'the figure annexe shares the counter'
assert yes "Annexe${nbsp}3. A hand-written annexe." 'the hand-written div shares it too'
assert yes "class=\"quarto-xref\">Annexe${nbsp}1</a>" 'a @anx- reference resolves'

checks=$((render_checks + source_checks))
failures=$((render_failures + source_failures))

if [ "$failures" -ne 0 ]; then
  if [ "$source_failures" -ne 0 ]; then
    printf '\n%s of %s assertions failed, %s of them on the probe source: it no\n' \
      "$failures" "$checks" "$source_failures" >&2
    printf 'longer carries the authoring form the other conditions rest on.\n' >&2
  else
    printf '\n%s of %s render assertions failed. Read each FAIL line: the carriers\n' \
      "$render_failures" "$render_checks" >&2
    printf 'and the captions failing together means the float reached neither the\n' >&2
    printf 'custom crossref type nor its own counter, where a condition or two\n' >&2
    printf 'means one property of that type moved.\n' >&2
  fi
  exit 1
fi

printf '\n%s assertions passed.\n' "$checks"
