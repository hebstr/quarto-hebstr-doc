local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/filetree.lua"

-- `annotations` defaults to `filetree.yml`, which the shortcode resolves against
-- the working directory : the repo's own production sidecar. Left unset, every
-- case below would read it, inherit its `highlight` and `paths`, and fill the
-- warning bucket with dead-key noise the asserts then sit on. Pointing at an
-- absent file exercises the same code path with nothing to inherit.
local NO_SIDECAR = "tests/fixtures/no-sidecar.yml"

local function kwargs(tbl)
  tbl = tbl or {}
  if tbl.annotations == nil then
    tbl.annotations = NO_SIDECAR
  end
  return support.kwargs(tbl)
end

TestFiletree = {}

function TestFiletree:test_lists_tree_as_bulletlist()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = false } })
  local div = sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/tree" }), {})
  lu.assertEquals(div.t, "Div")
  lu.assertTrue(div.classes:includes("filetree"))
  lu.assertEquals(div.content[1].t, "BulletList")
  local text = pandoc.utils.stringify(div)
  lu.assertStrContains(text, "README.md")
  lu.assertStrContains(text, "src/")
end

function TestFiletree:test_html_branch_emits_rawblock()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div = sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/tree" }), {})
  lu.assertEquals(div.content[1].t, "RawBlock")
  lu.assertStrContains(div.content[1].text, "README.md")
  lu.assertFalse(div.classes:includes("filetree-dynamic"))
end

local function described(name, desc)
  return '<span class="ft-name">' .. name .. '</span><span class="ft-desc">' .. desc .. "</span>"
end

local PROFILES = "tests/fixtures/profiles.yml"

local function profile_html(args, sidecar)
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true }, script_file = FILTER })
  local out = sc["filetree"](args, kwargs({ root = "tests/fixtures/tree", annotations = sidecar or PROFILES }), {})
  return out, table.concat(support.warnings, "\n")
end

function TestFiletree:test_bare_call_reads_the_default_profile()
  local div, warnings = profile_html(support.args())
  local html = div.content[1].text
  lu.assertStrContains(html, described("<strong>README.md</strong>", "default desc"))
  lu.assertStrContains(html, '<span class="ft-name"><strong>src/</strong></span>')
  lu.assertStrContains(html, "ft-more")
  lu.assertNotStrContains(html, "doc desc")
  lu.assertEquals(warnings, "")
end

function TestFiletree:test_positional_name_selects_a_profile_without_inheriting_default()
  local div, warnings = profile_html(support.args("doc"))
  local html = div.content[1].text
  lu.assertStrContains(html, described("main.lua", "doc desc"))
  lu.assertStrContains(html, "deep.lua")
  lu.assertNotStrContains(html, "README.md")
  lu.assertNotStrContains(html, "ft-hl")
  lu.assertEquals(warnings, "")
end

function TestFiletree:test_unknown_profile_warns_and_renders_nothing()
  local out, warnings = profile_html(support.args("nope"))
  lu.assertEquals(#out, 0)
  lu.assertStrContains(warnings, "no profile 'nope'")
  lu.assertStrContains(warnings, "profiles found: default, doc, scalar")
end

function TestFiletree:test_scalar_profile_renders_without_paths()
  local div, warnings = profile_html(support.args("scalar"))
  lu.assertStrContains(div.content[1].text, "README.md")
  lu.assertNotStrContains(div.content[1].text, "ft-desc")
  lu.assertEquals(warnings, "")
end

function TestFiletree:test_legacy_filetree_key_is_not_a_default()
  local out, warnings = profile_html(support.args(), "tests/fixtures/legacy-shape.yml")
  lu.assertEquals(#out, 0)
  lu.assertStrContains(warnings, "no profile 'default'")
  lu.assertStrContains(warnings, "profiles found: filetree")
end

function TestFiletree:test_named_profile_without_sidecar_renders_nothing()
  local out, warnings = profile_html(support.args("doc"), NO_SIDECAR)
  lu.assertEquals(#out, 0)
  lu.assertStrContains(warnings, "profile 'doc' not rendered, sidecar not found")
end

function TestFiletree:test_invalid_profile_name_warns_and_renders_nothing()
  local out, warnings = profile_html(support.args("../doc"))
  lu.assertEquals(#out, 0)
  lu.assertStrContains(warnings, "profile name must hold only")
end

function TestFiletree:test_extra_positional_args_are_warned_and_ignored()
  local div, warnings = profile_html(support.args("doc", "stray"))
  lu.assertStrContains(div.content[1].text, "doc desc")
  lu.assertStrContains(warnings, "other positional arguments are ignored: stray")
end

function TestFiletree:test_missing_root_warns_and_returns_empty()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = false } })
  local out = sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/nope" }), {})
  lu.assertEquals(#out, 0)
  lu.assertStrContains(table.concat(support.warnings, "\n"), "tests/fixtures/nope")
end

function TestFiletree:test_dynamic_mode_wraps_dirs_in_details()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div = sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/tree", mode = "dynamic" }), {})
  local html = div.content[1].text
  lu.assertTrue(div.classes:includes("filetree-dynamic"))
  lu.assertStrContains(html, "<summary>")
  lu.assertStrContains(html, '<summary><span class="ft-name">src/</span></summary>')
end

function TestFiletree:test_dynamic_open_reflects_depth()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div =
    sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/tree", mode = "dynamic", depth = "1" }), {})
  local html = div.content[1].text
  lu.assertStrContains(html, '<details open><summary><span class="ft-name">src/</span></summary>')
  lu.assertStrContains(html, '<details><summary><span class="ft-name">nested/</span></summary>')
  lu.assertNotStrContains(html, '<details open><summary><span class="ft-name">nested/')
end

function TestFiletree:test_dynamic_childless_dir_stays_flat()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div =
    sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/tree", mode = "dynamic", exclude = "^src/" }), {})
  local html = div.content[1].text
  lu.assertNotStrContains(html, "<details")
  lu.assertStrContains(html, "ft-dir")
end

function TestFiletree:test_dynamic_non_html_falls_back_to_bulletlist()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = false } })
  local div = sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/tree", mode = "dynamic" }), {})
  lu.assertEquals(div.content[1].t, "BulletList")
