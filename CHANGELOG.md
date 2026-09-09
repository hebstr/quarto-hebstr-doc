# Changelog

## [Unreleased]

### Added

- `reactable` tables follow the dark scheme where their author left them unthemed.
  The widget ships its own stylesheet, which Quarto loads after the theme bundle, so the rules carry the weight that settles source order rather than a marker.
  An untouched widget takes the theme's two page surfaces, `$primary-surface` for the ground, the search box and the column filters, `$primary-back` for the striped rows, with `$neutral` on its borders.
  That is the reverse of the pairing a `gt` table lands on, where the tint carries the ground and the striping is the page colour, `gt` reading its own palette from R while a widget here has none to read.
  A widget carrying any `reactableTheme()` keeps the palette its R code set, which is the route to prefer: `reactable` accepts a CSS variable where `gt` rejects one, so an author can follow the toggle from R with no override at all.
  That opt-out is a class guard rather than a weighing of selectors, Emotion emitting a theme at a weight that varies by property: matched on the striped rows, outranked on the table border, so specificity alone would have overridden half of an author's palette.
  It covers the six colours `reactableTheme()` names directly and stops there: the search box, the column filters and the page controls are reachable from R through style lists alone, which arrive as inline styles and outrank any stylesheet, so those are dressed whether the widget is themed or not.

- `example.qmd` renders a `gt` table under `# Table`, beside the Markdown one, which is where the dark override recorded under Changed becomes observable in this repo.
  The table asks for a deliberate light palette through `tab_options()`, the pale blue ground with white striped rows the house reports use (`#F0FAFF`, a step off the `#F2FAFF` `primary-back` compiles to in light), so dark shows the override winning over colours the chunk wrote rather than over `gt` defaults.
  Its shape follows those reports too: a flat body so the striping alternates uninterrupted, a spanner, bold column labels over a rule, no vertical hairlines, and a source note.
  The caption is a Quarto `tbl-cap` rather than a `gt` header, which is what those tables do and what makes the float centring rule apply.
  No render probe comes with it: an uncovered `gt` class paints a light card on a dark ground, which the published demo shows at a glance, where `tests/r-syntax-tokens.sh` and `tests/anx-float.sh` exist for defects that leave the render green.
  `gt` becomes a render-time requirement of the demo document, added to both workflows; it pulls `juicyjuice` and `V8`, the heaviest dependency `example.qmd` carries.

- `example.qmd` renders a `reactable` widget beside that table, naming the theme's own tokens through `reactableTheme()`, so it lands on the pairing the theme gives an untouched widget, `$primary-surface` on the ground and `$primary-back` on the striped rows, in both schemes from one declaration, and demonstrates the route the documentation recommends.
  `reactable` joins the workflows as its own entry rather than riding on `gt`, which imports it, so no install is added; the cost is page weight, the widget's bundle taking `example.html` from 4.20 MB to 4.66 MB under `embed-resources: true`.

- Body prose is justified in HTML, which the two other formats already did and the theme left to each document.
  `template.typ` sets `justify: true` on `par`, and the `Normal` style of `template.dotx` carries `w:jc w:val="both"`, so HTML was the odd one of the three rather than the second to fall in line.
  The rule is anchored on `#quarto-document-content` rather than written as a bare `p`: the id keeps the TOC sidebar out, and carries the weight a document-level `<style>` used to take from source order alone.
  The margin column is not kept out by that id, Quarto emitting it inside the same container, so a rule of its own hands `.column-margin` back to `left` : justification needs a measure the 450 px margin column does not have, and a document mixing the two columns opens its rivers there first.
  That one class covers the three shapes margin content takes, a `.column-margin` div, an `.aside` and a footnote under `reference-location: margin` all rendering as the same container, and it repeats the id to outweigh the rule above rather than relying on source order.
  `hyphens: auto` rides along on the same rule, and it is what makes the justification affordable rather than a decoration: a line absorbs its leftover width by breaking a word, instead of pushing all of it into the spaces between the few words it holds.
  The difference is measurable on this document, whose prose is dense in inline code, and inline code is the worst case for justification twice over, being unbreakable and long: a `<code>` that does not fit moves whole to the next line and leaves the gap behind it, on a line that holds fewer words to share it.
  Word spaces measured across the body of `example.qmd`, at 1000 px: a median of 5.7 px ragged-right against 7.6 px justified, and a worst line at 18.3 px, 3.2 times the natural space.
  A document that wants otherwise overrides it in three lines, and those three lines have to repeat the id : a bare `p { text-align: left }` loses whatever its position, source order settling only a tie, so the override reads `#quarto-document-content p` in a `custom.scss` or in a document `<style>` alike.

