# Contributing to hebstr-doc

This document covers the SemVer policy, the public API surface, and the release procedure for `hebstr-doc`.
For the SCSS layering and the variables it exposes, see [README.md](README.md); the public API surface below defines what of it is versioned.

## Public API surface

A change is "API-affecting" only if it touches one of these surfaces:

1. **Format names** declared in `_extension.yml`: `hebstr-doc-html`, `hebstr-doc-typst`, `hebstr-doc-docx`.
2. **SCSS variables** with `!default` in `theme-light.scss`, `theme-dark.scss`, or `theme-base.scss`.
3. **CSS custom properties** exposed under `:root` in `theme-base.scss`, each named after the SCSS variable it mirrors with `--` instead of `$`.
   The mapping is partial: typography defaults, the layout-chrome variables, and `$body-bg` / `$body-color` are consumed at compile time and have no `:root` counterpart.
4. **Frontmatter keys** wired through `_extension.yml` (`mainfont`, `monofont`, `linestretch`, `grid.*`, etc.).
5. **Shortcodes** registered in `_extension.yml`: currently `{{< script path >}}` and `{{< filetree >}}`, including the `filetree.yml` sidecar schema the latter reads.
6. **Bundled fonts** (Luciole, Fira Code, Font Awesome 7 Free, shipped as its Solid face): removing or replacing a font is API-affecting because consumer SCSS may reference the family name.
7. **`quarto-required`** version constraint in `_extension.yml`.
8. **Render-time R packages** the format requires through `_extension.yml` (currently `svglite`, wired as the HTML `knitr.opts_chunk.dev`): adding one makes a previously-working consumer render fail until it is installed.
9. **Shipped consumer-facing scripts**: currently `fonts/register.R`, which a project sources by path from its `.Rprofile` or a setup chunk.
   Moving or renaming it breaks that call site.
   It registers the bundled faces with `systemfonts` when the machine lacks them, and embeds Luciole regular and bold into svglite figures as web fonts through a `knitr::opts_hooks` entry; that second half is skipped when `knitr` or `svglite` is absent, and the script returns before either half when `systemfonts` is, so none of the three becomes a requirement beyond surface 8.
10. **Crossref types** declared under `crossref: custom:` in `_extension.yml`: currently `anx`, together with the `tbl-anx-` / `fig-anx-` carrier convention `filters/crossref-anx.lua` reads.
    Renaming the key or the carrier breaks every `@anx-…` reference and every annexe label in a consumer document.
    The `Annexe` prefix it ships is not part of the surface: a document overrides it by redeclaring the type.

Changes to private internals (rule selectors, computed colour-mix knobs that are not exposed as variables, internal helpers, file reorganisation that does not move public resources) are **not** API-affecting.
The `rhebstr` class that `filters/r-syntax.lua` adds to R code blocks is one of these: it exists so Pandoc resolves the bundled R syntax definition, it sits alongside the `r` class rather than replacing it, and it carries no promise.
The syntax colours themselves are internal for the same reason, being literals in `scss:rules` rather than `!default` variables; that is a gap rather than a decision, and closing it would add to surface 2.

## SemVer policy

