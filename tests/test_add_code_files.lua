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

function TestAddCodeFiles:test_the_js_reads_the_attribute_the_lua_emits()
  local sc = support.load_shortcode(FILTER, HTML)
  local div = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({}))
  local attribute = "code-filename"
  lu.assertNotNil(div.attributes[attribute])
  local fh = assert(io.open("_extensions/hebstr-doc/filters/add-code-files.js"))
  local js = fh:read("a")
  fh:close()
  lu.assertStrContains(js, "div[data-" .. attribute .. "]")
  lu.assertStrContains(js, 'getAttribute("data-' .. attribute .. '")')
end

function TestAddCodeFiles:test_the_code_window_contract_rides_on_the_codeblock()
  local sc = support.load_shortcode(FILTER, HTML)
  local cb = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({})).content[1]
  lu.assertTrue(cb.classes:includes("cw-auto"))
  lu.assertTrue(cb.classes:includes("number-lines"))
  lu.assertEquals(cb.attributes.filename, "r")
end

function TestAddCodeFiles:test_start_from_follows_the_lower_bound_only()
  local sc = support.load_shortcode(FILTER, HTML)
  local lower = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ lines = "2-" })).content[1]
  lu.assertEquals(lower.attributes.startFrom, "2")
  lu.assertEquals(lower.text, "y <- 2\nz <- 3\n")
  local upper = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ lines = "-2" })).content[1]
  lu.assertNil(upper.attributes.startFrom)
  lu.assertEquals(upper.text, "x <- 1\ny <- 2\n")
end

function TestAddCodeFiles:test_a_start_below_one_is_clamped_and_warned()
  local sc = support.load_shortcode(FILTER, HTML)
  local cb = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ lines = "0-2" })).content[1]
  lu.assertEquals(cb.attributes.startFrom, "1")
  lu.assertStrContains(table.concat(support.warnings, "\n"), "lines starts before line 1")
  local padded = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ lines = "01-02" })).content[1]
  lu.assertEquals(padded.attributes.startFrom, "1")
end

function TestAddCodeFiles:test_filename_and_suffix_build_the_label()
  local sc = support.load_shortcode(FILTER, HTML)
  local named = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ filename = "demo.R" }))
  lu.assertEquals(named.attributes["code-filename"], "demo.R")
  local suffixed = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ suffix = "(extract)" }))
  lu.assertEquals(suffixed.attributes["code-filename"], "tests/fixtures/hello.R (extract)")
  local both =
    sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ filename = "demo.R", suffix = "(L2)" }))
  lu.assertEquals(both.attributes["code-filename"], "demo.R (L2)")
end

function TestAddCodeFiles:test_lang_overrides_the_extension_and_an_unknown_one_emits_none()
  local sc = support.load_shortcode(FILTER, HTML)
  local forced = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ lang = "python" })).content[1]
  lu.assertEquals(forced.classes[1], "python")
  lu.assertEquals(forced.attributes.filename, "python")
  local bare = sc["script"](support.args("tests/fixtures/icons/main.rs"), support.kwargs({})).content[1]
  lu.assertEquals(bare.classes[1], "cell-code")
  lu.assertNil(bare.attributes.filename)
end

function TestAddCodeFiles:test_a_missing_path_names_the_mistake()
  local sc = support.load_shortcode(FILTER, HTML)
  lu.assertErrorMsgContains("a path is required", sc["script"], support.args(), support.kwargs({}))
end

function TestAddCodeFiles:test_log_and_txt_extensions_set_the_header_label()
  local sc = support.load_shortcode(FILTER, HTML)
  for path, lang in pairs({ ["tests/fixtures/run.log"] = "log", ["tests/fixtures/indented.txt"] = "txt" }) do
    local cb = sc["script"](support.args(path), support.kwargs({})).content[1]
    lu.assertEquals(cb.classes[1], lang)
    lu.assertEquals(cb.attributes.filename, lang)
  end
end

function TestAddCodeFiles:test_lines_range_selects_a_slice()
  local sc = support.load_shortcode(FILTER, HTML)
  local div = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ lines = "2-2" }))
  local cb = div.content[1]
  lu.assertStrContains(cb.text, "y <- 2")
  lu.assertNotStrContains(cb.text, "x <- 1")
  lu.assertNotStrContains(cb.text, "z <- 3")
end

function TestAddCodeFiles:test_a_bare_number_selects_that_line_alone()
  local sc = support.load_shortcode(FILTER, HTML)
  local cb = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ lines = "2" })).content[1]
  lu.assertEquals(cb.text, "y <- 2\n")
  lu.assertEquals(cb.attributes.startFrom, "2")
  lu.assertEquals(#support.warnings, 0)
end

function TestAddCodeFiles:test_lines_out_of_range_warns_on_the_empty_block()
  for _, spec in ipairs({ "99-", "5-9", "-0" }) do
    local sc = support.load_shortcode(FILTER, HTML)
    local div = sc["script"](support.args("tests/fixtures/hello.R"), support.kwargs({ lines = spec }))
    lu.assertEquals(div.content[1].text, "")
    lu.assertStrContains(table.concat(support.warnings, "\n"), "lines selects nothing")
  end
end

function TestAddCodeFiles:test_an_empty_file_read_whole_does_not_warn()
  local sc = support.load_shortcode(FILTER, HTML)
  local cb = sc["script"](support.args("tests/fixtures/icons/main.rs"), support.kwargs({})).content[1]
  lu.assertEquals(cb.text, "")
  lu.assertNotStrContains(table.concat(support.warnings, "\n"), "lines selects nothing")
end

function TestAddCodeFiles:test_dedent_strips_leading_spaces_only()
  local sc = support.load_shortcode(FILTER, HTML)
  local div = sc["script"](support.args("tests/fixtures/indented.txt"), support.kwargs({ dedent = "4" }))
  local cb = div.content[1]
  lu.assertStrContains(cb.text, "four spaces")
  lu.assertNotStrContains(cb.text, "    four spaces")
  lu.assertStrContains(cb.text, "two spaces")
  lu.assertNotStrContains(cb.text, "  two spaces")
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
  lu.assertStrContains(table.concat(support.warnings, "\n"), "dedent is not a whole number of spaces")
end

function TestAddCodeFiles:test_dedent_negative_or_fractional_warns_and_is_ignored()
  for _, spec in ipairs({ "-3", "2.5" }) do
    local sc = support.load_shortcode(FILTER, HTML)
    local div = sc["script"](support.args("tests/fixtures/indented.txt"), support.kwargs({ dedent = spec }))
    lu.assertStrContains(div.content[1].text, "    four spaces")
    lu.assertStrContains(div.content[1].text, "# a b c")
    lu.assertStrContains(table.concat(support.warnings, "\n"), "whole number of spaces, ignoring: " .. spec)
  end
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
  lu.assertStrContains(table.concat(support.warnings, "\n"), "cannot open tests/fixtures/does-not-exist.R")
end

function TestAddCodeFiles:test_unreadable_path_yields_message_not_error()
  local sc = support.load_shortcode(FILTER, HTML)
  local div = sc["script"](support.args("tests/fixtures"), support.kwargs({}))
  lu.assertEquals(div.t, "Div")
  lu.assertStrContains(pandoc.utils.stringify(div), "tests/fixtures]")
  lu.assertStrContains(table.concat(support.warnings, "\n"), "tests/fixtures")
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
