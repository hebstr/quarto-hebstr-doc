local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/add-code-files.lua"

local HTML = { formats = { ["html:js"] = true } }

TestAddCodeFiles = {}

function TestAddCodeFiles:test_reads_file_into_codeblock()
  local sc = support.load_shortcode(FILTER, HTML)
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
  local sc = support.load_shortcode(FILTER, HTML)
  local div = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ lines = "2-2" }))
  local cb = div.content[1]
  lu.assertStrContains(cb.text, "y <- 2")
  lu.assertNotStrContains(cb.text, "x <- 1")
  lu.assertNotStrContains(cb.text, "z <- 3")
end

function TestAddCodeFiles:test_dedent_strips_leading_spaces_only()
  local sc = support.load_shortcode(FILTER, HTML)
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
  local sc = support.load_shortcode(FILTER, HTML)
  local div = sc["script"](support.args("tests/fixtures/indented.txt"), support.kwargs({}))
  local cb = div.content[1]
  lu.assertStrContains(cb.text, "    four spaces")
  lu.assertStrContains(cb.text, "  two spaces")
end

function TestAddCodeFiles:test_registers_js_dependency_once()
  local sc = support.load_shortcode(FILTER, HTML)
  sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({}))
  sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({}))
  lu.assertEquals(#support.deps, 1)
  lu.assertEquals(support.deps[1].name, "add-code-files")
end

function TestAddCodeFiles:test_numbers_accepts_boolean_spellings()
  local sc = support.load_shortcode(FILTER, HTML)
  local off = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ numbers = "NO" }))
  lu.assertFalse(off.content[1].classes:includes("number-lines"))
  local on = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ numbers = "on" }))
  lu.assertTrue(on.content[1].classes:includes("number-lines"))
  lu.assertEquals(#support.warnings, 0)
end

function TestAddCodeFiles:test_numbers_non_boolean_warns_and_falls_back()
  local sc = support.load_shortcode(FILTER, HTML)
  local div = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ numbers = "wobble" }))
  lu.assertTrue(div.content[1].classes:includes("number-lines"))
  lu.assertStrContains(table.concat(support.warnings, "\n"), "numbers is not a boolean")
end

function TestAddCodeFiles:test_lines_not_a_range_warns_and_reads_whole_file()
  local sc = support.load_shortcode(FILTER, HTML)
  local div = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ lines = "two" }))
  lu.assertStrContains(div.content[1].text, "x <- 1")
  lu.assertStrContains(div.content[1].text, "z <- 3")
  lu.assertStrContains(table.concat(support.warnings, "\n"), "lines is not a range")
end

function TestAddCodeFiles:test_lines_reversed_range_warns_and_reads_whole_file()
  local sc = support.load_shortcode(FILTER, HTML)
  local div = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ lines = "3-1" }))
  lu.assertStrContains(div.content[1].text, "x <- 1")
  lu.assertStrContains(div.content[1].text, "z <- 3")
  lu.assertStrContains(table.concat(support.warnings, "\n"), "lines ends before it starts")
end

function TestAddCodeFiles:test_dedent_non_numeric_warns_and_is_ignored()
  local sc = support.load_shortcode(FILTER, HTML)
  local div = sc["script"](support.args("tests/fixtures/indented.txt"), support.kwargs({ dedent = "lots" }))
  lu.assertStrContains(div.content[1].text, "    four spaces")
  lu.assertStrContains(table.concat(support.warnings, "\n"), "dedent is not a number")
end

function TestAddCodeFiles:test_extra_positional_and_unknown_attribute_warn()
  local sc = support.load_shortcode(FILTER, HTML)
  sc["script"](support.args("tests/fixtures/hello.R", "stray"), support.kwargs({ wobble = "1", filename = "kept.R" }))
  local joined = table.concat(support.warnings, "\n")
  lu.assertStrContains(joined, "positional arguments are ignored")
  lu.assertStrContains(joined, "unknown attribute ignored: wobble")
  lu.assertNotStrContains(joined, "filename")
end

function TestAddCodeFiles:test_missing_file_yields_message_not_error()
  local sc = support.load_shortcode(FILTER, HTML)
  local div = sc["script"](support.args("tests/fixtures/does-not-exist.R"), support.kwargs({}))
  lu.assertEquals(div.t, "Div")
  lu.assertStrContains(pandoc.utils.stringify(div), "file not found")
end

function TestAddCodeFiles:test_outside_html_js_emits_nothing()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = false } })
  local out = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({}))
  lu.assertEquals(out, {})
  lu.assertEquals(#support.deps, 0)
end

function TestAddCodeFiles:test_outside_html_js_ignores_a_missing_path()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = false } })
  local out = sc["script"](support.args(), support.kwargs({}))
  lu.assertEquals(out, {})
  lu.assertEquals(#support.warnings, 0)
end
