# Changelog

All notable changes to this project are documented in this file.
The project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### New Features

- feat: Set the DOCX title in 24 pt and the subtitle in 20 pt, so the title block takes less room.

### Bug Fixes

- fix: Centre the callout icon and the collapse chevron on the first line of the title, with or without a body.
- fix: Let the text fill a phone screen under 768 px, with a 1 rem margin instead of the 4.5 rem bands of the desktop layout.
- fix: Style the colour toggle of a phone like the desktop rail's, so it stays visible on the dark scheme.
- fix: Wrap long URLs in links, references and notes at the column edge, so a long link no longer widens the page on a phone.
- fix: Keep each file tree entry on one line on a phone and scroll the tree sideways like a code block, so descriptions no longer wrap.

## 1.14.0 (2026-11-18)

### New Features

- feat: Scale a `gt` table wider than its column as one block, so it keeps its grid and proportions at any window width with no horizontal scroll.
- feat: List the authors of the HTML title block on one line with a superscript number per affiliation, each affiliation written once beneath.
- feat: Set the title in 1.5 rem and the subtitle in 1.25 rem, so the title card takes less room.

### Bug Fixes

- fix: Keep the highlighted table-of-contents entry on the heading being read on wide screens.
- fix: Leave the colour-scheme toggle and the format links where Quarto puts them on a website with a navbar.
- fix: Name the left rail as a landmark, hide Quarto's emptied toggle container and keep keyboard focus on the toggle across the 768 px breakpoint.

## 1.13.2 (2026-11-16)

### Bug Fixes

- fix: Keep a `gt` table's white-filled rows readable in dark mode.

## 1.13.1 (2026-11-16)

### Bug Fixes

- fix: Pair a figure with its dark twin when the document sits in a subfolder of a project.

## 1.13.0 (2026-11-16)

### New Features

- feat: Widen the margin column to 500 px and narrow the text column to 950 px.
- feat: Widen the page's side gutters from 3 rem to 4.5 rem, which takes 48 px from the text column at 1440 px.
- feat: Scale the whole page with the window width beyond 1440 px; `html { zoom: 1 }` restores the fixed layout.
- feat: Show the colour-scheme toggle and the `format-links` as icons in a fixed rail on the left edge, stacked under the floating toggle below 768 px.
- feat: Scroll the table of contents to keep the active heading at the vertical middle of the window.
- feat: Set the top-level entries of the table of contents in bold and the table of contents in 0.75 rem instead of 0.8 rem.
- feat: Set the bibliography in 0.75 em in HTML, as the Word template does.
- feat: Raise the default `linestretch` of the HTML output from 1.75 to 2.
- feat: Switch a figure with the light and dark scheme when `name-light.svg` has a `name-dark.svg` twin beside it.

### Bug Fixes

- fix: Keep the table of contents within the window above 1440 px.

## 1.12.0 (2026-11-08)

### New Features

- feat: Highlight Python code from the theme's own syntax definition, in HTML and in Word, with the colours of a Python editor.
- feat: Colour the code tokens left to Quarto's own palette: raw strings, hexadecimal and binary literals, string escapes, exception names and `TODO` in a comment.
- feat: Lead a code block's name with a larger icon on a title bar and on the folded header of a `{{< script >}}` block, with a `</>` glyph for a language the theme ships no icon for.

### Bug Fixes

- fix: Apply the syntax palette to inline highlighted code.
- fix: Bring `h6` into the heading ladder.
- fix: Fit a callout's icon to its glyph.
- fix: Strip the heading ladder's underline and indentation from a heading in the margin column.
- fix: Keep a code window's line numbers out of the code's accessible text.
- fix: Name the file tree's list structure explicitly, so the hierarchy survives in a browser that drops list semantics.
- fix: Fall back to the closed folder icon when a dynamic file tree cannot read its open variant.

## 1.11.0 (2026-11-07)

### New Features

- feat: Show the language's icon beside the name in a code window's title bar, for the twenty languages the theme ships one for.
- feat: Tint the header of a folded code block to follow the light and dark schemes.

### Bug Fixes

- fix: Set a level-4 heading in italic again in Word output.
- fix: Keep a font family you registered yourself when `fonts/register.R` is sourced.
- fix: Name the `source()` call `fonts/register.R` needs when it is reached another way.

## 1.10.0 (2026-10-30)

### New Features

- feat: Write a URL in a Word comment as a link.
- feat: Read the `script` shortcode's `lines` given as a single number as that line alone.

### Bug Fixes

- fix: Report a `dedent` that is not a whole number of spaces, a `lines` range that selects no line and a path the shortcode cannot read, instead of truncating, rendering an empty block or failing in silence.
- fix: Send every diagnostic of the shortcode through the render warning channel.
- fix: Clamp a `lines` range starting below line 1.

