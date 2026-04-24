# Changelog

## [0.10.0] — 2026-04-24

### Added

- `README.md` with install, formats, usage, fonts, customisation, licence sections.
- `example.qmd` at repo root: self-contained demo covering typography, lists,
  figure (ggplot + palmerpenguins), table, code block, equation, callouts, quote,
  cross-references. Renders to HTML, Typst (PDF), and DOCX.
- `LICENSE.md` (MIT) at repo root.
- Bundled font licence files: `_extensions/hebstr/fonts/LICENSE-Luciole.md`
  (CC-BY 4.0 + attribution) and `LICENSE-FiraCode.md` (OFL 1.1 upstream verbatim).
- `.gitignore` covering render artefacts, Quarto caches, editor files.

### Changed

- **Breaking (Typst)**: code raw theme path updated to
  `_extensions/hebstr/code.tmTheme` (previously `hebstr-template/resources/…`,
  which never resolved correctly after the rename).
- **Breaking (layout)**: removed `_extensions/hebstr/resources/` intermediate
  directory. `template.typ`, `code.tmTheme`, `chazard.dotx` are now at the
  extension root; font files and `fonts.css` grouped under `fonts/`. All paths
  in `_extension.yml` updated accordingly.
- **Breaking (defaults)**: `lang: fr` and `published-title: "dernière mise à jour"`
  removed from the `common:` block — consumers now declare their own language
  (`lang: fr` is a single-line opt-in in the consumer's `_quarto.yml`).
- `tbl-title` changed from `"Tableau"` to `"Table"` — neutral across EN and FR.
- Bumped `quarto-required` from `>=1.7.0` to `>=1.8.0`.
- HTML: set `page-layout: full` and increased `grid.gutter-width` from `2rem`
  to `3rem` for more generous horizontal spacing.

### Fixed

- Extension title renamed from `hebstr-template` to `hebstr`; the stale
  `hebstr-template` path in `template.typ` that prevented Typst rendering in
  consumers is now corrected.

## [0.9.0] — 2026-04-24

### Added

- Multi-format Quarto extension declaring `hebstr-html`, `hebstr-typst`,
  and `hebstr-docx` via a shared `common:` block.
- HTML theme (`theme.scss`) with Bootstrap/Bootswatch SCSS, Luciole and
  Fira Code fonts, lightbox, custom grid widths.
- Typst preamble (`template.typ`) styling headings, lists, tables, code
  blocks, equations, and quotes.
- DOCX reference doc (`chazard.dotx`).
- Luciole and Fira Code font files (`.woff` + `.woff2`).
