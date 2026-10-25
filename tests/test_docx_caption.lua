local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/docx-caption.lua"
local RAW_PPR =
  '<w:pPr>\n<w:jc w:val="left"/>\n<w:spacing w:before="200" />\n<w:pStyle w:val="ImageCaption" />\n</w:pPr>\n'

local function docx()
  return support.load_filter(FILTER, { formats = { docx = true } })
end

local function body()
  return support.load_filter(FILTER, { formats = { docx = true } }, 2)
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

local function row(cells)
  return { attr = pandoc.Attr(), body = { pandoc.Row(cells) }, head = {}, row_head_columns = 0 }
end

local function wrapper(blocks, align)
  return pandoc.Table(
    { long = {}, short = {} },
    { { align or pandoc.AlignCenter, 1.0 } },
    pandoc.TableHead(),
    { row({ pandoc.Cell(blocks) }) },
    pandoc.TableFoot()
  )
end

local function layout_cell(blocks)
  return pandoc.Div(blocks, pandoc.Attr("", { "cell-output-display", "quarto-layout-cell-subref" }))
end

local function layout_row(cells)
  local specs = {}
  for _ = 1, #cells do
    specs[#specs + 1] = { pandoc.AlignLeft, 0.49 }
  end
  local row_cells = {}
  for _, blocks in ipairs(cells) do
    row_cells[#row_cells + 1] = pandoc.Cell({ layout_cell(blocks) })
  end
  return pandoc.Table({ long = {}, short = {} }, specs, pandoc.TableHead(), { row(row_cells) }, pandoc.TableFoot())
end

local function float(id, blocks)
  return pandoc.Div(blocks, pandoc.Attr(id))
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
  lu.assertEquals(styles(out), { "Captioned Figure", "Image Caption" })
  lu.assertEquals(raw_openxml_count(out), 0)
end

-- The DOCX writer forces `Compact` onto a Plain in a table cell, over any Div style.
function TestDocxCaption:test_the_image_becomes_a_para_so_its_style_holds()
  local out = docx().Table(wrapper({ image(), caption(pandoc.Str("x")) }))
  lu.assertEquals(out[1].content[1].t, "Para")
end

-- A figure moved to fig-cap-location: top reads like a table caption.
function TestDocxCaption:test_a_caption_before_its_figure_is_a_table_caption()
  local out = docx().Table(wrapper({ caption(pandoc.Str("Top")), image() }))
  lu.assertEquals(styles(out), { "Table Caption", "Figure" })
end

-- Pandoc cuts the cell out of its own nominal width, so the image is clipped.
function TestDocxCaption:test_a_figure_float_leaves_its_wrapper()
  local out = docx().Table(wrapper({ float("fig-x", { image(), caption(pandoc.Str("x")) }) }))
  lu.assertEquals(#out, 1)
  lu.assertEquals(out[1].t, "Div")
  lu.assertEquals(out[1].identifier, "fig-x")
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

function TestDocxCaption:test_a_float_mixing_a_table_and_prose_leaves_its_wrapper()
  local blocks =
    { caption(pandoc.Str("Table")), pandoc.RawBlock("openxml", "<w:tbl/>"), pandoc.Para({ pandoc.Str("Note") }) }
  local out = docx().Table(wrapper({ float("tbl-x", blocks) }))
  lu.assertEquals(out[1].t, "Div")
  lu.assertEquals(pandoc.utils.stringify(out[1].content[3]), "Note")
end

function TestDocxCaption:test_raw_openxml_other_than_a_table_leaves_its_wrapper()
  local blocks = { caption(pandoc.Str("Table")), pandoc.RawBlock("openxml", "<w:p/>") }
  local out = docx().Table(wrapper({ float("tbl-x", blocks) }))
  lu.assertEquals(out[1].t, "Div")
  lu.assertEquals(out[1].content[2].text, "<w:p/>")
end

-- A direct alignment would reach the caption, where Word ranks it above any
-- style; the lift leaves no column to carry one.
function TestDocxCaption:test_a_centred_wrapper_leaves_no_column_alignment_behind()
  local out = docx().Table(wrapper({ image(), caption(pandoc.Str("x")) }))
  lu.assertNil(out.colspecs)
  lu.assertEquals(styles(out), { "Captioned Figure", "Image Caption" })
end

function TestDocxCaption:test_a_wrapper_aligned_otherwise_leaves_its_image_alone()
  local out = docx().Table(wrapper({ image(), caption(pandoc.Str("x")) }, pandoc.AlignLeft))
  lu.assertEquals(styles(out), { "Image Caption" })
end

-- knitr nests the float inside its cell output divs.
function TestDocxCaption:test_a_caption_nested_in_divs_is_found()
  local nested = pandoc.Div({ pandoc.Div({ image(), caption(pandoc.Str("Nested")) }) })
  local out = docx().Table(wrapper({ nested }))
  lu.assertEquals(styles(out), { "Captioned Figure", "Image Caption" })
end

-- Quarto builds one single-cell table per row of a layout, and that row holds
-- the panel's own wrapper rather than a caption of its own.
function TestDocxCaption:test_a_layout_row_of_one_cell_leaves_its_wrapper()
  local out = docx().Table(wrapper({ layout_cell({ image() }) }))
  lu.assertEquals(#out, 1)
  lu.assertEquals(out[1].t, "Div")
  lu.assertEquals(out[1].content[1].t, "Plain")
end

function TestDocxCaption:test_a_layout_row_of_several_cells_keeps_its_table()
  local out = docx().Table(layout_row({ { image() }, { image() } }))
  lu.assertEquals(out.t, "Table")
  lu.assertEquals(#out.bodies[1].body[1].cells, 2)
end

function TestDocxCaption:test_a_layout_row_of_several_cells_loses_its_column_alignment()
  local out = docx().Table(layout_row({ { image() }, { image() } }))
  lu.assertEquals(out.colspecs[1][1], pandoc.AlignDefault)
  lu.assertEquals(out.colspecs[2][1], pandoc.AlignDefault)
end

function TestDocxCaption:test_a_table_outside_a_layout_keeps_its_table_and_alignment()
  local cells =
    { pandoc.Cell({ pandoc.Plain({ pandoc.Str("a") }) }), pandoc.Cell({ pandoc.Plain({ pandoc.Str("b") }) }) }
  local specs = { { pandoc.AlignLeft, 0.5 }, { pandoc.AlignLeft, 0.5 } }
  local tbl = pandoc.Table({ long = {}, short = {} }, specs, pandoc.TableHead(), { row(cells) }, pandoc.TableFoot())
  lu.assertNil(docx().Table(tbl))
end

function TestDocxCaption:test_a_cell_holding_no_layout_cell_keeps_its_table()
  lu.assertNil(docx().Table(wrapper({ pandoc.Para({ pandoc.Str("prose") }) })))
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
  lu.assertEquals(styles(out), { "Captioned Figure", "Image Caption Title", "Image Caption Subtitle" })
end

function TestDocxCaption:test_the_title_and_subtitle_lose_the_blanks_around_the_break()
  local blocks = docx().Table(wrapper({ image(), subtitled() }))
  lu.assertEquals(pandoc.utils.stringify(blocks[2]), "Title")
  lu.assertEquals(#blocks[2].content[1].content, 1)
  lu.assertEquals(blocks[3].content[1].content[1].text, "Note")
  lu.assertEquals(#blocks[3].content[1].content, 1)
end

function TestDocxCaption:test_a_top_subcaption_follows_its_title_above_the_table()
  local inner = pandoc.RawBlock("openxml", "<w:tbl/>")
  local out = docx().Table(wrapper({ float("tbl-x", { subtitled(), inner }) }))
  lu.assertEquals(styles(out), { "Table Caption Title", "Table Caption Subtitle" })
  lu.assertEquals(out[1].content[3].text, "<w:tbl/>")
end

function TestDocxCaption:test_a_caption_without_a_subcaption_stays_one_paragraph()
  local out = docx().Table(wrapper({ image(), caption(pandoc.Str("Only"), pandoc.RawInline("html", "<br>")) }))
  lu.assertEquals(styles(out), { "Captioned Figure", "Image Caption" })
end

function TestDocxCaption:test_a_table_without_a_quarto_caption_is_left_alone()
  lu.assertNil(docx().Table(wrapper({ image(), pandoc.Para({ pandoc.Str("plain") }) })))
end

-- A float laid out in panels gets no wrapper of its own, so its caption is a
-- body-level paragraph the Table pass never reaches.
function TestDocxCaption:test_a_panel_float_caption_is_styled_at_body_level()
  local out = body().Blocks(pandoc.Blocks({ image(), caption(pandoc.Str("Overall")) }))
  lu.assertEquals(styles(out), { "Image Caption" })
  lu.assertEquals(raw_openxml_count(out), 0)
end

function TestDocxCaption:test_a_panel_float_subcaption_becomes_a_paragraph_of_its_own()
  local out = body().Blocks(pandoc.Blocks({ image(), subtitled() }))
  lu.assertEquals(styles(out), { "Image Caption Title", "Image Caption Subtitle" })
end

-- The body pass leaves the image where it is: no column centred it.
function TestDocxCaption:test_the_body_pass_leaves_the_blocks_beside_the_caption_alone()
  local out = body().Blocks(pandoc.Blocks({ image(), caption(pandoc.Str("Overall")) }))
  lu.assertEquals(out[1].t, "Plain")
end

function TestDocxCaption:test_blocks_without_a_caption_are_left_alone()
  lu.assertNil(body().Blocks(pandoc.Blocks({ image(), pandoc.Para({ pandoc.Str("plain") }) })))
end

function TestDocxCaption:test_other_formats_are_left_alone()
  local opts = { formats = { html = true } }
  lu.assertNil(support.load_filter(FILTER, opts).Table(wrapper({ image(), caption(pandoc.Str("x")) })))
  lu.assertNil(support.load_filter(FILTER, opts, 2).Blocks(pandoc.Blocks({ image(), caption(pandoc.Str("x")) })))
end
