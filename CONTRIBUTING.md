# Contributing to hebstr-doc

This document defines the public API surface, the versioning policy, the release procedure and the local checks for `hebstr-doc`.

## Public API surface

A change affects the public API only if it touches one of these surfaces:

1. **Format names** declared in `_extension.yml`: `hebstr-doc-html`, `hebstr-doc-typst`, `hebstr-doc-docx`.
2. **SCSS variables** declared with `!default` in `theme-light.scss`, `theme-dark.scss` or `theme-base.scss`, listed below.
3. **CSS custom properties** under `:root` in `theme-base.scss`, each named after its SCSS variable (`--primary` for `$primary`).
   Not every variable has one: typography defaults, layout chrome, `$body-bg` and `$body-color` are compile-time only.
4. **Front matter options** set in `_extension.yml` (`mainfont`, `monofont`, `linestretch`, `grid.*`, and so on).
5. **Shortcodes**: `{{< script >}}` and `{{< filetree >}}`, including the `filetree.yml` schema.
6. **Bundled fonts**: Luciole, Fira Code and Font Awesome 7 Free (Solid).
7. **`quarto-required`** in `_extension.yml`.
8. **Required R packages**: currently `svglite`, the device of the HTML format.
9. **Shipped scripts** that projects call by path: currently `fonts/register.R`.
10. **Cross-reference types**: currently `anx`, with its `tbl-anx-` and `fig-anx-` label prefixes.
    The `Annexe` caption prefix is not part of the surface.

The 47 SCSS variables of surface 2:

  | Group             | Declared in                            | Variables                                                                                                                                     |
  | ----------------- | -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
  | Typography        | `theme-base.scss`                      | `$font-family-sans-serif`, `$font-family-monospace`, `$font-size-root`, `$toc-font-size`, `$callout-icon-scale`                               |
  | Brand             | `theme-light.scss` + `theme-dark.scss` | `$primary`, `$primary-back`, `$primary-surface`, `$primary-dark`, `$secondary`                                                                |
  | Body              | `theme-light.scss` + `theme-dark.scss` | `$body-bg`, `$body-color`                                                                                                                     |
  | Surfaces          | `theme-light.scss` + `theme-dark.scss` | `$neutral`, `$em-background-color`, `$caption-color`                                                                                          |
  | Inline highlights | `theme-light.scss` + `theme-dark.scss` | `$str-color`, `$dig-color`                                                                                                                    |
  | Callouts          | `theme-light.scss` + `theme-dark.scss` | `$callout-{note,tip,caution,warning,important}-color`, `$callout-mix-base`, `$callout-text-mix`, `$callout-bg-mix`                            |
  | Code chrome       | `theme-base.scss`                      | `$code-foreground-color`, `$code-background-color`, `$code-comment-color`, `$code-window-{titlebar-bg,border,line-divider,muted,line-number}` |
  | Tabsets           | `theme-base.scss`                      | `$tab-surface`                                                                                                                                |
  | Filetree          | `theme-base.scss`                      | `$filetree-{bg,fg,muted,highlight,guide}`                                                                                                     |
  | Layout chrome     | `theme-light.scss` + `theme-dark.scss` | `$navbar-bg`, `$navbar-fg`, `$navbar-hl`, `$sidebar-bg`, `$sidebar-fg`, `$sidebar-hl`, `$footer-bg`, `$footer-fg`                             |

Variables declared in both scheme files take one value per colour scheme; those in `theme-base.scss` apply to both.
Layout chrome only applies to websites and books, and must be a Sass colour (hex, named, `tint-color()`, `shade-color()`): a CSS `color-mix()` breaks the build.
Code chrome and filetree colours are dark in both schemes by design.

Everything else is internal: selectors, unexposed colour computations, helper classes such as `rhebstr`, and the file layout inside the extension.
Syntax token colours are internal for now, as they are not exposed as variables.

## Versioning policy

