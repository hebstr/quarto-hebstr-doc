#!/usr/bin/env bash

# Asserts that the light and dark figure pairing survives a real `quarto render`.
# The Lua suite proves the filter pairs an Image handed to it; it cannot prove
# the Image Quarto hands a post-quarto filter, inside a sub-captioned layout,
# still carries a `src` the twin can be looked up from, nor that the pair keeps
# one numbered figure and its cross-reference.
# The probe is staged at the repo root because extension lookup does not walk
# up out of `tests/` in the absence of a `_quarto.yml`.
# Quarto runs pandoc from the document's own directory, so a twin looked up
# against the cwd passes here too: only the Lua suite tells the two apart.
# That staging also puts the document at the project root, where a path relative
# to the root and one relative to the document are the same path. A second
# scenario stages a throwaway project with the document one level down and the
# figure written relative to the root, the shape of a project that renders with
# `execute-dir: project`, which the first scenario cannot tell from a document at
# the root.

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
probe=${repo_root}/tests/figure-pair-probe.qmd
staged=${repo_root}/figure-pair-probe.qmd
rendered=${repo_root}/figure-pair-probe.html
project_probe=${repo_root}/tests/figure-pair-project-probe.qmd
project=${repo_root}/figure-pair-project
render_log=$(mktemp)

cleanup() {
  rm -rf -- "$staged" "$rendered" "$render_log" "${repo_root}/figure-pair-probe_files" "$project"
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

checks=0
failures=0

assert_count() {
  local pattern=$1 want=$2 why=$3 got
  checks=$((checks + 1))
  got=$(grep -oE -- "$pattern" "$rendered" | wc -l) || got=0
  if [ "$got" -eq "$want" ]; then
    printf 'ok    %s\n' "$why"
  else
    printf 'FAIL  %s: expected %s occurrences of %s, found %s\n' "$why" "$want" "$pattern" "$got" >&2
    failures=$((failures + 1))
  fi
}

assert_count '<figure[ >]' 5 'the pairing adds no figure: the two-panel float, its two panels and the two other floats make five'
assert_count 'class="light-content ' 3 'each paired image carries light-content'
assert_count 'class="dark-content ' 3 'each paired image gets a dark-content twin'
assert_count 'class="img-fluid figure-img"' 1 'the figure with no dark twin is left untouched'
assert_count '\?@fig' 0 'no cross-reference is left unresolved'
assert_count 'class="quarto-xref">Figure' 3 'the three references resolve'
assert_count 'style="width:50.0%"' 4 'out.width reaches the two panels and their twins'
assert_count '<img [^>]*data-ref-parent="fig-two"' 4 'the sub-captioned layout keeps its four images under fig-two'

mkdir -p -- "${project}/sub" "${project}/out"
ln -s -- ../_extensions "${project}/_extensions"
cp -- "${repo_root}"/tests/fixtures/figure-pair/a-light.svg "${repo_root}"/tests/fixtures/figure-pair/a-dark.svg "${project}/out/"
printf 'project:\n  type: default\n  execute-dir: project\n' >"${project}/_quarto.yml"
printf 'resource-path:\n  - ..\n' >"${project}/sub/_metadata.yml"
cp -- "$project_probe" "${project}/sub/probe.qmd"

if ! (cd -- "$project" && quarto render sub/probe.qmd --to hebstr-doc-html) >"$render_log" 2>&1; then
  cat -- "$render_log" >&2
  printf 'FAIL  the project probe did not render\n' >&2
  exit 1
fi
if grep -q 'ERROR' "$render_log"; then
  cat -- "$render_log" >&2
  printf 'FAIL  the project render reported an error and exited 0 anyway\n' >&2
  exit 1
fi

rendered=${project}/sub/probe.html
assert_count '<img [^>]*light-content' 1 'a root-relative figure in a subdirectory document carries light-content'
assert_count '<img [^>]*dark-content' 1 'and gets its dark-content twin'
assert_count '\?@fig' 0 'the project render leaves no cross-reference unresolved'

if [ "$failures" -ne 0 ]; then
  printf '\n%s of %s assertions failed.\n' "$failures" "$checks" >&2
  exit 1
fi

printf '\n%s assertions passed.\n' "$checks"
