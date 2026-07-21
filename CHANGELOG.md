# Changelog

## [Unreleased]

### Added

- `{{< filetree >}}` shortcode: renders a directory tree walked from disk at render time.
  Configuration lives in a `filetree.yml` sidecar: `root`, `depth`, `mode`, `exclude`, `highlight` and `hidden`, each also accepted as a shortcode attribute that overrides the sidecar, plus `paths` for the per-entry descriptions, which the sidecar alone supplies.
  Descriptions accept inline Markdown and must be quoted, and a `paths` key that never appears in the rendered tree raises a render warning.
  HTML emits a nested list styled by the new `.filetree` rules in `theme-base.scss`, other formats fall back to a bullet list.
  The `annotations` path is constrained to the project, so an absolute path or one climbing out with `..` is refused with a warning instead of read.
  A call site that misses the documented form is named rather than absorbed: a positional argument, an unknown attribute, a non-numeric `depth` and a `hidden` value outside the accepted boolean spellings (`true`/`yes`/`on`/`1` and their negatives, case-insensitive) each raise a render warning.
  A tree with nothing left to show warns too, and its box is hidden rather than drawn empty, which a bordered card with no entry would make look like a defect.
  `root` and `annotations` resolve from the project root rather than from the calling document, so a document in a subdirectory trees the project and one sidecar serves the whole project; a single-file render, having no project, keeps resolving against the document's own directory.
- Filetree theming: the box keeps a dark surface in both light and dark modes, on the same reasoning as the code window, driven by five new invariant variables in `theme-base.scss` (`$filetree-bg`, `$filetree-fg`, `$filetree-muted`, `$filetree-highlight`, `$filetree-guide`).
  Entries carry per-type icons from a curated Material Icon Theme subset (MIT, upstream v5.37.0) vendored under `_extensions/hebstr-doc/icons/`.
  The recognised set covers source files (`.R`, `.py`, `.qmd`, `.lua`, `.scss`, `.css`, `.html`, `.js`, `.typ`), config and data formats (`.yml`, `.json`, `.toml`, `.lock`, `.env`), and named files (`README.md`, `LICENSE`, `.gitignore`, `.gitattributes`, `.Rprofile`, `.Renviron`); an unmatched file falls back to a generic document icon and an unmatched directory to a folder icon.
  The shortcode reads each icon and inlines it as a `--ft-icon` custom property on the entry, so no request leaves the page, only the icons actually used are embedded, and the `ft-i-<key>` class stays available to override one icon from a `custom.scss`.
  The icon is never the sole carrier of meaning: directories keep their trailing slash, a highlighted entry is wrapped in `<strong>`, and the `…` truncation marker is hidden from assistive technology in favour of a spelled-out label.
- `{{< filetree >}}` gains a `mode` attribute and sidecar key.
  `dynamic` renders each expandable folder as a collapsible native `<details>/<summary>` with no JavaScript, scoped by a `.filetree-dynamic` class so the static tree is untouched; `depth` becomes the level open on load, deeper folders stay collapsed, and the Material folder icon switches to its `-open` variant on expand through a `--ft-icon-open` custom property.
  `static` stays the default and keeps the full tree to `depth`.
  Non-HTML formats ignore `mode` and keep the depth-bounded bullet list.
  The open-folder icons (`folder-base-open`, `folder-github-open`) are generated at build time rather than committed to the theme's git source, so they are vendored from its npm package at the same v5.37.0.

### Changed

- `$tab-background` is replaced by `$tab-surface`, moved from `theme-light.scss` / `theme-dark.scss` to `theme-base.scss`.
  `$tab-background` was declared and exposed as `--tab-background` but consumed by no rule, so overriding it never changed anything and no consumer can regress; the tabset fill has always come from the tint of `$primary` now published under its own name.
  `--tab-surface` also moves from the `.panel-tabset` scope to `:root`, which is what makes it overridable from a `custom.scss`.

### Fixed

- `{{< script >}}`: the `dedent` attribute stripped every space in the first `n` columns instead of the leading indentation, so a line indented by less than `n` lost an interior space (`# top level comment` rendered as `#top level comment` under `dedent=4`).
  It now removes leading spaces only, at most `n`, and dedents a shallower line as far as its own indentation allows.
  Lines indented by `n` or more are unaffected, which is the case every existing render exercised.

## [1.1.0] - 2026-07-07

### Added

- SVG lightbox figures now scale to fit the viewport (`object-fit: contain` inside a 90vw by 90vh box) instead of displaying at their small intrinsic size.
  Scoped to SVG via `img[src^="data:image/svg+xml"]` in `theme-base.scss`; raster (PNG) figures keep Quarto's default fit.

### Changed

