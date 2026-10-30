local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/collab-comments.lua"

-- The source the store anchors into. A case names the text it selects and the
-- harness derives the stored range from this table, so no offset is written by
-- hand. Quotes are kept out: pandoc.read applies `smart`, which would leave the
-- AST holding a character the source does not. The one line carrying a straight
-- apostrophe is there for exactly that divergence, which is what the three
-- apostrophe cases are about.
local LINES = {
  "---",
  "title: Fixture",
  "---",
  "",
  "A plain paragraph carries a simple anchor and nothing else.",
  "",
  "- A bullet item carries an anchor of its own.",
  "",
  "**A wholly bold paragraph carries an anchor.**",
  "",
  "A paragraph citing @ref2020 carries an anchor after the citation.",
  "",
  "A twice here and a twice here again.",
  "",
  "A soft wrapped anchor sits here.",
  "",
  "A paragraph with café then the target here.",
  "",
  "A paragraph holds l'os and nothing else.",
  "",
  "## A heading introduces the annexe section.",
  "",
  "A soft wrapped selection opens here",
  "and closes on the next line.",
  "",
}
local SOURCE = table.concat(LINES, "\n")

local PLAIN, BULLET, BOLD, CITED, TWICE, ACCENTED, APOSTROPHE = 5, 7, 9, 11, 13, 17, 19
local HEADING, WRAPPED = 21, 23
local STRAIGHT = "l'os and nothing"
local CURLY = STRAIGHT:gsub("'", "\u{2019}")

local function range_of(selection)
  for index, line in ipairs(LINES) do
    local from = line:find(selection, 1, true)
    if from then
      local before = utf8.len(line:sub(1, from - 1))
      return {
        start = { line = index - 1, character = before },
        ["end"] = { line = index - 1, character = before + utf8.len(selection) },
      }
    end
  end
  error("selection absent from the fixture source: " .. selection)
end

-- The AST comes from reading the fixture line itself, so the rendered inlines
-- and the stored literal cannot drift apart: a bold line arrives as Strong, a
-- citing line as Cite, a bullet line as a BulletList. A range of lines arrives
-- as one block holding a SoftBreak at each join, which is the shape a selection
-- across a soft-wrapped sentence has to resolve against.
local function block_of(number, last)
  return pandoc.read(table.concat(LINES, "\n", number, last or number), "markdown").blocks[1]
end

-- The same line as the reader would leave it untouched, which is the state a
-- raw table block arrives in: `smart` never runs on it, so the straight
-- apostrophe survives into the rendered document beside its typographic twin.
local function verbatim_block(number)
  local inlines = {}
  for word in LINES[number]:gmatch("%S+") do
    if #inlines > 0 then
      table.insert(inlines, pandoc.Space())
    end
    table.insert(inlines, pandoc.Str(word))
  end
  return pandoc.Para(inlines)
end

local function store_json(entries)
  local comments = {}
  for index, entry in ipairs(entries) do
    comments[index] = {
      id = entry.id or ("comment-" .. index),
      author = entry.author or "Reviewer One",
      timestamp = entry.timestamp or "2026-10-01T09:00:00Z",
      text = entry.text or "An opening comment.",
      filePath = entry.file_path or "doc.qmd",
      range = entry.range or range_of(entry.selection),
      selectedText = entry.selected_text or entry.selection,
      resolved = entry.resolved,
      replies = entry.replies,
      trackedChanges = entry.tracked_changes,
    }
  end
  return pandoc.json.encode({ comments = comments })
end

local DEFAULT_META = { ["collab-comments"] = { ["docx-comments"] = true } }

local function write_file(path, text)
  local handle = assert(io.open(path, "w"))
  handle:write(text)
  handle:close()
end

