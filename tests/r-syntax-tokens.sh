#!/usr/bin/env bash

# Asserts the R token classes the bundled syntax definition exists to produce.
# It has to go through a real `quarto render`: the definition only prevails
# because Quarto appends its own copy after the document's and that list is
# last-wins, an ordering repeated `--syntax-definition` flags invert, so a
# `quarto pandoc` spike passes whatever the render does.
# The probe is staged at the repo root because extension lookup does not walk
# up out of `tests/` in the absence of a `_quarto.yml`.

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
probe=${repo_root}/tests/r-syntax-probe.qmd
staged=${repo_root}/r-syntax-probe.qmd
rendered=${repo_root}/r-syntax-probe.html

cleanup() {
  rm -rf -- "$staged" "$rendered" "${repo_root}/r-syntax-probe_files"
}
trap cleanup EXIT

cp -- "$probe" "$staged"
quarto render "$staged" --to hebstr-doc-html --quiet

checks=0
failures=0

# Prefix match rather than a full span: skylighting merges adjacent characters
# that share a class, so a closing `))` arrives as one span.
assert_token() {
  local class=$1 text=$2 why=$3
  checks=$((checks + 1))
  if grep -qF -- "class=\"${class}\">${text}" "$rendered"; then
    printf 'ok    %s\n' "$why"
  else
    printf 'FAIL  %s: expected class="%s" on %s\n' "$why" "$class" "$text" >&2
    failures=$((failures + 1))
  fi
}

assert_token kw library 'library reads as a keyword, not an ordinary call'
assert_token im dplyr 'the package name in front of :: carries a namespace token'
assert_token dt L 'the suffix of an integer literal is tokenised'
assert_token sc ':=' ':= is one operator, not a colon followed by an error'
assert_token sc ',' 'the argument separator is tokenised'
assert_token ot '=' 'the = of a named argument leaves the argument name its own token'
assert_token re '(' 'brackets carry a class a stylesheet can reach'

if [ "$failures" -ne 0 ]; then
  printf '\n%s of %s assertions failed. The extension rendered, so the R blocks\n' "$failures" "$checks" >&2
  printf "reached Quarto's own r.xml instead of syntax/r.xml.\n" >&2
  exit 1
fi

printf '\n%s assertions passed.\n' "$checks"
