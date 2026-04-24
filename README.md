# hebstr Extension For Quarto

A Quarto extension providing a shared multi-format theme for HTML documents, Typst (PDF) reports, and Word (DOCX) documents.

## Installation

```bash
quarto add hebstr/quarto-hebstr
```

This will install the extension under the `_extensions` subdirectory.
If you are using version control, you will want to check in this directory.

To pin a specific version:

```bash
quarto add hebstr/quarto-hebstr@v0.10.0
```

## Formats

The extension provides three formats sharing a common set of defaults (numbered sections, TOC, cross-references, knitr chunk options):

- **`hebstr-html`**: self-contained HTML with custom SCSS theme, Luciole and Fira Code fonts, lightbox figures, and a wide body/margin grid.
- **`hebstr-typst`**: A4 PDF with Luciole as the main font and a Typst preamble styling headings, lists, tables, code blocks, and quotes.
- **`hebstr-docx`**: Word document using a reference `.dotx` for styles.

## Usage

```yaml
---
title: "My Document"
format: hebstr-html
---
```

```yaml
---
title: "My Report"
format: hebstr-typst
---
```

```yaml
---
title: "My Document"
format: hebstr-docx
---
```

A document can declare several formats at once:

```yaml
---
title: "My Document"
format:
  hebstr-html: default
  hebstr-typst: default
  hebstr-docx: default
---
```

## Fonts

The extension bundles the following open-licensed fonts:

- [Luciole](https://luciole-vision.com/) — a sans-serif font designed for low-vision readers (CC-BY 4.0).
- [Fira Code](https://github.com/tonsky/FiraCode) — a monospace font with programming ligatures (SIL OFL 1.1).

Both are shipped as `.woff` and `.woff2` under `_extensions/hebstr/fonts/` and referenced via `@font-face` (HTML) and `font-paths` (Typst). Licence texts are bundled alongside the font files (`LICENSE-Luciole.md`, `LICENSE-FiraCode.md`).

## Customisation

The SCSS theme exposes named CSS custom properties under `:root` (`--primary`, `--neutral`, `--line-color`, callout colours, etc.). To override in a consumer project:

```yaml
format:
  hebstr-html:
    theme:
      - hebstr
      - custom.scss
```

## Example

Source: [example.qmd](example.qmd).

To render locally:

```bash
quarto render example.qmd
```

This produces `index.html`, `example.pdf`, and `example.docx` covering headings, lists, figures, tables, code blocks, equations, callouts, and cross-references.

## Licence

Code is released under the MIT Licence (see [LICENSE.md](LICENSE.md)). Bundled fonts retain their respective licences (see `_extensions/hebstr/fonts/`).
