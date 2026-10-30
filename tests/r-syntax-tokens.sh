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
render_log=$(mktemp)

cleanup() {
  rm -rf -- "$staged" "$rendered" "$render_log" "${repo_root}/r-syntax-probe_files"
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

# Prefix match rather than a full span: skylighting merges adjacent characters
# that share a class, so a closing `))` arrives as one span.
assert_token() {
  local class=$1 text=$2 why=$3
  render_checks=$((render_checks + 1))
  if grep -qF -- "class=\"${class}\">${text}" "$rendered"; then
    printf 'ok    %s\n' "$why"
  else
    printf 'FAIL  %s: expected class="%s" on %s\n' "$why" "$class" "$text" >&2
    render_failures=$((render_failures + 1))
  fi
}

# A fourth argument reads the staged source instead of the rendered output.
# The two groups are counted apart so the epilogue can tell a probe that no
# longer carries the shape asserted from a rule of the definition that moved.
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

assert yes '```r' 'the probe still holds a markdown fence rather than an executable chunk' "$staged"

assert_token kw library 'library reads as a keyword, not an ordinary call'
assert_token im dplyr 'the package name in front of :: carries a namespace token'
assert_token dt L 'the suffix of an integer literal is tokenised'
assert_token sc ':=' ':= is one operator, not a colon followed by an error'
assert_token sc ',' 'the argument separator is tokenised'
assert_token ot '=' 'the = of a named argument leaves the argument name its own token'
assert_token re '(' 'brackets carry a class a stylesheet can reach'
assert_token sc '==' 'an equality is one operator, not a named argument'
assert no 'class="at">x' 'the left operand of == keeps its own token'

assert yes '<code class="sourceCode r">' 'the fork keeps the language name out of the code element'
assert yes 'data-filename="r"' 'code-window reads the block as R, not as the synthetic class'
assert no 'data-filename="rhebstr"' 'the synthetic class reaches no Quarto stage that reads the language'

checks=$((render_checks + source_checks))
failures=$((render_failures + source_failures))

if [ "$failures" -ne 0 ]; then
  if [ "$source_failures" -ne 0 ]; then
    printf '\n%s of %s assertions failed, %s of them on the probe source: it no\n' \
      "$failures" "$checks" "$source_failures" >&2
    printf 'longer carries the authoring form the other conditions rest on.\n' >&2
  else
    printf '\n%s of %s render assertions failed. Read each FAIL line: most of the\n' \
      "$render_failures" "$render_checks" >&2
    printf "token classes wrong at once means Quarto's own r.xml won the last-wins\n" >&2
    printf 'list or the rhebstr class is no longer prepended, where one or two mean\n' >&2
    printf 'a rule of syntax/r.xml, or of the upstream base it tracks, regressed.\n' >&2
  fi
  exit 1
fi

printf '\n%s assertions passed.\n' "$checks"
