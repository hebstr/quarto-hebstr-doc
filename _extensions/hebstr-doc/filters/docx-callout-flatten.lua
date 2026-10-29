-- Flattens a callout into body text, so Quarto builds no callout table in DOCX.
--
-- Both branches of Quarto's calloutDocx renderer wrap the callout in a w:tbl
-- carrying a thick left border, and the simple one also pulls the type icon
-- into word/media. Returning the title as a bold paragraph followed by the
-- callout's own blocks means that renderer never runs: the content comes out as
-- ordinary body prose, hyphenated and justified like the paragraphs around it.
--
-- What it costs the reader is the aside itself. A callout with no body becomes a
-- lone bold paragraph with nothing left marking it as one, and the bold is the
-- whole of what distinguishes it from the sentence above. HTML keeps its
-- callouts, the filter being wired under docx: alone and guarded on the format
-- besides, as docx-layout-flatten.lua is.
--
-- The title comes back as a paragraph rather than the heading it was authored
-- as, and that is the point: Quarto's own parse has already dropped the level by
-- the time this node exists, and a heading here would take a section number, a
-- table of contents entry and, at level 1, a page break from template.dotx.
--
-- A callout carrying an identifier is left as the table Quarto builds. Flattening
-- at pre-quarto means the crossref filters never see it, so a flattened callout
-- gets no number and no bookmark and a reference to it renders as `?@nte-x`.

local function Callout(callout)
  if not quarto.doc.is_format("docx") then
    return nil
  end
  if callout.attr.identifier ~= "" then
    return nil
  end
  local blocks = pandoc.Blocks({})
  local title = quarto.utils.as_inlines(callout.title)
  if #title > 0 then
    blocks:insert(pandoc.Para({ pandoc.Strong(title) }))
  end
  blocks:extend(quarto.utils.as_blocks(callout.content))
  return blocks
end

return { { Callout = Callout } }
