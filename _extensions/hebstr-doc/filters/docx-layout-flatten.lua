-- Drops the layout keys of a Div, so Quarto builds no layout table in DOCX.
--
-- Quarto turns a Div carrying `layout-ncol` into a table of one cell per
-- panel, sized against a page width of its own: a float lands there at the
-- size Pandoc gives it in the body, which no longer fits, and Word clips it at
-- the cell edge. The cells also carry the `tblCellMar` inset of the `Table`
-- style, and the column alignment Pandoc writes on every one of their
-- paragraphs outranks the caption and figure styles.
--
-- Removing the keys before Quarto's own filters run leaves the cells' blocks
-- in the body in order, each float keeping the one-cell wrapper that
-- docx-caption.lua lifts, so an image comes out at the size it has outside a
-- row. The juxtaposition is what it costs, and HTML keeps it.
--
-- The chunk form (`#| layout-ncol`) is out of reach here, Quarto carrying that
-- option inside a FloatRefTarget custom node rather than on the Div, which is
-- why docx-caption.lua keeps its own alignment reset for a layout row.

local KEYS = { "layout", "layout-ncol", "layout-nrow", "layout-align", "layout-valign" }

local function Div(div)
  if not quarto.doc.is_format("docx") then
    return nil
  end
  local dropped = false
  for _, key in ipairs(KEYS) do
    if div.attributes[key] ~= nil then
      div.attributes[key] = nil
      dropped = true
    end
  end
  if not dropped then
    return nil
  end
  return div
end

return { { Div = Div } }
