# hebstr-doc

[![Render](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/render.yml/badge.svg)](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/render.yml)
[![Pages](https://github.com/hebstr/quarto-hebstr-doc/actions/workflows/pages.yml/badge.svg)](https://hebstr.github.io/quarto-hebstr-doc/)
[![Release](https://img.shields.io/github/v/release/hebstr/quarto-hebstr-doc?label=release)](https://github.com/hebstr/quarto-hebstr-doc/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

A Quarto theme for HTML, Typst (PDF), and Word (DOCX) output.

> **Status (v1.0.0):** HTML is operational. Typst and DOCX are declared but not yet validated.

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

All overridable variables are listed in [CONTRIBUTING.md](CONTRIBUTING.md).

## Example

Source: [example.qmd](example.qmd) — live demo at [hebstr.github.io/quarto-hebstr-doc](https://hebstr.github.io/quarto-hebstr-doc/).

```bash
quarto render example.qmd
```

## License

[MIT](LICENSE.md)
