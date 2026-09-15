-- Styles DOCX float captions by where they sit rather than by float type.
--
-- Quarto renders every float into a one-cell table whose column is centred,
-- and opens its caption with a raw `<w:pPr>` naming `ImageCaption` with a
-- direct left alignment. Pandoc writes its own `w:pPr` for the column centring
-- ahead of that one, so the paragraph carries two property elements, and
-- either direct alignment overrides the reference document.
--
-- A caption placed before its content takes `Table Caption` (centred, kept
-- with what follows), one placed after takes `Image Caption` (left): a figure
-- moved to `fig-cap-location: top` reads like a table caption, which is the
-- rule `figcaption.quarto-float-caption-top` applies in the HTML theme. The
-- position is read off the rendered order, where Quarto has already resolved
-- the chunk, document and format options.
--
-- The raw element is dropped for a `custom-style` Div, so Pandoc writes a
-- single valid `w:pPr`, and the column centring moves onto the `Figure` style
-- of the image paragraph, since a direct centring would also reach the
-- caption. The image moves from Plain to Para on the way, the DOCX writer
-- forcing `Compact` onto any Plain inside a table cell over the Div's style. A
-- wrapper aligned otherwise keeps its alignment.
--
-- Runs post-render: the raw `<w:pPr>` only exists once Quarto's float renderer
-- has run, which is after every post-quarto filter.

local CAPTION_MARKER = 'w:pStyle w:val="ImageCaption"'
local SUBCAPTION_CLASS = "quarto-float-subcaption"

local function styled(blocks, style)
  return pandoc.Div(blocks, pandoc.Attr("", {}, { ["custom-style"] = style }))
end

local function is_caption(block)
  if block.t ~= "Para" and block.t ~= "Plain" then
    return false
  end
  local first = block.content[1]
  return first ~= nil
    and first.t == "RawInline"
    and first.format == "openxml"
    and first.text:find(CAPTION_MARKER, 1, true) ~= nil
end

local function caption_inlines(block)
  local out = pandoc.Inlines({})
  for i = 2, #block.content do
    local el = block.content[i]
    if el.t == "RawInline" and el.format == "html" and el.text:match("^<br%s*/?>$") then
      out:insert(pandoc.LineBreak())
    elseif el.t == "Span" and el.classes:includes(SUBCAPTION_CLASS) then
      el.attributes["custom-style"] = "Caption Subtitle"
      out:insert(el)
    else
      out:insert(el)
    end
  end
  return out
end

local function has_image(plain)
  local found = false
  plain:walk({
    Image = function()
      found = true
    end,
  })
  return found
end

local function center_images(block, style)
  return pandoc.Blocks({ block }):walk({
    Plain = function(plain)
      if has_image(plain) then
        return styled({ pandoc.Para(plain.content) }, style)
      end
    end,
  })
end

local function restyle(blocks, recenter)
  for i, block in ipairs(blocks) do
    if is_caption(block) then
      local top = i < #blocks
      local out = pandoc.Blocks({})
      for j, sibling in ipairs(blocks) do
        if j == i then
          out:insert(styled({ pandoc.Para(caption_inlines(block)) }, top and "Table Caption" or "Image Caption"))
        elseif recenter then
          out:extend(center_images(sibling, top and "Figure" or "Captioned Figure"))
        else
          out:insert(sibling)
        end
      end
      return out
    end
  end
  return nil
end

local function Table(tbl)
  if not quarto.doc.is_format("docx") then
    return nil
  end
  local specs = tbl.colspecs
  local recenter = #specs == 1 and specs[1][1] == pandoc.AlignCenter
  local found = false
  local out = tbl:walk({
    Blocks = function(blocks)
      local restyled = restyle(blocks, recenter)
      if restyled then
        found = true
        return restyled
      end
    end,
  })
  if not found then
    return nil
  end
  if recenter then
    out.colspecs = { { pandoc.AlignDefault, specs[1][2] } }
  end
  return out
end

return { { Table = Table } }
