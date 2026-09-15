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

local function float(id, blocks)
  return pandoc.Div(blocks, pandoc.Attr(id))
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

function TestDocxCaption:test_a_figure_float_keeps_its_wrapper()
  local out = docx().Table(wrapper({ float("fig-x", { image(), caption(pandoc.Str("x")) }) }))
  lu.assertEquals(out.t, "Table")
end

-- Word crushes a table nested in the wrapper's fixed-layout cell.
function TestDocxCaption:test_a_raw_table_float_leaves_its_wrapper()
  local inner = pandoc.RawBlock("openxml", "<w:tbl/>")
  local out = docx().Table(wrapper({ float("tbl-x", { caption(pandoc.Str("Table")), inner }) }))
  lu.assertEquals(#out, 1)
  lu.assertEquals(out[1].t, "Div")
  lu.assertEquals(styles(out), { "Table Caption" })
  lu.assertEquals(out[1].content[2].text, "<w:tbl/>")
end

-- Pandoc writes the bookmark cross-references point to from the Div identifier.
function TestDocxCaption:test_the_unwrapped_float_keeps_its_identifier()
  local inner = pandoc.RawBlock("openxml", "<w:tbl/>")
  local out = docx().Table(wrapper({ float("tbl-x", { caption(pandoc.Str("Table")), inner }) }))
  lu.assertEquals(out[1].identifier, "tbl-x")
end

function TestDocxCaption:test_a_pandoc_table_float_leaves_its_wrapper()
  local inner = wrapper({ pandoc.Plain({ pandoc.Str("1") }) }, pandoc.AlignDefault)
  local out = docx().Table(wrapper({ float("tbl-x", { caption(pandoc.Str("Table")), inner }) }))
  lu.assertEquals(out[1].content[2].t, "Table")
end

-- knitr nests the table inside its cell output div.
function TestDocxCaption:test_a_table_nested_in_divs_leaves_its_wrapper()
  local inner = pandoc.Div({ pandoc.RawBlock("openxml", '<w:tbl xmlns:w="w">') })
  local out = docx().Table(wrapper({ float("tbl-x", { caption(pandoc.Str("Table")), inner }) }))
  lu.assertEquals(out[1].identifier, "tbl-x")
end

function TestDocxCaption:test_a_table_captioned_below_leaves_its_wrapper_in_order()
  local inner = pandoc.RawBlock("openxml", "<w:tbl/>")
  local out = docx().Table(wrapper({ float("tbl-x", { inner, caption(pandoc.Str("Table")) }) }))
  lu.assertEquals(out[1].content[1].text, "<w:tbl/>")
  lu.assertEquals(styles(out), { "Image Caption" })
end

function TestDocxCaption:test_a_float_mixing_a_table_and_prose_keeps_its_wrapper()
  local blocks =
    { caption(pandoc.Str("Table")), pandoc.RawBlock("openxml", "<w:tbl/>"), pandoc.Para({ pandoc.Str("Note") }) }
  lu.assertEquals(docx().Table(wrapper({ float("tbl-x", blocks) })).t, "Table")
end

function TestDocxCaption:test_raw_openxml_other_than_a_table_keeps_its_wrapper()
  local blocks = { caption(pandoc.Str("Table")), pandoc.RawBlock("openxml", "<w:p/>") }
  lu.assertEquals(docx().Table(wrapper({ float("tbl-x", blocks) })).t, "Table")
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

local function subcaption()
  return pandoc.Span({ pandoc.Str("Note") }, pandoc.Attr("", { "quarto-float-subcaption" }))
end

-- hebstr::str_fig() writes `title<br>\n  <span class='quarto-float-subcaption'>`.
local function subtitled()
  return caption(
    pandoc.Str("Title"),
    pandoc.Space(),
    pandoc.RawInline("html", "<br>"),
    pandoc.SoftBreak(),
    subcaption()
  )
end

-- Word keeps a character style's `w:b w:val="0"` bold inside a bold paragraph.
function TestDocxCaption:test_a_subcaption_becomes_a_paragraph_of_its_own()
  local out = docx().Table(wrapper({ image(), subtitled() }))
  lu.assertEquals(styles(contents(out)), { "Captioned Figure", "Image Caption", "Image Caption Subtitle" })
end

function TestDocxCaption:test_the_title_and_subtitle_lose_the_blanks_around_the_break()
  local blocks = contents(docx().Table(wrapper({ image(), subtitled() })))
  lu.assertEquals(pandoc.utils.stringify(blocks[2]), "Title")
  lu.assertEquals(#blocks[2].content[1].content, 1)
  lu.assertEquals(blocks[3].content[1].content[1].text, "Note")
  lu.assertEquals(#blocks[3].content[1].content, 1)
end

function TestDocxCaption:test_a_top_subcaption_follows_its_title_above_the_table()
  local inner = pandoc.RawBlock("openxml", "<w:tbl/>")
  local out = docx().Table(wrapper({ float("tbl-x", { subtitled(), inner }) }))
  lu.assertEquals(styles(out), { "Table Caption", "Table Caption Subtitle" })
  lu.assertEquals(out[1].content[3].text, "<w:tbl/>")
end

function TestDocxCaption:test_a_caption_without_a_subcaption_stays_one_paragraph()
  local out = docx().Table(wrapper({ image(), caption(pandoc.Str("Only"), pandoc.RawInline("html", "<br>")) }))
  lu.assertEquals(styles(contents(out)), { "Captioned Figure", "Image Caption" })
end

function TestDocxCaption:test_a_table_without_a_quarto_caption_is_left_alone()
  lu.assertNil(docx().Table(wrapper({ image(), pandoc.Para({ pandoc.Str("plain") }) })))
end

function TestDocxCaption:test_other_formats_are_left_alone()
  local f = support.load_filter(FILTER, { formats = { html = true } })
  lu.assertNil(f.Table(wrapper({ image(), caption(pandoc.Str("x")) })))
end
