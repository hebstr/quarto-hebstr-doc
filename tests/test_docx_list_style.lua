local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/docx-list-style.lua"

local function docx()
  return support.load_filter(FILTER, { formats = { docx = true } })
end

local function para(text)
  return pandoc.Para({ pandoc.Str(text) })
end

local function plain(text)
  return pandoc.Plain({ pandoc.Str(text) })
end

local function styles(blocks)
  local found = {}
  pandoc.Blocks(blocks):walk({
    Div = function(div)
      found[#found + 1] = div.attributes["custom-style"]
    end,
  })
  return found
end

TestDocxListStyle = {}

function TestDocxListStyle:test_a_loose_item_takes_the_list_style()
  local out = docx().BulletList(pandoc.BulletList({ { para("one") }, { para("two") } }))
  lu.assertEquals(styles(out.content[1]), { "List Item" })
  lu.assertEquals(styles(out.content[2]), { "List Item" })
  lu.assertEquals(out.content[1][1].t, "Div")
  lu.assertEquals(out.content[1][1].content[1].t, "Para")
end

-- A tight item is a Plain, which Pandoc already writes in `Compact`.
function TestDocxListStyle:test_a_tight_list_is_left_alone()
  lu.assertNil(docx().BulletList(pandoc.BulletList({ { plain("one") }, { plain("two") } })))
end

function TestDocxListStyle:test_an_ordered_list_keeps_its_list_attributes()
  local attrs = pandoc.ListAttributes(3, pandoc.LowerRoman, pandoc.Period)
  local out = docx().OrderedList(pandoc.OrderedList({ { para("one") } }, attrs))
  lu.assertEquals(styles(out.content[1]), { "List Item" })
  lu.assertEquals(out.listAttributes.start, 3)
  lu.assertEquals(out.listAttributes.style, "LowerRoman")
  lu.assertEquals(out.listAttributes.delimiter, "Period")
end

-- A multi-paragraph item is styled throughout, each paragraph being a Para.
function TestDocxListStyle:test_every_paragraph_of_an_item_is_styled()
  local out = docx().BulletList(pandoc.BulletList({ { para("one"), para("still one") } }))
  lu.assertEquals(styles(out.content[1]), { "List Item", "List Item" })
end

-- Anything but a Para keeps the style its own block carries: a nested list is
-- reached when the filter visits it, a code block has `Source Code`.
function TestDocxListStyle:test_other_blocks_of_an_item_are_left_untouched()
  local nested = pandoc.BulletList({ { plain("inner") } })
  local out = docx().BulletList(pandoc.BulletList({ { plain("one"), nested, pandoc.CodeBlock("x <- 1") } }))
  lu.assertNil(out)
end

function TestDocxListStyle:test_a_mixed_item_styles_only_its_paragraphs()
  local out = docx().BulletList(pandoc.BulletList({ { plain("one"), para("and more") } }))
  lu.assertEquals(styles(out.content[1]), { "List Item" })
  lu.assertEquals(out.content[1][1].t, "Plain")
  lu.assertEquals(out.content[1][2].t, "Div")
end

function TestDocxListStyle:test_other_formats_are_left_alone()
  local html = support.load_filter(FILTER, { formats = { ["html:js"] = true } })
  lu.assertNil(html.BulletList(pandoc.BulletList({ { para("one") } })))
  lu.assertNil(html.OrderedList(pandoc.OrderedList({ { para("one") } })))
end