end

function TestFiletree:test_dynamic_folder_carries_open_icon_variant()
  local sc = support.load_shortcode(
    FILTER,
    { formats = { ["html:js"] = true }, script_file = "_extensions/hebstr-doc/filters/filetree.lua" }
  )
  local div = sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/tree", mode = "dynamic" }), {})
  lu.assertStrContains(div.content[1].text, "--ft-icon-open:url(")
end

function TestFiletree:test_icon_key_resolves_per_file_type()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true }, script_file = FILTER })
  local div = sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/icons", hidden = "true" }), {})
  local html = div.content[1].text
  for _, key in ipairs({
    "ft-i-toml",
    "ft-i-lock",
    "ft-i-tune",
    "ft-i-r",
    "ft-i-javascript",
    "ft-i-table",
    "ft-i-powerpoint",
    "ft-i-pdf",
    "ft-i-svg",
    "ft-i-bibliography",
    "ft-i-console",
    "ft-i-log",
    "ft-i-database",
    "ft-i-xml",
    "ft-i-rust",
  }) do
    lu.assertStrContains(html, key)
  end
  -- The classes emit regardless of a readable icon ; this proves the SVGs are
  -- vendored and the mapping names them correctly.
  lu.assertNotStrContains(table.concat(support.warnings, "\n"), "icon not readable")
end

local function glob_html(sidecar)
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div = sc["filetree"](
    support.args(),
    kwargs({ root = "tests/fixtures/tree", depth = "3", annotations = "tests/fixtures/" .. sidecar }),
    {}
  )
  return div.content[1].text, table.concat(support.warnings, "\n")
end

function TestFiletree:test_glob_key_annotates_matching_entries()
  local html, warnings = glob_html("glob-basic.yml")
  lu.assertStrContains(html, described("main.lua", "glob desc"))
  lu.assertStrContains(html, described("deep.lua", "nested desc"))
  lu.assertNotStrContains(warnings, "annotation")
end

function TestFiletree:test_glob_star_does_not_cross_a_slash()
  local html = glob_html("glob-basic.yml")
  lu.assertNotStrContains(html, described("deep.lua", "glob desc"))
end

function TestFiletree:test_exact_key_wins_over_glob()
  local html, warnings = glob_html("glob-exact.yml")
  lu.assertStrContains(html, described("main.lua", "exact desc"))
  lu.assertNotStrContains(html, "glob desc")
  lu.assertStrContains(warnings, "annotation glob describes no rendered entry: src/*.lua")
end

function TestFiletree:test_conflicting_globs_warn_and_pick_the_first_key()
  local html, warnings = glob_html("glob-conflict.yml")
  lu.assertStrContains(html, described("main.lua", "first desc"))
  lu.assertStrContains(warnings, "src/main.lua matches several globs")
end

function TestFiletree:test_dead_glob_warns_and_magic_characters_stay_literal()
  local html, warnings = glob_html("glob-literal.yml")
  lu.assertNotStrContains(html, "dash desc")
  lu.assertNotStrContains(html, "dot desc")
  lu.assertStrContains(warnings, "annotation glob describes no rendered entry: *.txt")
end

function TestFiletree:test_invalid_mode_warns_and_falls_back_to_static()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div = sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/tree", mode = "wobble" }), {})
  lu.assertNotStrContains(div.content[1].text, "<details")
  lu.assertStrContains(table.concat(support.warnings, "\n"), "mode is not static or dynamic")
end
