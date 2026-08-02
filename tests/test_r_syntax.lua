local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/r-syntax.lua"
local LANG = "rhebstr"

local function block(...)
  return pandoc.CodeBlock("palmerpenguins::penguins", pandoc.Attr("", { ... }))
end

TestRSyntax = {}

function TestRSyntax:test_html_prepends_the_language_class()
  local f = support.load_filter(FILTER, { formats = { html = true } })
  local out = f.CodeBlock(block("r"))
  lu.assertEquals(out.classes, pandoc.List({ LANG, "r" }))
end

function TestRSyntax:test_docx_prepends_the_language_class()
  local f = support.load_filter(FILTER, { formats = { docx = true } })
  local out = f.CodeBlock(block("r"))
  lu.assertEquals(out.classes[1], LANG)
end

-- Pandoc highlights with the first class that resolves to a syntax, so an
-- appended class would silently hand the block back to Quarto's own r.xml.
function TestRSyntax:test_language_class_comes_before_r()
  local f = support.load_filter(FILTER, { formats = { html = true } })
  local out = f.CodeBlock(block("r", "cell-code", "cw-auto"))
  lu.assertEquals(out.classes[1], LANG)
  lu.assertEquals(out.classes[2], "r")
  lu.assertTrue(out.classes:includes("cell-code"))
  lu.assertTrue(out.classes:includes("cw-auto"))
end

-- Typst re-emits a raw fence and highlights it itself, where an unknown
-- language name leaves the block uncoloured.
function TestRSyntax:test_typst_is_left_alone()
  local f = support.load_filter(FILTER, { formats = { typst = true } })
  lu.assertNil(f.CodeBlock(block("r")))
end

function TestRSyntax:test_other_languages_are_left_alone()
  local f = support.load_filter(FILTER, { formats = { html = true } })
  lu.assertNil(f.CodeBlock(block("python")))
  lu.assertNil(f.CodeBlock(block()))
end

function TestRSyntax:test_already_routed_block_is_left_alone()
  local f = support.load_filter(FILTER, { formats = { html = true } })
  lu.assertNil(f.CodeBlock(block(LANG, "r")))
end
