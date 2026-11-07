#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_qmd=${repo_root}/example.qmd
rendered=${repo_root}/fonts-svg-probe.html
render_log=$(mktemp)

keep=
cleanup() {
  rm -f -- "$render_log"
  if [ "$keep" = "" ]; then
    rm -f -- "$rendered"
  fi
}
trap cleanup EXIT

if ! quarto render "$source_qmd" --to hebstr-doc-html \
  --output "$(basename -- "$rendered")" >"$render_log" 2>&1; then
  cat -- "$render_log" >&2
  printf 'FAIL  example.qmd did not render\n' >&2
  exit 1
fi
if grep -q 'ERROR' "$render_log"; then
  cat -- "$render_log" >&2
  printf 'FAIL  the render reported an error and exited 0 anyway\n' >&2
  exit 1
fi

python3 "${repo_root}/tests/fonts-svg-assert.py" "$rendered" "$source_qmd" || {
  rc=$?
  keep=1
  printf 'FAIL  the rendered output is kept at %s\n' "$rendered" >&2
  exit "$rc"
}
