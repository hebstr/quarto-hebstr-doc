-- Carries a reviewer's Word comments back into the DOCX render.
--
-- Forked from the `docx` branch of MikeLydeamore/collab-comments at tag
-- `v1.1.0` (https://github.com/MikeLydeamore/collab-comments), and maintained
-- here as this extension's own code. The editor half, which writes and
-- re-anchors the comment store, stays upstream and unmodified.
--
-- A comment imported from a reviewed `.docx` lands in `.comments/collab-comments.json`
-- beside the project root, carrying the literal source text it selected. This
-- filter finds that literal in the source, matches it against the rendered
-- document, and wraps the occurrence in the `comment-start` / `comment-end`
-- spans Pandoc's DOCX writer turns into a real Word comment part. A selection
-- that no longer resolves is named on stderr and the render still succeeds.
--
-- Dropped at the fork: the HTML export, the live preview bridge and its
-- descriptor discovery (`trusted_descriptor_directory`, `live_descriptor`,
-- `config_script`), with the `collab-comments.js` and `collab-comments.css`
-- dependencies they loaded. Neither is wanted here, and an HTML dependency
-- resolved beside the filter would not have survived the move.
--
-- The metadata key is unchanged, so a consuming document keeps its own
-- `collab-comments:` block and loses only its `filters:` line. `docx-comments`
-- defaults to false: a document that does not ask for comments gets a no-op.
--
-- Wired at `post-quarto`, which is where the measurement that proves the move
-- was taken. A later stage is worse rather than better: Quarto's float renderer
-- runs after every `post-quarto` filter, so at `post-render` a float caption is
-- a `Para` whose first inline is a raw `<w:pPr>`, which the text view refuses
-- outright.

local MAX_FILTER_READ_BYTES = 20 * 1024 * 1024

-- Do not ask Lua to allocate or decode an unbounded file supplied through a
-- workspace. The store and source are both untrusted at this boundary.
local function read_file_limited(path, description)
  local file = io.open(path, "rb")
  if not file then
    return nil, "unable to open " .. description
  end
  local size_ok, size = pcall(file.seek, file, "end")
  if not size_ok or type(size) ~= "number" then
    file:close()
    return nil, "unable to determine " .. description .. " size"
  end
  if size > MAX_FILTER_READ_BYTES then
    file:close()
    return nil, description .. " exceeds 20 MiB limit"
  end
  local reset_ok = pcall(file.seek, file, "set", 0)
  if not reset_ok then
    file:close()
    return nil, "unable to read " .. description
  end
  local content = file:read("*a")
  file:close()
  if type(content) ~= "string" then
    return nil, "unable to read " .. description
  end
  return content
end

local function normalize(value)
  local normalized = (value or ""):gsub("\\", "/"):gsub("/+", "/")
  -- macOS exposes its temporary directory through both /var and /private/var.
  -- Node and Quarto can independently choose either spelling for the same inode.
  return normalized:gsub("^/private/var/", "/var/")
end

local function is_absolute(value)
  if pandoc.path and pandoc.path.is_absolute then
    local ok, result = pcall(pandoc.path.is_absolute, value)
    if ok then
      return result
    end
  end
  return value:sub(1, 1) == "/" or value:match("^%a:[/\\]") ~= nil
end

local function join_path(left, right)
  if pandoc.path and pandoc.path.join then
    return pandoc.path.join({ left, right })
  end
  return left .. "/" .. right
end

local function boolean(value, default)
  if value == nil then
    return default
  end
  return pandoc.utils.stringify(value):lower() == "true"
end

local function config_value(meta, key, default)
  local config = meta["collab-comments"]
  if config and config[key] ~= nil then
    return boolean(config[key], default)
  end
  return default
end

local function current_input()
  local input = quarto.doc.input_file or (PANDOC_STATE.input_files and PANDOC_STATE.input_files[1]) or ""
  if not is_absolute(input) then
    local root = quarto.project.directory or pandoc.system.get_working_directory()
    input = join_path(root, input)
  end
  return normalize(input)
end

local function exported_comments(workspace, input, show_resolved)
  workspace = normalize(workspace)
  local root = workspace
  local directory = normalize(input):match("^(.*)/[^/]+$") or workspace
  local store_path
  while directory and directory ~= "" do
    root = directory
    local candidate = join_path(join_path(root, ".comments"), "collab-comments.json")
    local file = io.open(candidate, "rb")
    if file then
      file:close()
      store_path = candidate
      break
    end
    local parent = directory:match("^(.*)/[^/]+$")
    if not parent or parent == directory then
      break
    end
    directory = parent
  end
  if not store_path then
    return {}
  end
  local raw, read_error = read_file_limited(store_path, "comment store")
  if not raw then
    io.stderr:write("[collab-comments] skipped comment export: " .. read_error .. "\n")
    return {}
  end
  local ok, store = pcall(pandoc.json.decode, raw)
  if not ok or type(store) ~= "table" or type(store.comments) ~= "table" then
    return {}
  end
  local function valid_position(position)
    return type(position) == "table"
      and type(position.line) == "number"
      and position.line >= 0
      and position.line == math.floor(position.line)
      and type(position.character) == "number"
      and position.character >= 0
      and position.character == math.floor(position.character)
  end
  local function valid_array(items, valid_item)
    if type(items) ~= "table" then
      return false
    end
    for key, item in pairs(items) do
      if type(key) ~= "number" or key < 1 or key ~= math.floor(key) or not valid_item(item) then
        return false
      end
    end
    return true
  end
  local function valid_reply(reply)
    return type(reply) == "table"
      and type(reply.id) == "string"
      and type(reply.author) == "string"
      and type(reply.timestamp) == "string"
      and type(reply.text) == "string"
  end
  local function valid_change(change)
    return type(change) == "table"
      and type(change.id) == "string"
      and type(change.author) == "string"
      and type(change.timestamp) == "string"
      and type(change.previousText) == "string"
      and type(change.newText) == "string"
  end
  local function valid_comment(comment)
    if
      type(comment) ~= "table"
      or type(comment.id) ~= "string"
      or type(comment.author) ~= "string"
      or type(comment.timestamp) ~= "string"
      or type(comment.text) ~= "string"
      or type(comment.filePath) ~= "string"
      or type(comment.range) ~= "table"
      or not valid_position(comment.range.start)
      or not valid_position(comment.range["end"])
    then
      return false
    end
    if comment.selectedText ~= nil and type(comment.selectedText) ~= "string" then
      return false
    end
    if comment.contextBefore ~= nil and type(comment.contextBefore) ~= "string" then
      return false
    end
    if comment.contextAfter ~= nil and type(comment.contextAfter) ~= "string" then
      return false
    end
    if comment.documentHash ~= nil and type(comment.documentHash) ~= "string" then
      return false
    end
    if comment.resolved ~= nil and type(comment.resolved) ~= "boolean" then
      return false
    end
    if comment.replies ~= nil and not valid_array(comment.replies, valid_reply) then
      return false
    end
    if comment.trackedChanges ~= nil and not valid_array(comment.trackedChanges, valid_change) then
      return false
    end
    return true
  end
  -- Reject a malformed collection as a whole. Do not turn a partial parse of
  -- an untrusted store into an export containing a possibly unrelated entry.
  if not valid_array(store.comments, valid_comment) then
    return {}
  end
  local relative = normalize(input):sub(#root + 2)
  local result = {}
  for _, comment in ipairs(store.comments) do
    if valid_comment(comment) and comment.filePath == relative and (show_resolved or not comment.resolved) then
      table.insert(result, comment)
    end
  end
  return result
end

local function warning(input, comment, reason)
  io.stderr:write(
    string.format(
      "[collab-comments] %s:%d: skipped Word comment %s: %s\n",
      input,
      (comment.range and comment.range.start and comment.range.start.line or 0) + 1,
      comment.id or "?",
      reason
    )
  )
end

local function source_lines(input)
  local text, read_error = read_file_limited(input, "QMD source")
  if not text then
    return nil, read_error
  end
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    table.insert(lines, line)
  end
  return lines
end

-- VS Code stores UTF-16 characters; Lua string slicing uses UTF-8 byte
-- offsets. Return a byte index only at a valid UTF-16 boundary.
local function utf16_byte_index(text, character)
  if character == 0 then
    return 1
  end
  local units, byte = 0, 1
  while byte <= #text do
    local codepoint = utf8.codepoint(text, byte)
    local width = codepoint and codepoint > 0xffff and 2 or 1
    if units + width > character then
      return nil
    end
    units = units + width
    byte = utf8.offset(text, 2, byte) or (#text + 1)
    if units == character then
      return byte
    end
  end
  return units == character and #text + 1 or nil
end

local function selected_source_text(lines, comment)
  if type(comment.selectedText) ~= "string" then
    return nil, "legacy comment has no stored selection text"
  end
  local start, finish = comment.range.start, comment.range["end"]
  if start.line ~= finish.line then
    return nil, "selection spans source lines"
  end
  local line = lines[start.line + 1]
  if line == nil then
    return nil, "source line no longer exists"
  end
  local from, to = utf16_byte_index(line, start.character), utf16_byte_index(line, finish.character)
  if not from or not to or to < from then
    return nil, "invalid source range"
  end
  local selected = line:sub(from, to - 1)
  if selected == "" or selected ~= comment.selectedText then
    return nil, "stored selection is stale or not literal source text"
  end
  return selected
end

local function transcript(comment)
  -- The opening is always first. Activity is chronological; timestamps use
  -- direct UTF-8 byte ordinal comparison (the TS side compares UTF-8 buffers),
  -- never locale-sensitive collation. Ties are Reply
  -- then Tracked change, retaining their original insertion order within a kind.
  local entries =
    { { timestamp = comment.timestamp, kind = "Opening comment", author = comment.author, text = comment.text } }
  local activity = {}
  for order, reply in ipairs(comment.replies or {}) do
    table.insert(activity, {
      timestamp = reply.timestamp,
      kind = "Reply",
      kind_rank = 1,
      order = order,
      author = reply.author,
      text = reply.text,
    })
  end
  for order, change in ipairs(comment.trackedChanges or {}) do
    table.insert(activity, {
      timestamp = change.timestamp,
      kind = "Tracked change",
      kind_rank = 2,
      order = order,
      author = change.author,
      text = "Previous: " .. change.previousText .. "\nCurrent: " .. change.newText,
    })
  end
  table.sort(activity, function(left, right)
    if left.timestamp ~= right.timestamp then
      return left.timestamp < right.timestamp
    end
    if left.kind_rank ~= right.kind_rank then
      return left.kind_rank < right.kind_rank
    end
    return left.order < right.order
  end)
  for _, entry in ipairs(activity) do
    table.insert(entries, entry)
  end
  local parts = {}
  for index, entry in ipairs(entries) do
    if index == 1 then
      table.insert(parts, entry.text)
    else
      table.insert(
        parts,
        "—— " .. entry.kind .. " · " .. entry.author .. " · " .. entry.timestamp .. " ——\n" .. entry.text
      )
    end
  end
  local body = table.concat(parts, "\n\n")
  return comment.resolved and ("Resolved\n\n" .. body) or body
end

-- 31-bit FNV-1a over the UTF-8 bytes of the local ID, a NUL separator, and
-- the exact flattened transcript sent to Word. This provenance snapshot keeps
-- a later local edit from being mistaken for the exported Word comment.
local function word_id(local_id, exported_body)
  local hash = 0x811c9dc5
  local input = local_id .. "\0" .. exported_body
  for index = 1, #input do
    hash = (hash ~ string.byte(input, index)) * 0x01000193
    hash = hash & 0xffffffff
  end
  hash = hash & 0x7fffffff
  if hash == 0 then
    hash = 1
  end
  return tostring(hash)
end

local function literal_inlines(text)
  -- Pandoc's native line-break inline represents all source newline styles.
  -- Normalise before splitting so CRLF never becomes Space + LineBreak.
  text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
  local result = {}
  local first = true
  for line in (text .. "\n"):gmatch("(.-)\n") do
    if not first then
      table.insert(result, pandoc.LineBreak())
    end
    first = false
    local word_start = 1
    while word_start <= #line do
      local space_start, space_end = line:find("%s+", word_start)
      if space_start == word_start then
        table.insert(result, pandoc.Space())
        word_start = space_end + 1
      else
        local finish = space_start and space_start - 1 or #line
        if finish >= word_start then
          table.insert(result, pandoc.Str(line:sub(word_start, finish)))
        end
        word_start = space_start or (#line + 1)
      end
    end
  end
  return result
end

-- One text view serves both the occurrence count and the rewrite, and that is a
-- correctness requirement rather than tidiness. The count decides whether a
-- selection is unique; the rewrite maps byte offsets back onto inlines. Two
-- views can disagree on a byte, and then counting validates an occurrence the
-- rewrite places somewhere else: `pandoc.utils.stringify`, which this replaces,
-- renders a SoftBreak as a space where the offset map needs a newline.
--
-- It is total, so no block drops out of the count. A formatting container
-- contributes its children; an atomic inline contributes the text Word shows
-- for it, so a selection matching inside one still makes another match
-- ambiguous. Raw markup, a footnote's body and an inline type newer than this
-- table contribute nothing: none of the three is body text a selection can
-- legitimately land in.
local CONTAINER_INLINES = {
  Emph = true,
  Strong = true,
  Underline = true,
  Strikeout = true,
  Superscript = true,
  Subscript = true,
  SmallCaps = true,
  Quoted = true,
  Link = true,
  Span = true,
}

local ATOMIC_INLINES = {
  Cite = true,
  Code = true,
  Math = true,
  Image = true,
  RawInline = true,
  Note = true,
}

local BREAK_TEXT = {
  Space = " ",
  SoftBreak = "\n",
  LineBreak = "\n",
}

local inline_text

local function atomic_text(inline)
  if inline.t == "Cite" then
    return inline_text(inline.content)
  end
  if inline.t == "Code" or inline.t == "Math" then
    return inline.text
  end
  if inline.t == "Image" then
    return inline_text(inline.caption)
  end
  return ""
end

local function piece_text(inline)
  if inline.t == "Str" then
    return inline.text
  end
  if BREAK_TEXT[inline.t] then
    return BREAK_TEXT[inline.t]
  end
  if CONTAINER_INLINES[inline.t] then
    return inline_text(inline.content)
  end
  return atomic_text(inline)
end

function inline_text(inlines)
  local result = {}
  for _, inline in ipairs(inlines) do
    table.insert(result, piece_text(inline))
  end
  return table.concat(result)
end

local function rendered_block_texts(doc)
  local result = {}
  -- Pandoc's native walk visits blocks inside all containers, including table
  -- cells and structures added by newer Pandoc versions. A match in a block the
  -- rewrite cannot reach still makes another match ambiguous.
  local function record(block)
    table.insert(result, inline_text(block.content))
  end
  doc:walk({ Para = record, Plain = record, Header = record })
  return result
end

local function rewrite_block(block, candidates, used)
  local inlines = block.content
  local text = inline_text(inlines)
  local matches = {}
  for _, candidate in ipairs(candidates) do
    local from = 1
    while true do
      local start = text:find(candidate.selection, from, true)
      if not start then
        break
      end
      table.insert(matches, { start = start, finish = start + #candidate.selection - 1, candidate = candidate })
      -- Advance one byte so overlapping literal occurrences (for example
      -- `aaa` in `aaaa`) make the source ambiguous instead of exportable.
      from = start + 1
    end
  end
  if #matches == 0 then
    return block
  end
  -- A selection must have one and only one rendered occurrence in the document.
  local accepted = {}
  for _, match in ipairs(matches) do
    if candidates[match.candidate.index].occurrences == 1 then
      table.insert(accepted, match)
    end
  end
  table.sort(accepted, function(left, right)
    return left.start < right.start
  end)
  for index = 2, #accepted do
    if accepted[index].start <= accepted[index - 1].finish then
      accepted[index].candidate.overlap = true
      accepted[index - 1].candidate.overlap = true
    end
  end
  if #accepted == 0 then
    return block
  end
  -- A candidate is claimed only once the rewrite below has run to the end. The
  -- walk still refuses a block it cannot map, and marking the claim before that
  -- refusal would drop the comment with no warning at all, every diagnosis
  -- downstream reading the claim as a delivered marker.
  local claimed = {}
  local starts, ends = {}, {}
  for _, match in ipairs(accepted) do
    if not match.candidate.overlap then
      starts[match.start] = match.candidate
      ends[match.finish + 1] = match.candidate
      table.insert(claimed, match.candidate)
    end
  end
  local function start_marker(candidate)
    local attr = pandoc.Attr("", { "comment-start" }, {
      id = candidate.word_id,
      author = candidate.comment.author,
      date = candidate.comment.timestamp,
    })
    return pandoc.Span(literal_inlines(candidate.body), attr)
  end
  local function end_marker(candidate)
    return pandoc.Span({}, pandoc.Attr("", { "comment-end" }, { id = candidate.word_id }))
  end
  -- The offsets the markers sit at are byte offsets into the one text view
  -- above, so the walk below has to advance through the inlines by the same
  -- rule: `position` is shared across the recursion and `piece_text` is what
  -- moves it, never a second reading of the inline.
  --
  -- A marker lands at a given offset once. The outer level reaches a
  -- container's opening offset first, so a selection starting there opens
  -- outside the formatting; the recursion reaches the closing offset first, so
  -- a selection ending there closes inside it. Either is valid: the DOCX writer
  -- emits both range markers as run-level siblings whatever inline encloses
  -- them.
  --
  -- A refused block is returned untouched, which is why a container is rebuilt
  -- as a clone rather than mutated: a refusal deeper in the same paragraph
  -- would otherwise leave a half-rewritten node behind.
  local position = 1
  local emitted = {}
  local function markers_at(output, offset)
    if emitted[offset] then
      return
    end
    if ends[offset] then
      table.insert(output, end_marker(ends[offset]))
    end
    if starts[offset] then
      table.insert(output, start_marker(starts[offset]))
    end
    emitted[offset] = true
  end
  local function boundaries_within(from, to)
    local seen = {}
    for offset, _ in pairs(starts) do
      if offset > from and offset < to then
        seen[offset] = true
      end
    end
    for offset, _ in pairs(ends) do
      if offset > from and offset < to then
        seen[offset] = true
      end
    end
    local boundaries = {}
    for offset, _ in pairs(seen) do
      table.insert(boundaries, offset)
    end
    table.sort(boundaries)
    return boundaries
  end
  local function split_string(output, inline, finish)
    local piece = inline.text
    local cursor = position
    for _, boundary in ipairs(boundaries_within(position, finish)) do
      if boundary > cursor then
        table.insert(output, pandoc.Str(piece:sub(cursor - position + 1, boundary - position)))
      end
      markers_at(output, boundary)
      cursor = boundary
    end
    if cursor < finish then
      table.insert(output, pandoc.Str(piece:sub(cursor - position + 1)))
    end
  end
  local rewrite_inlines
  function rewrite_inlines(source)
    local output = {}
    for _, inline in ipairs(source) do
      local finish = position + #piece_text(inline)
      markers_at(output, position)
      if inline.t == "Str" then
        split_string(output, inline, finish)
        position = finish
      elseif BREAK_TEXT[inline.t] then
        table.insert(output, inline)
        position = finish
      elseif CONTAINER_INLINES[inline.t] then
        local inner = rewrite_inlines(inline.content)
        if not inner then
          return nil
        end
        local container = inline:clone()
        container.content = inner
        table.insert(output, container)
      elseif ATOMIC_INLINES[inline.t] then
        -- An atomic inline is an opaque run: it carries its own text through
        -- the offset map, so a selection can open and close around it, and a
        -- marker boundary falling inside it refuses the block rather than
        -- cutting a citation, a code span or a formula in two.
        if #boundaries_within(position, finish) > 0 then
          return nil
        end
        table.insert(output, inline)
        position = finish
      else
        return nil
      end
      markers_at(output, finish)
    end
    return output
  end
  local output = rewrite_inlines(inlines)
  if not output then
    return block
  end
  for _, candidate in ipairs(claimed) do
    used[candidate.index] = true
  end
  block.content = output
  return block
end

local function add_docx_comments(doc, input, workspace, show_resolved)
  local lines, read_error = source_lines(input)
  if not lines then
    io.stderr:write("[collab-comments] skipped Word export: " .. read_error .. "\n")
    return doc
  end
  local selected = exported_comments(workspace, input, show_resolved)
  local raw_candidates = {}
  for _, comment in ipairs(selected) do
    local literal, reason = selected_source_text(lines, comment)
    if not literal then
      warning(input, comment, reason)
    else
      local body = transcript(comment)
      table.insert(raw_candidates, {
        comment = comment,
        selection = literal,
        body = body,
        word_id = word_id(comment.id, body),
        occurrences = 0,
      })
    end
  end
  local id_counts = {}
  for _, candidate in ipairs(raw_candidates) do
    id_counts[candidate.word_id] = (id_counts[candidate.word_id] or 0) + 1
  end
  local candidates = {}
  for _, candidate in ipairs(raw_candidates) do
    if id_counts[candidate.word_id] > 1 then
      warning(input, candidate.comment, "deterministic Word ID collision")
    else
      candidate.index = #candidates + 1
      table.insert(candidates, candidate)
    end
  end
  -- Count every rendered Para/Plain/Header before rewriting, including content
  -- in nested containers and tables. A match in an unsupported rewrite
  -- structure still makes another match ambiguous.
  local rendered_blocks = rendered_block_texts(doc)
  for _, text in ipairs(rendered_blocks) do
    for _, candidate in ipairs(candidates) do
      local from = 1
      while true do
        local start = text:find(candidate.selection, from, true)
        if not start then
          break
        end
        candidate.occurrences = candidate.occurrences + 1
        -- Count overlapping rendered occurrences too; this must agree with
        -- rewrite_block's literal scan above.
        from = start + 1
      end
    end
  end
  -- The rewrite walks the body rather than iterating its top level, so a
  -- paragraph inside a list, a Div or a table cell is reachable. It walks
  -- `doc.blocks` and not the document, because a document walk visits metadata
  -- too and a title or an abstract is no place for a comment marker; the count
  -- above does walk the document, a match in the metadata being a real
  -- occurrence in the rendered output.
  local used = {}
  local function rewrite(block)
    return rewrite_block(block, candidates, used)
  end
  doc.blocks = pandoc.Blocks(doc.blocks):walk({ Para = rewrite, Plain = rewrite, Header = rewrite })
  for _, candidate in ipairs(candidates) do
    if candidate.overlap then
      warning(input, candidate.comment, "overlapping rendered selection")
    elseif candidate.occurrences == 0 then
      warning(input, candidate.comment, "selection is absent from supported rendered blocks")
    elseif candidate.occurrences > 1 then
      warning(input, candidate.comment, "selection is ambiguous in rendered document")
    elseif not used[candidate.index] then
      warning(input, candidate.comment, "selection occurs only in unsupported rendered structure")
    end
  end
  return doc
end

local function Pandoc(doc)
  if not quarto.doc.is_format("docx") then
    return doc
  end
  if not config_value(doc.meta, "docx-comments", false) then
    return doc
  end
  local input = current_input()
  local workspace = normalize(quarto.project.directory or pandoc.system.get_working_directory())
  local show_resolved = config_value(doc.meta, "show-resolved", false)
  return add_docx_comments(doc, input, workspace, show_resolved)
end

return { { Pandoc = Pandoc } }
