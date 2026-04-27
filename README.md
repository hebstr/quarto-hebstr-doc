# hebstr Extension For Quarto

A Quarto extension providing a shared multi-format theme for HTML documents, Typst (PDF) reports, and Word (DOCX) documents.

> **Status (v0.11.0)** — only the **HTML** format is operational. Typst and DOCX formats are planned but not yet shippable.

## Installation

```bash
quarto add hebstr/quarto-hebstr
```

This will install the extension under the `_extensions` subdirectory.
If you are using version control, you will want to check in this directory.

To pin a specific version:

```bash
quarto add hebstr/quarto-hebstr@v0.11.0
```

## Formats

The extension targets three formats sharing a common set of defaults (numbered sections, TOC, cross-references, knitr chunk options):

- **`hebstr-html`** *(operational)*: self-contained HTML with custom SCSS theme, Luciole and Fira Code fonts, lightbox figures, and a wide body/margin grid.
- **`hebstr-typst`** *(planned)*: A4 PDF with Luciole as the main font and a Typst preamble styling headings, lists, tables, code blocks, and quotes.
- **`hebstr-docx`** *(planned)*: Word document using a reference `.dotx` for styles.

## Usage

```yaml
---
title: "My Document"
format: hebstr-html
---
```

The Typst and DOCX formats below are declared but not yet ship-ready (no validated rendering on `main`):

```yaml
---
title: "My Report"
format: hebstr-typst   # planned
---
```

```yaml
---
title: "My Document"
format: hebstr-docx    # planned
---
```

## Fonts

The extension bundles the following open-licensed fonts:

- [Luciole](https://luciole-vision.com/) — a sans-serif font designed for low-vision readers (CC-BY 4.0).
- [Fira Code](https://github.com/tonsky/FiraCode) — a monospace font with programming ligatures (SIL OFL 1.1).

Both are shipped as `.woff` and `.woff2` under `_extensions/hebstr/fonts/` and referenced via `@font-face` (HTML) and `font-paths` (Typst). Font Awesome 7 Solid is also bundled there as `fa-solid-900.woff2`. Licence texts are bundled alongside the font files (`Luciole.LICENSE`, `FiraCode.LICENSE`, `FontAwesome.LICENSE`).

Callout icons are rendered with **Font Awesome 7 Solid**, shipped locally as `fa-solid-900.woff2` under `_extensions/hebstr/fonts/` and declared in the same `@font-face` block as Luciole and Fira Code. No render-time network access is required.

## Customisation

The HTML theme is split across three SCSS files loaded as ordered pairs by Quarto's `theme:` key:

- `_extensions/hebstr/theme-light.scss` — light-mode `scss:defaults` only.
- `_extensions/hebstr/theme-dark.scss` — dark-mode `scss:defaults` only.
- `_extensions/hebstr/theme-base.scss` — invariant defaults (typography, code-window chrome) + `:root` block exposing every SCSS variable as a CSS custom property + every `scss:rules`.

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

- typography: `$font-family-sans-serif`, `$font-family-monospace`, `$font-size-root`, `$toc-font-size`, `$callout-icon-scale`
- brand & body: `$primary`, `$secondary`, `$body-bg`, `$body-color`, `$primary-back`, `$primary-surface`, `$primary-dark`
- surfaces, inline highlights, callouts: same names as the matching custom properties (drop the `--` prefix, replace with `$`)
- code chrome (invariant across light/dark): `$code-foreground-color`, `$code-background-color`, `$code-comment-color`, `$code-window-{titlebar-bg,border,line-divider,muted,line-number}`

To override in a consumer project, redeclare both halves of the theme key (overriding the whole `theme:` value drops the dark variant):

```yaml
format:
  hebstr-html:
    theme:
      light: [theme-light.scss, theme-base.scss, custom.scss]
      dark:  [theme-dark.scss,  theme-base.scss, custom.scss]
```

Place `custom.scss` **last** : Quarto layers SCSS files in the order given, with the **last** file's `scss:defaults` taking precedence over preceding ones — opposite to the standard Bootstrap convention.

## Example

Source: [example.qmd](example.qmd).

To render locally:

```bash
quarto render example.qmd
```

This produces `index.html` covering headings, lists, figures, tables, code blocks, equations, callouts, and cross-references. Typst (`example.pdf`) and DOCX (`example.docx`) outputs are planned for a later release.

## Licence

Code is released under the MIT Licence (see [LICENSE.md](LICENSE.md)). Bundled fonts retain their respective licences (see `_extensions/hebstr/fonts/`).
