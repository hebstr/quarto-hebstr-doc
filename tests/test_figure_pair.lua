local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/figure-pair.lua"

local function touch(path)
  local handle = assert(io.open(path, "wb"))
  handle:write("<svg/>")
  handle:close()
end

local function with_document(files, fn)
  pandoc.system.with_temporary_directory("figure-pair", function(dir)
    pandoc.system.make_directory(pandoc.path.join({ dir, "out" }))
    for _, name in ipairs(files) do
      touch(pandoc.path.join({ dir, name }))
    end
    local f = support.load_filter(FILTER, { input_file = pandoc.path.join({ dir, "doc.qmd" }) })
    fn(f, dir)
    return true
  end)
end

local function with_project(files, fn)
  pandoc.system.with_temporary_directory("figure-pair", function(dir)
    pandoc.system.make_directory(pandoc.path.join({ dir, "sub" }))
    pandoc.system.make_directory(pandoc.path.join({ dir, "out" }))
    for _, name in ipairs(files) do
      touch(pandoc.path.join({ dir, name }))
    end
    local f = support.load_filter(FILTER, {
      input_file = pandoc.path.join({ dir, "sub", "doc.qmd" }),
      project_dir = dir,
    })
    fn(f, dir)
    return true
  end)
end

local function image(src, classes)
  return pandoc.Image({ pandoc.Str("alt") }, src, "", pandoc.Attr("fig-x", classes or {}, { { "width", "50%" } }))
end

TestFigurePair = {}

function TestFigurePair:test_a_light_image_with_a_twin_becomes_the_pair()
  with_document({ "out/a-light.svg", "out/a-dark.svg" }, function(f)
    local out = f.Image(image("out/a-light.svg"))
    lu.assertEquals(#out, 2)
    lu.assertEquals(out[1].src, "out/a-light.svg")
    lu.assertEquals(out[1].classes, pandoc.List({ "light-content" }))
    lu.assertEquals(out[2].src, "out/a-dark.svg")
    lu.assertEquals(out[2].classes, pandoc.List({ "dark-content" }))
  end)
end

function TestFigurePair:test_the_dark_clone_has_no_identifier_and_keeps_the_rest()
  with_document({ "out/a-light.svg", "out/a-dark.svg" }, function(f)
    local out = f.Image(image("out/a-light.svg"))
    lu.assertEquals(out[1].identifier, "fig-x")
    lu.assertEquals(out[2].identifier, "")
    lu.assertEquals(out[2].attributes.width, "50%")
    lu.assertEquals(pandoc.utils.stringify(out[2].caption), "alt")
  end)
end

function TestFigurePair:test_existing_classes_stay_on_the_light_image_only()
  with_document({ "out/a-light.svg", "out/a-dark.svg" }, function(f)
    local out = f.Image(image("out/a-light.svg", { "img-fluid" }))
    lu.assertEquals(out[1].classes, pandoc.List({ "img-fluid", "light-content" }))
    lu.assertEquals(out[2].classes, pandoc.List({ "dark-content" }))
  end)
end

function TestFigurePair:test_a_missing_twin_leaves_the_image_alone()
  with_document({ "out/a-light.svg" }, function(f)
    lu.assertNil(f.Image(image("out/a-light.svg")))
  end)
end

function TestFigurePair:test_the_twin_is_looked_up_beside_the_document_not_the_working_directory()
  with_document({ "out/a-light.svg", "out/a-dark.svg" }, function(f, dir)
    lu.assertNotEquals(pandoc.system.get_working_directory(), dir)
    lu.assertEquals(#f.Image(image("out/a-light.svg")), 2)
  end)
end

function TestFigurePair:test_a_project_rooted_src_is_paired_from_a_document_in_a_subdirectory()
  with_project({ "out/a-light.svg", "out/a-dark.svg" }, function(f)
    local out = f.Image(image("out/a-light.svg"))
    lu.assertEquals(#out, 2)
    lu.assertEquals(out[2].src, "out/a-dark.svg")
  end)
end

function TestFigurePair:test_a_src_beside_the_document_is_still_paired_when_the_project_is_known()
  with_project({ "sub/a-light.svg", "sub/a-dark.svg" }, function(f)
    lu.assertEquals(#f.Image(image("a-light.svg")), 2)
  end)
end

function TestFigurePair:test_a_twin_under_neither_the_document_nor_the_project_leaves_the_image_alone()
  with_project({ "out/a-light.svg" }, function(f)
    lu.assertNil(f.Image(image("out/a-light.svg")))
  end)
end

function TestFigurePair:test_an_absolute_src_is_taken_as_is()
  with_document({ "out/a-light.svg", "out/a-dark.svg" }, function(f, dir)
    local light = pandoc.path.join({ dir, "out", "a-light.svg" })
    local out = f.Image(image(light))
    lu.assertEquals(out[2].src, pandoc.path.join({ dir, "out", "a-dark.svg" }))
  end)
end

function TestFigurePair:test_other_names_are_left_alone()
  with_document({ "out/a-light.png", "out/a-dark.png", "out/a.svg", "out/a-dark.svg" }, function(f)
    lu.assertNil(f.Image(image("out/a-light.png")))
    lu.assertNil(f.Image(image("out/a.svg")))
    lu.assertNil(f.Image(image("out/a-dark.svg")))
    lu.assertNil(f.Image(image("-light.svg")))
  end)
end

function TestFigurePair:test_a_remote_or_data_src_is_left_alone()
  with_document({}, function(f)
    lu.assertNil(f.Image(image("https://example.org/a-light.svg")))
    lu.assertNil(f.Image(image("data:image/svg+xml;base64,AAAA-light.svg")))
  end)
end

function TestFigurePair:test_an_image_already_classed_is_not_paired_twice()
  with_document({ "out/a-light.svg", "out/a-dark.svg" }, function(f)
    lu.assertNil(f.Image(image("out/a-light.svg", { "light-content" })))
    lu.assertNil(f.Image(image("out/a-light.svg", { "dark-content" })))
  end)
end

function TestFigurePair:test_without_an_input_file_the_image_is_left_alone()
  local f = support.load_filter(FILTER, {})
  lu.assertNil(f.Image(image("out/a-light.svg")))
end