-- The store and the source are read from disk by path, so each case gets a
-- directory of its own rather than a committed fixture tree: the cases differ
-- by their store alone, and an isolated one cannot make another ambiguous.
local function run(opts)
  return pandoc.system.with_temporary_directory("collab-comments", function(dir)
    local folder = dir
    if opts.subdir then
      folder = dir .. "/" .. opts.subdir
      pandoc.system.make_directory(folder, true)
    end
    write_file(folder .. "/doc.qmd", SOURCE)
    if opts.comments then
      pandoc.system.make_directory(dir .. "/.comments")
      write_file(dir .. "/.comments/collab-comments.json", opts.store_text or store_json(opts.comments))
    end
    local filter = support.load_filter(FILTER, {
      formats = opts.formats or { docx = true },
      project_dir = dir,
      input_file = folder .. "/doc.qmd",
    })
    local captured = {}
    local real = io.stderr
    io.stderr = {
      write = function(_, text)
        captured[#captured + 1] = text
      end,
    }
    local ok, result = pcall(filter.Pandoc, pandoc.Pandoc(opts.blocks, opts.meta or DEFAULT_META))
    io.stderr = real
    assert(ok, result)
    return { doc = result, stderr = table.concat(captured) }
  end)
end

local function classes_at(inlines)
  local found = {}
  for _, inline in ipairs(inlines) do
    if inline.t == "Span" and #inline.classes > 0 then
      found[#found + 1] = inline.classes[1]
    end
  end
  return found
end

-- The rendered text the reader sees, the marker bodies taken back out: a
-- rewrite that split a Str on the wrong byte shows up here and nowhere else.
local function text_without_markers(block)
  local stripped = pandoc.Blocks({ block }):walk({
    Span = function(span)
      if span.classes:includes("comment-start") or span.classes:includes("comment-end") then
        return {}
      end
      return nil
    end,
  })
  return pandoc.utils.stringify(stripped)
end

-- The two markers of one range carry the same id, which is what pairs the
-- `w:commentRangeStart` and `w:commentRangeEnd` Word reads.
local function marker_ids(inlines)
  local ids = {}
  for _, inline in ipairs(inlines) do
    if inline.t == "Span" and (inline.classes:includes("comment-start") or inline.classes:includes("comment-end")) then
      ids[#ids + 1] = inline.attributes.id
    end
  end
  return ids
end

-- The ordered shape of a comment body, one entry per inline: a field that moved
-- out of its token's place, a prefix or a suffix lost to the promotion, and a
-- token wrongly promoted each show up here, where two lists split by type do not.
local function body_shape(inlines)
  local shape = {}
  for _, inline in ipairs(inlines) do
    if inline.t == "Str" then
      shape[#shape + 1] = "Str:" .. inline.text
    elseif inline.t == "RawInline" then
      shape[#shape + 1] = "Raw:" .. inline.format
    else
      shape[#shape + 1] = inline.t
    end
  end
  return shape
end

local function raw_inlines(inlines)
  local found = {}
  for _, inline in ipairs(inlines) do
    if inline.t == "RawInline" then
      found[#found + 1] = inline
    end
  end
  return found
end

local function start_spans(inlines)
  local found = {}
  for _, inline in ipairs(inlines) do
    if inline.t == "Span" and inline.classes:includes("comment-start") then
      found[#found + 1] = inline
    end
  end
  return found
end

local function first_span(inlines)
  local found = start_spans(inlines)[1]
  return assert(found, "no comment-start span at this level")
end

local function distinct(values)
  local seen, count = {}, 0
  for _, value in ipairs(values) do
    if not seen[value] then
      seen[value] = true
      count = count + 1
    end
  end
  return count
end

TestCollabComments = {}

function TestCollabComments:test_a_plain_paragraph_gains_the_comment_markers()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = { { selection = "simple anchor" } },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), { "comment-start", "comment-end" })
  lu.assertEquals(text_without_markers(out.doc.blocks[1]), LINES[PLAIN])
  local ids = marker_ids(out.doc.blocks[1].content)
  lu.assertEquals(#ids, 2)
  lu.assertEquals(ids[1], ids[2])
end

function TestCollabComments:test_the_start_marker_carries_the_author_and_the_date()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = { { selection = "simple anchor", author = "Reviewer Two", timestamp = "2026-10-02T11:30:00Z" } },
  })
  local span = first_span(out.doc.blocks[1].content)
  lu.assertEquals(span.attributes.author, "Reviewer Two")
  lu.assertEquals(span.attributes.date, "2026-10-02T11:30:00Z")
  lu.assertStrMatches(span.attributes.id, "%d+")
end

-- The fan-out: every entry of a thread is a Word comment of its own, anchored
-- on the span the opening comment selected and carrying its own author and
-- timestamp, the replies following the opening in chronological order.
function TestCollabComments:test_each_reply_becomes_a_comment_of_its_own()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = {
      {
        selection = "simple anchor",
        text = "The opening remark.",
        replies = {
          { id = "r2", author = "Reviewer Three", timestamp = "2026-10-03T08:00:00Z", text = "The later answer." },
          { id = "r1", author = "Reviewer Two", timestamp = "2026-10-02T08:00:00Z", text = "The earlier answer." },
        },
      },
    },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {
    "comment-start",
    "comment-start",
    "comment-start",
    "comment-end",
    "comment-end",
    "comment-end",
  })
  local spans = start_spans(out.doc.blocks[1].content)
  lu.assertEquals(pandoc.utils.stringify(spans[1]), "The opening remark.")
  lu.assertEquals(spans[1].attributes.author, "Reviewer One")
  lu.assertEquals(spans[1].attributes.date, "2026-10-01T09:00:00Z")
  lu.assertEquals(pandoc.utils.stringify(spans[2]), "The earlier answer.")
  lu.assertEquals(spans[2].attributes.author, "Reviewer Two")
  lu.assertEquals(spans[2].attributes.date, "2026-10-02T08:00:00Z")
  lu.assertEquals(pandoc.utils.stringify(spans[3]), "The later answer.")
  lu.assertEquals(spans[3].attributes.author, "Reviewer Three")
  lu.assertEquals(spans[3].attributes.date, "2026-10-03T08:00:00Z")
  lu.assertEquals(text_without_markers(out.doc.blocks[1]), LINES[PLAIN])
end

-- The order of the closing markers is a condition of the feature rather than a
-- detail: Word threads the staggered order it writes itself and refuses the
-- reverse-nested one that adjacent spans produce by default.
function TestCollabComments:test_the_closing_markers_repeat_the_opening_order()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = {
      {
        selection = "simple anchor",
        replies = {
          { id = "r1", author = "Reviewer Two", timestamp = "2026-10-02T08:00:00Z", text = "The earlier answer." },
          { id = "r2", author = "Reviewer Three", timestamp = "2026-10-03T08:00:00Z", text = "The later answer." },
        },
      },
    },
  })
  local ids = marker_ids(out.doc.blocks[1].content)
  lu.assertEquals(#ids, 6)
  lu.assertEquals(distinct(ids), 3)
  lu.assertEquals({ ids[4], ids[5], ids[6] }, { ids[1], ids[2], ids[3] })
end

-- `word_id` hashes the entry's own local id against that entry's own body, so
-- two replies repeating one sentence under two ids stay two comments. Hashing
-- the store entry's id against the whole thread would collide all three.
function TestCollabComments:test_the_word_id_is_hashed_per_entry()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = {
      {
        selection = "simple anchor",
        text = "Agreed.",
        replies = {
          { id = "r1", author = "Reviewer Two", timestamp = "2026-10-02T08:00:00Z", text = "Agreed." },
          { id = "r2", author = "Reviewer Three", timestamp = "2026-10-03T08:00:00Z", text = "Agreed." },
        },
      },
    },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(distinct(marker_ids(out.doc.blocks[1].content)), 3)
end

-- A tracked change stays in the opening comment's body, chronological and
-- printing both of its texts. No store in use carries one.
function TestCollabComments:test_the_opening_body_keeps_its_tracked_changes_in_order()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = {
      {
        selection = "simple anchor",
        text = "The opening remark.",
        tracked_changes = {
          {
            id = "t2",
            author = "The Author",
            timestamp = "2026-10-03T08:00:00Z",
            previousText = "a moved anchor",
            newText = "a simple anchor",
          },
          {
            id = "t1",
            author = "The Author",
            timestamp = "2026-10-02T08:00:00Z",
            previousText = "a simple anchor",
            newText = "a moved anchor",
          },
        },
      },
    },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(#start_spans(out.doc.blocks[1].content), 1)
  local body = pandoc.utils.stringify(first_span(out.doc.blocks[1].content))
  lu.assertStrContains(body, "The opening remark.")
  local earlier = assert(body:find("Previous: a simple anchor", 1, true))
  local later = assert(body:find("Previous: a moved anchor", 1, true))
  lu.assertTrue(earlier < later)
  lu.assertStrContains(body, "Current: a moved anchor")
  lu.assertStrContains(body, "Tracked change")
end

-- A token pandoc reads as a bare URI becomes a `w:fldSimple` HYPERLINK field,
-- which carries its URL inside the part that cites it. Every other token stays
-- the Str the literal filter writes: a token with no scheme is never read, and
-- one the shape check refuses is handed back untouched. The two promoted tokens
-- carry the punctuation pandoc splits off a URL, a surrounding pair and a
-- sentence-final period, so the prefix and suffix branches are both exercised
-- and the field is asserted where its token sat rather than merely counted.
function TestCollabComments:test_a_url_in_the_body_becomes_a_hyperlink_field()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = {
      {
        selection = "simple anchor",
        text = "See (https://x.test/a) then https://x.test/b?c=1&d=2. Not CR_OK and `tbl_one` and www.x.test/a.",
      },
    },
  })
  lu.assertEquals(out.stderr, "")
  local content = first_span(out.doc.blocks[1].content).content
  lu.assertEquals(body_shape(content), {
    "Str:See",
    "Space",
    "Str:(",
    "Raw:openxml",
    "Str:)",
    "Space",
    "Str:then",
    "Space",
    "Raw:openxml",
    "Str:.",
    "Space",
    "Str:Not",
    "Space",
    "Str:CR_OK",
    "Space",
    "Str:and",
    "Space",
    "Str:`tbl_one`",
    "Space",
    "Str:and",
    "Space",
    "Str:www.x.test/a.",
  })
  local fields = raw_inlines(content)
  lu.assertStrContains(fields[1].text, 'w:instr="HYPERLINK &quot;https://x.test/a&quot;"')
  lu.assertStrContains(fields[1].text, '<w:rStyle w:val="Hyperlink"/>')
  lu.assertStrContains(fields[2].text, 'w:instr="HYPERLINK &quot;https://x.test/b?c=1&amp;d=2&quot;"')
  lu.assertStrContains(fields[2].text, ">https://x.test/b?c=1&amp;d=2</w:t>")
end

-- Both tokens below parse to a Link the content/target check lets through or
-- refuses on its own, and the byte-equality check against the token is what
-- settles each: an angle-bracketed autolink loses its delimiters to the parser,
-- so promoting it would drop them from the body, and a quote in the path comes
-- back percent-encoded in the target alone, so promoting it would show the
-- reader a URL the reviewer did not write.
function TestCollabComments:test_an_angle_bracketed_url_stays_text()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = { { selection = "simple anchor", text = "See <https://x.test/a> here." } },
  })
  lu.assertEquals(out.stderr, "")
  local content = first_span(out.doc.blocks[1].content).content
  lu.assertEquals(raw_inlines(content), {})
  lu.assertEquals(body_shape(content), {
    "Str:See",
    "Space",
    "Str:<https://x.test/a>",
    "Space",
    "Str:here.",
  })
