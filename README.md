# hebstr-doc

[![Render](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/render.yml/badge.svg)](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/render.yml)
[![Pages](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/pages.yml/badge.svg)](https://hebstr.github.io/quarto-hebstr-doc/)
[![Release](https://img.shields.io/github/v/release/hebstr/quarto-hebstr-doc?label=release)](https://github.com/hebstr/quarto-hebstr-doc/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

A Quarto theme for HTML, Typst (PDF), and Word (DOCX) output.

> **Status (v1.2.0):** HTML is operational.
> Typst and DOCX are declared but not yet validated.

## Installation

```bash
quarto add hebstr/quarto-hebstr-doc
```

## Usage

```yaml
---
title: "My Document"
format: hebstr-doc-html
---
```

## Shortcodes

### `script`

Injects an external file as a code block with the code-window chrome, so the script stays a file on disk, not a copy in the document.

```markdown
{{< script scripts/demo.R >}}
```

  | Attribute  | Default                 | Effect                                                                                                                                       |
  | ---------- | ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
  | `lang`     | from the file extension | Highlighting language, and the label shown in the title bar. An extension the shortcode does not map yields no language and no title bar     |
  | `filename` | the path                | Label shown on the code-fold summary                                                                                                         |
  | `suffix`   | none                    | Appended to the summary label                                                                                                                |
  | `numbers`  | `true`                  | Line numbers                                                                                                                                 |
  | `lines`    | whole file              | Range to include: `10-20`, `10-`, `-20`. A bare `12` is read as `12-`                                                                        |
  | `dedent`   | none                    | Leading spaces to strip, at most this many. A line indented by less is dedented as far as its own indentation allows; tabs are never touched |

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
  | `depth`     | `2`      | Levels shown without interaction. In `static`, deeper directories collapse to `…`; in `dynamic`, they become collapsed folders that expand on click                                                                              |
  | `mode`      | `static` | `static` renders the full tree to `depth`; `dynamic` makes folders collapsible native `<details>` (no JavaScript), with `depth` as the level open on load                                                                        |
  | `exclude`   | none     | [Lua patterns](https://www.lua.org/manual/5.4/manual.html#6.4.1) matched against each path relative to `root`, directories included and without a trailing slash (`^output$`, not `^output/`). Escape literals with `%`, not `\` |
  | `highlight` | none     | Lua patterns; matching entries render bold                                                                                                                                                                                       |
  | `hidden`    | `false`  | Include dotfiles. `true`/`yes`/`on`/`1` and their negatives are all accepted, case-insensitively; anything else warns and falls back to `false`                                                                                  |
  | `paths`     | none     | Descriptions, keyed by path                                                                                                                                                                                                      |

Every key except `paths` is also a shortcode attribute, overriding the sidecar for that one call: `{{< filetree root="src" depth=1 >}}`.
Attributes are the only call-site syntax; a positional argument or an unknown attribute warns.
As attributes, `exclude` and `highlight` take `|`-separated patterns with no escaping; a pattern matching a literal `|` belongs in the sidecar.
Descriptions are read from the sidecar only.
`annotations` (default `filetree.yml`) sets the sidecar path and must stay inside the project: an absolute path, a drive letter, or a `..` climbing out warns, and the call runs unconfigured.
`root` and `annotations` resolve from the project root, not the calling document, so one sidecar serves every document in the project.
Outside a project, a single-file render falls back to the document's own directory for both.
Document frontmatter is never read: `exclude` and `highlight` hold Lua patterns, which Pandoc would corrupt by parsing as inline Markdown.

Descriptions accept inline Markdown, so a path or a command can render as code.
A trailing slash on a `paths` key is optional.
A `paths` key that never appears in the tree, whether absent from disk or dropped by `exclude`, `hidden` or `depth`, raises a render warning naming it.
Quote every description: YAML reads a bare `no`, `yes`, `on`, `off`, `true` or `false` as a boolean, and the shortcode drops the annotation with a warning naming the key.
A bare `~` reaches the shortcode as an empty string and is dropped silently.

HTML renders a nested list on a dark surface in both light and dark modes, styled by the `.filetree` rules in `theme-base.scss`.
In `dynamic` mode each folder is a native `<details>` element that expands without JavaScript, its Material folder icon switching to the open variant while expanded.
Each entry carries a [Material Icon Theme](https://github.com/material-extensions/vscode-material-icon-theme) icon, resolved by exact name, then extension, then a generic document; a directory resolves by name (only `.github` so far), then a generic folder.
Icons ship under `_extensions/hebstr-doc/icons/` and are inlined per entry, so the page makes no outside request and only the icons used are embedded.
Override one with a `background-image` on `.ft-i-<key> > .ft-name::before` in a `custom.scss` placed last in `theme:`.
Five invariant SCSS variables drive the surface: `$filetree-bg`, `$filetree-fg`, `$filetree-muted`, `$filetree-highlight`, `$filetree-guide`.
Icons are decorative and never the sole carrier of meaning: directories keep their trailing slash, a highlighted entry is wrapped in `<strong>`, and the `…` marker carries a spelled-out label for assistive technology.

Typst and DOCX fall back to a plain bullet list.

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

HTML figures render as SVG (`fig-format: svg`) via R's built-in cairo device, so vector output needs no extra package.
For selectable text and lighter files, opt into the `svglite` device (requires the `svglite` R package) with `knitr: { opts_chunk: { dev: svglite } }` in the document YAML.
Render as raster instead with `fig-format: png`.
Typst and DOCX are unaffected.

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

## Example

Source: [example.qmd](example.qmd).
Live demo at [hebstr.github.io/quarto-hebstr-doc](https://hebstr.github.io/quarto-hebstr-doc/).

```bash
quarto render example.qmd
```

## License

[MIT](LICENSE.md)
