local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/docx-layout-flatten.lua"

local function docx()
  return support.load_filter(FILTER, { formats = { docx = true } })
end

local function html()
  return support.load_filter(FILTER, { formats = { ["html:js"] = true, html = true } })
end

local function row(attributes, classes, identifier)
  return pandoc.Div(
    { pandoc.Para({ pandoc.Str("left") }), pandoc.Para({ pandoc.Str("right") }) },
    pandoc.Attr(identifier or "", classes or {}, attributes)
  )
end

TestDocxLayoutFlatten = {}

function TestDocxLayoutFlatten:test_a_layout_row_loses_the_key_that_builds_the_table()
  local out = docx().Div(row({ ["layout-ncol"] = "2" }))
  lu.assertNil(out.attributes["layout-ncol"])
  lu.assertEquals(#out.content, 2)
  lu.assertEquals(pandoc.utils.stringify(out.content[1]), "left")
end

function TestDocxLayoutFlatten:test_every_layout_key_goes()
  local out = docx().Div(row({
    ["layout"] = "[[1,1]]",
    ["layout-nrow"] = "2",
    ["layout-align"] = "left",
    ["layout-valign"] = "top",
  }))
  lu.assertEquals(out.attributes, pandoc.Attr().attributes)
end

-- The Div survives the strip, so a class the author put on it keeps working.
function TestDocxLayoutFlatten:test_the_div_keeps_its_identifier_classes_and_other_attributes()
  local out = docx().Div(row({ ["layout-ncol"] = "2", width = "70%" }, { "column-page" }, "shots"))
  lu.assertEquals(out.identifier, "shots")
  lu.assertEquals(out.classes, pandoc.List({ "column-page" }))
  lu.assertEquals(out.attributes["width"], "70%")
end

function TestDocxLayoutFlatten:test_a_div_carrying_no_layout_is_left_alone()
  lu.assertNil(docx().Div(row({}, { "callout-note" })))
end

function TestDocxLayoutFlatten:test_another_format_keeps_its_layout()
  lu.assertNil(html().Div(row({ ["layout-ncol"] = "2" })))
end
