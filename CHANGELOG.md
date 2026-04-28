# Changelog

## [Unreleased]

## [0.12.0] - 2026-04-28

### Changed

- **Breaking**: extension renamed `hebstr` → `hebstr-doc` and repo renamed
  `quarto-hebstr` → `quarto-hebstr-doc` to make room for upcoming
  `hebstr-book` and `hebstr-website` project templates. Re-run
  `quarto add hebstr/quarto-hebstr-doc` and update `format:` to
  `hebstr-doc-html` / `hebstr-doc-typst` / `hebstr-doc-docx`. Extension
  directory moved to `_extensions/hebstr-doc/`; the Typst raw-theme path in
  `template.typ` was updated accordingly.

### Added

- Frontmatter overrides for the most common aesthetic knobs, surfaced at the
  format level in `_extension.yml`: `mainfont`, `monofont`, `fontsize`,
  `linestretch` (joining `page-layout`, `toc*`, `grid.*`). Consumers can
  retune typography and layout from a document's YAML without writing SCSS.
- `_brand.yml` interop: existing `$primary` / `$secondary` `!default` SCSS
  already defers to Quarto's brand layer, and derived shades recompute via
  `color-mix`. Cross-format brand colours and typography work without any
  extension change.
- Release pipeline via GitHub Actions: `render.yml` (HTML render on push/PR,
  artefact upload), `pages.yml` (deploy demo via `actions/deploy-pages@v4`),
  `release.yml` (GitHub Release on `v*` tag with auto-generated notes).
  README badges (CI, Pages, release, MIT) and `.gitignore` entries for
  `_site/` plus R session artefacts (`.Rhistory`, `.RData`, `.Ruserdata`,
  `.Rproj.user/`).

### Fixed

- `linestretch` from the YAML is now respected. Previously a hardcoded
  `p { line-height: 1.75rem }` in `theme-base.scss` shadowed Bootstrap's
  `$line-height-base`, silently ignoring any consumer override. The rule was
  removed; `linestretch: 1.75` (the new default) reproduces the prior look.

## [0.11.0] - 2026-04-27

### Added

- Light and dark theme support, switchable via Quarto's color-scheme toggle
  (sun/moon icon, rendered with Font Awesome, anchored in the document title).
- Font Awesome 7 Solid bundled locally (no CDN dependency at render time).

### Changed

- **Breaking** for consumers overriding the theme directly: the single
  `theme.scss` is gone. Use `format: hebstr-html` (recommended), or wire
  `theme: { light: [theme-light.scss, theme-base.scss], dark: [theme-dark.scss, theme-base.scss] }`.
- Callout colors adapt to the active theme. `tip` and `warning` body text
  are slightly darker than before.
- `anchor-sections: false` by default (no hover-anchor icons next to headings).

## [0.10.0] - 2026-04-26

### Added

- Self-contained `example.qmd` demonstrating the theme (HTML).
- `script` shortcode for injecting external scripts:
  `{{< script path/to/file.R >}}` auto-derives language and filename,
  renders inside a foldable code block. Optional args: `lang=`, `filename=`,
  `numbers=`, `lines=10-30`, `dedent=N`, `suffix=`.
- Embedded [`mcanouil/code-window`](https://github.com/mcanouil/quarto-code-window)
  for code-block chrome (HTML + Typst).

### Changed

- **Breaking**: extension renamed `hebstr-template` → `hebstr`. Re-run
  `quarto add hebstr/quarto-hebstr` and update `format:` to `hebstr-html` /
  `hebstr-typst` / `hebstr-docx`.
- **Breaking**: `lang` removed from common defaults. Declare your own `lang:`
  in `_quarto.yml`.
- `quarto-required` bumped to `>=1.9.36`.

## [0.9.0] - 2026-04-24

### Added

- Initial multi-format Quarto extension (`hebstr-html`, `hebstr-typst`,
  `hebstr-docx`) with bundled Luciole + Fira Code fonts.
