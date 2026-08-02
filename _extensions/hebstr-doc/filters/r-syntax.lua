-- Routes R code blocks to the definition bundled at syntax/r.xml.
--
-- Quarto appends its own syntax definitions after the document's, and pandoc
-- reads that list last-wins, so a bundled definition calling itself R is always
-- beaten by Quarto's own r.xml. Ours declares the language as RHebstr and this
-- filter reaches it by prepending the matching class; pandoc picks the first
-- class that resolves to a syntax, so the position matters.
--
-- The class only has to survive to the writer, and every Quarto stage that reads
-- a code block's language (code-window's auto-filename, code folding) has run by
-- then, which is why this is wired at post-quarto rather than pre-quarto.

local LANG = "rhebstr"

-- Formats where pandoc does the highlighting. Typst is excluded because its
-- writer re-emits a raw fence and lets Typst highlight it, where an unknown
-- language name would leave the block uncoloured.
local function highlighted_by_pandoc()
  return quarto.doc.is_format("html") or quarto.doc.is_format("docx")
end

local function CodeBlock(el)
  if not highlighted_by_pandoc() then
    return nil
  end
  if not el.classes:includes("r") or el.classes:includes(LANG) then
    return nil
  end
  el.classes:insert(1, LANG)
  return el
end

return { { CodeBlock = CodeBlock } }