- A figure with no cross-reference label takes the float caption's typography and is centred, alongside the top-located float caption.
  Such a figure carries no `.quarto-float-caption`, so it fell outside the `.quarto-float` block and rendered as body prose, which shows on any document mixing labelled and unlabelled figures.
  Centring is where the two stop agreeing, and deliberately so : a labelled figure keeps its caption at the bottom and reads left, the position Quarto defaults it to, while an unlabelled one carries no number to hang that line on and is centred with the top-located captions.

- `link-citations: true` on the Word format, so a citation hyperlinks to its bibliography entry instead of printing a dead marker.
  Pandoc defaults the key to `false` and it reaches `docx` and PDF only: the HTML writer anchors citations on its own, and the Typst format hands `@key` to Typst's bibliography engine rather than to citeproc, so `docx` is the single format here that consumes it.
  The link lands styled rather than dangling, which is not a given for this template: Pandoc resolves a style by its `w:name` and not by its identifier, so the `Hyperlink` it asks for reaches `template.dotx`'s `Lienhypertexte`, and the bibliography it anchors into reaches `Bibliographie` the same way (measured on a probe carrying one citation, whose run comes back as `<w:rStyle w:val="Lienhypertexte"/>`).

### Changed

- `gt` tables follow the dark scheme instead of staying on the light palette their R code resolved.
  A `gt` table writes its own colours into a `<style>` block scoped by the table's generated id, so the page renders a light card on a dark ground, and nothing in a stylesheet could reach it: every selector in that block carries an id, which no id-free rule can outrank whatever its class count.
  Quarto ships its own `table.gt_table { color: var(--quarto-body-color); background-color: transparent }` and loses for exactly that reason.
  The rules therefore carry `!important`, and they are the one `scss:rules` region outside `theme-base.scss`: they must exist in a single scheme, the light palette being already right, and being compiled into the dark bundle alone is what scopes them, with no dependency on the `body.quarto-dark` class the toggle script adds after the sheet is live.
  Text and the rules that structure the table follow `var(--bs-body-color)`, Bootstrap's own mirror of `$body-color`, which the theme exposes no `:root` counterpart for, and the hairlines between cells are drawn from `$neutral`, so those are what a consumer re-tints to move a table.
  The two surfaces are the page's own pair rather than a neutral grey, which is what keeps a dark table the counterpart of the light one instead of a second design: the blocks a light table leaves on the page background (column labels, striped rows, footnotes) take `$primary-surface`, the colour the page carries, and the table ground takes `$primary-back`, the tint the TOC sidebar is painted with, which is the pairing a light house table already lands on.
  Per channel the two sit (2, 4, 5) apart in dark against (13, 5, 0) in light, which reads as a wider gap than it is: in CIE lightness they measure 1.86 and 2.18, so the striping is about as faint in either scheme, sRGB's curve giving a small step near black more lightness than a larger one near white.
  Going the other way is not available: `gt` validates each colour option through `html_color()` and rejects `var()`, `currentColor` and `inherit`, so no theme token can be handed to `gt::tab_options()` in the first place.
  Measured on a probe rendering a plain `gt` table and one carrying the palette `hebstr::theme_gt()` writes; the light bundle carries no rule from this change, so light output is untouched.

- The light/dark toggle now sits at the top of the TOC sidebar, above the table of contents and centred on that panel, instead of beside the document title.
  `filters/toggle-position.html` inserts a `.hebstr-toggle-row` as the first child of `#quarto-margin-sidebar` and moves the control into it ; the `.hebstr-title-row` it used to build around the `h1` is gone, and so are its two theme rules.
  The margin sidebar leaves the layout below Quarto's breakpoint, and a toggle parked inside it would leave with it, so the same function hands the control back to the parent it was found in, floating `top-right` again, and a frame-throttled `resize` listener re-runs it on both sides of that threshold.
  The `aria-label` the control gained in 1.2.1 is unchanged.

