# Changelog

All notable changes to this project are documented in this file.
The project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### New Features

- feat: Highlight Python code from the theme's own syntax definition, in HTML and in Word, so keywords, imports, constants, function names and decorators read in the theme's colours instead of Pandoc's defaults.
- feat: Colour the code tokens the theme left to Quarto's own palette, so a raw string, a hexadecimal or binary literal, a string escape, an exception name and a `TODO` in a comment stay legible on the dark code surface.
- feat: Mark a code block whose language the theme ships no icon for with a `</>` glyph, the one Quarto gives its own code-tools button, so every block carries a mark rather than only the twenty keyed languages.
  The glyph takes the colour of the name beside it, on a title bar and on a folded header alike, in both schemes.
- feat: Show the language's icon on the folded header of a `{{< script >}}` block, as the title bar of a code window does, so a folded listing is identifiable before it is opened.
  The path reads smaller beside it, so the icon is what the eye lands on.
- feat: Lead a code block's name with a larger icon and a smaller name, on a code window's title bar and on a folded header alike, so the icon carries the recognition and the name no longer competes with it.
  Every code block in a document changes size this way, the title bar's own height excepted.

## 1.11.0 (2026-11-07)

### New Features

- feat: Show the language's icon beside the name in a code window's title bar, for the twenty languages the theme ships an icon for, so a block is identifiable before it is read.
  A language with no icon, a block whose title is a file name you set yourself, and the output of an executed cell keep the bar they had.
- feat: Tint the header of a folded code block to follow the light and dark schemes, so it reads as a surface of its own.
  It was transparent before.

### Bug Fixes

- fix: Set a level-4 heading in italic again in Word output, so it is told apart from a level-3 one.
- fix: Keep a font family you registered yourself when `fonts/register.R` is sourced, so your own faces survive the call.
  It replaced a family of the same name before.
- fix: Name the call `fonts/register.R` needs when it is reached another way, so the failure says what to write.
  It has to be `source("…/register.R")`; `sys.source()`, a connection and `Rscript` do not work.

## 1.10.0 (2026-10-30)

### New Features

- feat: Write a URL in a Word comment as a link, clickable from the comment itself, with nothing to wire in the consuming project.
- feat: Read the `script` shortcode's `lines` attribute given as a single number as that line alone, so a one-line selection needs no range.
  It showed that line and everything after it before, which `10-` already spells.

### Bug Fixes

- fix: Refuse a `dedent` that is not a whole number of spaces, with a warning, so the listing is neither truncated nor the render lost.
- fix: Mark a path the shortcode can open but not read, a directory being the common case, with the same visible marker as a missing file, so the mistake shows in the output.
- fix: Send every diagnostic of the shortcode through the render warning channel, so a mistake that marks the output is reported there too.
- fix: Report a `lines` range that selects no line, so an empty code block no longer renders in silence.
- fix: Clamp a `lines` range starting below line 1, so the rendered listing is no longer numbered from zero.

## 1.9.0 (2026-10-29)

### New Features

- feat: Render a callout as body text in Word rather than as a bordered table, its title a bold paragraph and its content ordinary prose, so it takes the document's own text width and styles.
  The type icon goes with the table, a title authored as a heading stays out of the outline and the table of contents, and a callout carrying an identifier keeps its table so a cross-reference to it still resolves; HTML is unaffected.

## 1.8.0 (2026-10-28)

### New Features

- feat: Carry a reply to a Word comment back as a reply rather than as a line inside the comment it answers, each becoming a Word comment of its own, anchored on the same text and carrying its own author and date.
  Add `scripts/thread-docx-comments.py` to `project: post-render:` to nest the replies; without it they read as separate comments in chronological order, a document Word has already threaded is left untouched, and one the script cannot read is reported without failing the render.

## 1.7.4 (2026-10-26)

### Bug Fixes

- fix: Name on standard error a comment store the extension cannot read, so an unreadable export no longer costs every comment in silence and the render still succeeds.
  Reading the render's messages remains the way to check a delivery.
- fix: Name and ignore a `collab-comments` option written as a single value instead of a block of keys, where it used to stop the render.

## 1.7.3 (2026-10-26)

### Bug Fixes

- fix: Read the straight apostrophe and the typographic one as one character when anchoring a Word comment, so a comment whose source carries either is placed instead of being dropped in silence.
  A selection the rendered document carries in both forms at once is refused and named.

