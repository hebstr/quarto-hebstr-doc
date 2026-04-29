# hebstr-doc

[![Render](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/render.yml/badge.svg)](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/render.yml)
[![Pages](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/pages.yml/badge.svg)](https://hebstr.github.io/quarto-hebstr-doc/)
[![Release](https://img.shields.io/github/v/release/hebstr/quarto-hebstr-doc?label=release)](https://github.com/hebstr/quarto-hebstr-doc/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

A shared Quarto theme for HTML, Typst (PDF), and Word (DOCX) output.

> **Status (v1.0.0)**: only **HTML** ships. Typst and DOCX are declared but not yet ready.

## Installation

```bash
quarto add hebstr/quarto-hebstr-doc
```

The extension lands under `_extensions`. Check that directory in if you use version control.

To pin a version:

```bash
quarto add hebstr/quarto-hebstr-doc@v1.0.0
```

## Formats

The three formats share a common base (numbered sections, TOC, cross-references, knitr chunk options):

- **`hebstr-doc-html`** *(operational)*: self-contained HTML with a custom SCSS theme, Luciole and Fira Code fonts, lightbox figures, and a wide body/margin grid.
- **`hebstr-doc-typst`** *(planned)*: A4 PDF with Luciole as the main font and a Typst preamble for headings, lists, tables, code blocks, and quotes.
- **`hebstr-doc-docx`** *(planned)*: Word document with a `.dotx` reference for styles.

## Usage

```yaml
---
title: "My Document"
format: hebstr-doc-html
---
```

Typst and DOCX are declared but `main` does not validate them yet:

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

The extension bundles two open-licensed fonts:

- [Luciole](https://luciole-vision.com/): a sans-serif designed for low-vision readers (CC-BY 4.0).
- [Fira Code](https://github.com/tonsky/FiraCode): a monospace with programming ligatures (SIL OFL 1.1).

Both ship as `.woff` and `.woff2` under `_extensions/hebstr-doc/fonts/`, wired through `@font-face` (HTML) and `font-paths` (Typst). Font Awesome 7 Solid sits in the same directory as `fa-solid-900.woff2`. Licence texts ship next to the files (`Luciole.LICENSE`, `FiraCode.LICENSE`, `FontAwesome.LICENSE`).

Callout icons use **Font Awesome 7 Solid** from the local `fa-solid-900.woff2`, declared in the same `@font-face` block as Luciole and Fira Code. Rendering needs no network access.

## Customisation

### Frontmatter overrides (no SCSS required)

Most aesthetic choices ride on standard Quarto keys, so you can override them from the document's YAML frontmatter:

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
| `mainfont` | `Luciole` | Bound to `$font-family-sans-serif`. A non-bundled family loses the system fallback chain; for robust fallbacks, override SCSS instead (see below). |
| `monofont` | `Fira Code` | Bound to `$font-family-monospace`. Same caveat. |
| `fontsize` | `1.2rem` | Bound to `$font-size-root`. Accepts `rem`, `em`, `px`. |
| `linestretch` | `1.75` | Bound to Bootstrap's `$line-height-base` (unitless multiplier). |
| `page-layout` | `full` | Standard Quarto values: `full`, `article`, `custom`. |
| `toc` / `toc-depth` / `toc-expand` | `true` / `4` / `true` | Standard Quarto TOC keys. |
| `grid` | `body-width: 1100px`, `margin-width: 600px`, `gutter-width: 3rem`, `sidebar-width: 0` | Override individual keys; missing keys fall back to extension defaults. |

### Brand colours and typography via `_brand.yml`

For one palette and font stack across HTML, Typst, and DOCX, drop a `_brand.yml` at the project root:

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

Quarto wires `color.palette.primary` to Bootstrap's `$primary` (and `secondary` to `$secondary`) before the extension's SCSS layers load. The derived `$primary-back` / `$primary-surface` / `$primary-dark` follow from the brand colour automatically. See [Quarto Brand](https://quarto.org/docs/authoring/brand.html) for the full schema.

### Deeper SCSS overrides

For the rest (callout colours, code-window chrome, surface tints, callout mix knobs), the HTML theme splits across three SCSS files that Quarto's `theme:` key loads as ordered pairs:

- `_extensions/hebstr-doc/theme-light.scss`: light-mode `scss:defaults` only.
- `_extensions/hebstr-doc/theme-dark.scss`: dark-mode `scss:defaults` only.
- `_extensions/hebstr-doc/theme-base.scss`: invariant defaults (typography, code-window chrome) + `:root` block exposing the runtime-themable SCSS variables as CSS custom properties + every `scss:rules`. Layout-chrome variables (navbar/sidebar/footer) are consumed by Quarto's own Bootstrap layer at compile time and therefore have no CSS custom property counterpart.

Quarto's color-scheme toggle picks the active theme (default in the title block).

CSS custom properties exposed under `:root`, grouped by purpose:

- **brand colours**: `--primary`, `--secondary`, `--primary-back`, `--primary-surface`, `--primary-dark`, `--neutral`
- **surfaces**: `--surface-default`, `--em-background-color`, `--caption-color`, `--figure-shadow`, `--tab-background`
- **inline highlights**: `--str-color`, `--dig-color`
- **code highlight**: `--code-foreground-color`, `--code-background-color`, `--code-comment-color`
- **code-window chrome**: `--code-window-titlebar-bg`, `--code-window-border`, `--code-window-line-divider`, `--code-window-muted`, `--code-window-line-number`
- **callout colours**: `--callout-{note,tip,caution,warning,important}-color`
- **callout mix knobs** (drive the light/dark tint logic): `--callout-mix-base`, `--callout-text-mix`, `--callout-bg-mix`

SCSS variables exposed with `!default` (override before the theme files load):

- typography: `$font-family-sans-serif`, `$font-family-monospace`, `$toc-font-size`, `$callout-icon-scale` (root font size and line height come from `fontsize` / `linestretch` in the YAML; see above)
- brand & body: `$primary`, `$secondary`, `$body-bg`, `$body-color`, `$primary-back`, `$primary-surface`, `$primary-dark`
- surfaces, inline highlights, callouts: same names as the matching custom properties (drop the `--` prefix, replace with `$`)
- code chrome (invariant across light/dark): `$code-foreground-color`, `$code-background-color`, `$code-comment-color`, `$code-window-{titlebar-bg,border,line-divider,muted,line-number}`
- layout chrome (navbar / sidebar / footer, only active in project layouts like book and website): `$navbar-bg`, `$navbar-fg`, `$navbar-hl`, `$sidebar-bg`, `$sidebar-fg`, `$sidebar-hl`, `$footer-bg`, `$footer-fg`. These are consumed directly by Quarto's Bootstrap layer (which calls `theme-contrast()` on them), so override values must be SCSS-resolvable colors (hex, named, `mix(...)`) — not CSS `color-mix(...)`.

To override in a consumer project, redeclare both halves of the theme key (overriding the whole `theme:` value drops the dark variant):

```yaml
format:
  hebstr-doc-html:
    theme:
      light: [theme-light.scss, theme-base.scss, custom.scss]
      dark:  [theme-dark.scss,  theme-base.scss, custom.scss]
```

Put `custom.scss` **last**: Quarto layers SCSS files in the order given, and the **last** file's `scss:defaults` wins over the preceding ones. This is the opposite of the standard Bootstrap convention.

## Composing on top

`hebstr-doc` is the visual identity layer for the wider `hebstr-*` family of Quarto extensions (`hebstr-book` and `hebstr-website`, separate repos). Project templates that build on top of it ship as their own Quarto extension and reference `hebstr-doc-html` as the format, layering an `extras.scss` for project-specific chrome (sidebar tweaks for books, navbar/listing tweaks for websites):

```yaml
format:
  hebstr-doc-html:
    theme:
      light: [theme-light.scss, theme-base.scss, book-extras.scss]
      dark:  [theme-dark.scss,  theme-base.scss, book-extras.scss]
  hebstr-doc-typst: default
```

The downstream extension installs alongside `hebstr-doc` (no `--embed`) so consumers can update each independently. Treat the SCSS variables listed under "Deeper SCSS overrides" as the public API: renaming or removing one is a MAJOR-version change, additions are MINOR.

## Example

Source: [example.qmd](example.qmd).

To render locally:

```bash
quarto render example.qmd
```

This produces `example.html` covering headings, lists, figures, tables, code blocks, equations, callouts, and cross-references. Typst (`example.pdf`) and DOCX (`example.docx`) come in a later release.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the public API surface, the SemVer policy, the release procedure, and the local validation workflow.

## Licence

Code ships under the MIT Licence (see [LICENSE.md](LICENSE.md)). Bundled fonts keep their own licences (see `_extensions/hebstr-doc/fonts/`).
