local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/crossref-anx.lua"

-- The handler reads `.identifier` and writes `.identifier` and `.type`, so a
-- bare table stands in for Quarto's FloatRefTarget node; nothing else of that
-- node is touched, and the fields it would carry are irrelevant here.
local function float(id, kind)
  return { identifier = id, type = kind or "Table" }
end

TestCrossrefAnx = {}

function TestCrossrefAnx:test_table_carrier_becomes_an_annexe()
  local f = support.load_filter(FILTER, {})
  local out = f.FloatRefTarget(float("tbl-anx-demo"))
  lu.assertEquals(out.identifier, "anx-demo")
  lu.assertEquals(out.type, "Annexe")
end

function TestCrossrefAnx:test_figure_carrier_becomes_an_annexe()
  local f = support.load_filter(FILTER, {})
  local out = f.FloatRefTarget(float("fig-anx-demo", "Figure"))
  lu.assertEquals(out.identifier, "anx-demo")
  lu.assertEquals(out.type, "Annexe")
end

-- Only the carrier prefix goes: the rest of the identifier is the author's and
-- may hold further dashes, including ones that look like a prefix themselves.
function TestCrossrefAnx:test_only_the_leading_prefix_is_stripped()
  local f = support.load_filter(FILTER, {})
  lu.assertEquals(f.FloatRefTarget(float("tbl-anx-fig-2")).identifier, "anx-fig-2")
end

-- A hand-written ::: {#anx-...} div reaches the filter already typed by Quarto
-- and shares the same counter; stripping a prefix off it would mangle the id.
function TestCrossrefAnx:test_bare_anx_identifier_is_left_alone()
  local f = support.load_filter(FILTER, {})
  lu.assertNil(f.FloatRefTarget(float("anx-manual")))
end

function TestCrossrefAnx:test_ordinary_floats_are_left_alone()
  local f = support.load_filter(FILTER, {})
  lu.assertNil(f.FloatRefTarget(float("tbl-foo")))
  lu.assertNil(f.FloatRefTarget(float("fig-foo", "Figure")))
end

-- The carrier only means anything at the head of the identifier; anywhere else
-- it is part of a name the author chose.
function TestCrossrefAnx:test_embedded_carrier_is_left_alone()
  local f = support.load_filter(FILTER, {})
  lu.assertNil(f.FloatRefTarget(float("tbl-fig-anx-demo")))
  lu.assertNil(f.FloatRefTarget(float("lst-anx-demo", "Listing")))
end