## 1.7.2 (2026-10-26)

### Bug Fixes

- fix: Anchor a Word comment whose stored position no longer matches the source wherever the source carries its selected text exactly once, so an edit made with the editor closed no longer drops every comment of the document at the next render.
  A selection spanning two source lines is carried the same way, and a selected text the source no longer carries, or carries twice, is still refused and named.
- fix: Keep a figure inside the text column in Word, and style the overall caption of a figure laid out in panels (`layout-nrow`, `layout-ncol`) like any other, so neither comes out clipped nor unstyled.
- fix: Place the parts of a two-column layout (`::: {layout-ncol=2}`) one after another at full width in Word, so neither the figures nor the text of the block is cut off or pushed right of the body margin.
  HTML keeps the columns side by side, and a row Quarto turns into a float still comes out in columns: a row carrying a float id, and a chunk row with `fig-subcap`.
- fix: Align the sub-captions of one float the same way in Word.
  A table written by the author keeps the alignment they gave it.

## 1.7.1 (2026-10-24)

### New Features

- feat: Open a new page on a level-1 heading in Word, as the table of contents already did, so each section starts on a clean page.
- feat: Set Word references at 9 pt through the `Bibliography` style, so the reference list reads smaller than the prose instead of taking the document default.

### Bug Fixes

- fix: Keep a list written with a blank line between its items at the prose size and line spacing in Word, where it rendered one point larger.
  A custom `reference-doc` has one more style to carry, `List Item`.

## 1.7.0 (2026-10-24)

### Breaking Changes

- refactor: Remove the `hebstr-doc-typst` format, with the `template.typ` preamble and the `code.tmTheme` code theme it read.
  HTML and Word are the two output formats; for a PDF, export the Word output from Word.

### New Features

- feat: Carry Word comments imported from a reviewed `.docx` back into the Word output, so a reviewer's remarks survive every later render.
  Set `docx-comments: true` under a `collab-comments:` block in the document, keep the `collab-comments` editor extension installed for the store it writes, and drop the document's own `filters:` line with the editor open on it, since removing those lines shifts every stored comment in the body.

### Bug Fixes

- fix: Stop reading a comment at the end of a line in `filetree.yml` as part of the value, so an `exclude` or `highlight` pattern written with a trailing comment matches again.
  It matched nothing, without a warning, before.
- fix: Warn on an empty description under `paths`, naming the key, instead of ignoring it in silence or rendering an empty element.
- fix: Warn on two `paths` keys that differ only by a trailing slash, so which one survives no longer depends on the order the file happens to be read in.
- fix: Render nothing for a named profile whose `filetree.yml` cannot be parsed, as a missing file already did, instead of rendering an unconfigured tree.
- fix: Warn on a profile written on one line (`default: { depth: 3 }`) or under a quoted name, where it lost every key but `paths` in silence.
  Write each key on its own line under the unquoted profile name.

## 1.6.0 (2026-09-26)

### Breaking Changes

- refactor: Remove the `filetree:` key from `filetree.yml`: its top-level keys are profiles, and `{{< filetree >}}` renders the one named `default`.
  Rename `filetree:` to `default:` in an existing file; until then the shortcode renders nothing and raises a warning.

### New Features

