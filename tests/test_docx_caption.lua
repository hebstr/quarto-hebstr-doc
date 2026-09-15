local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/docx-caption.lua"
local RAW_PPR =
  '<w:pPr>\n<w:jc w:val="left"/>\n<w:spacing w:before="200" />\n<w:pStyle w:val="ImageCaption" />\n</w:pPr>\n'

local function docx()
  return support.load_filter(FILTER, { formats = { docx = true } })
end

local function caption(...)
  local inlines = { pandoc.RawInline("openxml", RAW_PPR) }
  for _, el in ipairs({ ... }) do
    inlines[#inlines + 1] = el
  end
  return pandoc.Para(inlines)
end

local function image()
  return pandoc.Plain({ pandoc.Image({}, "dot.png") })
end

local function wrapper(blocks, align)
  return pandoc.Table(
    { long = {}, short = {} },
    { { align or pandoc.AlignCenter, 1.0 } },
    pandoc.TableHead(),
    { { attr = pandoc.Attr(), body = { pandoc.Row({ pandoc.Cell(blocks) }) }, head = {}, row_head_columns = 0 } },
    pandoc.TableFoot()
  )
end

local function contents(tbl)
  return tbl.bodies[1].body[1].cells[1].contents
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

local function raw_openxml_count(blocks)
  local n = 0
  pandoc.Blocks(blocks):walk({
    RawInline = function(r)
      if r.format == "openxml" then
        n = n + 1
      end
    end,
  })
  return n
end

TestDocxCaption = {}

function TestDocxCaption:test_a_caption_after_its_figure_is_an_image_caption()
  local out = docx().Table(wrapper({ image(), caption(pandoc.Str("Bottom")) }))
  lu.assertEquals(styles(contents(out)), { "Captioned Figure", "Image Caption" })
  lu.assertEquals(raw_openxml_count(contents(out)), 0)
end

-- The DOCX writer forces `Compact` onto a Plain in a table cell, over any Div style.
function TestDocxCaption:test_the_image_becomes_a_para_so_its_style_holds()
  local out = docx().Table(wrapper({ image(), caption(pandoc.Str("x")) }))
  lu.assertEquals(contents(out)[1].content[1].t, "Para")
end

-- A figure moved to fig-cap-location: top reads like a table caption.
function TestDocxCaption:test_a_caption_before_its_figure_is_a_table_caption()
  local out = docx().Table(wrapper({ caption(pandoc.Str("Top")), image() }))
  lu.assertEquals(styles(contents(out)), { "Table Caption", "Figure" })
end

function TestDocxCaption:test_a_table_float_keeps_its_content_untouched()
  local inner = pandoc.RawBlock("openxml", "<w:tbl/>")
  local out = docx().Table(wrapper({ caption(pandoc.Str("Table")), inner }))
  local blocks = contents(out)
  lu.assertEquals(styles(blocks), { "Table Caption" })
  lu.assertEquals(blocks[2].text, "<w:tbl/>")
end

-- The centring moves to the image style, or it would reach the caption as a
-- direct alignment Word ranks above any style.
function TestDocxCaption:test_a_centred_wrapper_loses_its_direct_alignment()
  local out = docx().Table(wrapper({ image(), caption(pandoc.Str("x")) }))
  lu.assertEquals(out.colspecs[1][1], pandoc.AlignDefault)
end

function TestDocxCaption:test_a_wrapper_aligned_otherwise_keeps_its_alignment()
  local out = docx().Table(wrapper({ image(), caption(pandoc.Str("x")) }, pandoc.AlignLeft))
  lu.assertEquals(out.colspecs[1][1], pandoc.AlignLeft)
  lu.assertEquals(styles(contents(out)), { "Image Caption" })
end

-- knitr nests the float inside its cell output divs.
function TestDocxCaption:test_a_caption_nested_in_divs_is_found()
  local nested = pandoc.Div({ pandoc.Div({ image(), caption(pandoc.Str("Nested")) }) })
  local out = docx().Table(wrapper({ nested }))
  lu.assertEquals(styles(contents(out)), { "Captioned Figure", "Image Caption" })
end

-- hebstr::str_fig() writes `title<br><span class='quarto-float-subcaption'>`.
function TestDocxCaption:test_a_subcaption_breaks_the_line_and_takes_its_own_style()
  local sub = pandoc.Span({ pandoc.Str("Note") }, pandoc.Attr("", { "quarto-float-subcaption" }))
  local out = docx().Table(wrapper({ image(), caption(pandoc.Str("Title"), pandoc.RawInline("html", "<br>"), sub) }))
  local para = contents(out)[2].content[1]
  lu.assertEquals(para.content[1].text, "Title")
  lu.assertEquals(para.content[2].t, "LineBreak")
  lu.assertEquals(para.content[3].attributes["custom-style"], "Caption Subtitle")
end

function TestDocxCaption:test_a_table_without_a_quarto_caption_is_left_alone()
  lu.assertNil(docx().Table(wrapper({ image(), pandoc.Para({ pandoc.Str("plain") }) })))
end

function TestDocxCaption:test_other_formats_are_left_alone()
  local f = support.load_filter(FILTER, { formats = { html = true } })
  lu.assertNil(f.Table(wrapper({ image(), caption(pandoc.Str("x")) })))
end