- The `prettier` hook of `prek.toml` widens from the stylesheets to the HTML and JS the extension ships (`filters/toggle-position.html`, `filters/add-code-files.js`), which held no format gate until now, and skips `tests/fixtures/` so the verbatim test inputs stay byte-identical.
  `filters/toggle-position.html` is reformatted to that gate ; no rendered output, public SCSS variable or CSS custom property changes.

### Removed

- `$surface-default` and `$figure-shadow`, two public SCSS variables that nothing consumed, together with their `--surface-default` and `--figure-shadow` counterparts under `:root`.
  Both were declared with `!default` in each scheme file and mirrored in `theme-base.scss`, so surfaces 2 and 3 of `CONTRIBUTING.md` promised a consumer that overriding them moved something; neither was read by a single rule, so an override compiled clean and changed nothing.
  `var(--figure-shadow)` never appeared in any commit of this repository; `var(--surface-default)` lost its last consumer when the `gt` override above moved to the page's own surface pair.
  `$surface-default` carried a second cost: its name announces the theme's default surface where the real ones are `$primary-surface` and `$primary-back`, which is the confusion the first pass at that override fell into.
  Breaking under the strict table, shipped under MINOR rather than MAJOR per the no-consumer clause in [CONTRIBUTING.md](CONTRIBUTING.md).

### Fixed

- A `gt` table wider than the body column compresses its columns instead of hiding them behind a horizontal scrollbar.
  `gt` declares the table width in pixels and wraps the table in a scrolling container, so anything past the column edge was reachable only by scrolling ; `table.gt_table` now caps at `max-width: 100%`, which leaves the declared width alone wherever it fits.

## [1.4.0] - 2026-08-29

### Added

- Numbered annexes, through a custom `anx` crossref type declared in `_extension.yml` and reached by `filters/crossref-anx.lua`.
  An annexe is captioned *Annexe n.*, referenced as `@anx-...`, and counted in a sequence of its own, shared by the three forms that can produce one.
  Quarto has no appendix type of its own: the built-in list stops at fig/tbl/eq/sec/lst and the theorem family, and `crossref: appendix-title` letters the chapters of a book project and reaches nothing else.
  A chunk cannot carry an `anx-` label either, the knitr engine building a float only from a label matching `^#?(fig|tbl)-` and dropping any other before it reaches Pandoc, so an annexe is authored as `tbl-anx-x` or `fig-anx-x` and the filter strips that carrier prefix at `pre-quarto`, the one stage where the float node is built and still mutable.
  The carrier earns its place twice over: it decides whether `tbl-cap` or `fig-cap` is read, and it leaves the block an ordinary table or figure, still visible and still captioned, should the filter ever stop running.
  A hand-written `::: {#anx-x}` div carries no prefix and joins the same counter.
  `theme-base.scss` extends the rule that centres a float caption to the new type, which has no styling of its own.
  Declared for all three formats and asserted in HTML by `tests/anx-float.sh`, which renders its own probe: a float that stopped reaching the type would lose its number and caption without failing the render.
  Numbering is in digits: `anx-labels` does not exist, the `crossref` schema being closed, and lettering would mean pinning five other `*-labels` keys back to arabic in every document for a cosmetic effect on one type.