end

function TestCollabComments:test_a_url_whose_target_is_percent_encoded_stays_text()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = { { selection = "simple anchor", text = 'See https://x.test/a"b here.' } },
  })
  lu.assertEquals(out.stderr, "")
  local content = first_span(out.doc.blocks[1].content).content
  lu.assertEquals(raw_inlines(content), {})
  lu.assertEquals(body_shape(content), {
    "Str:See",
    "Space",
    'Str:https://x.test/a"b',
    "Space",
    "Str:here.",
  })
end

-- Stair 1: the rewrite walks the body instead of iterating its top level.
function TestCollabComments:test_a_bullet_item_is_reached()
  local out = run({
    blocks = { block_of(BULLET) },
    comments = { { selection = "an anchor of its own" } },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(out.doc.blocks[1].t, "BulletList")
  lu.assertEquals(classes_at(out.doc.blocks[1].content[1][1].content), { "comment-start", "comment-end" })
end

-- Stair 2a: the rewrite recurses into a formatting container.
function TestCollabComments:test_a_wholly_bold_paragraph_is_reached_inside_its_strong()
  local out = run({
    blocks = { block_of(BOLD) },
    comments = { { selection = "bold paragraph carries" } },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(out.doc.blocks[1].content[1].t, "Strong")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
  lu.assertEquals(classes_at(out.doc.blocks[1].content[1].content), { "comment-start", "comment-end" })
end

-- Both walks are wired for Header, and a comment on a heading is the one shape
-- a reviewer's remark on a whole section can take.
function TestCollabComments:test_a_heading_is_reached()
  local out = run({
    blocks = { block_of(HEADING) },
    comments = { { selection = "introduces the annexe" } },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(out.doc.blocks[1].t, "Header")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), { "comment-start", "comment-end" })
end

-- Stair 2b: an atomic inline is an opaque run the selection can sit beside.
function TestCollabComments:test_a_paragraph_carrying_a_citation_is_reached()
  local out = run({
    blocks = { block_of(CITED) },
    comments = { { selection = "carries an anchor after" } },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), { "comment-start", "comment-end" })
  local kinds = {}
  for _, inline in ipairs(out.doc.blocks[1].content) do
    kinds[inline.t] = true
  end
  lu.assertTrue(kinds.Cite)
end

-- The refusal is what keeps an opaque run whole, and the warning is what keeps
-- the refusal from being a silent loss: the claim on a candidate is recorded
-- only once the rewrite has run to the end.
function TestCollabComments:test_a_selection_cutting_an_atomic_inline_is_refused_and_named()
  local out = run({
    blocks = { block_of(CITED) },
    comments = { { selection = "citing @ref" } },
  })
  lu.assertStrContains(out.stderr, "selection occurs only in unsupported rendered structure")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

-- Two comments on one paragraph is ordinary reviewer use, and the two cases
-- below are what hold the multi-candidate half of the rewrite: the sort that
-- puts the markers in document order, and the overlap that drops both.
function TestCollabComments:test_two_disjoint_selections_in_one_paragraph_both_land()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = { { selection = "simple anchor" }, { selection = "plain paragraph" } },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(
    classes_at(out.doc.blocks[1].content),
    { "comment-start", "comment-end", "comment-start", "comment-end" }
  )
  lu.assertEquals(text_without_markers(out.doc.blocks[1]), LINES[PLAIN])
end

function TestCollabComments:test_two_overlapping_selections_are_both_dropped_and_named()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = { { selection = "a simple anchor" }, { selection = "simple anchor and" } },
  })
  lu.assertStrContains(out.stderr, "skipped Word comment comment-1: overlapping rendered selection")
  lu.assertStrContains(out.stderr, "skipped Word comment comment-2: overlapping rendered selection")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

-- The identical anchor is what hands the parent relation to the post-zip step,
-- so it may only ever come from one thread: two distinct comments reaching it
-- stay refused, which is what makes the derivation sound.
function TestCollabComments:test_two_distinct_comments_on_one_span_are_both_dropped_and_named()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = { { selection = "simple anchor" }, { selection = "simple anchor" } },
  })
  lu.assertStrContains(out.stderr, "skipped Word comment comment-1: overlapping rendered selection")
  lu.assertStrContains(out.stderr, "skipped Word comment comment-2: overlapping rendered selection")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

