-- Gives a loose list item the body size.
--
-- Pandoc drops its own body style wherever the paragraph already carries
-- properties, so an item of a loose list (a blank line between items) arrives
-- with a `w:numPr` and no `w:pStyle` at all. It then falls through `Normal` to
-- the document defaults, one point larger than the prose and single-spaced,
-- where a tight item, being a Plain, takes `Compact`.
--
-- The style lands through a `custom-style` Div, as in docx-caption.lua, so
-- Pandoc writes one `w:pPr` carrying both the style and the numbering. The
-- `List Item` style of template.dotx is based on `Compact` and restores the
-- paragraph spacing the loose form asks for, so `Normal` stays bare and
-- retouching the prose still happens on `Body Text` alone.

local STYLE = "List Item"

local function style_items(items)
  local out = {}
  local touched = false
  for i, blocks in ipairs(items) do
    local styled = {}
    for j, block in ipairs(blocks) do
      if block.t == "Para" then
        styled[j] = pandoc.Div({ block }, pandoc.Attr("", {}, { ["custom-style"] = STYLE }))
        touched = true
      else
        styled[j] = block
      end
    end
    out[i] = styled
  end
  if not touched then
    return nil
  end
  return out
end

local function BulletList(el)
  if not quarto.doc.is_format("docx") then
    return nil
  end
  local items = style_items(el.content)
  if not items then
    return nil
  end
  return pandoc.BulletList(items)
end

local function OrderedList(el)
  if not quarto.doc.is_format("docx") then
    return nil
  end
  local items = style_items(el.content)
  if not items then
    return nil
  end
  return pandoc.OrderedList(items, el.listAttributes)
end

return { { BulletList = BulletList, OrderedList = OrderedList } }
