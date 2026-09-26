# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.6.0] - 2026-09-26

### Added

- The `script` shortcode recognises `.log` and `.txt` files, and labels their code header `log` or `txt`.
- `filetree.yml` holds several named profiles, and `{{< filetree name >}}` renders the profile `name`.
  See [`filetree`](README.md#filetree).

### Changed

- **Breaking:** `filetree.yml` no longer has a `filetree:` key: its top-level keys are profiles, and `{{< filetree >}}` renders the one named `default`.
  Rename `filetree:` to `default:` in an existing file; until then the shortcode renders nothing and raises a warning.

- The embedded `code-window` extension is updated from 1.1.5 to 1.5.1, and code blocks change in two ways:
  - a code block with no language gets a header labelled `default`; add `code-window-enabled="false"` to the block to keep it plain;
  - printed output of a chunk whose code is hidden gets the same `default` header, with line numbers, because `collapse: true` merges it into a block with no language; set `collapse: false` on the chunk to show it as plain output on the dark code surface, without a header or a copy button.

  The update also brings the `collapse` and `lines-label` options and checks the `code-window` settings for errors.
  See the [code-window changelog](https://github.com/mcanouil/quarto-code-window/blob/1.5.1/CHANGELOG.md).

### Fixed

- Figures follow `fig-align` again in HTML.
  Since 1.5.0, body justification also applied to the image of a figure built with `renderings` or of an unlabelled figure with a caption, which left it aligned to the left.
  The body text override in [Text alignment](README.md#text-alignment) now excludes figures; the previous form still works but also moves those figures to the left.

## [1.5.0] - 2026-09-22

### Added

- `reactable` tables follow the dark scheme when left unthemed.
  A widget with its own `reactableTheme()` keeps its colours; pass CSS variables such as `var(--primary-surface)` to follow the toggle from R.
- Body text is justified and hyphenated in HTML, matching the Typst and Word formats.
  Margin content stays left-aligned.
  See [Text alignment](README.md#text-alignment) to opt out.
- Figures without a cross-reference label get the float caption style, centred.
- Citations link to their bibliography entry in Word output (`link-citations: true`).
- `scripts/check-docx.R` checks a rendered `.docx` or the `.dotx` template for the properties Word output depends on: defined styles, well-formed table cells, no unused media, text width, hyphenation and font fallback.
  Requires the `officer` and `xml2` R packages.
- `scripts/build_template.py` rebuilds `template.dotx` from Pandoc's reference document.
- `filetree`: keys under `paths` accept a `*` wildcard, matching within a single path segment (`docs/*_report.html`).
  Exact keys take precedence over wildcards.
- `filetree`: icons for spreadsheets and CSV, presentations, PDF, SVG, BibTeX, shell scripts, logs, databases and data files (SQL, SQLite, DuckDB, Parquet, Feather), XML and CSL, and Rust.
- `example.qmd` demonstrates `gt` and `reactable` tables.

### Changed

- `gt` tables follow the dark scheme instead of keeping the light palette set in R.
  Colours passed to `gt::tab_options()` are replaced in dark mode; to adjust them, override `$primary-surface`, `$primary-back`, `$neutral` and `$body-color`.
  Light mode is unchanged.

- The light/dark toggle moved from beside the document title to the top of the table of contents sidebar.
  On narrow screens it returns to the top-right corner.

- `{{< script >}}` renders in HTML only and produces no output in Typst and Word.
  Use a plain code block to show a file in every format.

- `filetree`: `.svg` files use the dedicated SVG icon instead of the generic image icon.
  Rules targeting `.ft-i-image` no longer apply to them; use `.ft-i-svg`.

- `template.dotx` is rebuilt from Pandoc's reference document (12 KB, down from 562 KB), and Word output changes accordingly:
  - text is set in Aptos, with Calibri as fallback for Word versions before 2024;
  - body text is 11 pt with 1.5 line spacing, justified and hyphenated; headings, captions, lists, footnotes and single-paragraph table cells are not hyphenated;
  - the title block has its own page, and the table of contents starts on the second page;
  - captions are bold, 10 pt, not italic;
  - every style Pandoc uses is defined (the previous template left 35 of them to fall back to `Normal`), and rendered documents no longer carry about 1 MB of unused media.

  Page geometry is unchanged: A4, 2.5 cm margins, 6.2958 in text width.
  `quarto update` replaces an installed copy of the template edited by hand.
  The template is licensed under the GPL, version 2 or later, as a derivative of Pandoc's reference document; see [LICENSE.md](LICENSE.md).

### Removed

- **Breaking:** the SCSS variables `$surface-default` and `$figure-shadow`, and their CSS custom properties `--surface-default` and `--figure-shadow`.
  No rule used either, so overriding them had no effect.
  Shipped as a minor release under the no-consumer clause of `CONTRIBUTING.md`.

### Fixed

- `gt` tables wider than the text column shrink to fit instead of scrolling horizontally.
- Word no longer refuses to open documents containing cross-referenced `flextable` or `gt` tables ("an ambiguous cell mapping was encountered").
- Cross-referenced tables are no longer squeezed in Word, whether Markdown, `gt` or `flextable`.
- Word captions are styled by position: a caption above its content uses `Table Caption` (centred, kept with the next paragraph), one below uses `Image Caption` (left-aligned).
  A subtitle written as `<br><span class='quarto-float-subcaption'>…</span>`, as `hebstr::str_fig()` does, becomes a separate paragraph in a lighter style.
- The Word table of contents takes its title from the document language instead of a hard-coded "Table of Contents", and the body starts on the page after it.
  Word offers to update the table of contents when the document is opened.

## [1.4.0] - 2026-08-29

### Added

- Numbered annexes through a custom `anx` cross-reference type.
  Label a chunk `tbl-anx-<name>` or `fig-anx-<name>`, or a fenced div `anx-<name>`, and reference it as `@anx-<name>`; it is captioned *Annexe n.* and numbered separately.
- R code highlighting marks the package name before `::` and `:::`, and treats `library`, `require` and `requireNamespace` as keywords.
  Applies to HTML and Word.
  The R syntax definition is licensed under the GPL v2; see [LICENSE.md](LICENSE.md).
- Figure SVGs embed the Luciole regular and bold faces when `fonts/register.R` is sourced, so figure text renders in Luciole for readers who do not have it installed.
  Adds about 114 KB per figure.
  Italic and monospaced figure text still depends on the reader's fonts.
- New public SCSS variable `$font-size-root`, defaulting to `1rem`, so the document follows the reader's browser font size and can be rescaled from one variable.

### Changed

- R code highlighting colours argument separators, the `=` of named arguments, and brackets.
  Brackets reuse the `.re` token class, which now renders in gold in every language.
- The import/namespace token `.im` has its own colour (`#fad430`), distinct from keywords.
  This also affects imports in other languages, such as Python.
- Code blocks are no longer bold throughout; bold is kept for keywords, imports and constants.
- Code sizes are harmonised: code blocks and inline code at `0.9rem`, the code-fold label at `0.8rem`.
- `$toc-font-size` changes from `0.825rem` to `0.8rem`.

### Fixed

- The R `:=` operator (`data.table`, rlang) is no longer highlighted as an error.
- Code comments and line numbers meet WCAG contrast requirements: `$code-comment-color` changes to `#8d8d8d` and `$code-window-line-number` to `#7b7a76`.
- `fonts/register.R` works on systems whose FreeType lacks WOFF2 support.

## [1.3.0] - 2026-08-01

### Added

- `fonts/register.R` makes the bundled Luciole and Fira Code fonts available to R graphics devices on machines where they are not installed.
  Source it from `.Rprofile` or a setup chunk.

### Changed

- **The HTML format requires the `svglite` R package.**
  Figures render with `svglite`, which keeps text selectable and produces smaller files.
  Any document with an R chunk needs the package, even if it draws no figure.
  To keep R's built-in device, set `knitr: { opts_chunk: { dev: svg, dev.args: null } }`.
- In HTML figures, the generic `sans` and `mono` font families map to Luciole and Fira Code.
  A chunk that sets its own `dev.args` loses this mapping.

### Fixed

- The light theme page background is plain white; `$primary-surface` no longer mixes in 2% of `$primary`.

## [1.2.1] - 2026-07-26

### Added

- `filetree`: icons for more file types, including `.mjs`, `.cjs`, `.Rmd`, `.htm`, `.jsonc`, `.ttf`, `.otf`, `.gif`, `.webp`, `.avif`, `.doc`, `.odt` and `.rtf`.
- `{{< script >}}` warns on invalid arguments instead of ignoring them silently.
- Alternative text for the color-scheme toggle and callout icons.

### Changed

- Stylesheets are checked by stylelint and prettier.
  No visual change.
- Unused rules removed from `template.typ`.

### Fixed

- `{{< script >}}`: a code block without `code-fold` stopped filenames from appearing on the whole page.
- `filetree`: highlighted folders lost their styling in `dynamic` mode.
- `filetree`: a blank line or a comment in the sidecar truncated the `exclude` and `highlight` lists.

## [1.2.0] - 2026-07-21

### Added

- `{{< filetree >}}` shortcode, which renders a directory tree read from disk.
  Configure it with a `filetree.yml` sidecar or shortcode attributes; see the [README](README.md#filetree).
  Includes file-type icons from Material Icon Theme and five SCSS variables for its colours.
- `mode: dynamic` renders the tree with collapsible folders, without JavaScript.

### Changed

- `$tab-background` is renamed `$tab-surface` and exposed as a CSS custom property.
- The default layout is narrower: `body-width` 1000px (was 1100px), `margin-width` 450px (was 600px).

### Removed

- **Breaking:** the HTML format no longer sets `fontsize: 1.2rem`.
  Set `fontsize` in your document to restore it.

### Fixed

- `{{< script >}}`: `dedent` removed spaces inside lines instead of only leading indentation.

## [1.1.0] - 2026-07-07

### Added

- SVG figures in the lightbox scale to fit the viewport.

### Changed

- HTML figures render as SVG instead of PNG.
  Use `fig-format: png` to restore raster output.

## [1.0.0] - 2026-04-29

First stable release.
The public API surface is versioned as described in `CONTRIBUTING.md`.

### Added

- SCSS variables for the navbar, sidebar and footer of websites and books: `$navbar-bg`, `$navbar-fg`, `$navbar-hl`, `$sidebar-bg`, `$sidebar-fg`, `$sidebar-hl`, `$footer-bg`, `$footer-fg`.
- `CONTRIBUTING.md`, with the public API surface, versioning policy and release procedure.

### Changed

- With `title-block-banner: true`, the banner uses the navbar colour instead of Quarto's default blue.

## [0.12.0] - 2026-04-28

### Changed

- **Breaking:** the extension is renamed `hebstr-doc` and the repository `quarto-hebstr-doc`.
  Reinstall with `quarto add hebstr/quarto-hebstr-doc` and use `hebstr-doc-html`, `hebstr-doc-typst` or `hebstr-doc-docx`.

### Added

- Front matter options `mainfont`, `monofont`, `fontsize` and `linestretch`.
- Support for `_brand.yml` colours and typography.
- GitHub Actions workflows for rendering, the demo site and releases.

### Fixed

- `linestretch` is respected.

## [0.11.0] - 2026-04-27

### Added

- Light and dark themes, switchable from the page.
- Font Awesome 7 icons bundled locally.

### Changed

- **Breaking:** `theme.scss` is split into `theme-base.scss`, `theme-light.scss` and `theme-dark.scss`.
  Use `format: hebstr-html`, or list the files in `theme:`.
- Callout colours follow the active theme.
- Section anchors are disabled by default.

## [0.10.0] - 2026-04-26

### Added

- `example.qmd` demonstration document.
- `{{< script >}}` shortcode, which includes an external file as a foldable code block.
- Embedded `mcanouil/code-window` extension for code block headers.

### Changed

- **Breaking:** the extension is renamed `hebstr`.
- **Breaking:** `lang` is no longer set by default; declare it in `_quarto.yml`.
- Requires Quarto 1.9.36 or later.

## [0.9.0] - 2026-04-24

### Added

- Initial release: HTML, Typst and Word formats with bundled Luciole and Fira Code fonts.
