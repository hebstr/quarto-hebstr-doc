# Changelog

## [Unreleased]

### Added

- Light/dark theme split. SCSS theme is now a triplet:
  - `theme-base.scss` — invariant defaults (typography, code-window chrome) +
    `:root` block exposing every SCSS variable as a CSS custom property +
    every `scss:rules`.
  - `theme-light.scss` — `scss:defaults` only, light palette.
  - `theme-dark.scss` — `scss:defaults` only, dark palette.
  - Wiring in `_extension.yml` :
    `theme: { light: [theme-light.scss, theme-base.scss], dark: [theme-dark.scss, theme-base.scss] }`.
- New SCSS variables exposed as part of the public theme API:
  `$body-bg`, `$body-color`, `$primary-back`, `$primary-surface`, `$primary-dark`,
  `$figure-shadow`, `$tab-background`, `$str-color`, `$dig-color`,
  `$summary-fold-color`, `$callout-mix-base`, `$callout-text-mix`, `$callout-bg-mix`.
- New custom properties exposed in `:root` for consumer overrides:
  `--str-color`, `--dig-color`, `--figure-shadow`, `--tab-background`,
  `--summary-fold-color`, `--callout-mix-base`, `--callout-text-mix`,
  `--callout-bg-mix`.

### Changed

- **Breaking** if a consumer overrides `theme.scss` directly:
  the file no longer exists. Consumers must reference
  `[theme-light.scss, theme-base.scss]` (or rely on `format: hebstr-html`,
  which already wires the pair).
- Callout color-mixes now use `--callout-mix-base` / `--callout-text-mix` /
  `--callout-bg-mix` instead of hardcoded `white` / `black` / `97%` literals.
- `.str` and `.dig` foreground colors moved from rule-level literals to
  `--str-color` / `--dig-color` so they switch with the active theme.

## [0.10.0] — 2026-04-26

### Added

- `README.md`, `LICENSE.md` (MIT), `.gitignore`.
- Self-contained `example.qmd` (HTML; Typst and DOCX planned), plus
  `scripts/demo_penguins.R` for the externalised-script demo.
- Bundled font licences (Luciole CC-BY 4.0, Fira Code OFL 1.1).
- Embedded [`mcanouil/code-window`](https://github.com/mcanouil/quarto-code-window)
  (HTML + Typst).
- `script` shortcode (`filters/add-code-files.lua`): one-liner `{{< script path/to/file.R >}}`
  for injecting external scripts. Auto-derives `source-lang` from extension
  (or basename for dotfiles like `.Rprofile`),
  defaults `code-filename` to the path, line numbers on by default. Args:
  `lang=`, `filename=`, `numbers=`, `lines=10-30`, `dedent=N`, `suffix=` (num
  or str, appended to the displayed filename with a space). The shortcode
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