-- The one text view is a correctness requirement: a counting view rendering the
-- SoftBreak as a space would call this selection present and the rewrite would
-- then look for it one byte away.
function TestCollabComments:test_the_counting_view_reads_a_soft_break_as_the_rewrite_does()
  local out = run({
    blocks = {
      pandoc.Para({
        pandoc.Str("A"),
        pandoc.Space(),
        pandoc.Str("soft"),
        pandoc.SoftBreak(),
        pandoc.Str("wrapped"),
        pandoc.Space(),
        pandoc.Str("anchor"),
        pandoc.Space(),
        pandoc.Str("sits"),
        pandoc.Space(),
        pandoc.Str("here."),
      }),
    },
    comments = { { selection = "soft wrapped" } },
  })
  lu.assertStrContains(out.stderr, "selection is absent from supported rendered blocks")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

function TestCollabComments:test_a_selection_occurring_twice_is_named_ambiguous()
  local out = run({
    blocks = { block_of(TWICE) },
    comments = { { selection = "twice here" } },
  })
  lu.assertStrContains(out.stderr, "selection is ambiguous in rendered document")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

-- The count walks the document, metadata included, so a match there is a real
-- occurrence; the rewrite walks the body alone, so a title is never marked up.
function TestCollabComments:test_a_selection_landing_only_in_metadata_is_named()
  local out = run({
    blocks = { block_of(TWICE) },
    meta = {
      ["collab-comments"] = { ["docx-comments"] = true },
      abstract = pandoc.MetaBlocks({ block_of(PLAIN) }),
    },
    comments = { { selection = "simple anchor" } },
  })
  lu.assertStrContains(out.stderr, "selection occurs only in unsupported rendered structure")
  lu.assertEquals(classes_at(out.doc.meta.abstract[1].content), {})
