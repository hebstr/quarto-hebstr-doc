-- Opens the DOCX body on a new page after the table of contents.
--
-- The template's `TOC Heading` breaks the page before the table of contents,
-- which Pandoc writes ahead of the first block, and nothing breaks after it,
-- so the first heading followed the last entry on the same page. The break
-- rides on a 1 pt paragraph, as in docx-cell-paragraph.lua, so the paragraph
-- mark it carries onto the next page costs no visible height.
--
-- The table of contents is read off the writer options rather than the
-- metadata: Quarto turns `toc: true` into Pandoc's `--toc` and leaves no `toc`
-- key in the document.

local PAGE_BREAK = table.concat({
  "<w:p><w:pPr>",
  '<w:spacing w:before="0" w:after="0" w:line="20" w:lineRule="exact"/>',
  '<w:rPr><w:sz w:val="2"/><w:szCs w:val="2"/></w:rPr>',
  "</w:pPr>",
  '<w:r><w:rPr><w:sz w:val="2"/><w:szCs w:val="2"/></w:rPr><w:br w:type="page"/></w:r>',
  "</w:p>",
})

local function Pandoc(doc)
  if not quarto.doc.is_format("docx") then
    return nil
  end
  if not (PANDOC_WRITER_OPTIONS and PANDOC_WRITER_OPTIONS.table_of_contents) then
    return nil
  end
  doc.blocks:insert(1, pandoc.RawBlock("openxml", PAGE_BREAK))
  return doc
end

return { { Pandoc = Pandoc } }
