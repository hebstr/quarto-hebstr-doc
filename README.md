# hebstr-doc Extension For Quarto

[![Render](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/render.yml/badge.svg)](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/render.yml)
[![Pages](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/pages.yml/badge.svg)](https://hebstr.github.io/quarto-hebstr-doc/)
[![Release](https://img.shields.io/github/v/release/hebstr/quarto-hebstr-doc?label=release)](https://github.com/hebstr/quarto-hebstr-doc/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

A Quarto extension providing a shared multi-format theme for HTML documents, Typst (PDF) reports, and Word (DOCX) documents.

> **Status (v0.12.0)** : only the **HTML** format is operational. Typst and DOCX formats are planned but not yet shippable.

## Installation

```bash
quarto add hebstr/quarto-hebstr-doc
```

This will install the extension under the `_extensions` subdirectory.
If you are using version control, you will want to check in this directory.

To pin a specific version:

```bash
quarto add hebstr/quarto-hebstr-doc@v0.12.0
```

## Formats

The extension targets three formats sharing a common set of defaults (numbered sections, TOC, cross-references, knitr chunk options):

- **`hebstr-doc-html`** *(operational)*: self-contained HTML with custom SCSS theme, Luciole and Fira Code fonts, lightbox figures, and a wide body/margin grid.
- **`hebstr-doc-typst`** *(planned)*: A4 PDF with Luciole as the main font and a Typst preamble styling headings, lists, tables, code blocks, and quotes.
- **`hebstr-doc-docx`** *(planned)*: Word document using a reference `.dotx` for styles.

## Usage

```yaml
---
title: "My Document"
format: hebstr-doc-html
---
```

The Typst and DOCX formats below are declared but not yet ship-ready (no validated rendering on `main`):

```yaml
---
title: "My Report"
format: hebstr-doc-typst   # planned
---
```

```yaml
---
title: "My Document"
format: hebstr-doc-docx    # planned
---
```

## Fonts

The extension bundles the following open-licensed fonts:

- [Luciole](https://luciole-vision.com/) : a sans-serif font designed for low-vision readers (CC-BY 4.0).
- [Fira Code](https://github.com/tonsky/FiraCode) : a monospace font with programming ligatures (SIL OFL 1.1).

Both are shipped as `.woff` and `.woff2` under `_extensions/hebstr-doc/fonts/` and referenced via `@font-face` (HTML) and `font-paths` (Typst). Font Awesome 7 Solid is also bundled there as `fa-solid-900.woff2`. Licence texts are bundled alongside the font files (`Luciole.LICENSE`, `FiraCode.LICENSE`, `FontAwesome.LICENSE`).

Callout icons are rendered with **Font Awesome 7 Solid**, shipped locally as `fa-solid-900.woff2` under `_extensions/hebstr-doc/fonts/` and declared in the same `@font-face` block as Luciole and Fira Code. No render-time network access is required.

## Customisation

### Frontmatter overrides (no SCSS required)

Most aesthetic choices ship as standard Quarto keys, so a consumer can override them directly from a document's YAML frontmatter:

```yaml
---
title: "My Document"
format:
  hebstr-doc-html:
    mainfont: "Inter"
    monofont: "JetBrains Mono"
    fontsize: 1rem
    linestretch: 1.6
    page-layout: article
    toc-depth: 2
    toc-expand: false
    grid:
      body-width: 900px
      margin-width: 300px
---
```

Available knobs:

| Key | Default | Notes |
|---|---|---|
| `mainfont` | `Luciole` | Bound to `$font-family-sans-serif`. Setting it to a non-bundled family loses the system fallback chain ; for robust fallbacks, override SCSS instead (see below). |
| `monofont` | `Fira Code` | Bound to `$font-family-monospace`. Same caveat. |
| `fontsize` | `1.2rem` | Bound to `$font-size-root`. Accepts `rem`, `em`, `px`. |
| `linestretch` | `1.75` | Bound to Bootstrap's `$line-height-base` (unitless multiplier). |
| `page-layout` | `full` | Standard Quarto values: `full`, `article`, `custom`. |
| `toc` / `toc-depth` / `toc-expand` | `true` / `4` / `true` | Standard Quarto TOC keys. |
| `grid` | `body-width: 1100px`, `margin-width: 600px`, `gutter-width: 3rem`, `sidebar-width: 0` | Override individual keys; missing keys fall back to extension defaults. |

### Brand colours and typography via `_brand.yml`

For cross-format brand consistency (HTML + Typst + DOCX share the same palette and fonts), drop a `_brand.yml` at the project root:

```yaml
color:
  palette:
    primary: "#0099FF"
    secondary: "#FF0000"
typography:
  base:
    family: "Luciole"
  monospace:
    family: "Fira Code"
```

Quarto wires `color.palette.primary` to Bootstrap's `$primary` (and `secondary` to `$secondary`) before the extension's SCSS layers load. The derived `$primary-back` / `$primary-surface` / `$primary-dark` are recomputed from the brand colour automatically. See [Quarto Brand](https://quarto.org/docs/authoring/brand.html) for the full schema.

### Deeper SCSS overrides

For everything else (callout colours, code-window chrome, surface tints, callout mix knobs), the HTML theme is split across three SCSS files loaded as ordered pairs by Quarto's `theme:` key:

- `_extensions/hebstr-doc/theme-light.scss` : light-mode `scss:defaults` only.
- `_extensions/hebstr-doc/theme-dark.scss` : dark-mode `scss:defaults` only.
- `_extensions/hebstr-doc/theme-base.scss` : invariant defaults (typography, code-window chrome) + `:root` block exposing every SCSS variable as a CSS custom property + every `scss:rules`.

The active theme is selected by Quarto's color-scheme toggle (default in the title block).

CSS custom properties exposed under `:root`, grouped by purpose:

- **brand colours**: `--primary`, `--secondary`, `--primary-back`, `--primary-surface`, `--primary-dark`, `--neutral`
- **surfaces**: `--surface-default`, `--em-background-color`, `--caption-color`, `--figure-shadow`, `--tab-background`
- **inline highlights**: `--str-color`, `--dig-color`
- **code highlight**: `--code-foreground-color`, `--code-background-color`, `--code-comment-color`
- **code-window chrome**: `--code-window-titlebar-bg`, `--code-window-border`, `--code-window-line-divider`, `--code-window-muted`, `--code-window-line-number`
- **callout colours**: `--callout-{note,tip,caution,warning,important}-color`
- **callout mix knobs** (drive the light/dark tint logic): `--callout-mix-base`, `--callout-text-mix`, `--callout-bg-mix`

SCSS variables exposed with `!default` (override before the theme files are loaded):

- typography: `$font-family-sans-serif`, `$font-family-monospace`, `$toc-font-size`, `$callout-icon-scale` (root font size and line height are driven by `fontsize` / `linestretch` in the YAML ; see above)
- brand & body: `$primary`, `$secondary`, `$body-bg`, `$body-color`, `$primary-back`, `$primary-surface`, `$primary-dark`
- surfaces, inline highlights, callouts: same names as the matching custom properties (drop the `--` prefix, replace with `$`)
- code chrome (invariant across light/dark): `$code-foreground-color`, `$code-background-color`, `$code-comment-color`, `$code-window-{titlebar-bg,border,line-divider,muted,line-number}`

To override in a consumer project, redeclare both halves of the theme key (overriding the whole `theme:` value drops the dark variant):

```yaml
format:
  hebstr-doc-html:
    theme:
      light: [theme-light.scss, theme-base.scss, custom.scss]
      dark:  [theme-dark.scss,  theme-base.scss, custom.scss]
```

Place `custom.scss` **last** : Quarto layers SCSS files in the order given, with the **last** file's `scss:defaults` taking precedence over preceding ones. This is opposite to the standard Bootstrap convention.

## Example

Source: [example.qmd](example.qmd).

To render locally:

```bash
quarto render example.qmd
```

This produces `example.html` covering headings, lists, figures, tables, code blocks, equations, callouts, and cross-references. Typst (`example.pdf`) and DOCX (`example.docx`) outputs are planned for a later release.

## Licence

Code is released under the MIT Licence (see [LICENSE.md](LICENSE.md)). Bundled fonts retain their respective licences (see `_extensions/hebstr-doc/fonts/`).
