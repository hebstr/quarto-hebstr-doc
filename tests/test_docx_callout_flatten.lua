local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/docx-callout-flatten.lua"

local function docx()
  return support.load_filter(FILTER, { formats = { docx = true } })
end

local function html()
  return support.load_filter(FILTER, { formats = { ["html:js"] = true, html = true } })
end

-- The fields Quarto's Callout constructor stores on the node, which a handler
-- reads through quarto.utils: the title slot is nil on an untitled callout.
local function callout(title, content, identifier)
  return {
    title = title,
    content = pandoc.Blocks(content or { pandoc.Para({ pandoc.Str("Body.") }) }),
    type = "note",
    appearance = "simple",
    icon = true,
    attr = pandoc.Attr(identifier or ""),
  }
end

TestDocxCalloutFlatten = {}

function TestDocxCalloutFlatten:test_a_title_comes_back_as_a_bold_paragraph()
  local out = docx().Callout(callout(pandoc.Inlines({ pandoc.Str("Note"), pandoc.Space(), pandoc.Str("title") })))
  lu.assertEquals(pandoc.utils.type(out), "Blocks")
  lu.assertEquals(out[1].t, "Para")
  lu.assertEquals(#out[1].content, 1)
  lu.assertEquals(out[1].content[1].t, "Strong")
  lu.assertEquals(pandoc.utils.stringify(out[1]), "Note title")
end

function TestDocxCalloutFlatten:test_an_inline_title_comes_back_as_a_bold_paragraph()
  local out = docx().Callout(callout(pandoc.Str("Note")))
  lu.assertEquals(out[1].t, "Para")
  lu.assertEquals(#out[1].content, 1)
  lu.assertEquals(out[1].content[1].t, "Strong")
  lu.assertEquals(pandoc.utils.stringify(out[1]), "Note")
end

function TestDocxCalloutFlatten:test_an_untitled_callout_opens_on_its_own_content()
  local out = docx().Callout(callout(nil))
  lu.assertEquals(#out, 1)
  lu.assertEquals(pandoc.utils.stringify(out[1]), "Body.")
  lu.assertEquals(#docx().Callout(callout(pandoc.Inlines({}))), 1)
end

function TestDocxCalloutFlatten:test_the_body_blocks_pass_through_untouched()
  local body = {
    pandoc.Para({ pandoc.Str("Lead"), pandoc.Space(), pandoc.Strong({ pandoc.Str("bold") }) }),
    pandoc.BulletList({ { pandoc.Plain({ pandoc.Str("one") }) }, { pandoc.Plain({ pandoc.Str("two") }) } }),
    pandoc.CodeBlock("x <- 1", pandoc.Attr("", { "r" })),
  }
  local out = docx().Callout(callout(pandoc.Inlines({ pandoc.Str("T") }), body))
  lu.assertEquals(#out, 4)
  lu.assertEquals(out[2], body[1])
  lu.assertEquals(out[3], body[2])
  lu.assertEquals(out[4], body[3])
end

-- Flattening happens before the crossref filters, so a reference to a
-- flattened callout would render as `?@nte-x`.
function TestDocxCalloutFlatten:test_a_callout_carrying_an_identifier_keeps_its_table()
  lu.assertNil(docx().Callout(callout(pandoc.Inlines({ pandoc.Str("T") }), nil, "nte-x")))
end

function TestDocxCalloutFlatten:test_another_format_keeps_its_callouts()
  lu.assertNil(html().Callout(callout(pandoc.Inlines({ pandoc.Str("T") }))))
end
