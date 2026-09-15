local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/docx-toc-break.lua"

local function doc()
  return pandoc.Pandoc({ pandoc.Header(1, { pandoc.Str("One") }), pandoc.Para({ pandoc.Str("Body") }) })
end

local function run(formats, writer_options)
  PANDOC_WRITER_OPTIONS = writer_options
  return support.load_filter(FILTER, { formats = formats }).Pandoc(doc())
end

TestDocxTocBreak = {}

function TestDocxTocBreak:tearDown()
  PANDOC_WRITER_OPTIONS = nil
end

function TestDocxTocBreak:test_a_page_break_opens_the_body_under_a_toc()
  local out = run({ docx = true }, { table_of_contents = true })
  lu.assertEquals(out.blocks[1].t, "RawBlock")
  lu.assertEquals(out.blocks[1].format, "openxml")
  lu.assertStrContains(out.blocks[1].text, '<w:br w:type="page"/>')
end

function TestDocxTocBreak:test_the_body_follows_the_break_untouched()
  local out = run({ docx = true }, { table_of_contents = true })
  lu.assertEquals(#out.blocks, 3)
  lu.assertEquals(out.blocks[2].t, "Header")
end

-- Quarto leaves no `toc` key in the metadata, so the writer option is the signal.
function TestDocxTocBreak:test_no_break_without_a_toc()
  lu.assertNil(run({ docx = true }, { table_of_contents = false }))
end

function TestDocxTocBreak:test_no_break_without_writer_options()
  lu.assertNil(run({ docx = true }, nil))
end

function TestDocxTocBreak:test_other_formats_are_left_alone()
  lu.assertNil(run({ html = true }, { table_of_contents = true }))
end