- Figure SVGs carry the body font with them, so they no longer fall back to another face on a machine without Luciole installed.
  An SVG lands in the page as `<img src="data:image/svg+xml;base64,…">`, and an SVG referenced by `<img>` is an isolated document: it never reaches the `@font-face` rules of `fonts/fonts.css`, so its `font-family` resolves against the reader's installed fonts alone.
  Tables, being ordinary nodes of the parent document, were unaffected, which is what made the gap look like a figure-only quirk.
  `fonts/register.R` now embeds the Luciole regular and bold faces into every svglite figure as `@font-face` blocks with a base64 WOFF2 `src:`, adding roughly 114 KB per figure.
  Those two faces only: figure text set in italic, and anything monospaced, which the format's `mono` alias sends to Fira Code, still resolves against the reader's installed fonts.
  It calls `svglite::font_face(woff2 = <data URI>)` and builds the URI itself, which keeps the `;charset=utf-8` token `embed = TRUE` adds off a binary payload; the form to avoid is `local = <family>` with `embed = TRUE`, which resolves the family through `systemfonts::font_info()` and embeds whichever file that yields, a system TTF where one is installed, at many times the weight.
  The faces are built on first use rather than at source time, so an interactive session that never renders does not pay the encoding.
  Injection goes through `knitr::opts_hooks$set(dev = )` rather than `opts_chunk$set()`: a hook runs after option resolution, so it survives both a chunk setting its own `dev.args` and the format applying its value after `.Rprofile` has run.
  It merges, so a chunk keeps its own `bg`.
  `!expr` in the format's `knitr.opts_chunk` was tried first and does not work: Quarto passes the tagged node through unevaluated and the render fails on `unused arguments (value = …, tag = "!expr")`.
  That tag is a knitr chunk-option feature, not a Quarto metadata one.

- R code blocks colour the package name in front of `::` and `:::`, and read `library`/`require`/`requireNamespace` as keywords rather than as ordinary calls.
  Pandoc's stock R definition emits no token for either, so no stylesheet could reach them: the package name arrived as unstyled normal text and `library` was indistinguishable from any other function call.
  `syntax/r.xml` supplies both missing rules, `filters/r-syntax.lua` routes R blocks to it, and the theme colours the resulting `.im` token.
  Applies to HTML and DOCX, the two formats Pandoc highlights itself; Typst re-emits a raw fence and highlights it through `code.tmTheme`, which is unchanged.
  The definition derives from the KDE Kate module for R and is **GPL v2**, the extension's one copyleft component, attributed in `syntax/RSyntax.LICENSE` and listed in [LICENSE.md](LICENSE.md).
  It is taken at upstream version 14 while Quarto bundles version 12, so the two rules above are not the whole of what changes: the `:=` entry below comes with that newer base, as does a `.dt` token on the `L` and `i` suffixes of an integer or complex literal, which the theme colours with the other numeric literals rather than leaving on Quarto's light fallback.

- `$font-size-root` joins the public SCSS variables, at `1rem`.
  Quarto declares it at `17px` in its own Bootstrap layer, and a theme layer is applied first, so the document now takes the reader's browser root size instead.
  It reaches the page as `--bs-root-font-size` on `html`, which every `rem`-derived size, padding and margin in the document scales against, so overriding it rescales the whole document from one knob.

### Changed

- R code blocks colour their punctuation.
  The argument separator and the `=` of a named argument take the operator colour; brackets of every shape, round, curly and square, take the namespace gold.
  Upstream tokenises none of the three: the first two fall through to normal text and brackets map to `dsNormal`, which skylighting emits without a span at all, so no stylesheet could reach any of them.
  Colouring brackets means borrowing a token style that nominally means something else, skylighting exposing a closed set of them; `dsRegionMarker` carries them, so `.re` is gold from now on wherever it appears, in any language.
  The `=` rule also splits `n =` into two tokens where it used to be one, so an argument name keeps `.at` and only the `=` moves.

- `.im` no longer shares the keyword colour.
  It is now `#fad430` against `#d08aff` for `.kw`/`.cf`, which is what makes the package name legible as a namespace rather than as a keyword.
  Languages other than R that emit `.im` are affected too: a Python `from x import y` now renders its `import` and `from` in the same gold.

- Code blocks are no longer bold as a whole.
  Weight is reserved for `.kw`, `.cf`, `.im` and `.cn`, so identifiers, strings, numbers and function calls render at normal weight.

- Code type sizes are harmonised.
  A code block and an inline `code()` span outside one both sit at `0.9rem`, and the code-fold summary label drops to `0.8rem` so a filename header reads as chrome rather than as content.

- `$toc-font-size` drops from `0.825rem` to `0.8rem`, which settles the table of contents on the same step as the code-fold label.

### Fixed

- `:=` no longer renders its `=` as an error token in R code.
  Quarto's bundled R definition predates the rule that reads the pair as a single operator, so `data.table`'s `DT[, x := 1]` and rlang's `!!name :=` arrived as a `.sc` colon followed by an `.er` equals.
  The rule comes with the upstream base `syntax/r.xml` is taken at, rather than being one of the two added here.

