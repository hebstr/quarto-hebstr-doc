local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/filetree.lua"

TestFiletree = {}

function TestFiletree:test_lists_tree_as_bulletlist()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = false } })
  local div = sc["filetree"](support.args(), support.kwargs({ root = "tests/fixtures/tree" }), {})
  lu.assertEquals(div.t, "Div")
  lu.assertTrue(div.classes:includes("filetree"))
  lu.assertEquals(div.content[1].t, "BulletList")
  local text = pandoc.utils.stringify(div)
  lu.assertStrContains(text, "README.md")
  lu.assertStrContains(text, "src/")
end

function TestFiletree:test_html_branch_emits_rawblock()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div = sc["filetree"](support.args(), support.kwargs({ root = "tests/fixtures/tree" }), {})
  lu.assertEquals(div.content[1].t, "RawBlock")
  lu.assertStrContains(div.content[1].text, "README.md")
end

function TestFiletree:test_positional_args_are_warned_and_ignored()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = false } })
  sc["filetree"](support.args("stray"), support.kwargs({ root = "tests/fixtures/tree" }), {})
  local joined = table.concat(support.warnings, "\n")
  lu.assertStrContains(joined, "positional arguments are ignored")
end

function TestFiletree:test_missing_root_warns_and_returns_empty()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = false } })
  local out = sc["filetree"](support.args(), support.kwargs({ root = "tests/fixtures/nope" }), {})
  lu.assertEquals(#out, 0)
  lu.assertNotEquals(#support.warnings, 0)
end
