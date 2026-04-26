# Changelog

## [0.10.0] — 2026-04-26

### Added

- `README.md`, `LICENSE.md` (MIT), `.gitignore`.
- Self-contained `example.qmd` (HTML; Typst and DOCX planned), plus
  `scripts/demo_penguins.R` for the externalised-script demo.
- Bundled font licences (Luciole CC-BY 4.0, Fira Code OFL 1.1).
- Embedded [`mcanouil/code-window`](https://github.com/mcanouil/quarto-code-window)
  (HTML + Typst).
- `script` shortcode (`filters/add-code-files.lua`): one-liner `{{< script path/to/file.R >}}`
  for injecting external scripts. Auto-derives `source-lang` from extension,
  defaults `code-filename` to the path, line numbers on by default. Args:
  `lang=`, `filename=`, `numbers=`, `lines=10-30`, `dedent=N`. The shortcode
  reads the file itself and emits the populated CodeBlock with `cell-code`
  class (so Quarto's `code-fold` wraps it in `<details>`) plus the `cw-auto`
  + `filename` attributes that hand off to `code-window`'s JS for the chrome.
  Registers `filters/add-code-files.js` (derived from
  [`shafayetShafee/add-code-files`](https://github.com/shafayetShafee/add-code-files),
  MIT) via `quarto.doc.add_html_dependency` to rewrite the foldable `<summary>`
  text with the filename.
- SCSS custom properties for code-window chrome and surface/caption colours.

### Changed

- **Breaking**: extension renamed `hebstr-template` → `hebstr`; resource layout
  flattened (`template.typ`, `code.tmTheme`, `template.dotx` at extension root,
  fonts under `fonts/`); Typst raw theme path fixed accordingly.
- **Breaking**: `lang` and `published-title` removed from `common:` — consumers
  declare their own language.
- `quarto-required` bumped to `>=1.9.36` (matches the embedded `mcanouil/code-window` 1.1.5); `tbl-title` neutralised to `"Table"`.
- HTML: `page-layout: full`, wider `gutter-width`, `code-copy: always`.
- Theme: code-filename block restyled to match code-window; system font
  fallbacks added with `!default` for consumer overrides; code-highlight
  palette switched from purple to dark grey to match the code-window chrome.
- Font licence files renamed `LICENSE-Luciole.md` → `Luciole.LICENSE` and
  `LICENSE-FiraCode.md` → `FiraCode.LICENSE` (alignment with
  `filters/add-code-file.LICENSE`).

### Removed

- `filters/resources/add-code-files.css`: all rules were already shadowed by
  `theme.scss` (`body div[data-code-filename] { … }`); the inlined filter
  registers only the JS dependency.

## [0.9.0] — 2026-04-24

### Added

- Multi-format Quarto extension (`hebstr-html`, `hebstr-typst`, `hebstr-docx`)
  via a shared `common:` block.
- HTML theme (Bootstrap/Bootswatch SCSS), Typst preamble, DOCX reference doc,
  Luciole and Fira Code fonts.
