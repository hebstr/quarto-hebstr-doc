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
  lu.assertStrContains(warnings, "profiles found: default, disabled, doc, scalar")
end

function TestFiletree:test_scalar_profile_renders_without_paths()
  for _, name in ipairs({ "scalar", "disabled" }) do
    local div, warnings = profile_html(support.args(name))
    lu.assertEquals(div.t, "Div", name)
    lu.assertStrContains(div.content[1].text, "README.md")
    lu.assertNotStrContains(div.content[1].text, "ft-desc")
    lu.assertEquals(warnings, "", name)
  end
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

local function escaping_sidecars()
  local cwd = pandoc.system.get_working_directory()
  return { "../" .. pandoc.path.filename(cwd) .. "/" .. PROFILES, cwd .. "/" .. PROFILES }
end

function TestFiletree:test_annotations_outside_the_project_warn_and_leave_the_default_profile_bare()
  for _, path in ipairs(escaping_sidecars()) do
    local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = false } })
    local div = sc["filetree"](support.args(), support.kwargs({ root = "tests/fixtures/tree", annotations = path }), {})
    local text = pandoc.utils.stringify(div)
    lu.assertStrContains(table.concat(support.warnings, "\n"), "annotations must be a path inside the project", path)
    lu.assertStrContains(text, "README.md", path)
    lu.assertNotStrContains(text, "default desc", path)
  end
end

function TestFiletree:test_annotations_outside_the_project_abort_a_named_profile()
  for _, path in ipairs(escaping_sidecars()) do
    local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = false } })
    local out =
      sc["filetree"](support.args("doc"), support.kwargs({ root = "tests/fixtures/tree", annotations = path }), {})
    lu.assertEquals(#out, 0, path)
    lu.assertStrContains(table.concat(support.warnings, "\n"), "annotations must be a path inside the project", path)
  end
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

function TestFiletree:test_trailing_comments_are_stripped_from_raw_keys()
  local div, warnings = profile_html(support.args(), "tests/fixtures/comments.yml")
  local html = div.content[1].text
  lu.assertStrContains(html, '<span class="ft-name"><strong>src/</strong></span>')
  lu.assertNotStrContains(html, "README.md")
  lu.assertStrContains(html, "deep.lua")
  lu.assertEquals(warnings, "")
end

function TestFiletree:test_empty_annotations_warn_and_emit_no_description()
  local div, warnings = profile_html(support.args(), "tests/fixtures/empty-annotation.yml")
  local html = div.content[1].text
  lu.assertStrContains(html, described("main.lua", "kept"))
  lu.assertNotStrContains(html, '<span class="ft-desc"></span>')
  lu.assertStrContains(warnings, "paths key 'README.md': annotation is empty")
  lu.assertStrContains(warnings, "paths key 'src': annotation is empty")
end

function TestFiletree:test_keys_differing_only_by_a_trailing_slash_warn_and_keep_the_first()
  local div, warnings = profile_html(support.args(), "tests/fixtures/duplicate-key.yml")
  local html = div.content[1].text
  lu.assertStrContains(html, described("src/", "kept desc"))
  lu.assertNotStrContains(html, "dropped desc")
  lu.assertStrContains(warnings, "paths key 'src' is described more than once, keeping the first: src/ ignored")
end

function TestFiletree:test_unparsable_sidecar_aborts_a_named_profile_and_spares_the_default()
  local out, named = profile_html(support.args("doc"), "tests/fixtures/run.log")
  lu.assertEquals(#out, 0)
  lu.assertStrContains(named, "profile 'doc' not rendered, cannot parse")

  local div, default = profile_html(support.args(), "tests/fixtures/run.log")
  lu.assertStrContains(div.content[1].text, "README.md")
  lu.assertStrContains(default, "cannot parse")
  lu.assertNotStrContains(default, "not rendered")
end

function TestFiletree:test_dead_annotation_keys_are_split_by_existence_on_disk()
  local div, warnings = profile_html(support.args(), "tests/fixtures/dead-keys.yml")
  lu.assertStrContains(div.content[1].text, described("README.md", "live desc"))
  lu.assertStrContains(warnings, "annotation key does not match any path: nope.md")
  lu.assertStrContains(warnings, "exists on disk but matches no rendered entry")
  lu.assertStrContains(warnings, "the key spelling: src/main.lua")
  lu.assertNotStrContains(warnings, "does not match any path: src/main.lua")
end

function TestFiletree:test_list_branch_carries_highlight_and_description()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = false } })
  local div = sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/tree", annotations = PROFILES }), {})
  local found = {}
  pandoc.walk_block(div.content[1], {
    Strong = function(el)
      found.strong = pandoc.utils.stringify(el)
    end,
    Emph = function(el)
      found.emph = pandoc.utils.stringify(el)
    end,
  })
  lu.assertEquals(found.strong, "README.md")
  lu.assertEquals(found.emph, "default desc")
  lu.assertStrContains(pandoc.utils.stringify(div), "README.md default desc")
