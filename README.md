# hebstr-doc

[![Render](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/render.yml/badge.svg)](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/render.yml)
[![Pages](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/pages.yml/badge.svg)](https://hebstr.github.io/quarto-hebstr-doc/)
[![Release](https://img.shields.io/github/v/release/hebstr/quarto-hebstr-doc?label=release)](https://github.com/hebstr/quarto-hebstr-doc/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

A Quarto theme for HTML, Typst (PDF), and Word (DOCX) output.

> **Status (v1.6.0):** HTML and Word output are supported.
> Typst is declared but not yet validated.

## Installation

```bash
quarto add hebstr/quarto-hebstr-doc
```

The HTML format renders figures with the `svglite` R package, which must be installed separately:

```r
install.packages("svglite")
```

Any document with an R chunk needs it, even if no chunk draws a figure.
To use R's built-in SVG device instead:

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

The formats are `hebstr-doc-html`, `hebstr-doc-docx` and `hebstr-doc-typst`.

The HTML format sets `embed-resources: true`, producing a single self-contained file.
For a website or a book, turn it off in `_quarto.yml`, otherwise every page embeds all assets:

```yaml
format:
  hebstr-doc-html:
    embed-resources: false
```

## Shortcodes

### `script`

Includes an external file as a foldable code block, with its filename as header.

```markdown
{{< script scripts/demo.R >}}
```

  | Attribute  | Default                 | Effect                                                                |
  | ---------- | ----------------------- | --------------------------------------------------------------------- |
  | `lang`     | from the file extension | Highlighting language, shown in the header                            |
  | `filename` | the path                | Label of the fold summary                                             |
  | `suffix`   | none                    | Text appended to the label                                            |
  | `numbers`  | `true`                  | Line numbers (`true`/`false`, `yes`/`no`, `on`/`off`, `1`/`0`)        |
  | `lines`    | whole file              | Line range: `10-20`, `10-` or `-20`                                   |
  | `dedent`   | none                    | Number of leading spaces to remove from each line                     |

Invalid arguments raise a render warning and fall back to the default.

The shortcode renders in HTML only and produces nothing in Typst and Word.
To show a file in every format, use a regular code block.

### `filetree`

Renders a directory tree read from disk at render time.

```markdown
{{< filetree >}}
```

Configure it in a `filetree.yml` file at the project root:

```yaml
default:
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

  | Key         | Default  | Effect                                                                                                     |
  | ----------- | -------- | -------------------------------------------------------------------------------------------------------    |
  | `root`      | `.`      | Directory to list, relative to the project root                                                            |
  | `depth`     | `2`      | Number of levels shown; deeper directories collapse to `…`                                                 |
  | `mode`      | `static` | `dynamic` makes folders collapsible, with `depth` levels open on load                                      |
  | `exclude`   | none     | [Lua patterns](https://www.lua.org/manual/5.4/manual.html#6.4.1) of paths to leave out, relative to `root` |
  | `highlight` | none     | Lua patterns of paths to show in bold                                                                      |
  | `hidden`    | `false`  | Include hidden files                                                                                       |
  | `paths`     | none     | Descriptions, keyed by path                                                                                |

Patterns match paths without a trailing slash (`^output$`, not `^output/`), and special characters are escaped with `%`, not `\`.

Each top-level key of `filetree.yml` is a profile.
`{{< filetree >}}` renders the `default` profile, and any other profile is rendered by passing its name:

```yaml
default:
  depth: 2
docs:
  root: "docs"
  depth: 1
```

```markdown
{{< filetree docs >}}
```

Profiles are independent: a profile does not inherit the keys of `default`.
A profile name holds only letters, digits, `_` and `-`.
An unknown profile renders nothing and raises a warning listing the profiles found.

Every key except `paths` can also be set on the shortcode, overriding the sidecar for that call:

```markdown
{{< filetree root="src" depth=1 mode=dynamic >}}
```

As attributes, `exclude` and `highlight` take patterns separated by `|`.
`annotations` sets the path of the sidecar, which must be inside the project.
Paths resolve from the project root, or from the document's directory when rendering outside a project.
The document front matter is not read, because Markdown parsing would alter patterns written there.

Descriptions accept inline Markdown.
Quote every description, since YAML reads unquoted `yes`, `no`, `true` or `false` as booleans.
A `*` in a key matches any characters within one path segment, so `docs/*_report.html` describes a dated file under any date; an exact key takes precedence.
When several wildcard keys match the same entry, the first in byte order applies and a warning names them.
A key that matches nothing in the rendered tree raises a warning.

In HTML, the tree is shown on a dark background in both colour schemes, with [Material Icon Theme](https://github.com/material-extensions/vscode-material-icon-theme) icons chosen by file name, then extension.
To replace an icon, add a rule to your `custom.scss`:

```scss
.ft-i-markdown .ft-name::before {
  background-image: url("my-icon.svg");
}
```

In `dynamic` mode, an open folder also needs `.ft-i-<key> details[open] > summary .ft-name::before`.
The colours are set by `$filetree-bg`, `$filetree-fg`, `$filetree-muted`, `$filetree-highlight` and `$filetree-guide`.

Typst and Word render the tree as a bulleted list.

## Annexes

The extension adds an `anx` cross-reference type for annexes, captioned *Annexe n.*, numbered separately and referenced as `@anx-<name>`.
Since knitr only creates floats from `fig-` and `tbl-` labels, a chunk declares an annexe with one of these prefixes, which the extension removes:

````markdown
```{r}
#| label: tbl-anx-vif
#| tbl-cap: "Variance inflation factors."

vif_table
```

See @anx-vif.
````

  | Form         | Label                   | Caption                      |
  | ------------ | ----------------------- | ---------------------------- |
  | Table chunk  | `tbl-anx-<name>`        | `tbl-cap`                    |
  | Figure chunk | `fig-anx-<name>`        | `fig-cap`                    |
  | Fenced div   | `anx-<name>`            | last paragraph of the div    |

References always omit the prefix: `@anx-vif`, not `@tbl-anx-vif`.

To use another prefix, redeclare the type in the document.
A document-level `crossref:` replaces the format's settings, so repeat `title-delim` and `tbl-title`:

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

### Front matter

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

### Figures

HTML figures render as SVG with `svglite`, which keeps text selectable.
To render PNG instead:

```yaml
knitr:
  opts_chunk:
    dev: png
    dev.args: null
```

Setting `fig-format: png` alone has no effect, as the format's `dev` setting takes precedence.

### Figure fonts

In HTML figures, R's generic `sans` and `mono` families map to Luciole and Fira Code.
Plots that name a font explicitly are not affected.

Install Luciole and Fira Code on the machine that renders the document, including CI runners and servers; otherwise figures silently use a fallback font.

An SVG figure cannot use the page's web fonts, so figure text depends on the fonts installed on the reader's machine, and readers without Luciole see a substitute.

A chunk that sets `dev.args` replaces the format's value and loses the font mapping: repeat `system_fonts` in that chunk or set the font in the plot, for example with ggplot2's `base_family`.

### Figures that follow the light/dark toggle

Use Quarto's `renderings` option to produce one plot per colour scheme, with a transparent background.
`renderings` does not support `fig-cap` or a `fig-` label, so put the chunk in a fenced div that carries them:

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

The `ink` argument requires ggplot2 4.0 and does not colour axis text or grid lines, which need `axis.text`, `panel.grid` and `axis.ticks`.
See the Figure section of [`example.qmd`](example.qmd).

### Tables that follow the light/dark toggle

`gt` tables need no configuration: in dark mode, the theme replaces their colours.
Colours set in R with `gt::tab_options()` apply in light mode only.
To adjust the dark rendering, override `$primary-back` (table background), `$primary-surface` (column labels, striped rows, notes), `$body-color` (text) and `$neutral` (cell borders).

`reactable` tables without a `theme` argument get the same treatment.
A table with `reactableTheme()` keeps its colours; use CSS variables to follow the toggle:

```r
reactable::reactableTheme(
  color = "var(--bs-body-color)",
  backgroundColor = "var(--primary-surface)",
  stripedColor = "var(--primary-back)"
)
```

The search box, filters and pagination are styled by the theme in either case.
Tables from other packages are not adapted.

### Brand colours with `_brand.yml`

```yaml
color:
  palette:
    primary: "#0099FF"
    secondary: "#FF0000"
```

See [Quarto Brand](https://quarto.org/docs/authoring/brand.html) for the full schema.

### SCSS overrides

Create a `custom.scss` and add it last to both theme lists:

```yaml
format:
  hebstr-doc-html:
    theme:
      light: [theme-light.scss, theme-base.scss, custom.scss]
      dark:  [theme-dark.scss,  theme-base.scss, custom.scss]
```

[CONTRIBUTING.md](CONTRIBUTING.md#public-api-surface) lists the 47 variables you can override.

### Text alignment

Body text is justified and hyphenated.
Hyphenation depends on the document language and on the reader's browser.
Content in the margin column stays left-aligned, and figures keep their `fig-align`.

To align body text left, the rule must include the `#quarto-document-content` id:

```scss
#quarto-document-content p:not(:where(figure p)) {
  text-align: left;
}
```

A plain `p { text-align: left }` has no effect.

### Figure captions

Captions of cross-referenced figures sit below the figure and are left-aligned.
Captions of unlabelled figures, and captions placed on top (tables, annexes, or `fig-cap-location: top`), are centred.

### Word output

`hebstr-doc-docx` uses the bundled `template.dotx`:

- text in Aptos, with Calibri as fallback;
- body text justified and hyphenated, in the `Body Text` style, which you modify to restyle paragraphs;
- headings numbered by the template, which is why the format sets `number-sections: false`;
- the title block on the first page and the table of contents on the second, titled in the document language;
- A4 pages with 2.5 cm margins, for a text width of 6.2958 in.

Word offers to update the table of contents when the document is opened; it stays empty until the update is accepted.
To change its title, set `language: toc-title-document:` in `_quarto.yml`.

The `hebstr` R package sizes tables from this text width, so the changelog records any change to it.

Captions are styled by position, as in HTML: `Table Caption` above the content, `Image Caption` below.
A caption can carry a second line, written as `<br>` followed by a `quarto-float-subcaption` span, the form `hebstr::str_fig()` produces:

```r
#| label: fig-mass
#| fig-cap: "Body mass by species<br><span class='quarto-float-subcaption'>Adult penguins only.</span>"
```

To use your own template, keep the styles the extension relies on: `Table Caption`, `Image Caption`, `Table Caption Title`, `Image Caption Title`, `Table Caption Subtitle`, `Image Caption Subtitle`, `Figure` and `Captioned Figure`.

```yaml
format:
  hebstr-doc-docx:
    reference-doc: my-template.dotx
```

### Code highlighting

Code blocks have a dark background in both colour schemes.
In HTML and Word, R code also highlights package names before `::`, `library()` and similar calls, argument separators, named-argument `=`, and brackets.
Brackets use the `.re` class, which is gold in every language.

Token colours are not exposed as variables; override them in `custom.scss`:

```scss
code span .im {
  color: #b58900;
}
```

Classes: `.im` (imports and namespaces), `.re` (brackets), `.kw` / `.cf` (keywords), `.fu` (function calls), `.st` (strings), `.dv` / `.fl` (numbers), `.op` / `.ot` / `.sc` (operators and punctuation), `.co` (comments).

## Example

Source: [example.qmd](example.qmd).
Live demo: [hebstr.github.io/quarto-hebstr-doc](https://hebstr.github.io/quarto-hebstr-doc/).

```bash
quarto render example.qmd
```

## License

[MIT](LICENSE.md), except two files under the GPL: `_extensions/hebstr-doc/syntax/r.xml` ([GPL v2](_extensions/hebstr-doc/syntax/RSyntax.LICENSE)) and `_extensions/hebstr-doc/template.dotx` ([GPL v2 or later](_extensions/hebstr-doc/template.LICENSE)).
Bundled fonts and icons keep their own licences, listed in [LICENSE.md](LICENSE.md).