- HTML figures render as SVG (`fig-format: svg`) via R's built-in cairo device instead of the default raster, so output is vector (crisp at any zoom) with no added R dependency.
  Opt into the `svglite` device (selectable text, lighter files; needs the `svglite` R package) per document with `knitr.opts_chunk.dev: svglite`, or render raster with `fig-format: png`.
  Scoped to `hebstr-doc-html`; Typst and DOCX keep `default-image-extension: png`.

## [1.0.0] - 2026-04-29

First public stable release.
The public API surface (formats, SCSS variables, CSS custom properties, frontmatter keys, shortcodes, bundled fonts, `quarto-required`) is now versioned per [CONTRIBUTING.md](CONTRIBUTING.md): MAJOR for breaking changes, MINOR for additions, PATCH for fixes.

### Added

- Public SCSS API for layout chrome: `$navbar-bg`, `$navbar-fg`, `$navbar-hl`, `$sidebar-bg`, `$sidebar-fg`, `$sidebar-hl`, `$footer-bg`, `$footer-fg` (defaults in `theme-light.scss` and `theme-dark.scss`, derived from the existing palette via Sass `mix()`).
  These variables are consumed by Quarto's Bootstrap layer at compile time and only take effect in project layouts (book, website); single-document renders are unaffected.
  No CSS custom property counterpart is exposed because Quarto's Bootstrap calls `theme-contrast()` on them, which requires Sass-resolvable colours.
- [CONTRIBUTING.md](CONTRIBUTING.md): public API surface, SemVer policy, release procedure, local validation, repo layout.
- README section covering the new layout-chrome variables.

### Changed

- Bootstrap-Quarto couples `$navbar-bg` / `$navbar-fg` to the `.quarto-title-banner` rules.
  Consumers using `title-block-banner: true` on `hebstr-doc-html` will see their banner background switch from Quarto's slate-blue default (`#517699`) to the new hebstr navbar-bg (light tint of `$primary` in light theme; dark tint in dark theme).
  Opt out by setting `title-block-banner: false`, by overriding `.quarto-title-banner { background: ... }` in a custom SCSS layer, or by overriding `$navbar-bg` itself.

## [0.12.0] - 2026-04-28

### Changed

- **Breaking**: extension renamed `hebstr` → `hebstr-doc` and repo renamed `quarto-hebstr` → `quarto-hebstr-doc` under the `hebstr-*` namespace.
  Re-run `quarto add hebstr/quarto-hebstr-doc` and update `format:` to `hebstr-doc-html` / `hebstr-doc-typst` / `hebstr-doc-docx`.
  Extension directory moved to `_extensions/hebstr-doc/`; the Typst raw-theme path in `template.typ` was updated accordingly.

### Added

- Frontmatter overrides for the most common aesthetic knobs, surfaced at the format level in `_extension.yml`: `mainfont`, `monofont`, `fontsize`, `linestretch` (joining `page-layout`, `toc*`, `grid.*`).
  Consumers can retune typography and layout from a document's YAML without writing SCSS.
- `_brand.yml` interop: existing `$primary` / `$secondary` `!default` SCSS already defers to Quarto's brand layer, and derived shades recompute via `color-mix`.
  Cross-format brand colours and typography work without any extension change.
- Release pipeline via GitHub Actions: `render.yml` (HTML render on push/PR, artefact upload), `pages.yml` (deploy demo via `actions/deploy-pages@v4`), `release.yml` (GitHub Release on `v*` tag with auto-generated notes).
  README badges (CI, Pages, release, MIT) and `.gitignore` entries for `_site/` plus R session artefacts (`.Rhistory`, `.RData`, `.Ruserdata`, `.Rproj.user/`).

### Fixed

- `linestretch` from the YAML is now respected.
  Previously a hardcoded `p { line-height: 1.75rem }` in `theme-base.scss` shadowed Bootstrap's `$line-height-base`, silently ignoring any consumer override.
  The rule was removed; `linestretch: 1.75` (the new default) reproduces the prior look.

## [0.11.0] - 2026-04-27

### Added

- Light and dark theme support, switchable via Quarto's color-scheme toggle (sun/moon icon, rendered with Font Awesome, anchored in the document title).
- Font Awesome 7 Solid bundled locally (no CDN dependency at render time).

### Changed

- **Breaking** for consumers overriding the theme directly: the single `theme.scss` is gone.
  Use `format: hebstr-html` (recommended), or wire `theme: { light: [theme-light.scss, theme-base.scss], dark: [theme-dark.scss, theme-base.scss] }`.
- Callout colors adapt to the active theme.
  `tip` and `warning` body text are slightly darker than before.
- `anchor-sections: false` by default (no hover-anchor icons next to headings).

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