end

function TestCollabComments:test_an_accented_prefix_does_not_shift_the_selection()
  local out = run({
    blocks = { block_of(ACCENTED) },
    comments = { { selection = "the target here" } },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), { "comment-start", "comment-end" })
end

function TestCollabComments:test_a_stale_selection_is_named()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = { { selection = "simple anchor", selected_text = "a moved anchor" } },
  })
  lu.assertStrContains(out.stderr, "stored selection is stale or not literal source text")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

function TestCollabComments:test_a_selection_spanning_source_lines_is_named()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = {
      {
        selection = "simple anchor",
        selected_text = "a moved anchor",
        range = { start = { line = 4, character = 0 }, ["end"] = { line = 5, character = 2 } },
      },
    },
  })
  lu.assertStrContains(out.stderr, "selection spans source lines")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

-- The three cases below hold the fallback: the stored range stays the fast path
-- and a drift in it costs the comment only where the source cannot carry it
-- alone.
function TestCollabComments:test_a_range_spanning_source_lines_resolves_on_its_unique_literal()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = {
      {
        selection = "simple anchor",
        range = { start = { line = 4, character = 0 }, ["end"] = { line = 5, character = 2 } },
      },
    },
  })
  lu.assertStrContains(out.stderr, "drifted Word comment")
  lu.assertStrContains(out.stderr, "selection spans source lines")
  lu.assertNotStrContains(out.stderr, "skipped Word comment")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), { "comment-start", "comment-end" })