end

function TestFiletree:test_malformed_patterns_are_reported_once_each_and_the_tree_still_renders()
  local div, warnings = profile_html(support.args(), "tests/fixtures/bad-pattern.yml")
  local html = div.content[1].text
  lu.assertStrContains(warnings, "exclude pattern ignored: [a")
  lu.assertStrContains(warnings, "exclude pattern ignored: README%.md[a")
  lu.assertEquals(#support.warnings, 2)
  lu.assertStrContains(html, "README.md")
  lu.assertStrContains(html, "src/")
end

local SHAPES = "tests/fixtures/profile-shapes.yml"

function TestFiletree:test_a_profile_not_written_as_a_block_warns_instead_of_losing_its_keys()
  for _, name in ipairs({ "flow", "quoted" }) do
    local div, warnings = profile_html(support.args(name), SHAPES)
    lu.assertStrContains(warnings, "profile '" .. name .. "' is not written as an indented block", name)
    lu.assertNotStrContains(div.content[1].text, "deep.lua", name)
  end

  local div, warnings = profile_html(support.args("block"), SHAPES)
  lu.assertStrContains(div.content[1].text, "deep.lua")
  lu.assertEquals(warnings, "")
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

function TestFiletree:test_dynamic_scan_stops_at_its_own_bound()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div =
    sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/deep", mode = "dynamic", depth = "1" }), {})
  local html = div.content[1].text
  lu.assertStrContains(html, "l12/")
  lu.assertNotStrContains(html, "l13")
  lu.assertStrContains(html, "ft-more")
  lu.assertEquals(select(2, html:gsub("<details open>", "")), 1)
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
  local div =
    sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/icons", hidden = "true", mode = "dynamic" }), {})
  local html = div.content[1].text
  for _, key in ipairs({
    "ft-i-bibliography",
    "ft-i-console",
    "ft-i-css",
    "ft-i-database",
    "ft-i-document",
    "ft-i-folder-base",
    "ft-i-folder-github",
    "ft-i-font",
    "ft-i-git",
    "ft-i-html",
    "ft-i-image",
    "ft-i-javascript",
    "ft-i-json",
    "ft-i-license",
    "ft-i-lock",
    "ft-i-log",
    "ft-i-lua",
    "ft-i-markdown",
    "ft-i-pdf",
    "ft-i-powerpoint",
    "ft-i-python",
    "ft-i-quarto",
    "ft-i-r",
    "ft-i-readme",
    "ft-i-rust",
    "ft-i-sass",
    "ft-i-svg",
    "ft-i-table",
    "ft-i-toml",
    "ft-i-tune",
    "ft-i-typst",
    "ft-i-word",
    "ft-i-xml",
    "ft-i-yaml",
  }) do
    lu.assertStrContains(html, key .. '"')
  end
  lu.assertStrContains(html, "--ft-icon-open:url(")
  -- The classes emit regardless of a readable icon ; this proves the SVGs are
  -- vendored and the mapping names them correctly.
  lu.assertNotStrContains(table.concat(support.warnings, "\n"), "icon not readable")
end

local function glob_html(sidecar)
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true }, script_file = FILTER })
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
  lu.assertEquals(warnings, "")
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

function TestFiletree:test_invalid_hidden_warns_and_falls_back_to_false()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div = sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/icons", hidden = "maybe" }), {})
  lu.assertStrContains(div.content[1].text, "uv.lock")
  lu.assertNotStrContains(div.content[1].text, ".Rprofile")
  lu.assertStrContains(table.concat(support.warnings, "\n"), "hidden is not a boolean, using false: maybe")
end

function TestFiletree:test_invalid_depth_warns_and_falls_back_to_two()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div = sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/tree", depth = "deep" }), {})
  local html = div.content[1].text
  lu.assertStrContains(html, "ft-more")
  lu.assertNotStrContains(html, "deep.lua")
  lu.assertStrContains(table.concat(support.warnings, "\n"), "depth is not a number, using 2: deep")
end

function TestFiletree:test_invalid_mode_warns_and_falls_back_to_static()
  local sc = support.load_shortcode(FILTER, { formats = { ["html:js"] = true } })
  local div = sc["filetree"](support.args(), kwargs({ root = "tests/fixtures/tree", mode = "wobble" }), {})
  lu.assertNotStrContains(div.content[1].text, "<details")
  lu.assertStrContains(table.concat(support.warnings, "\n"), "mode is not static or dynamic")
end