- Comment and line-number contrast inside code blocks, both of which failed WCAG AA against the code surface.
  `$code-comment-color` moves from `#6c675f` to `#8d8d8d` (2.70:1 to 4.57:1) and `$code-window-line-number` from `#5a5955` to `#7b7a76` (2.16:1 to 3.53:1).
  `$code-comment-color` also backs the code-block selection band and the copy-button hover, both of which lighten with it.

- `fonts/register.R` reads the `.woff` faces rather than the `.woff2` ones.
  FreeType decodes WOFF with zlib, which every build carries, but WOFF2 only where brotli was compiled in, so the registration silently produced nothing on a build without it and the figure fell back to the system sans.
  Both formats ship beside the script and carry identical metrics; `fonts.css` keeps WOFF2 for the browser, which needs no such caveat.

## [1.3.0] - 2026-08-01

### Added

- `fonts/register.R` ships beside the font files and makes the bundled Luciole and Fira Code usable on a machine that has neither installed.
  A project activates it with one `source()` from its `.Rprofile` or a setup chunk; the script locates its own directory while being sourced, so no font path leaks into the project.
  It skips any family the system already provides, `systemfonts::register_font()` being an error on an installed one, and it covers both routes to the font: the plots that name their family, and the generic `system_fonts` alias below, which resolves through the same registry.
  Without it, `svglite` writes the fallback family it matched, so the figure claims a family nobody asked for and carries the wrong metrics.
  This settles the render side only: an SVG inserted as `<img>` never sees the page's `@font-face` rules, so which typeface a reader sees still depends on what that reader has installed.

### Changed

- HTML figures render through `svglite` (`dev: svglite`) instead of R's built-in cairo device.
  Cairo bakes every figure label into vector paths; `svglite` writes them as `<text>`, so they stay selectable and searchable and the file runs several times lighter, which compounds under `embed-resources: true`.
  **The `svglite` R package becomes a render-time requirement for the HTML format**, and it covers more than the documents that draw.
  knitr resolves the device when it opens a chunk, so one that merely prints a table fails the same way, on `there is no package called 'svglite'`; only a document with no R chunk at all is spared.
  A document returns to the cairo device with `knitr: { opts_chunk: { dev: svg, dev.args: null } }`, the second key being required because `svg()` rejects the `svglite`-only font arguments the format sets.
  That override is the documented fallback, so the new requirement ships under MINOR rather than MAJOR; the no-consumer clause in [CONTRIBUTING.md](CONTRIBUTING.md) covers it either way.
  Typst and DOCX are unaffected.

