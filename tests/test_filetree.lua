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
  lu.assertFalse(div.classes:includes("filetree-dynamic"))
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

function TestFiletree:test_dynamic_mode_wraps_dirs_in_details()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div = sc["filetree"](support.args(), support.kwargs({ root = "tests/fixtures/tree", mode = "dynamic" }), {})
  local html = div.content[1].text
  lu.assertTrue(div.classes:includes("filetree-dynamic"))
  lu.assertStrContains(html, "<summary>")
  lu.assertStrContains(html, '<summary><span class="ft-name">src/</span></summary>')
end

function TestFiletree:test_dynamic_open_reflects_depth()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div =
    sc["filetree"](support.args(), support.kwargs({ root = "tests/fixtures/tree", mode = "dynamic", depth = "1" }), {})
  local html = div.content[1].text
  lu.assertStrContains(html, '<details open><summary><span class="ft-name">src/</span></summary>')
  lu.assertStrContains(html, '<details><summary><span class="ft-name">nested/</span></summary>')
  lu.assertNotStrContains(html, '<details open><summary><span class="ft-name">nested/')
end

function TestFiletree:test_dynamic_childless_dir_stays_flat()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div = sc["filetree"](
    support.args(),
    support.kwargs({ root = "tests/fixtures/tree", mode = "dynamic", exclude = "^src/" }),
    {}
  )
  local html = div.content[1].text
  lu.assertNotStrContains(html, "<details")
  lu.assertStrContains(html, "ft-dir")
end

function TestFiletree:test_dynamic_non_html_falls_back_to_bulletlist()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = false } })
  local div = sc["filetree"](support.args(), support.kwargs({ root = "tests/fixtures/tree", mode = "dynamic" }), {})
  lu.assertEquals(div.content[1].t, "BulletList")
end

function TestFiletree:test_dynamic_folder_carries_open_icon_variant()
  local sc = support.load_shortcode(
    FILTER,
    { formats = { ["html:js"] = true }, script_file = "_extensions/hebstr-doc/filters/filetree.lua" }
  )
  local div = sc["filetree"](support.args(), support.kwargs({ root = "tests/fixtures/tree", mode = "dynamic" }), {})
  lu.assertStrContains(div.content[1].text, "--ft-icon-open:url(")
end

function TestFiletree:test_icon_key_resolves_per_file_type()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true }, script_file = FILTER })
  local div = sc["filetree"](support.args(), support.kwargs({ root = "tests/fixtures/icons", hidden = "true" }), {})
  local html = div.content[1].text
  for _, key in ipairs({ "ft-i-toml", "ft-i-lock", "ft-i-tune", "ft-i-r" }) do
    lu.assertStrContains(html, key)
  end
  -- The classes emit regardless of a readable icon ; this proves the SVGs are
  -- vendored and the mapping names them correctly.
  lu.assertNotStrContains(table.concat(support.warnings, "\n"), "icon not readable")
end

function TestFiletree:test_invalid_mode_warns_and_falls_back_to_static()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div = sc["filetree"](support.args(), support.kwargs({ root = "tests/fixtures/tree", mode = "wobble" }), {})
  lu.assertNotStrContains(div.content[1].text, "<details")
  lu.assertStrContains(table.concat(support.warnings, "\n"), "mode is not static or dynamic")
end
