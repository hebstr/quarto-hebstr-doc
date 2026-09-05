# hebstr-doc

[![Render](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/render.yml/badge.svg)](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/render.yml)
[![Pages](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/pages.yml/badge.svg)](https://hebstr.github.io/quarto-hebstr-doc/)
[![Release](https://img.shields.io/github/v/release/hebstr/quarto-hebstr-doc?label=release)](https://github.com/hebstr/quarto-hebstr-doc/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

A Quarto theme for HTML, Typst (PDF), and Word (DOCX) output.

> **Status (v1.4.0):** HTML is operational.
> Typst and DOCX are declared but not yet validated.

## Installation

```bash
quarto add hebstr/quarto-hebstr-doc
```

The HTML format draws figures on the `svglite` device, which `quarto add` does not install:

```r
install.packages("svglite")
```

Any document running an R chunk needs it, whether or not that chunk draws.
knitr resolves the device when it opens a chunk, so one that only prints a table fails the same way, on `there is no package called 'svglite'`.
A document with no R chunk at all is unaffected.
To stay on R's built-in cairo device instead, override both keys, the second dropping the `svglite`-only font arguments that `svg()` would reject:

```yaml
knitr:
  opts_chunk:
    dev: svg
    dev.args: null
```

## Usage

```yaml
---
title: "My Document"
format: hebstr-doc-html
---
```

The format targets the single self-contained document, so it sets `embed-resources: true` and every asset, fonts included, is inlined into the `.html`.
A project layout renders fine but pays that cost per page: measured on a two-page website, 3.6 MB per page against 31 KB with the option off, and `site_libs/` is written either way, so the assets are duplicated rather than moved.
Turn it off in the project config when the output is a website or a book:

```yaml
format:
  hebstr-doc-html:
    embed-resources: false
```

## Shortcodes

### `script`

Injects an external file as a code block with the code-window chrome, so the script stays a file on disk, not a copy in the document.

```markdown
{{< script scripts/demo.R >}}
```

  | Attribute  | Default                 | Effect                                                                                                                                                                                 |
  | ---------- | ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
  | `lang`     | from the file extension | Highlighting language, and the label shown in the title bar. An extension the shortcode does not map yields no language and no title bar                                               |
  | `filename` | the path                | Label shown on the code-fold summary                                                                                                                                                   |
  | `suffix`   | none                    | Appended to the summary label                                                                                                                                                          |
  | `numbers`  | `true`                  | Line numbers. `true`/`yes`/`on`/`1` and their negatives are all accepted, case-insensitively; anything else warns and falls back to `true`                                             |
  | `lines`    | whole file              | Range to include: `10-20`, `10-`, `-20`. A bare `12` is read as `12-`. A spec that is not a range, or one that ends before it starts, warns and reads the whole file                   |
  | `dedent`   | none                    | Leading spaces to strip, at most this many. A line indented by less is dedented as far as its own indentation allows; tabs are never touched. A non-numeric value warns and is ignored |

The path is the only positional argument; a second one warns and is ignored, as does an attribute outside the table above.

### `filetree`

Renders a directory tree read from disk at render time.

```markdown
{{< filetree >}}
```

Configuration lives in a `filetree.yml` sidecar at the project root:

```yaml
filetree:
  depth: 2
  hidden: false
  exclude:
    - "^output$"
    - "^%.git$"
  highlight:
    - "^rproject%.toml$"
  paths:
    "scripts": "one script per output"
    "scripts/_setup.R": "data recoding"
    "rproject.toml": "project dependencies"
```

  | Key         | Default  | Effect                                                                                                                                                                                                                           |
  | ----------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
  | `root`      | `.`      | Directory to walk, relative to the project root, wherever in the project the document sits                                                                                                                                       |
  | `depth`     | `2`      | Levels shown without interaction. In `static`, deeper directories collapse to `…`; in `dynamic`, they become collapsed folders that expand on click. A non-numeric value warns and falls back to `2`                             |
  | `mode`      | `static` | `static` renders the full tree to `depth`; `dynamic` makes folders collapsible native `<details>` (no JavaScript), with `depth` as the level open on load. Any other value warns and falls back to `static`                      |
  | `exclude`   | none     | [Lua patterns](https://www.lua.org/manual/5.4/manual.html#6.4.1) matched against each path relative to `root`, directories included and without a trailing slash (`^output$`, not `^output/`). Escape literals with `%`, not `\` |
  | `highlight` | none     | Lua patterns; matching entries render bold                                                                                                                                                                                       |
  | `hidden`    | `false`  | Include dotfiles. `true`/`yes`/`on`/`1` and their negatives are all accepted, case-insensitively; anything else warns and falls back to `false`                                                                                  |
  | `paths`     | none     | Descriptions, keyed by path                                                                                                                                                                                                      |

Every key except `paths` is also a shortcode attribute, overriding the sidecar for that one call: `{{< filetree root="src" depth=1 >}}`.
Attributes are the only call-site syntax; a positional argument or an unknown attribute warns.
As attributes, `exclude` and `highlight` take `|`-separated patterns with no escaping; a pattern matching a literal `|` belongs in the sidecar.
Descriptions are read from the sidecar only.
`annotations` (default `filetree.yml`) sets the sidecar path and must stay inside the project: an absolute path, a drive letter, or a `..` climbing out warns, and the call runs unconfigured.
The constraint is deliberately not mirrored on `root`, which may point anywhere, including a sibling package in a monorepo: the sidecar is opened and read, whereas `root` is only listed, so it yields entry names and never file contents.
`root` and `annotations` resolve from the project root, not the calling document, so one sidecar serves every document in the project.
Outside a project, a single-file render falls back to the document's own directory for both.
Document frontmatter is never read: `exclude` and `highlight` hold Lua patterns, which Pandoc would corrupt by parsing as inline Markdown.

Descriptions accept inline Markdown, so a path or a command can render as code.
A trailing slash on a `paths` key is optional.
A `paths` key that never appears in the tree, whether absent from disk or dropped by `exclude`, `hidden` or `depth`, raises a render warning naming it.
Quote every description: YAML reads a bare `no`, `yes`, `on`, `off`, `true` or `false` as a boolean, and the shortcode drops the annotation with a warning naming the key.
A bare `~` reaches the shortcode as an empty string and is dropped silently.

HTML renders a nested list on a dark surface in both light and dark modes, styled by the `.filetree` rules in `theme-base.scss`.
In `dynamic` mode each expandable folder is a native `<details>` element that expands without JavaScript, its Material folder icon switching to the open variant while expanded; a childless folder renders flat, the disclosure widget having nothing to reveal.
Each entry carries a [Material Icon Theme](https://github.com/material-extensions/vscode-material-icon-theme) icon, resolved by exact name, then extension, then a generic document; a directory resolves by name (only `.github` so far), then a generic folder.
Icons ship under `_extensions/hebstr-doc/icons/` and are inlined per entry, so the page makes no outside request and only the icons used are embedded.
Override one with a `background-image` on `.ft-i-<key> .ft-name::before` in a `custom.scss` placed last in `theme:`.
The combinator has to be the descendant one: `ft-i-<key>` sits on the list item, and in `dynamic` mode the name is nested one `<details><summary>` deeper.
An expanded folder swaps to the Material open variant through a rule scoped to `.filetree-dynamic`, so overriding a folder icon there takes a second declaration that carries the key class through: `.ft-i-<key> details[open] > summary .ft-name::before`.
Dropping the key class loses on specificity whatever the `theme:` order, where the collapsed-state override above only ties and is settled by loading last.
Five invariant SCSS variables drive the surface: `$filetree-bg`, `$filetree-fg`, `$filetree-muted`, `$filetree-highlight`, `$filetree-guide`.
Icons are decorative and never the sole carrier of meaning: directories keep their trailing slash, a highlighted entry is wrapped in `<strong>`, and the `…` marker carries a spelled-out label for assistive technology.

Typst and DOCX fall back to a plain bullet list.

## Annexes

Quarto numbers figures, tables, equations and listings, and has no appendix among them: `crossref: appendix-title` letters the chapters of a book project and reaches nothing else.
The extension declares a custom `anx` crossref type, so an annexe is captioned *Annexe n.*, referenced as `@anx-...`, and counted in a sequence of its own.

A chunk cannot carry that label directly: the knitr engine builds a float only from a label matching `^#?(fig|tbl)-` and drops any other before it reaches Pandoc.
An annexe is therefore authored with one of those two as a carrier prefix, which `filters/crossref-anx.lua` strips once the float node exists.

````markdown
```{r}
#| label: tbl-anx-vif
#| tbl-cap: "Variance inflation factors."

vif_table
```

See @anx-vif.
````

  | Form         | Label                   | Caption read from            |
  | ------------ | ----------------------- | ---------------------------- |
  | Table chunk  | `tbl-anx-<name>`        | `tbl-cap`                    |
  | Figure chunk | `fig-anx-<name>`        | `fig-cap`                    |
  | Fenced div   | `anx-<name>` on the div | the last paragraph inside it |

The three share one counter, and the reference always drops the carrier: `@anx-vif`, never `@tbl-anx-vif`.
The carrier earns its place twice over: it decides which caption key is read, and it leaves the block an ordinary table or figure, still visible and still captioned, should the filter ever be removed.

The prefix is French because the type was built for French documents; a document overrides it by redeclaring the type.
A document-level `crossref:` block replaces the format's own rather than merging into it, so repeat the two keys that block also carries:

```yaml
crossref:
  title-delim: "\\."
  tbl-title: "Table"
  custom:
    - kind: float
      key: anx
      reference-prefix: "Appendix"
      caption-prefix: "Appendix"
      caption-location: top
```

## Customization

### Frontmatter

Common overrides in `_quarto.yml`:

```yaml
format:
  hebstr-doc-html:
    mainfont: "Inter"
    fontsize: 1rem
    linestretch: 1.6
    page-layout: article
    toc-depth: 2
    grid:
      body-width: 900px
      margin-width: 300px
```

HTML figures render as SVG (`fig-format: svg`) through the `svglite` device (`dev: svglite`), which **requires the `svglite` R package** in the rendering library.
It writes figure labels as `<text>` elements, so they stay selectable and searchable and the file runs several times lighter, which compounds under `embed-resources: true`.
Fall back to R's built-in cairo device, which needs no extra package but bakes every label into vector paths, with `knitr: { opts_chunk: { dev: svg, dev.args: null } }` in the document YAML.
Render as raster with `knitr: { opts_chunk: { dev: png, dev.args: null } }` instead.
`fig-format: png` on its own leaves the device on `svglite`, the format's explicit `dev` taking precedence over it.
Typst and DOCX are unaffected.

### Figure fonts

A plotting device resolves R's own font families, not `mainfont`, so a figure would otherwise land beside Luciole body text on whatever the render machine resolves for the generic `sans`.
The format aliases the two generics to the document fonts:

```yaml
dev.args:
  system_fonts:
    sans: "Luciole"
    mono: "Fira Code"
```

The alias only decides what the **generic** `sans` and `mono` resolve to, which is what a plot that named no font receives.
A plot that asks for a family explicitly (`par(family=)`, ggplot's `base_family=`) resolves through a different path and is left alone, so this changes the undecided case and overrides nothing.

Two things to know:

**A figure never reaches the page's webfonts.** Quarto inserts each SVG as `<img src="data:image/svg+xml;...">`, and an SVG loaded through `<img>` is an isolated document: the `@font-face` rules in `fonts.css` do not cross into it, whatever family name the figure carries.
Figure text is therefore resolved against the **reader's** installed fonts, not against the webfonts the page downloads for its body text.
A reader without Luciole sees a substitute in the figures while the prose around them renders correctly, unless the figure carries a face of its own, which `fonts/register.R` below supplies.

`svglite` pins each string's width with `textLength` and `lengthAdjust='spacingAndGlyphs'`, so a substitution keeps the layout and changes only the glyph shapes.

The bundled `fonts/register.R` closes this gap: where it is sourced, it embeds the Luciole regular and bold faces into every svglite figure as `@font-face` blocks carrying a base64 WOFF2 `src:`, which an isolated SVG document *can* read since the data never leaves it.
That costs roughly 114 KB per figure, and covers those two faces only: italic figure text, and anything monospaced that the `mono` alias sends to Fira Code, still resolves against the reader's fonts.
The form to keep away from is `svglite::font_face(local = <family>, embed = TRUE)`: that one resolves the family through `systemfonts::font_info()` and embeds whichever file it lands on, a system TTF where one is installed, at many times the weight of the WOFF2.
`embed = TRUE` alongside `woff2 = <path>` stays on the WOFF2 and is a shorter route to the same bytes; the script encodes the URI itself to keep the `;charset=utf-8` token that form adds out of a binary payload.

**It also reads the render machine's installed fonts.** `svglite` writes the family it actually matched, never the one requested, so on a machine without Luciole the SVG names that machine's fallback and carries its metrics (`Noto Sans` on a typical desktop, `Liberation Sans` on a stock GitHub runner).
The figure then claims a family nobody asked for, and even a reader who *has* Luciole sees the fallback.

Naming the family in the plot (`par(family=)`, ggplot's `base_family=`) does **not** protect against this.
It settles which family is asked for, not whether the machine can supply it: an explicit request for an absent font falls back exactly like the generic does.

This bites hardest where the render machine is not the authoring one, a CI job or a server, since the substitution is silent and lands in the published artefact.
Install Luciole and Fira Code there: the alias resolves through `systemfonts`, so the two families have to sit on whichever machine runs the render, not only on the one where the document is written.
Measured on a fontconfig restricted to DejaVu, the alias writes `DejaVu Math TeX Gyre` into the SVG.

**`dev.args` is replaced, not merged.** A chunk setting it for another purpose loses the alias entirely and falls back.
Either repeat `system_fonts` in that call, or give the font in plot terms, which is what `example.qmd` does for its transparent-background figure.
The embedded faces are not lost the same way: `fonts/register.R` adds them from a knitr option hook, which runs after the chunk's own value is resolved and merges into it.

### Figures that follow the light/dark toggle

Use Quarto's `renderings` cell option: emit one plot per mode and Quarto tags them `.light-content` / `.dark-content`, which the body class selects at runtime.
Give the device a transparent background so the page background shows through, and set the ink per mode.
The cell may carry a plain `label` but no `fig-cap` or `fig-`-prefixed label (`renderings` is incompatible with cell-level crossref options), so wrap it in a fenced div that supplies the id and caption:

````markdown
::: {#fig-example}

```{r}
#| renderings: [light, dark]
#| dev.args: !expr list(bg = "transparent")

p <- ggplot(...)
p + theme_minimal(ink = "#1a1a1a")
p + theme_minimal(ink = "#e8e8e8")
```

Caption goes here.
:::
````

`ink` requires ggplot2 4.0 and does not reach tick labels or gridlines, which need explicit `axis.text`, `panel.grid` and `axis.ticks` colours.
Both renderings stay in the DOM, so switching modes costs no reload and the lightbox keeps working.
See the Figure section of [`example.qmd`](example.qmd).

### Tables that follow the light/dark toggle

`gt` tables need nothing: the theme restyles them in dark mode on its own.
A `gt` table resolves its palette in R and writes it into a `<style>` block scoped by the table's own generated id, so left alone it renders as a light card on a dark page, and no ordinary stylesheet rule can outrank an id-weighted selector.
The dark theme therefore carries a marked override, and it is deliberately one-sided: in light a table keeps whatever palette its R code chose.

Four variables move it.
Text and the rules that structure the table follow `$body-color`, and the hairlines between cells are drawn from `$neutral`.
The two surfaces are the page's own pair, so a table reads in dark as it does in light: whatever a light table leaves on the page background (column labels, striped rows, footnotes) takes `$primary-surface`, the colour the page itself is painted with, and the table ground takes `$primary-back`, the tint the TOC sidebar is painted with.
Re-tinting a table in dark mode means overriding those in your own `custom.scss` rather than styling the table in R: a colour passed to `gt::tab_options()` is what the override replaces.
`gt` will not take a CSS variable either, validating every colour option through `html_color()` and rejecting `var()`, `currentColor` and `inherit`.
See the `gt` section of [`example.qmd`](example.qmd), which asks for a light palette in R and lets the dark bundle replace it.

A table drawn by another package is not covered, and does not need to be if its colours are ordinary CSS: `reactable`, for one, passes its theme strings through untouched, so `reactableTheme(color = "var(--bs-body-color)")` follows the toggle from the R side.

### Brand colors via `_brand.yml`

```yaml
color:
  palette:
    primary: "#0099FF"
    secondary: "#FF0000"
```

See [Quarto Brand](https://quarto.org/docs/authoring/brand.html) for the full schema.

### SCSS overrides

Create a `custom.scss` and place it last in the `theme:` key:

```yaml
format:
  hebstr-doc-html:
    theme:
      light: [theme-light.scss, theme-base.scss, custom.scss]
      dark:  [theme-dark.scss,  theme-base.scss, custom.scss]
```

The overridable variables are the `!default` declarations in `theme-light.scss`, `theme-dark.scss` and `theme-base.scss`; [CONTRIBUTING.md](CONTRIBUTING.md) defines that surface and the SemVer policy that protects it.

### Code highlighting

Code blocks use a dark surface in both light and dark modes, and R gets five tokens Pandoc's stock definition does not emit: the package name in front of `::` or `:::`, `library`/`require`/`requireNamespace` read as keywords rather than as ordinary calls, the argument separator, the `=` of a named argument, and brackets of every shape.
This runs at render time in HTML and DOCX; Typst highlights through `code.tmTheme` instead and is unaffected.

Brackets carry one caveat worth knowing before you restyle anything.
Skylighting exposes a closed set of token types and maps brackets to one that emits no span at all, so reaching them means borrowing `.re`, which nominally marks region markers.
That borrowing is not scoped to R: `.re` renders in the namespace gold in every language the theme touches.

Token colours are not exposed as variables yet, so overriding one means a rule in your `custom.scss`:

```scss
code span .im {
  color: #b58900;
}
```

The classes are Pandoc's: `.im` (imports and namespaces), `.re` (brackets, borrowed), `.kw` / `.cf` (keywords), `.fu` (function calls), `.st` (strings), `.dv` / `.fl` (numbers), `.op` / `.ot` / `.sc` (operators and punctuation), `.co` (comments).

## Example

Source: [example.qmd](example.qmd).
Live demo at [hebstr.github.io/quarto-hebstr-doc](https://hebstr.github.io/quarto-hebstr-doc/).

```bash
quarto render example.qmd
```

## License

[MIT](LICENSE.md), except `_extensions/hebstr-doc/syntax/r.xml`, which derives from the KDE Kate highlighting module for R and stays [GPL v2](_extensions/hebstr-doc/syntax/RSyntax.LICENSE).
Bundled fonts and icons keep their own licences; [LICENSE.md](LICENSE.md) lists all of them.
