# Contributing to hebstr-doc

This document covers the SemVer policy, the public API surface, and the release procedure for `hebstr-doc`. For architecture and SCSS layering, see [.claude/CLAUDE.md](.claude/CLAUDE.md) and [README.md](README.md).

## Public API surface

A change is "API-affecting" only if it touches one of these surfaces:

1. **Format names** declared in `_extension.yml`: `hebstr-doc-html`, `hebstr-doc-typst`, `hebstr-doc-docx`.
2. **SCSS variables** with `!default` in `theme-light.scss`, `theme-dark.scss`, or `theme-base.scss`.
3. **CSS custom properties** exposed under `:root` in `theme-base.scss`, each named after the SCSS variable it mirrors with `--` instead of `$`. The mapping is partial: typography defaults, the layout-chrome variables, and `$body-bg` / `$body-color` are consumed at compile time and have no `:root` counterpart.
4. **Frontmatter keys** wired through `_extension.yml` (`mainfont`, `monofont`, `linestretch`, `grid.*`, etc.).
5. **Shortcodes** registered in `_extension.yml`: currently `{{< script path >}}` and `{{< filetree >}}`, including the `filetree.yml` sidecar schema the latter reads.
6. **Bundled fonts** (Luciole, Fira Code, Font Awesome 7 Solid): removing or replacing a font is API-affecting because consumer SCSS may reference the family name.
7. **`quarto-required`** version constraint in `_extension.yml`.

Changes to private internals (rule selectors, computed colour-mix knobs that are not exposed as variables, internal helpers, file reorganisation that does not move public resources) are **not** API-affecting.

## SemVer policy

Versioning follows [Semantic Versioning 2.0.0](https://semver.org), applied to the public API surface above. While the extension is on a `0.x.y` line, MINOR bumps may include breaking changes if explicitly flagged in the changelog; from `1.0.0` onward, the rules below are strict.

| Bump | Triggers |
|---|---|
| **MAJOR** | Renaming or removing a public SCSS variable, CSS custom property, format name, or shortcode. Removing a frontmatter key. Replacing a bundled font with one that has a different family name. Raising `quarto-required` to a version that drops support for previously-supported users. |
| **MINOR** | Adding a new public SCSS variable, CSS custom property, format, frontmatter key, or shortcode. Adding a bundled font. Lowering `quarto-required`. Visual changes that consumers can opt out of via existing variables. |
| **PATCH** | Fix that does not alter the public API. Internal refactors. Documentation. Visual fixes that bring the rendered output closer to the documented behaviour. |

When in doubt, ask: "Could a consumer's existing `_quarto.yml` or `custom.scss` stop working after this change?" If yes, it is at least MINOR (with a deprecation note) or MAJOR (without a fallback).

**No-consumer clause.** The strict table above is a contract with installed consumers, and the extension currently has none. Until it has known consumers, a breaking change to the public API surface may ship under a MINOR release when flagged in the changelog, rather than forcing a MAJOR bump. The first MAJOR is reserved for the first break that would reach an actual installed consumer.

## Release procedure

Releases are git-tag-driven; the `release.yml` workflow turns each `v*` tag into a GitHub Release with auto-generated notes.

1. Update `version` in `_extensions/hebstr-doc/_extension.yml`.
2. Move `## [Unreleased]` entries in `CHANGELOG.md` under a new `## [X.Y.Z] - YYYY-MM-DD` heading; add a fresh empty `## [Unreleased]` on top.
3. Commit with message `vX.Y.Z` (or similar).
4. Tag annotated: `git tag -a vX.Y.Z -m "vX.Y.Z"`.
5. Push commit and tag: `git push && git push --tags`.
6. The `release.yml` workflow opens a GitHub Release; copy the relevant CHANGELOG section into the release body if the auto-generated notes are too terse.

Consumers pin via `quarto add hebstr/quarto-hebstr-doc@vX.Y.Z`. Always tag: Quarto resolves `quarto add user/repo` to the latest release if any tag exists, otherwise to the default branch.

## Local validation

`example.qmd` at the repo root is the canonical local validation surface. After editing the theme:

```bash
quarto render example.qmd --to hebstr-doc-html
```

Currently HTML only; once Typst and DOCX are validated (see [.claude/PLAN.md](.claude/PLAN.md), P1), extend `example.qmd` to declare all three formats and render each.

## Pre-commit hooks

The repo ships a [`prek`](https://github.com/j178/prek) config (`prek.toml`): YAML/large-file/merge-conflict checks, secret scanning (gitleaks), R format/lint (air, jarl), Typst (typstyle), and Lua (StyLua).
The same hooks run in CI (`render.yml`), so running them locally before pushing avoids a red build.

```bash
prek install                             # install the git hook (runs on commit)
prek run --all-files --skip prose-lint   # run everything once against the whole tree
```

The `prose-lint` hook is a local-only tool; skip it as shown (CI skips it too).

## Where things live

- `_extensions/hebstr-doc/`: the extension itself (do not flatten).
- `_extensions/hebstr-doc/_extensions/`: embedded third-party extensions (currently `mcanouil/code-window`).
- `.claude/PLAN.md`: post-v1.0 backlog.
- `.claude/DEFERRED.md`: items intentionally postponed.
- `.github/workflows/`: `render.yml` (CI), `pages.yml` (demo deploy), `release.yml` (releases).
