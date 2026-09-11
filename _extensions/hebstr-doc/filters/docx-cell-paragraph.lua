-- Closes a raw OOXML table with an empty paragraph.
--
-- Word requires the last block-level element of a `w:tc` to be a `w:p`, and
-- refuses to open a document where one is missing: "an ambiguous cell mapping
-- was encountered", with no recovery offered. Quarto wraps every referenced
-- float in a one-cell table to keep caption and content together, so a table
-- arriving as raw OOXML (a flextable or a gt table, which knitr prints as an
-- `{=openxml}` block ending on `</w:tbl>`) lands last in that cell and leaves it
-- open. LibreOffice renders such a file, which is why the defect only shows on
-- a real Word install.
--
-- The paragraph is appended to the raw block rather than inserted into the
-- surrounding cell, because a Pandoc Para carrying no inline is dropped before
-- the writer ever sees it. It is sized to 1 pt with its spacing zeroed so it
-- costs no visible height wherever the block is not inside a cell.

local CLOSING_PARAGRAPH = table.concat({
  "<w:p><w:pPr>",
  '<w:spacing w:before="0" w:after="0" w:line="20" w:lineRule="exact"/>',
  '<w:rPr><w:sz w:val="2"/><w:szCs w:val="2"/></w:rPr>',
  "</w:pPr></w:p>",
})

local function RawBlock(el)
  if not quarto.doc.is_format("docx") then
    return nil
  end
  if el.format ~= "openxml" or not el.text:match("</w:tbl>%s*$") then
    return nil
  end
  return pandoc.RawBlock("openxml", el.text .. CLOSING_PARAGRAPH)
end

return { { RawBlock = RawBlock } }