- HTML figures alias the generic `sans` and `mono` families to `Luciole` and `Fira Code`, so a plot that names no font matches the document typography instead of landing on `Liberation Sans`.
  Only the generics move: a plot asking for a family explicitly (`par(family=)`, ggplot's `base_family=`) resolves through another path and is untouched.
  The alias reads the rendering machine's fonts and degrades silently to the fallback family where they are missing, unless `fonts/register.R` above has supplied them.
  A chunk that sets `dev.args` for another purpose replaces the alias rather than extending it and falls back.

### Fixed

- The light theme's `$primary-surface` mixed 2% of `$primary` into what is meant to be the page white, tinting the body background, the appendix block and the blockquote border that fill from it.
  Its default is plain white.

## [1.2.1] - 2026-07-26

### Added

- `{{< filetree >}}` resolves more file types to a specific icon: extensions `mjs`, `cjs`, `rmd`, `htm`, `jsonc`, `json5`, `ttf`, `otf`, `gif`, `webp`, `avif`, `doc`, `odt`, `rtf`, and the names `.Rhistory`, `.luacheckrc`, `typst.toml`.
  They previously fell through to the generic `ft-i-document`, so a consumer overriding that class no longer reaches them.
  No new SVG ships.

- `{{< script >}}` names a malformed call site instead of absorbing it: an extra positional argument, an unknown attribute, a non-boolean `numbers`, a `lines` spec that is not a range or ends before it starts, and a non-numeric `dedent` each raise a render warning and fall back to the documented default.
  `numbers` accepts `true`/`yes`/`on`/`1` and their negatives, case-insensitively, matching `hidden` on `{{< filetree >}}`.

- The color-scheme toggle and the callout icons carry alternative text.
  The toggle sits beside the title in a `.hebstr-title-row` rather than inside the `h1`, so it no longer joins the heading's accessible name or its heading-navigation target, and it gains an `aria-label`.

### Changed

- The three theme stylesheets and `fonts/fonts.css` are brought to conformance with a new SCSS lint/format gate (`stylelint`, `prettier`), pinned in `package.json`.
  No public SCSS variable, CSS custom property, or compiled colour changes.

- `template.typ` drops a `#set document()` that configured nothing and a redundant `#show heading` rule.

### Fixed

- `{{< script >}}`: the summary rewriter threw on the first code block rendered without `code-fold`, aborting the script so no block on the page got its filename.

- `{{< filetree >}}`: a `highlight` match on an expandable folder rendered without `$filetree-highlight` or its bold weight in `dynamic` mode.

- `{{< filetree >}}`: a blank line or a `#` comment inside the `filetree:` block of the sidecar ended the sequence being read, so `exclude` and `highlight` silently lost every pattern written after one.
  A key left empty now falls through to its default instead of handing a list to the readers of `root`, `depth`, `hidden` and `mode`.

## [1.2.0] - 2026-07-21

### Added

- `{{< filetree >}}` shortcode: renders a directory tree walked from disk at render time.
  Config via a `filetree.yml` sidecar (`root`, `depth`, `mode`, `exclude`, `highlight`, `hidden`, `paths`); every key but `paths` is also a shortcode attribute overriding the sidecar, while `paths` supplies quoted inline-Markdown per-entry descriptions.
  HTML emits a nested `.filetree` list, other formats a bullet list.
  `root` and `annotations` resolve from the project root, a single-file render from the document's own directory.
  Malformed call sites raise a render warning.
- Filetree theming: dark surface in both light and dark modes, driven by five invariant SCSS variables (`$filetree-bg`, `$filetree-fg`, `$filetree-muted`, `$filetree-highlight`, `$filetree-guide`).
  Per-type icons (curated Material Icon Theme subset, MIT) inlined as a `--ft-icon` custom property so the page stays self-contained; the `ft-i-<key>` class overrides one icon from a `custom.scss`.
  Icons never carry meaning alone: directories keep their trailing slash, highlighted entries are wrapped in `<strong>`, and the truncation marker is labelled for assistive technology.
- `mode` attribute and sidecar key for `{{< filetree >}}`: `dynamic` renders each expandable folder as a JavaScript-free collapsible `<details>/<summary>`, with `depth` as the level open on load.
  `static` (default) keeps the full tree to `depth`; non-HTML formats ignore `mode`.

### Changed

- `$tab-background` renamed to `$tab-surface`, now exposed at `:root` so it is overridable from a `custom.scss`.
  The old variable drove no rule, so nothing regresses.

- The `grid` defaults tighten: `body-width` from 1100px to 1000px and `margin-width` from 600px to 450px.
  Both remain frontmatter overrides.

### Removed

- `fontsize: 1.2rem` is no longer declared by `hebstr-doc-html`; body text falls back to the Bootstrap default Quarto ships.
  `fontsize` is a stock Quarto key, so a consumer wanting the previous measure declares it themselves.
  Shipped under MINOR rather than MAJOR per the no-consumer clause in [CONTRIBUTING.md](CONTRIBUTING.md).

### Fixed

- `{{< script >}}`: `dedent=n` stripped every space in the first `n` columns instead of the leading indentation, dropping an interior space on lines indented by less than `n`.
  It now removes leading spaces only, at most `n`.

## [1.1.0] - 2026-07-07

### Added

- SVG lightbox figures scale to fit the viewport instead of displaying at their small intrinsic size.
  Scoped to SVG; raster figures keep Quarto's default fit.

### Changed

- HTML figures render as SVG (`fig-format: svg`) via R's built-in cairo device instead of the default raster, with no added R dependency.
  Opt into the `svglite` device per document with `knitr.opts_chunk.dev: svglite`, or render raster with `fig-format: png`.
  Scoped to `hebstr-doc-html`; Typst and DOCX keep `default-image-extension: png`.

## [1.0.0] - 2026-04-29

First public stable release.
The public API surface (formats, SCSS variables, CSS custom properties, frontmatter keys, shortcodes, bundled fonts, `quarto-required`) is now versioned per [CONTRIBUTING.md](CONTRIBUTING.md): MAJOR for breaking changes, MINOR for additions, PATCH for fixes.

### Added

- Public SCSS API for layout chrome: `$navbar-bg`, `$navbar-fg`, `$navbar-hl`, `$sidebar-bg`, `$sidebar-fg`, `$sidebar-hl`, `$footer-bg`, `$footer-fg`.
  These are consumed by Quarto's Bootstrap layer at compile time and only take effect in project layouts (book, website); single-document renders are unaffected.
  No CSS custom property counterpart is exposed.
- [CONTRIBUTING.md](CONTRIBUTING.md): public API surface, SemVer policy, release procedure, local validation, repo layout.

### Changed

- Consumers using `title-block-banner: true` on `hebstr-doc-html` see their banner background switch from Quarto's slate-blue default (`#517699`) to the hebstr navbar-bg, which Bootstrap-Quarto couples to `$navbar-bg`.
  Opt out with `title-block-banner: false`, by overriding `.quarto-title-banner { background: ... }`, or by overriding `$navbar-bg`.

## [0.12.0] - 2026-04-28

### Changed

- **Breaking**: extension renamed `hebstr` → `hebstr-doc` and repo renamed `quarto-hebstr` → `quarto-hebstr-doc`.
  Re-run `quarto add hebstr/quarto-hebstr-doc` and update `format:` to `hebstr-doc-html` / `hebstr-doc-typst` / `hebstr-doc-docx`.

### Added

- Frontmatter overrides for the most common aesthetic knobs: `mainfont`, `monofont`, `fontsize`, `linestretch` (joining `page-layout`, `toc*`, `grid.*`).
- `_brand.yml` interop: `$primary` / `$secondary` defer to Quarto's brand layer and derived shades recompute, so cross-format brand colours and typography work without any extension change.
- Release pipeline via GitHub Actions: `render.yml` (HTML render on push/PR), `pages.yml` (deploy demo), `release.yml` (GitHub Release on `v*` tag).

### Fixed

- `linestretch` from the YAML is respected.
  A hardcoded `p { line-height: 1.75rem }` shadowed Bootstrap's `$line-height-base` and silently ignored any consumer override; `linestretch: 1.75` (the new default) reproduces the prior look.

## [0.11.0] - 2026-04-27

### Added

- Light and dark theme support, switchable via Quarto's color-scheme toggle (sun/moon icon, anchored in the document title).
- Font Awesome 7 Solid bundled locally (no CDN dependency at render time).

### Changed

- **Breaking** for consumers overriding the theme directly: the single `theme.scss` is gone.
  Use `format: hebstr-html` (recommended), or wire `theme: { light: [theme-light.scss, theme-base.scss], dark: [theme-dark.scss, theme-base.scss] }`.
- Callout colors adapt to the active theme.
  `tip` and `warning` body text are slightly darker than before.
- `anchor-sections: false` by default.

## [0.10.0] - 2026-04-26

### Added

- Self-contained `example.qmd` demonstrating the theme (HTML).
- `script` shortcode for injecting external scripts: `{{< script path/to/file.R >}}` auto-derives language and filename, renders inside a foldable code block.
  Optional args: `lang=`, `filename=`, `numbers=`, `lines=10-30`, `dedent=N`, `suffix=`.
- Embedded [`mcanouil/code-window`](https://github.com/mcanouil/quarto-code-window) for code-block chrome (HTML + Typst).

### Changed

- **Breaking**: extension renamed `hebstr-template` → `hebstr`.
  Re-run `quarto add hebstr/quarto-hebstr` and update `format:` to `hebstr-html` / `hebstr-typst` / `hebstr-docx`.
- **Breaking**: `lang` removed from common defaults.
  Declare your own `lang:` in `_quarto.yml`.
- `quarto-required` bumped to `>=1.9.36`.

## [0.9.0] - 2026-04-24

### Added

- Initial multi-format Quarto extension (`hebstr-html`, `hebstr-typst`, `hebstr-docx`) with bundled Luciole + Fira Code fonts.
