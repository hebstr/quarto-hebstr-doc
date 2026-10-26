local lu = require("luaunit")
local support = require("support")

local FILTER = "_extensions/hebstr-doc/filters/collab-comments.lua"

-- The source the store anchors into. A case names the text it selects and the
-- harness derives the stored range from this table, so no offset is written by
-- hand. Apostrophes and quotes are kept out: pandoc.read applies `smart`, which
-- would leave the AST holding a character the source does not.
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
}
local SOURCE = table.concat(LINES, "\n")

local PLAIN, BULLET, BOLD, CITED, TWICE, ACCENTED = 5, 7, 9, 11, 13, 17

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
-- citing line as Cite, a bullet line as a BulletList.
local function block_of(number)
  return pandoc.read(LINES[number], "markdown").blocks[1]
end

local function store_json(entries)
  local comments = {}
  for index, entry in ipairs(entries) do
    comments[index] = {
      id = entry.id or ("comment-" .. index),
      author = entry.author or "Reviewer One",
      timestamp = entry.timestamp or "2026-10-01T09:00:00Z",
      text = entry.text or "An opening comment.",
      filePath = "doc.qmd",
      range = entry.range or range_of(entry.selection),
      selectedText = entry.selected_text or entry.selection,
      resolved = entry.resolved,
      replies = entry.replies,
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
    write_file(dir .. "/doc.qmd", SOURCE)
    if opts.comments then
      pandoc.system.make_directory(dir .. "/.comments")
      write_file(dir .. "/.comments/collab-comments.json", store_json(opts.comments))
    end
    local filter = support.load_filter(FILTER, {
      formats = opts.formats or { docx = true },
      project_dir = dir,
      input_file = dir .. "/doc.qmd",
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

local function first_span(inlines)
  local found
  for _, inline in ipairs(inlines) do
    if inline.t == "Span" and inline.classes:includes("comment-start") then
      found = inline
      break
    end
  end
  return assert(found, "no comment-start span at this level")
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

function TestCollabComments:test_the_marker_body_carries_the_whole_transcript()
  local out = run({
    blocks = { block_of(PLAIN) },
    comments = {
      {
        selection = "simple anchor",
        text = "The opening remark.",
        replies = {
          { id = "r1", author = "Reviewer Two", timestamp = "2026-10-03T08:00:00Z", text = "The answer." },
        },
      },
    },
  })
  local body = pandoc.utils.stringify(first_span(out.doc.blocks[1].content))
  lu.assertStrContains(body, "The opening remark.")
  lu.assertStrContains(body, "Reply")
  lu.assertStrContains(body, "The answer.")
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

function TestCollabComments:test_an_absent_store_is_a_no_op()
  local out = run({ blocks = { block_of(PLAIN) } })
  lu.assertEquals(out.stderr, "")
  lu.assertEquals(classes_at(out.doc.blocks[1].content), {})
end
