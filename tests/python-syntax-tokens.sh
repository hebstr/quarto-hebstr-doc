#!/usr/bin/env bash

# Asserts the Python token classes the bundled syntax definition exists to
# produce. It has to go through a real `quarto render`: the one failure mode of
# this wiring is a future Quarto shipping its own python.xml, which would be
# appended after the document's and win the last-wins list while the render
# still exits 0, and repeated `--syntax-definition` flags invert that ordering,
# so a `quarto pandoc` spike passes whatever the render does.
# The probe is staged at the repo root because extension lookup does not walk
# up out of `tests/` in the absence of a `_quarto.yml`.

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
probe=${repo_root}/tests/python-syntax-probe.qmd
staged=${repo_root}/python-syntax-probe.qmd
rendered=${repo_root}/python-syntax-probe.html
render_log=$(mktemp)

cleanup() {
  rm -rf -- "$staged" "$rendered" "$render_log" "${repo_root}/python-syntax-probe_files"
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

assert yes '```python' 'the probe still holds a markdown fence rather than an executable chunk' "$staged"

# The fourteen conditions pandoc's own definition cannot satisfy: a Quarto that
# started shipping python.xml would redden all fourteen at once.
assert_token im 'def' 'def leaves the keyword style it shared with class and lambda'
assert_token kw 'import' 'import reads as a keyword rather than as an import token'
assert_token cn 'True' 'a language constant leaves the style it shared with self'
assert_token fu 'width' 'the name a def introduces is tokenised'
assert_token fu 'read_csv' 'a non-builtin call is tokenised'
assert_token fu '@cache' 'a decorator carries the function style'
assert_token op ',' 'the argument separator is tokenised'
assert_token op '.' 'the attribute separator is tokenised'
assert_token re 'MAX_ROWS' 'an ALL_CAPS name is tokenised'
assert_token op 'is' 'a logical operator leaves the keyword style'
assert_token op 'in' 'in reads as an operator where it compares'
assert_token cf 'in' 'in keeps the flow style in a for header'
assert_token kw 'TODO' 'a codetag leaves the comment colour for the keyword style'
assert_token bu 'ValueError' 'an exception name carries the builtin style'

assert_token va 'self' 'self keeps the variable style the constants left'
assert no 'class="im">import' 'the import keyword no longer carries the namespace gold'
assert no 'class="kw">is' 'a logical operator no longer reads as a keyword'
assert no 'class="pp">ValueError' 'an exception name no longer carries the preprocessor style'

# The three classes the theme's own groupings exist to colour, each emitted by
# the upstream base rather than by a change of this fork.
assert_token vs 'r&quot;' 'a raw string carries the verbatim-string class the theme styles'
assert_token bn '0xFF' 'a hexadecimal literal carries the base-N class the theme styles'
assert_token ch '\n' 'a string escape carries the char class the theme styles'

assert yes '<code class="sourceCode python">' 'the basename keeps the emitted language name'

checks=$((render_checks + source_checks))
failures=$((render_failures + source_failures))

if [ "$failures" -ne 0 ]; then
  if [ "$source_failures" -ne 0 ]; then
    printf '\n%s of %s assertions failed, %s of them on the probe source: it no\n' \
      "$failures" "$checks" "$source_failures" >&2
    printf 'longer carries the authoring form the other conditions rest on.\n' >&2
  else
    printf '\n%s of %s render assertions failed. Read each FAIL line: the fourteen\n' \
      "$render_failures" "$render_checks" >&2
    printf "fork conditions wrong at once means Quarto now ships a python.xml of\n" >&2
    printf 'its own and won the last-wins list, where one or two mean a rule of\n' >&2
    printf 'syntax/python.xml, or of the upstream base it tracks, regressed.\n' >&2
  fi
  exit 1
fi

printf '\n%s assertions passed.\n' "$checks"