end

-- The case above fabricates a two-line range over a single-line literal, so it
-- holds the fallback and not the recovery it enables. Here the stored selection
-- itself spans the two fixture lines, which is what a reviewer selecting across
-- a soft-wrapped sentence files: the fast path refuses every multi-line range by
-- construction, so the literal is the only route, and it has to be found with
-- its newline on both sides, the source joined by lines and the rendered block
-- reading its SoftBreak as one.
function TestCollabComments:test_a_selection_spanning_two_source_lines_resolves_on_its_literal()
  local out = run({
    blocks = { block_of(WRAPPED, WRAPPED + 1) },
    comments = {
      {
        selection = "selection opens here\nand closes",
        range = {
          start = { line = WRAPPED - 1, character = 15 },
          ["end"] = { line = WRAPPED, character = 10 },
        },
      },
    },
  })
  lu.assertStrContains(out.stderr, "drifted Word comment")
  lu.assertStrContains(out.stderr, "selection spans source lines")
  lu.assertNotStrContains(out.stderr, "skipped Word comment")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), { "comment-start", "comment-end" })
end

function TestCollabComments:test_a_stale_range_resolves_on_its_unique_literal()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = {
      {
        selection = "simple anchor",
        range = { start = { line = 6, character = 2 }, ["end"] = { line = 6, character = 15 } },
      },
    },
  })
  lu.assertStrContains(out.stderr, "drifted Word comment")
  lu.assertStrContains(out.stderr, "stored selection is stale or not literal source text")
  lu.assertNotStrContains(out.stderr, "skipped Word comment")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), { "comment-start", "comment-end" })
end

function TestCollabComments:test_a_stale_range_whose_literal_is_not_unique_in_the_source_is_named()
  local out = run({
    blocks = { block_of(TWICE) },
    comments = {
      {
        selection = "twice here",
        range = { start = { line = 4, character = 0 }, ["end"] = { line = 4, character = 10 } },
      },
    },
  })
  lu.assertStrContains(out.stderr, "stored range is stale and the selection is not unique in the source")
  lu.assertNotStrContains(out.stderr, "drifted Word comment")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

