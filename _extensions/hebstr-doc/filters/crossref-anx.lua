-- Retypes a float authored as a table or a figure into the `anx` crossref
-- category declared in _extension.yml, so an annexe is numbered, captioned and
-- referenced like a table without being one.
--
-- An annexe cannot be authored as `anx-x` directly: the knitr engine hardcodes
-- ^#?(fig|tbl)- in is_figure_label()/is_table_label() and drops any other label
-- before the id reaches Pandoc. It is authored as `tbl-anx-x` or `fig-anx-x`
-- instead, and the carrier prefix is stripped here. That prefix is not dead
-- weight either: it is what decides tbl-cap against fig-cap upstream, and what
-- makes the float degrade into a plain, visible table or figure should this
-- filter ever stop running.
--
-- Wired at pre-quarto because that is the one stage where the FloatRefTarget
-- node is already built and still mutable: Quarto's own crossref filters, which
-- read the type to number and label the float, run right after it.

-- Quarto resolves a float against its categories by name, and a custom
-- category takes its name from `reference-prefix`, so this string is the one
-- declared under `crossref: custom:` in _extension.yml, not the `anx` key.
local TYPE = "Annexe"

local function FloatRefTarget(float)
  local id = float.identifier
  if not (id:match("^tbl%-anx%-") or id:match("^fig%-anx%-")) then
    return nil
  end
  float.identifier = id:gsub("^%a+%-", "")
  float.type = TYPE
  return float
end

return { { FloatRefTarget = FloatRefTarget } }