Versions follow [Semantic Versioning 2.0.0](https://semver.org), applied to the public API surface above.

  | Bump      | Triggers                                                                                                                                                                                                                                                                                                                                             |
  | --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------                            |
  | **MAJOR** | Renaming or removing a public SCSS variable, CSS custom property, format, shortcode or cross-reference type. Removing a front matter option. Replacing a bundled font with a different family. Raising `quarto-required` beyond what existing users have. Moving or renaming a shipped script. Requiring a new R package with no documented opt-out. |
  | **MINOR** | Adding a public SCSS variable, CSS custom property, format, front matter option, shortcode, cross-reference type, bundled font or shipped script. Lowering `quarto-required`. Requiring a new R package with a documented opt-out. Visual changes that can be reverted through existing variables.                                                   |
  | **PATCH** | Fixes that do not change the public API. Internal refactoring. Documentation. Visual fixes that bring the output in line with the documentation.                                                                                                                                                                                                     |

To classify a change, ask whether an existing `_quarto.yml` or `custom.scss` could stop working after it.
If it could, the change is MINOR when a documented fallback exists, with a note in the changelog, and MAJOR otherwise.

**No-consumer clause.** While the extension has no known installed users, a breaking change may ship in a MINOR release if the changelog flags it as breaking.
The first MAJOR release is reserved for the first break that would affect an actual user.

## Release procedure

Git tags drive releases: `release.yml` creates a GitHub Release for each `v*` tag.

1. Update `version` in `_extensions/hebstr-doc/_extension.yml`.
2. In `CHANGELOG.md`, move the `## [Unreleased]` entries under `## [X.Y.Z] - YYYY-MM-DD` and add an empty `## [Unreleased]` above it.
3. Commit.
4. Create an annotated tag: `git tag -a vX.Y.Z -m "vX.Y.Z"`.
5. Push the commit and the tag: `git push && git push --tags`.
6. Check the GitHub Release created by `release.yml`, whose body is the tag's changelog section followed by the comparison link.
   The job fails if `CHANGELOG.md` has no non-empty `## [X.Y.Z]` section matching the tag.

Users pin a release with `quarto add hebstr/quarto-hebstr-doc@vX.Y.Z`, which downloads the tagged source archive.
`quarto add hebstr/quarto-hebstr-doc`, with or without `@latest`, installs the current `main` branch, not the latest release.

## Local checks

### Render

`example.qmd` is the reference document for visual checks:

```bash
quarto render example.qmd --to hebstr-doc-html
```

It requires the R packages `svglite`, `ggplot2`, `dplyr`, `gt`, `reactable`, `palmerpenguins` and `sessioninfo`.
It does not cover every rule of the theme: check anything it does not show in a separate test document.
Typst and Word are not yet rendered from `example.qmd`.

### Word template

`template.dotx` is generated; do not edit it in Word.
Change `scripts/build_template.py`, rebuild, then check the result:

```bash
uv run scripts/build_template.py
Rscript scripts/check-docx.R _extensions/hebstr-doc/template.dotx
```

`scripts/check-docx.R` accepts any `.docx` or `.dotx` and requires the `officer` and `xml2` R packages.
Changes to Word output should also be checked in Word itself: LibreOffice does not render or validate documents the way Word does.

### Tests

The Lua filters have a [luaunit](https://github.com/bluebird75/luaunit) test suite:

```bash
quarto pandoc lua tests/run.lua
```

Four scripts render test documents through the extension and check the output:

```bash
bash tests/r-syntax-tokens.sh   # R syntax highlighting
bash tests/anx-float.sh         # annexe cross-references
bash tests/docx-cell.sh         # Word table cells
bash tests/docx-template.sh     # Word styles, captions and table of contents
```

CI runs all of them, plus the pre-commit hooks and a `lua-language-server --check` pass.

## Pre-commit hooks

The repository uses [`prek`](https://github.com/j178/prek), configured in `prek.toml`.
The hooks check YAML, large files, merge conflicts and secrets, and format or lint R, Typst, Lua, shell scripts, stylesheets, HTML and JavaScript.

The stylesheet tools are pinned in `package.json` (Node 20.19 or later):

```bash
npm ci
prek install
prek run --all-files --skip prose-lint
```

`prose-lint` is a local tool and is skipped in CI.
The stylesheet rules live in `stylelint.config.mjs`.
`@import` and `@use` are not allowed in theme files: use Bootstrap's `tint-color()` and `shade-color()` instead of the `sass:color` module.

## Repository layout

- `_extensions/hebstr-doc/`: the extension.
- `_extensions/hebstr-doc/_extensions/`: embedded third-party extensions (`mcanouil/code-window`).
- `scripts/`: the script included by `example.qmd`, and the Word template build and check scripts.
- `tests/`: the Lua test suite and the render test scripts.
- `.github/workflows/`: `render.yml` (CI), `pages.yml` (demo site), `release.yml` (releases).
- `.github/dependabot.yml`: monthly update pull requests for the GitHub Actions and the npm packages.
  The `prek.toml` hooks are updated by hand with `prek update --cooldown-days 7`.
- `prek.toml`, `package.json`, `stylelint.config.mjs`, `stylua.toml`, `.luarc.json`: tooling configuration.