-- The three cases below hold the apostrophe normalisation: the comparator reads
-- the two forms as one character, so the form the source carries and the form
-- the store carries each cost the comment nothing.
function TestCollabComments:test_a_stored_curly_literal_resolves_against_a_straight_source()
  local out = run({
    blocks = { block_of(APOSTROPHE) },
    comments = { { selection = STRAIGHT, selected_text = CURLY } },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), { "comment-start", "comment-end" })
  lu.assertEquals(text_without_markers(out.doc.blocks[1]), LINES[APOSTROPHE]:gsub("'", "\u{2019}"))
end

function TestCollabComments:test_a_straight_literal_resolves_against_the_curly_rendered_prose()
  local out = run({
    blocks = { block_of(APOSTROPHE) },
    comments = { { selection = STRAIGHT } },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), { "comment-start", "comment-end" })
end

function TestCollabComments:test_both_forms_occurring_once_is_named_ambiguous()
  local out = run({
    blocks = { block_of(APOSTROPHE), verbatim_block(APOSTROPHE) },
    comments = { { selection = STRAIGHT } },
  })
  lu.assertStrContains(out.stderr, "selection is ambiguous in rendered document")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
  lu.assertEquals(classes_at(out.doc.blocks[2].content), {})
end

function TestCollabComments:test_a_resolved_comment_is_dropped_by_default()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = { { selection = "simple anchor", resolved = true } },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

function TestCollabComments:test_show_resolved_brings_it_back()
  local out = run({
    blocks = { block_of(PLAIN) },
    meta = { ["collab-comments"] = { ["docx-comments"] = true, ["show-resolved"] = true } },
    comments = { { selection = "simple anchor", resolved = true } },
  })
  lu.assertEquals(classes_at(out.doc.blocks[1].content), { "comment-start", "comment-end" })
  lu.assertStrContains(pandoc.utils.stringify(first_span(out.doc.blocks[1].content)), "Resolved")
end

-- The default is what keeps the filter a no-op for every document of a
-- consuming project that does not ask for comments.
function TestCollabComments:test_a_document_that_does_not_ask_is_left_alone()
  local out = run({
    blocks = { block_of(PLAIN) },
    meta = {},
    comments = { { selection = "simple anchor" } },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

function TestCollabComments:test_other_formats_are_left_alone()
  local out = run({
    blocks = { block_of(PLAIN) },
    formats = { html = true },
    comments = { { selection = "simple anchor" } },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

-- The shape every real store has: the document sits in a subdirectory and the
-- store at the project root, so the walk climbs and the key carries the folder.
function TestCollabComments:test_a_nested_document_finds_the_store_above_it()
  local out = run({
    subdir = "docs/csi",
    blocks = { block_of(PLAIN) },
    comments = { { selection = "simple anchor", file_path = "docs/csi/doc.qmd" } },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), { "comment-start", "comment-end" })
end

function TestCollabComments:test_an_entry_naming_another_document_is_not_exported()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = { { selection = "simple anchor", file_path = "other.qmd" } },
  })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

-- A store the schema check refuses is a total loss of the export, so it is
-- named: the delivery check for this filter is the stderr of the render.
function TestCollabComments:test_an_unparsable_store_is_named()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = { { selection = "simple anchor" } },
    store_text = "{ not json",
  })
  lu.assertStrContains(out.stderr, "comment store is not valid JSON")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

function TestCollabComments:test_a_store_carrying_no_comment_collection_is_named()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = { { selection = "simple anchor" } },
    store_text = "{}",
  })
  lu.assertStrContains(out.stderr, "comment store holds no comment collection")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

function TestCollabComments:test_a_store_holding_an_invalid_entry_names_that_entry()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = { { selection = "simple anchor" } },
    store_text = pandoc.json.encode({
      comments = {
        { id = "comment-1", author = "Reviewer One" },
      },
    }),
  })
  lu.assertStrContains(out.stderr, "comment entry 1 does not match the comment schema")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

-- A scalar where the block is expected is named and ignored, rather than
-- costing the render: every other refusal of this filter exits 0.
function TestCollabComments:test_a_scalar_metadata_value_is_named_and_ignored()
  local out = run({
    blocks = { block_of(PLAIN) },
    meta = { ["collab-comments"] = true },
    comments = { { selection = "simple anchor" } },
  })
  lu.assertStrContains(out.stderr, "ignored the collab-comments metadata")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end

function TestCollabComments:test_an_absent_store_is_a_no_op()
  local out = run({ blocks = { block_of(PLAIN) } })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end