- feat: Recognise `.log` and `.txt` files in the `script` shortcode, and label their code header `log` or `txt`.
- feat: Hold several named profiles in `filetree.yml`, `{{< filetree name >}}` rendering the profile `name`, so one sidecar serves every tree of a project.
  See [`filetree`](README.md#filetree).
- feat: Label a code block with no language `default` and frame it like a highlighted one, so it carries the same chrome as its neighbours.
  Add `code-window-enabled="false"` to the block to keep it plain.
- feat: Frame the printed output of a chunk whose code is hidden under the same `default` header, with line numbers, `collapse: true` merging it into a block with no language.
  Set `collapse: false` on the chunk to show it as plain output on the dark code surface, without a header or a copy button.
- build: Update the embedded `code-window` extension from 1.1.5 to 1.5.1, which brings the `collapse` and `lines-label` options and checks the `code-window` settings for errors.
  See the [code-window changelog](https://github.com/mcanouil/quarto-code-window/blob/1.5.1/CHANGELOG.md).

### Bug Fixes

- fix: Follow `fig-align` again in HTML, so a figure built with `renderings` and an unlabelled figure with a caption stay centred.
  Body justification had applied to a figure's image since 1.5.0; the body text override in [Text alignment](README.md#text-alignment) now excludes figures, and the previous form still works but also moves those figures to the left.

## 1.5.0 (2026-09-22)

### Breaking Changes

- refactor: Remove the SCSS variables `$surface-default` and `$figure-shadow`, and their CSS custom properties `--surface-default` and `--figure-shadow`.
  No rule used either, so overriding them had no effect.

### New Features

- feat: Follow the dark scheme in an unthemed `reactable` table, so a widget matches the page with no R-side change.
  A widget with its own `reactableTheme()` keeps its colours; pass CSS variables such as `var(--primary-surface)` to follow the toggle from R.
- feat: Follow the dark scheme in a `gt` table instead of keeping the light palette set in R, so a table matches the page.
  Colours passed to `gt::tab_options()` are replaced in dark mode, light mode is unchanged, and to adjust them override `$primary-surface`, `$primary-back`, `$neutral` and `$body-color`.
- feat: Justify and hyphenate body text in HTML, matching the Word output, margin content staying left-aligned.
  See [Text alignment](README.md#text-alignment) to opt out.
- feat: Give a figure without a cross-reference label the float caption style, centred, so it reads like a labelled one.
- feat: Link a citation to its bibliography entry in Word output (`link-citations: true`), so a reader can reach the reference from the text.
- feat: Move the light/dark toggle from beside the document title to the top of the table of contents sidebar, so it sits with the page's own navigation.
  On a narrow screen it returns to the top-right corner.
- feat: Accept a `*` wildcard in a `filetree` key under `paths`, matching within a single path segment (`docs/*_report.html`), so one key describes a family of files.
  Exact keys take precedence over wildcards.
- feat: Add `filetree` icons for spreadsheets and CSV, presentations, PDF, SVG, BibTeX, shell scripts, logs, databases and data files (SQL, SQLite, DuckDB, Parquet, Feather), XML and CSL, and Rust.
- feat: Add `scripts/check-docx.R`, which checks a rendered `.docx` or the `.dotx` template for the properties Word output depends on, so a broken deliverable is caught before it is sent: defined styles, well-formed table cells, no unused media, text width, hyphenation and font fallback.
  It requires the `officer` and `xml2` R packages.
- feat: Add `scripts/build_template.py`, which rebuilds `template.dotx` from Pandoc's reference document, so a template change is a recipe rather than a hand edit.
- feat: Demonstrate `gt` and `reactable` tables in `example.qmd`, so both table surfaces can be checked in one render.
- refactor: Produce no output from `{{< script >}}` outside HTML, so a Word render no longer carries a listing meant for the screen.
  Use a plain code block to show a file in every format.
- refactor: Use the dedicated SVG icon for a `.svg` file in `filetree` instead of the generic image icon.
  A rule targeting `.ft-i-image` no longer reaches them; use `.ft-i-svg`.
- build: Rebuild `template.dotx` from Pandoc's reference document, 12 KB down from 562 KB, so every style Pandoc uses is defined and a rendered document no longer carries about 1 MB of unused media.
  Word output changes with it: text is set in Aptos with Calibri as fallback for Word versions before 2024, body text is 11 pt with 1.5 line spacing, justified and hyphenated where headings, captions, lists, footnotes and single-paragraph table cells are not, the title block has its own page, the table of contents starts on the second page, and captions are bold, 10 pt and not italic.
  Page geometry is unchanged (A4, 2.5 cm margins, 6.2958 in text width), `quarto update` replaces an installed copy of the template edited by hand, and the template is licensed under the GPL, version 2 or later, as a derivative of Pandoc's reference document; see [LICENSE.md](LICENSE.md).

### Bug Fixes

- fix: Shrink a `gt` table wider than the text column to fit, where it scrolled horizontally.
- fix: Let Word open a document holding a cross-referenced `flextable` or `gt` table, which it refused with "an ambiguous cell mapping was encountered".
- fix: Keep a cross-referenced table at its own width in Word, whether Markdown, `gt` or `flextable`, where it came out squeezed.
- fix: Style a Word caption by its position, `Table Caption` above its content and `Image Caption` below, so a caption reads the same way wherever it sits.
  A subtitle written as `<br><span class='quarto-float-subcaption'>…</span>`, as `hebstr::str_fig()` does, becomes a separate paragraph in a lighter style.
- fix: Take the Word table of contents title from the document language instead of a hard-coded "Table of Contents", and start the body on the page after it.
  Word offers to update the table of contents when the document is opened.

## 1.4.0 (2026-08-29)

### New Features

- feat: Number annexes through a custom `anx` cross-reference type, so an annexe is captioned and counted apart from the figures and tables.
  Label a chunk `tbl-anx-<name>` or `fig-anx-<name>`, or a fenced div `anx-<name>`, and reference it as `@anx-<name>`; it is captioned *Annexe n.* and numbered separately.
- feat: Mark the package name before `::` and `:::` in R code, and treat `library`, `require` and `requireNamespace` as keywords, so a namespaced call reads apart from an ordinary one.
  It applies to HTML and Word, and the R syntax definition is licensed under the GPL v2; see [LICENSE.md](LICENSE.md).
- feat: Colour the argument separator, the `=` of a named argument and the brackets in R code, so an argument list reads apart from its values.
  Brackets reuse the `.re` token class, which now renders in gold in every language.
- feat: Give the import and namespace token `.im` its own colour (`#fad430`), distinct from a keyword, so an import is not read as one.
  This also reaches imports in other languages, such as Python.
- feat: Embed the Luciole regular and bold faces in a figure's SVG when `fonts/register.R` is sourced, so figure text renders in Luciole for a reader who does not have it installed.
  It adds about 114 KB per figure, and italic and monospaced figure text still depends on the reader's fonts.
- feat: Add the public SCSS variable `$font-size-root`, defaulting to `1rem`, so the document follows the reader's browser font size and rescales from one variable.
- refactor: Keep bold for keywords, imports and constants alone instead of setting a whole code block in bold, so a block reads evenly.
- refactor: Harmonise the type scale, code blocks and inline code at `0.9rem`, the code-fold label at `0.8rem` and `$toc-font-size` from `0.825rem` to `0.8rem`, so fewer sizes are in play.

### Bug Fixes

- fix: Stop highlighting the R `:=` operator (`data.table`, rlang) as an error.
- fix: Raise code comments and line numbers to the WCAG contrast ratio against the code surface, `$code-comment-color` to `#8d8d8d` and `$code-window-line-number` to `#7b7a76`, so both stay legible.
- fix: Register the bundled fonts on a system whose FreeType lacks WOFF2 support, so `fonts/register.R` works there too.

## 1.3.0 (2026-08-01)

### Breaking Changes

- build: Require the `svglite` R package for the HTML format, figures rendering with `svglite` so their text stays selectable and the files stay small.
  Any document with an R chunk needs the package, even if it draws no figure; to keep R's built-in device, set `knitr: { opts_chunk: { dev: svg, dev.args: null } }`.

### New Features

- feat: Add `fonts/register.R`, which makes the bundled Luciole and Fira Code fonts available to R graphics devices on a machine where they are not installed, so a figure is not drawn in a substitute face.
  Source it from a setup chunk.
- feat: Map the generic `sans` and `mono` font families to Luciole and Fira Code in HTML figures, so figure text matches the body.
  A chunk that sets its own `dev.args` loses the mapping.

### Bug Fixes

- fix: Keep the light theme page background plain white, `$primary-surface` no longer mixing in 2% of `$primary`.

## 1.2.1 (2026-07-26)

### New Features

- feat: Add `filetree` icons for more file types, among them `.mjs`, `.cjs`, `.Rmd`, `.htm`, `.jsonc`, `.ttf`, `.otf`, `.gif`, `.webp`, `.avif`, `.doc`, `.odt` and `.rtf`.
- feat: Warn on an invalid argument to `{{< script >}}` instead of ignoring it silently, so a typo is reported rather than absorbed.
- feat: Give the color-scheme toggle and the callout icons alternative text, so a screen reader names them.

### Bug Fixes

- fix: Keep filenames showing on the rest of the page when a `{{< script >}}` block carries no `code-fold`.
- fix: Keep a highlighted folder styled in `filetree`'s `dynamic` mode.
- fix: Read past a blank line or a comment in the `filetree` sidecar, so the `exclude` and `highlight` lists are no longer truncated.

### Refactoring

- build: Check the stylesheets with stylelint and prettier, so a malformed rule is caught at the commit.
  No visual change.
- refactor: Remove the rules `template.typ` no longer used.

## 1.2.0 (2026-07-21)

### Breaking Changes

- refactor: Stop setting `fontsize: 1.2rem` in the HTML format.
  Set `fontsize` in your document to restore it.
- refactor: Rename `$tab-background` to `$tab-surface` and expose it as a CSS custom property.
  Rename the override in a consumer's own stylesheet.

### New Features

- feat: Add the `{{< filetree >}}` shortcode, which renders a directory tree read from disk, so a documented layout stays in step with what is on disk.
  Configure it with a `filetree.yml` sidecar or shortcode attributes, see the [README](README.md#filetree); it carries file-type icons from Material Icon Theme and five SCSS variables for its colours.
- feat: Add `mode: dynamic`, which renders the tree with collapsible folders and no JavaScript, so a deep tree opens where the reader wants it.
- refactor: Narrow the default layout, `body-width` to 1000px from 1100px and `margin-width` to 450px from 600px, so the text column holds a shorter measure.

### Bug Fixes

- fix: Remove only the leading indentation with `{{< script >}}`'s `dedent`, where it also took spaces from inside a line.

## 1.1.0 (2026-07-07)

### New Features

- feat: Render HTML figures as SVG instead of PNG, so figure text stays sharp at any zoom.
  Use `fig-format: png` to restore raster output.
- feat: Scale an SVG figure in the lightbox to fit the viewport, so a tall figure is read without scrolling.

## 1.0.0 (2026-04-29)

First stable release.

### New Features

- feat: Add SCSS variables for the navbar, sidebar and footer of a website or a book, `$navbar-bg`, `$navbar-fg`, `$navbar-hl`, `$sidebar-bg`, `$sidebar-fg`, `$sidebar-hl`, `$footer-bg` and `$footer-fg`, so a project layout takes the theme's own colours.
- feat: Use the navbar colour for the title block banner under `title-block-banner: true`, instead of Quarto's default blue.
- docs: Add `CONTRIBUTING.md`, carrying the public API surface, the versioning policy and the release procedure.

## 0.12.0 (2026-04-28)

### Breaking Changes

- refactor: Rename the extension to `hebstr-doc` and the repository to `quarto-hebstr-doc`.
  Reinstall with `quarto add hebstr/quarto-hebstr-doc` and declare `hebstr-doc-html`, `hebstr-doc-typst` or `hebstr-doc-docx`.

### New Features

- feat: Read the front matter options `mainfont`, `monofont`, `fontsize` and `linestretch`, so a document sets its own type without touching the theme.
- feat: Take colours and typography from `_brand.yml`, so a project's brand reaches the output.
- build: Add GitHub Actions workflows for the render, the demo site and the releases.

### Bug Fixes

- fix: Honour `linestretch`.

## 0.11.0 (2026-04-27)

### Breaking Changes

- refactor: Split `theme.scss` into `theme-base.scss`, `theme-light.scss` and `theme-dark.scss`.
  Declare `format: hebstr-html`, or list the files in `theme:`.

### New Features

- feat: Add a light and a dark theme, switchable from the page.
- feat: Bundle the Font Awesome 7 icons locally, so a callout icon needs no remote request.
- feat: Follow the active theme in the callout colours.
- refactor: Turn section anchors off by default, so a heading carries no hover anchor.

## 0.10.0 (2026-04-26)

### Breaking Changes

- refactor: Rename the extension to `hebstr`.
- refactor: Stop setting `lang` by default; declare it in `_quarto.yml`.
- build: Require Quarto 1.9.36 or later.

### New Features

- feat: Add the `{{< script >}}` shortcode, which includes an external file as a foldable code block, so a listing stays in step with the file on disk.
- feat: Embed the `mcanouil/code-window` extension, which gives a code block its filename header.
- docs: Add the `example.qmd` demonstration document, so every surface of the theme is rendered from one file.

## 0.9.0 (2026-04-24)

### New Features

- feat: Add the HTML, Typst and Word formats, with the Luciole and Fira Code fonts bundled, so the three outputs share one theme.
