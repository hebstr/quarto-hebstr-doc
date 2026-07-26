# Changelog

## [Unreleased]

### Added

- CSS/SCSS commit gate: `stylelint --fix` then `prettier --write` as two `prek` hooks, with the toolchain pinned in `package.json` and restored by `npm ci` in CI.
  The hooks exclude `_extensions/hebstr-doc/_extensions/`, whose contents are vendored upstream copies.

- `{{< filetree >}}` resolves more file types to a specific icon: extensions `mjs`, `cjs`, `rmd`, `htm`, `jsonc`, `json5`, `ttf`, `otf`, `gif`, `webp`, `avif`, `doc`, `odt`, `rtf`, and the names `.Rhistory`, `.luacheckrc`, `typst.toml`.
  Each reuses an icon already vendored and follows the Material Icon Theme mapping at the pinned v5.37.0, so no new SVG ships.
  These file types previously fell through to the generic `ft-i-document`, so a consumer overriding that class no longer reaches them.

- `{{< script >}}` names a malformed call site instead of absorbing it: an extra positional argument, an unknown attribute, a `numbers` value that is not a boolean, a `lines` spec that is not a range or that ends before it starts, and a non-numeric `dedent` each raise a render warning and fall back to the documented default.
  `numbers` accepts `true`/`yes`/`on`/`1` and their negatives, case-insensitively, matching `hidden` on `{{< filetree >}}`.

- The color-scheme toggle and the callout icons carry alternative text.
  The toggle sits beside the title in a `.hebstr-title-row` rather than inside the `h1`, so a control no longer joins the heading's accessible name or its heading-navigation target, and it gains an `aria-label` since Quarto builds it with no text.
  The Font Awesome glyphs are private-use codepoints, so `content: "…" / ""` gives them empty alternative text where that syntax is understood; elsewhere the plain declaration stands and the glyph renders unchanged.

### Changed

- The three theme stylesheets and `fonts/fonts.css` brought to gate conformance.
  The layout-chrome defaults move from Sass `mix()` to Bootstrap's `tint-color()` / `shade-color()`, which compute the same colours through a wrapper rather than the global built-in that `scss/no-global-function-names` rejects and Dart Sass 3.0.0 removes; `$callout-types` becomes a list of 5-tuples unpacked by `@each` destructuring, since the same rule rejects `nth()`; the two Font Awesome declarations gain a generic family; palette variables are grouped under `//` section headers.
  No public SCSS variable, CSS custom property, or compiled colour changes.

- `template.typ` drops a `#set document()` that configured nothing and a `#show heading` rule that suppressed the indent of the paragraph following a title.
  Typst's `first-line-indent` defaults to `all: false` and therefore only indents after another paragraph, so the rule was already redundant.

### Fixed

- `{{< script >}}`: the summary rewriter threw on the first code block rendered without `code-fold`, which has no `<summary>` to relabel.
  The exception aborted the whole script, so no block on the page got its filename.

- `{{< filetree >}}`: a `highlight` match on an expandable folder rendered without `$filetree-highlight` or its bold weight in `dynamic` mode.
  `.ft-hl > .ft-name` assumed the static shape, where the name is a direct child of the `li`; a toggled folder nests it under `details > summary`, so the child combinator missed it and only the `<strong>` fallback showed.

- `{{< filetree >}}`: a blank line or a `#` comment inside the `filetree:` block of the sidecar ended the sequence being read, so `exclude` and `highlight` silently lost every pattern written after one.
  A key left empty also yielded a list where the readers of `root`, `depth`, `hidden` and `mode` expect a string; those four now fall through to their default.

## [1.2.0] - 2026-07-21

### Added

- `{{< filetree >}}` shortcode: renders a directory tree walked from disk at render time.
  Config via a `filetree.yml` sidecar (`root`, `depth`, `mode`, `exclude`, `highlight`, `hidden`, `paths`); every key but `paths` is also a shortcode attribute overriding the sidecar, while `paths` supplies quoted inline-Markdown per-entry descriptions.
  HTML emits a nested `.filetree` list, other formats a bullet list.
  `root` and `annotations` resolve from the project root (one sidecar serves a whole project), a single-file render from the document's own directory.
  Malformed call sites (positional argument, unknown attribute, non-numeric `depth`, out-of-spec `hidden`, out-of-project `annotations`, empty tree) each raise a render warning.
- Filetree theming: dark surface in both light and dark modes, driven by five invariant SCSS variables (`$filetree-bg`, `$filetree-fg`, `$filetree-muted`, `$filetree-highlight`, `$filetree-guide`).
  Per-type icons (curated Material Icon Theme subset, MIT) inlined as a `--ft-icon` custom property so the page stays self-contained; the `ft-i-<key>` class overrides one icon from a `custom.scss`.
  Icons never carry meaning alone: directories keep their trailing slash, highlighted entries are wrapped in `<strong>`, and the truncation marker is labelled for assistive technology.
- `mode` attribute and sidecar key for `{{< filetree >}}`: `dynamic` renders each expandable folder as a JavaScript-free collapsible `<details>/<summary>` scoped by `.filetree-dynamic`, with `depth` as the level open on load and the folder icon switching to its `-open` variant on expand via `--ft-icon-open`.
  `static` (default) keeps the full tree to `depth`; non-HTML formats ignore `mode`.

### Changed

- `$tab-background` renamed to `$tab-surface`, now exposed at `:root` so it is overridable from a `custom.scss`.
  The old variable drove no rule, so nothing regresses.

- The `grid` defaults tighten: `body-width` from 1100px to 1000px and `margin-width` from 600px to 450px, `sidebar-width` and `gutter-width` unchanged.
  Both remain frontmatter overrides, so the previous measure is one `grid:` block away.

### Removed

- `fontsize: 1.2rem` is no longer declared by `hebstr-doc-html`; body text falls back to the Bootstrap default Quarto ships.
  `fontsize` is a stock Quarto key, not an extension invention, so a consumer wanting the previous measure declares it themselves.
  Shipped under MINOR rather than MAJOR per the no-consumer clause in [CONTRIBUTING.md](CONTRIBUTING.md).

### Fixed

- `{{< script >}}`: `dedent=n` stripped every space in the first `n` columns instead of the leading indentation, dropping an interior space on lines indented by less than `n` (`# top level comment` rendered as `#top level comment` under `dedent=4`).
  It now removes leading spaces only, at most `n`.

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
