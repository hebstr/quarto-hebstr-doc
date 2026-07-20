local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/add-code-files.lua"

TestAddCodeFiles = {}

function TestAddCodeFiles:test_reads_file_into_codeblock()
  local sc = support.load_shortcode(FILTER)
  local div = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({}))
  lu.assertEquals(div.t, "Div")
  lu.assertEquals(div.attributes["code-filename"], "tests/fixtures/hello.R")
  local cb = div.content[1]
  lu.assertEquals(cb.t, "CodeBlock")
  lu.assertStrContains(cb.text, "x <- 1")
  lu.assertTrue(cb.classes:includes("r"))
  lu.assertTrue(cb.classes:includes("cell-code"))
end

function TestAddCodeFiles:test_lines_range_selects_a_slice()
  local sc = support.load_shortcode(FILTER)
  local div = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ lines = "2-2" }))
  local cb = div.content[1]
  lu.assertStrContains(cb.text, "y <- 2")
  lu.assertNotStrContains(cb.text, "x <- 1")
  lu.assertNotStrContains(cb.text, "z <- 3")
end

function TestAddCodeFiles:test_dedent_strips_leading_spaces_only()
  local sc = support.load_shortcode(FILTER)
  local div = sc["script"](support.args("tests/fixtures/indented.txt"), support.kwargs({ dedent = "4" }))
  local cb = div.content[1]
  lu.assertStrContains(cb.text, "four spaces")
  lu.assertNotStrContains(cb.text, "    four spaces")
  lu.assertStrContains(cb.text, "two spaces")
  lu.assertNotStrContains(cb.text, "  two spaces")
  -- a zero-indent line keeps its interior spaces: the bug turned "# a b c" into "#a b c"
  lu.assertStrContains(cb.text, "# a b c")
end

function TestAddCodeFiles:test_dedent_absent_preserves_indentation()
  local sc = support.load_shortcode(FILTER)
  local div = sc["script"](support.args("tests/fixtures/indented.txt"), support.kwargs({}))
  local cb = div.content[1]
  lu.assertStrContains(cb.text, "    four spaces")
  lu.assertStrContains(cb.text, "  two spaces")
end

function TestAddCodeFiles:test_registers_js_dependency_once()
  local sc = support.load_shortcode(FILTER)
  sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({}))
  sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({}))
  lu.assertEquals(#support.deps, 1)
  lu.assertEquals(support.deps[1].name, "add-code-files")
end

function TestAddCodeFiles:test_missing_file_yields_message_not_error()
  local sc = support.load_shortcode(FILTER)
  local div = sc["script"](support.args("tests/fixtures/does-not-exist.R"), support.kwargs({}))
  lu.assertEquals(div.t, "Div")
  lu.assertStrContains(pandoc.utils.stringify(div), "file not found")
end
