export default {
  extends: ["stylelint-config-standard-scss"],
  rules: {
    // Quarto region markers (/*-- scss:defaults --*/) carry no inner whitespace;
    // the rule's autofix rewrites them and Quarto then rejects the theme file
    "comment-whitespace-inside": null,
    // Pandoc emits camelCase classes (.sourceCode, .numberSource) that cannot be renamed
    "selector-class-pattern": "^[a-zA-Z][a-zA-Z0-9_-]*$",
    // Sass @import is deprecated since Dart Sass 1.80.0 and removed in 3.0.0; the
    // compiler warning is swallowed by a Quarto render, so the gate is the only signal.
    // @use is banned for a different reason: Quarto concatenates user layers without
    // deduplicating, so a consumer loading the same module fails the render on a
    // duplicate namespace
    "at-rule-disallowed-list": ["import", "use"],
  },
};