## 1.9.0 (2026-10-29)

### New Features

- feat: Render a callout as body text in Word rather than as a bordered table; a callout carrying an identifier keeps its table.

## 1.8.0 (2026-10-28)

### New Features

- feat: Carry a reply to a Word comment back as a Word comment of its own; add `scripts/thread-docx-comments.py` to `project: post-render:` to nest the replies.

## 1.7.4 (2026-10-26)

### Bug Fixes

- fix: Name on standard error a comment store the extension cannot read.
- fix: Name and ignore a `collab-comments` option written as a single value instead of a block of keys.

## 1.7.3 (2026-10-26)

### Bug Fixes

- fix: Read the straight and the typographic apostrophe as one character when anchoring a Word comment.

## 1.7.2 (2026-10-26)

### Bug Fixes

- fix: Anchor a Word comment whose stored position no longer matches the source wherever the source carries its selected text exactly once.
- fix: Keep a figure inside the text column in Word and style the overall caption of a figure laid out in panels like any other.
- fix: Place the parts of a two-column layout one after another at full width in Word.
- fix: Align the sub-captions of one float the same way in Word.

## 1.7.1 (2026-10-24)

### New Features

- feat: Open a new page on a level-1 heading in Word.
- feat: Set Word references at 9 pt through the `Bibliography` style.

### Bug Fixes

- fix: Keep a list written with a blank line between its items at the prose size and line spacing in Word.

## 1.7.0 (2026-10-24)

### Breaking Changes

- refactor: Remove the `hebstr-doc-typst` format; for a PDF, export the Word output from Word.

### New Features

- feat: Carry Word comments imported from a reviewed `.docx` back into the Word output (`docx-comments: true` under `collab-comments:`).

### Bug Fixes

- fix: Stop reading a trailing comment in `filetree.yml` as part of the value.
- fix: Warn on an empty description under `paths`, on two `paths` keys differing only by a trailing slash, and on a profile written on one line or under a quoted name.
- fix: Render nothing for a named profile whose `filetree.yml` cannot be parsed.

## 1.6.0 (2026-09-26)

### Breaking Changes

- refactor: Remove the `filetree:` key from `filetree.yml`: its top-level keys are profiles and `{{< filetree >}}` renders `default`.

### New Features

- feat: Hold several named profiles in `filetree.yml`, `{{< filetree name >}}` rendering the profile `name`.
- feat: Recognise `.log` and `.txt` files in the `script` shortcode.
- feat: Label a code block with no language `default` and frame it like a highlighted one; `code-window-enabled="false"` keeps it plain.
- feat: Frame the printed output of a chunk whose code is hidden under the `default` header; `collapse: false` shows it as plain output.

### Bug Fixes

- fix: Follow `fig-align` again in HTML.

### Refactoring

- build: Update the embedded `code-window` extension from 1.1.5 to 1.5.1.

## 1.5.0 (2026-09-22)

### Breaking Changes

- refactor: Remove the SCSS variables `$surface-default` and `$figure-shadow` and their CSS custom properties.

### New Features

- feat: Follow the dark scheme in an unthemed `reactable` table and in a `gt` table.
- feat: Justify and hyphenate body text in HTML, matching the Word output.
- feat: Give a figure without a cross-reference label the float caption style, centred.
- feat: Link a citation to its bibliography entry in Word output (`link-citations: true`).
- feat: Accept a `*` wildcard in a `filetree` key under `paths`.
- feat: Add `filetree` icons for spreadsheets, presentations, PDF, SVG, BibTeX, shell scripts, logs, databases and data files, XML and CSL, and Rust.
- feat: Add `scripts/check-docx.R`, which checks a rendered `.docx` or the `.dotx` template for the properties Word output depends on.
- feat: Add `scripts/build_template.py`, which rebuilds `template.dotx` from Pandoc's reference document.

### Bug Fixes

- fix: Let Word open a document holding a cross-referenced `flextable` or `gt` table.
- fix: Keep a cross-referenced table at its own width in Word.
- fix: Style a Word caption by its position, `Table Caption` above and `Image Caption` below.
- fix: Take the Word table of contents title from the document language and start the body on the page after it.

### Refactoring

- refactor: Produce no output from `{{< script >}}` outside HTML.
- refactor: Use the dedicated SVG icon for a `.svg` file in `filetree`.
- build: Rebuild `template.dotx` from Pandoc's reference document, 12 KB down from 562 KB; Word output changes with it (Aptos text, 11 pt body at 1.5 line spacing, title block on its own page).

