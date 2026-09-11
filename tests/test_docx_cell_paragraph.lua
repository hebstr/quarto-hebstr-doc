local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/docx-cell-paragraph.lua"
local TABLE = "<w:tbl><w:tr><w:tc><w:tcPr/><w:p/></w:tc></w:tr></w:tbl>"

local function docx()
  return support.load_filter(FILTER, { formats = { docx = true } })
end

TestDocxCellParagraph = {}

function TestDocxCellParagraph:test_a_raw_table_gains_a_closing_paragraph()
  local out = docx().RawBlock(pandoc.RawBlock("openxml", TABLE))
  lu.assertStrMatches(out.text, "^" .. TABLE:gsub("%p", "%%%0") .. "<w:p>.*</w:p>$")
  lu.assertEquals(out.format, "openxml")
end

-- knitr ends the block with a newline, and flextable prepends a caption.
function TestDocxCellParagraph:test_trailing_whitespace_is_tolerated()
  local out = docx().RawBlock(pandoc.RawBlock("openxml", "<w:p/>" .. TABLE .. "\n"))
  lu.assertStrContains(out.text, "</w:tbl>\n<w:p>")
end

-- An empty paragraph of its own would push the table down the page.
function TestDocxCellParagraph:test_the_paragraph_carries_no_height()
  local out = docx().RawBlock(pandoc.RawBlock("openxml", TABLE))
  lu.assertStrContains(out.text, 'w:line="20" w:lineRule="exact"')
  lu.assertStrContains(out.text, 'w:sz w:val="2"')
end

function TestDocxCellParagraph:test_a_block_ending_elsewhere_is_left_alone()
  lu.assertNil(docx().RawBlock(pandoc.RawBlock("openxml", "<w:p><w:r><w:t>x</w:t></w:r></w:p>")))
end

function TestDocxCellParagraph:test_other_raw_formats_are_left_alone()
  lu.assertNil(docx().RawBlock(pandoc.RawBlock("html", "<table></table>")))
end

-- The block reaches no other writer, but the guard keeps the filter honest
-- wherever Quarto carries an openxml block through another format.
function TestDocxCellParagraph:test_other_formats_are_left_alone()
  local f = support.load_filter(FILTER, { formats = { html = true } })
  lu.assertNil(f.RawBlock(pandoc.RawBlock("openxml", TABLE)))
end