Versioning follows [Semantic Versioning 2.0.0](https://semver.org), applied to the public API surface above.
While the extension is on a `0.x.y` line, MINOR bumps may include breaking changes if explicitly flagged in the changelog; from `1.0.0` onward, the rules below are strict.

  | Bump      | Triggers                                                                                                                                                                                                                                                                                                                                                                                                                                    |
  | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
  | **MAJOR** | Renaming or removing a public SCSS variable, CSS custom property, format name, shortcode, or crossref type. Removing a frontmatter key. Replacing a bundled font with one that has a different family name. Raising `quarto-required` to a version that drops support for previously-supported users. Moving or renaming a shipped consumer-facing script. Adding a render-time R package requirement that no documented frontmatter override opts out of. |
  | **MINOR** | Adding a new public SCSS variable, CSS custom property, format, frontmatter key, shortcode, or crossref type. Adding a bundled font or a shipped consumer-facing script. Lowering `quarto-required`. Adding a render-time R package requirement that a documented frontmatter override opts out of. Visual changes that consumers can opt out of via existing variables.                                                                                   |
  | **PATCH** | Fix that does not alter the public API. Internal refactors. Documentation. Visual fixes that bring the rendered output closer to the documented behaviour.                                                                                                                                                                                                                                                                                  |

When in doubt, ask: "Could a consumer's existing `_quarto.yml` or `custom.scss` stop working after this change?"
If yes, it is at least MINOR (with a deprecation note) or MAJOR (without a fallback).

**No-consumer clause.** The strict table above is a contract with installed consumers, and the extension currently has none.
Until it has known consumers, a breaking change to the public API surface may ship under a MINOR release when flagged in the changelog, rather than forcing a MAJOR bump.
The first MAJOR is reserved for the first break that would reach an actual installed consumer.

## Release procedure

Releases are git-tag-driven; the `release.yml` workflow turns each `v*` tag into a GitHub Release with auto-generated notes.

1. Update `version` in `_extensions/hebstr-doc/_extension.yml`.
2. Move `## [Unreleased]` entries in `CHANGELOG.md` under a new `## [X.Y.Z] - YYYY-MM-DD` heading; add a fresh empty `## [Unreleased]` on top.
3. Commit with message `vX.Y.Z` (or similar).
4. Tag annotated: `git tag -a vX.Y.Z -m "vX.Y.Z"`.
5. Push commit and tag: `git push && git push --tags`.
6. The `release.yml` workflow opens a GitHub Release; copy the relevant CHANGELOG section into the release body if the auto-generated notes are too terse.

Consumers pin via `quarto add hebstr/quarto-hebstr-doc@vX.Y.Z`, and the tag alone is what makes that form resolvable: GitHub serves a source archive for every tag, and Quarto downloads `archive/refs/tags/vX.Y.Z.tar.gz` from it.
Without a modifier, `quarto add hebstr/quarto-hebstr-doc` takes `archive/refs/heads/main.tar.gz`, so an unpinned consumer tracks `main` and receives every push whether it is tagged or not.
The literal `@latest` resolves the same way as the bare form, not to the last published version (`githubLatestUrlProvider` in Quarto's bundle; verified against Quarto 1.10.18).
The GitHub Release that `release.yml` opens is therefore for readers, not for the installer: Quarto queries GitHub's releases API for TinyTeX and for nothing else.
Tag anyway, and tag before telling a consumer to pin: it is the only thing that makes an install reproducible.

## Local validation

`example.qmd` at the repo root is the canonical local validation surface.
After editing the theme:

```bash
quarto render example.qmd --to hebstr-doc-html
```

That render needs the `svglite` package, which the HTML format sets as the knitr device, plus what `example.qmd` itself loads (`ggplot2`, `dplyr`, `palmerpenguins`, `sessioninfo`).
Its setup chunk sources `_extensions/hebstr-doc/fonts/register.R`, so the bundled faces are registered on a machine that lacks them and the figures do not fall back silently.

Currently HTML only: `hebstr-doc-typst` and `hebstr-doc-docx` are declared in `_extension.yml` but not yet validated, and `example.qmd` will declare all three once they are.

The in-tree Lua filters carry a [luaunit](https://github.com/bluebird75/luaunit) suite under `tests/`, which CI runs as its own step:

```bash
quarto pandoc lua tests/run.lua
```

A change to `filters/*.lua` is expected to keep that suite green and to add a fixture when it adds behaviour.

A second CI step covers what that suite cannot reach, the R syntax definition actually winning over the one Quarto bundles:

```bash
bash tests/r-syntax-tokens.sh
```

It renders `tests/r-syntax-probe.qmd` through the extension and asserts seven tokens in the HTML, one per divergence from the definition Quarto bundles, so a Quarto upgrade that reordered syntax-definition resolution fails here rather than silently reverting R code blocks to Pandoc's stock colours.
The probe is staged at the repo root for the render and removed afterwards.

A third step does the same for the `anx` crossref type:

```bash
bash tests/anx-float.sh
```

It renders `tests/anx-float-probe.qmd` and asserts the three authoring forms of an annexe against the HTML: the carrier prefix stripped, the custom float class applied, one counter shared by the three, and a `@anx-` reference resolved.
A float that stopped reaching the type would lose its number and its caption while the render still exited 0, which is what the assertions exist to catch.
This probe is staged and removed the same way.

## Pre-commit hooks

The repo ships a [`prek`](https://github.com/j178/prek) config (`prek.toml`): YAML/large-file/merge-conflict checks, secret scanning (gitleaks), R format/lint (air, jarl), Typst (typstyle), Lua (StyLua), shell format/lint (shfmt, shellcheck), CSS/SCSS lint plus format (stylelint, prettier), and prose-lint.
The same hooks run in CI (`render.yml`), alongside four gates that are not hooks: the three test steps above and a `lua-language-server --check` type pass.
Running the hooks locally therefore avoids most of a red build, not all of it.

The CSS/SCSS hooks resolve from `node_modules/.bin`, so install the pinned toolchain once before running them (stylelint 17 needs Node >= 20.19; CI pins 22):

```bash
npm ci                                   # restores the versions in package-lock.json
prek install                             # install the git hook (runs on commit)
prek run --all-files --skip prose-lint   # run everything once against the whole tree
```

The `prose-lint` hook is a local-only tool; skip it as shown (CI skips it too).
The SCSS rules live in `stylelint.config.mjs`, which extends `stylelint-config-standard-scss`: that base ruleset is what enforces hex shortening, one selector per line, lowercase `currentcolor`, a generic family on every `font-family`, and a namespaced `color.mix` over the global `mix`, so expect it to rewrite more than the three local rules describe.
Those three deliberately disable `comment-whitespace-inside` (its autofix rewrites Quarto's `/*-- scss:defaults --*/` region markers, and Quarto then rejects the theme file), ban both `@import` and `@use`, and widen `selector-class-pattern` to accept the camelCase classes Pandoc emits (`.sourceCode`, `.numberSource`).
`@import` is removed in Dart Sass 3.0.0 and a Quarto render swallows the deprecation warning, so the gate is the only signal.
`@use` is banned because Quarto concatenates user layers without deduplicating, so a consumer whose own `custom.scss` loads the same module fails the render on a duplicate namespace.
That closes the migration path `scss/no-global-function-names` suggests: reach for Bootstrap's `tint-color()` / `shade-color()` wrappers instead of `color.mix`, which also keeps the value typed as a colour for Quarto's SCSS analysis.
Both CSS hooks skip generated output (`_site/`, `_freeze/`, `*_files/`) and `_extensions/hebstr-doc/_extensions/`: the extensions embedded there are vendored upstream copies, and formatting them in place would drift from what `quarto add --embed` reinstalls.

## Where things live

- `_extensions/hebstr-doc/`: the extension itself (do not flatten).
- `_extensions/hebstr-doc/_extensions/`: embedded third-party extensions (currently `mcanouil/code-window`).
- `tests/`: luaunit suite for the in-tree Lua filters, entrypoint `run.lua`, plus the two render probes `r-syntax-tokens.sh` and `anx-float.sh` with the `.qmd` each renders; `prek.toml`, `stylua.toml`, `.styluaignore` and `.luarc.json` configure the Lua, shell and prose gates.
- `.github/workflows/`: `render.yml` (CI), `pages.yml` (demo deploy), `release.yml` (releases).
- `package.json` + `package-lock.json` + `stylelint.config.mjs`: the pinned CSS/SCSS gate toolchain and its rules; `node_modules/` is gitignored.