## 1.4.0 (2026-08-29)

### New Features

- feat: Number annexes through a custom `anx` cross-reference type, labelled `tbl-anx-<name>`, `fig-anx-<name>` or `anx-<name>` and referenced as `@anx-<name>`.
- feat: Mark the package name before `::` and `:::` in R code and treat `library`, `require` and `requireNamespace` as keywords.
- feat: Colour the argument separator, the `=` of a named argument and the brackets in R code.
- feat: Give the import and namespace token `.im` its own colour, `#fad430`.
- feat: Embed the Luciole regular and bold faces in a figure's SVG when `fonts/register.R` is sourced.
- feat: Add the public SCSS variable `$font-size-root`, defaulting to `1rem`.

### Bug Fixes

- fix: Stop highlighting the R `:=` operator as an error.
- fix: Raise code comments and line numbers to the WCAG contrast ratio against the code surface.
- fix: Register the bundled fonts on a system whose FreeType lacks WOFF2 support.

### Refactoring

- refactor: Keep bold for keywords, imports and constants alone instead of a whole code block.
- refactor: Harmonise the type scale, code blocks and inline code at `0.9rem`.

## 1.3.0 (2026-08-01)

### Breaking Changes

- build: Require the `svglite` R package for the HTML format.

### New Features

- feat: Add `fonts/register.R`, which makes the bundled Luciole and Fira Code fonts available to R graphics devices.
- feat: Map the generic `sans` and `mono` font families to Luciole and Fira Code in HTML figures.

### Bug Fixes

- fix: Keep the light theme page background plain white.

## 1.2.1 (2026-07-26)

### New Features

- feat: Add `filetree` icons for more file types.
- feat: Warn on an invalid argument to `{{< script >}}` instead of ignoring it.
- feat: Give the colour-scheme toggle and the callout icons alternative text.

### Bug Fixes

- fix: Keep filenames showing on the rest of the page when a `{{< script >}}` block carries no `code-fold`.
- fix: Keep a highlighted folder styled in `filetree`'s `dynamic` mode.
- fix: Read past a blank line or a comment in the `filetree` sidecar.

## 1.2.0 (2026-07-21)

### Breaking Changes

- refactor: Stop setting `fontsize: 1.2rem` in the HTML format.
- refactor: Rename `$tab-background` to `$tab-surface` and expose it as a CSS custom property.

### New Features

- feat: Add the `{{< filetree >}}` shortcode, which renders a directory tree read from disk, configured by a `filetree.yml` sidecar or shortcode attributes.
- feat: Add `mode: dynamic`, which renders the tree with collapsible folders and no JavaScript.

### Bug Fixes

- fix: Remove only the leading indentation with `{{< script >}}`'s `dedent`.

## 1.1.0 (2026-07-07)

### New Features

- feat: Render HTML figures as SVG instead of PNG; `fig-format: png` restores raster output.
- feat: Scale an SVG figure in the lightbox to fit the viewport.

## 1.0.0 (2026-04-29)

First stable release.

### New Features

- feat: Add SCSS variables for the navbar, sidebar and footer of a website or a book: `$navbar-bg`, `$navbar-fg`, `$navbar-hl`, `$sidebar-bg`, `$sidebar-fg`, `$sidebar-hl`, `$footer-bg` and `$footer-fg`.
- feat: Use the navbar colour for the title block banner under `title-block-banner: true`.

## 0.12.0 (2026-04-28)

### Breaking Changes

- refactor: Rename the extension to `hebstr-doc` and the repository to `quarto-hebstr-doc`.

### New Features

- feat: Read the front matter options `mainfont`, `monofont`, `fontsize` and `linestretch`.
- feat: Take colours and typography from `_brand.yml`.

## 0.11.0 (2026-04-27)

### Breaking Changes

- refactor: Split `theme.scss` into `theme-base.scss`, `theme-light.scss` and `theme-dark.scss`.

### New Features

- feat: Add a light and a dark theme, switchable from the page.
- feat: Bundle the Font Awesome 7 icons locally.
- feat: Follow the active theme in the callout colours.

### Refactoring

- refactor: Turn section anchors off by default.

## 0.10.0 (2026-04-26)

### Breaking Changes

- refactor: Rename the extension to `hebstr`.
- refactor: Stop setting `lang` by default.
- build: Require Quarto 1.9.36 or later.

### New Features

- feat: Add the `{{< script >}}` shortcode, which includes an external file as a foldable code block.
- feat: Embed the `mcanouil/code-window` extension, which gives a code block its filename header.

## 0.9.0 (2026-04-24)

### New Features

- feat: Add the HTML, Typst and Word formats, with the Luciole and Fira Code fonts bundled.
