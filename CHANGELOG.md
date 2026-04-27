# Changelog

## [0.11.0] — 2026-04-27

### Added

- Light and dark theme support, switchable via Quarto's color-scheme toggle
  (sun/moon icon, rendered with Font Awesome, anchored in the document title).
- Font Awesome 7 Solid bundled locally — no CDN dependency at render time.

### Changed

- **Breaking** for consumers overriding the theme directly: the single
  `theme.scss` is gone. Use `format: hebstr-html` (recommended), or wire
  `theme: { light: [theme-light.scss, theme-base.scss], dark: [theme-dark.scss, theme-base.scss] }`.
- Callout colors adapt to the active theme. `tip` and `warning` body text
  are slightly darker than before.
- `anchor-sections: false` by default — no hover-anchor icons next to headings.

## [0.10.0] — 2026-04-26

### Added

- Self-contained `example.qmd` demonstrating the theme (HTML).
- `script` shortcode for injecting external scripts:
  `{{< script path/to/file.R >}}` — auto-derives language and filename,
  renders inside a foldable code block. Optional args: `lang=`, `filename=`,
  `numbers=`, `lines=10-30`, `dedent=N`, `suffix=`.
- Embedded [`mcanouil/code-window`](https://github.com/mcanouil/quarto-code-window)
  for code-block chrome (HTML + Typst).

### Changed

- **Breaking**: extension renamed `hebstr-template` → `hebstr`. Re-run
  `quarto add hebstr/quarto-hebstr` and update `format:` to `hebstr-html` /
  `hebstr-typst` / `hebstr-docx`.
- **Breaking**: `lang` removed from common defaults — declare your own `lang:`
  in `_quarto.yml`.
- `quarto-required` bumped to `>=1.9.36`.

## [0.9.0] — 2026-04-24

### Added

- Initial multi-format Quarto extension (`hebstr-html`, `hebstr-typst`,
  `hebstr-docx`) with bundled Luciole + Fira Code fonts.
