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
-- A `<br>` followed by a `quarto-float-subcaption` span, the markup
-- `hebstr::str_fig()` writes, becomes a paragraph of its own in `Table Caption
-- Subtitle` or `Image Caption Subtitle`, based on the caption style of the same
-- position. A character style cannot unbold it: bold is a toggle property that
-- Word combines across paragraph and character styles, and it leaves an
-- explicit `w:b w:val="0"` there bold, where `basedOn` between paragraph styles
-- is a plain override.
--
-- A float whose content is a table leaves the wrapper altogether, its caption
-- and table set at the level the wrapper stood. Word lays out a table nested in
-- that cell against the wrapper's fixed layout and nominal grid, and crushes
-- it, where the same table at top level fits its content. The float's Div keeps
-- its identifier, from which Pandoc writes the bookmark cross-references point
-- to, and `Table Caption` keeps the caption with the table that follows it.
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

local BLANK = { Space = true, SoftBreak = true, LineBreak = true }

local function trim(inlines)
  while #inlines > 0 and BLANK[inlines[1].t] do
    inlines:remove(1)
  end
  while #inlines > 0 and BLANK[inlines[#inlines].t] do
    inlines:remove(#inlines)
  end
  return inlines
end

local function split_caption(block)
  local title, subtitle = pandoc.Inlines({}), nil
  for i = 2, #block.content do
    local el = block.content[i]
    if subtitle == nil and el.t == "RawInline" and el.format == "html" and el.text:match("^<br%s*/?>$") then
      subtitle = pandoc.Inlines({})
    elseif el.t == "Span" and el.classes:includes(SUBCAPTION_CLASS) then
      subtitle = subtitle or pandoc.Inlines({})
      subtitle:extend(el.content)
    elseif subtitle then
      subtitle:insert(el)
    else
      title:insert(el)
    end
  end
  if subtitle and #trim(subtitle) == 0 then
    subtitle = nil
  end
  return trim(title), subtitle
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

local function is_tabular(block)
  if block.t == "Table" then
    return true
  elseif block.t == "RawBlock" then
    return block.format == "openxml" and block.text:match("^%s*<w:tbl[%s/>]") ~= nil
  elseif block.t == "Div" and #block.content > 0 then
    for _, child in ipairs(block.content) do
      if not is_tabular(child) then
        return false
      end
    end
    return true
  end
  return false
end

local function restyle(blocks, recenter)
  for i, block in ipairs(blocks) do
    if is_caption(block) then
      local top = i < #blocks
      local tabular = #blocks > 1
      local out = pandoc.Blocks({})
      for j, sibling in ipairs(blocks) do
        if j == i then
          local role = top and "Table Caption" or "Image Caption"
          local title, subtitle = split_caption(block)
          out:insert(styled({ pandoc.Para(title) }, role))
          if subtitle then
            out:insert(styled({ pandoc.Para(subtitle) }, role .. " Subtitle"))
          end
        else
          tabular = tabular and is_tabular(sibling)
          if recenter then
            out:extend(center_images(sibling, top and "Figure" or "Captioned Figure"))
          else
            out:insert(sibling)
          end
        end
      end
      return out, tabular
    end
  end
  return nil
end

local function single_cell(tbl)
  local bodies = tbl.bodies
  return #tbl.head.rows == 0
    and #tbl.foot.rows == 0
    and #bodies == 1
    and #bodies[1].head == 0
    and #bodies[1].body == 1
    and #bodies[1].body[1].cells == 1
end

local function Table(tbl)
  if not quarto.doc.is_format("docx") then
    return nil
  end
  local specs = tbl.colspecs
  local recenter = #specs == 1 and specs[1][1] == pandoc.AlignCenter
  local found, tabular = false, false
  local out = tbl:walk({
    Blocks = function(blocks)
      local restyled, holds_table = restyle(blocks, recenter)
      if restyled then
        found, tabular = true, holds_table == true
        return restyled
      end
    end,
  })
  if not found then
    return nil
  end
  if tabular and single_cell(out) then
    return out.bodies[1].body[1].cells[1].contents
  end
  if recenter then
    out.colspecs = { { pandoc.AlignDefault, specs[1][2] } }
  end
  return out
end

return { { Table = Table } }
