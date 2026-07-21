local function warn(msg)
  if quarto and quarto.log and quarto.log.warning then
    quarto.log.warning("filetree: " .. msg)
  else
    io.stderr:write("filetree: " .. msg .. "\n")
  end
end

-- Dynamic mode scans past `depth` so collapsed folders stay reachable ; this caps
-- the recursion on a pathological tree or a symlink cycle, where `exclude` remains
-- the real filter.
local DYNAMIC_SCAN_MAX = 12

local function kw(kwargs, name, default)
  local v = kwargs[name]
  if v == nil then
    return default
  end
  local s = pandoc.utils.stringify(v)
  if s == "" then
    return default
  end
  return s
end

local function split(spec)
  local out = {}
  if not spec then
    return out
  end
  for token in spec:gmatch("[^|]+") do
    token = token:match("^%s*(.-)%s*$")
    if token ~= "" then
      out[#out + 1] = token
    end
  end
  return out
end

-- `list_directory` is the only file-type probe pandoc's Lua API offers, so the
-- kind is read off its error: a non-directory reports "inappropriate type" even
-- when it is itself unreadable, and only a directory we may not open reports
-- "permission denied". `io.open` is deliberately not used as an existence test:
-- it blocks forever on a named pipe with no writer.
local unknown_errors = {}

local function classify(path)
  local ok, err = pcall(pandoc.system.list_directory, path)
  if ok then
    return "directory"
  end
  local err = tostring(err)
  if err:find("does not exist", 1, true) then
    return "absent"
  end
  if err:find("inappropriate type", 1, true) then
    return "file"
  end
  -- Denial can come from the entry itself or from a parent that is readable but
  -- not searchable, in which case a regular file, a directory and an absent path
  -- are indistinguishable. The kind is unknown, not "directory".
  if err:find("permission denied", 1, true) then
    return "unreadable"
  end
  local reason = err:match("openDirStream:%s*(.*)$") or err
  if not unknown_errors[reason] then
    unknown_errors[reason] = true
    warn("unrecognised listing error, entry treated as a file: " .. reason)
  end
  return "file"
end

local function strip_slash(path)
  return (path:gsub("/+$", ""))
end

local icon_by_name = {
  ["README.md"] = "readme",
  ["LICENSE"] = "license",
  ["LICENSE.md"] = "license",
  [".gitignore"] = "git",
  [".gitattributes"] = "git",
  [".Rprofile"] = "r",
  [".Renviron"] = "tune",
}

local icon_by_extension = {
  r = "r",
  py = "python",
  qmd = "quarto",
  md = "markdown",
  typ = "typst",
  yml = "yaml",
  yaml = "yaml",
  toml = "toml",
  lock = "lock",
  env = "tune",
  lua = "lua",
  scss = "sass",
  sass = "sass",
  css = "css",
  json = "json",
  html = "html",
  js = "javascript",
  woff = "font",
  woff2 = "font",
  docx = "word",
  dotx = "word",
  png = "image",
  jpg = "image",
  jpeg = "image",
  svg = "image",
  license = "license",
}

local icon_by_dirname = {
  [".github"] = "folder-github",
}

local function icon_key(name, dir)
  if dir then
    return icon_by_dirname[name] or "folder-base"
  end
  local exact = icon_by_name[name]
  if exact then
    return exact
  end
  local ext = name:match("%.([^.]+)$")
  return ext and icon_by_extension[ext:lower()] or "document"
end

-- The icons sit beside this script inside the extension, wherever Quarto
-- installed it, so their location is derived from the script rather than from a
-- path relative to the project being rendered.
local icon_dir = (PANDOC_SCRIPT_FILE or ""):match("^(.*)[/\\][^/\\]*$")
icon_dir = icon_dir and (icon_dir .. "/../icons/")

-- Everything outside the unreserved set is percent-encoded, so the result holds
-- no quote, space, parenthesis or semicolon and survives both an unquoted CSS
-- `url()` and a double-quoted HTML attribute.
local function encode_svg(svg)
  return (svg:gsub("%s+", " "):gsub("[^%w%-%._~:/=,]", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

local icon_cache = {}

local function icon_uri(key)
  local cached = icon_cache[key]
  if cached ~= nil then
    return cached or nil
  end
  local fh = icon_dir and io.open(icon_dir .. key .. ".svg", "rb")
  if not fh then
    warn("icon not readable, entry rendered without one: " .. key .. ".svg")
    icon_cache[key] = false
    return nil
  end
  local svg = fh:read("a")
  fh:close()
  local uri = "data:image/svg+xml," .. encode_svg(svg)
  icon_cache[key] = uri
  return uri
end

local function is_absolute(path)
  return path:match("^[/\\]") ~= nil or path:match("^%a:") ~= nil
end

-- The sidecar is read as a file, so an unconstrained path turns the shortcode
-- into an arbitrary-file reader. Only project-relative paths are accepted.
local function is_project_relative(path)
  if is_absolute(path) then
    return false
  end
  for part in path:gmatch("[^/\\]+") do
    if part == ".." then
      return false
    end
  end
  return true
end

-- Pandoc runs with the document's directory as working directory, so a bare
-- relative path would mean "beside this document" and a tree of the project
-- would be unreachable from any document that is not at its root. Paths are
-- resolved against the project instead, which is what the shortcode documents.
local project_dir = quarto and quarto.project and quarto.project.directory

local function in_project(path)
  if not project_dir or is_absolute(path) then
    return path
  end
  return project_dir .. "/" .. path
end

local reported = {}

local function report_bad_pattern(name, pattern, err)
  local seen = reported[name]
  if not seen then
    seen = {}
    reported[name] = seen
  end
  if seen[pattern] then
    return
  end
  seen[pattern] = true
  warn(name .. " pattern ignored: " .. pattern .. " (" .. tostring(err) .. ")")
end

local function matches_any(name, path, patterns)
  for _, pattern in ipairs(patterns) do
    local ok, hit = pcall(string.find, path, pattern)
    if not ok then
      report_bad_pattern(name, pattern, hit)
    elseif hit then
      return true
    end
  end
  return false
end

-- Lua patterns are interpreted, not compiled: a malformed pattern only raises
-- once the matcher reaches the defect, so a literal prefix that fails early
-- hides it here. `matches_any` keeps the residual case reported.
local function compile_patterns(name, list)
  local out = {}
  for _, pattern in ipairs(list) do
    local ok, err = pcall(string.find, "", pattern)
    if ok then
      out[#out + 1] = pattern
    else
      report_bad_pattern(name, pattern, err)
    end
  end
  return out
end

local function to_patterns(value)
  if value == nil then
    return {}
  end
  if type(value) == "table" then
    return value
  end
  return split(value)
end

local function unquote(text)
  text = text:match("^%s*(.-)%s*$")
  local quote = text:sub(1, 1)
  if #text >= 2 and (quote == '"' or quote == "'") and text:sub(-1) == quote then
    return text:sub(2, -2)
  end
  return text
end

local root_problem = {
  absent = "does not exist",
  file = "is not a directory",
  unreadable = "cannot be read (permission denied)",
}

local raw_keys = { root = true, depth = true, hidden = true, exclude = true, highlight = true, mode = true }

local known_kwargs = {
  root = true,
  depth = true,
  hidden = true,
  exclude = true,
  highlight = true,
  annotations = true,
  mode = true,
}

-- Booleans reach here as raw text: the sidecar bypasses YAML through
-- `read_raw_config`, so `yes` and `on` are never coerced, and an attribute is a
-- string either way. A rejected value fails invisibly, hence the warning.
local booleans = {
  ["true"] = true,
  yes = true,
  on = true,
  ["1"] = true,
  ["false"] = false,
  no = false,
  off = false,
  ["0"] = false,
}

local function to_bool(name, text, default)
  local value = booleans[text:lower()]
  if value ~= nil then
    return value
  end
  warn(name .. " is not a boolean, using " .. tostring(default) .. ": " .. text)
  return default
end

local modes = { static = true, dynamic = true }

local function to_mode(text, default)
  local value = text:lower()
  if modes[value] then
    return value
  end
  warn("mode is not static or dynamic, using " .. default .. ": " .. text)
  return default
end

-- Pandoc parses YAML metadata scalars as inline Markdown, which silently mangles
-- Lua patterns (`__pycache__` becomes `pycache`). Config values are read from the
-- raw text; only `paths` goes through pandoc.read, where Markdown is intended.
local function read_raw_config(text)
  local out, list = {}, nil
  local inside = false
  for line in (text .. "\n"):gmatch("(.-)\n") do
    if line:match("^filetree%s*:%s*$") then
      inside = true
    elseif inside and line:match("^%S") then
      break
    elseif inside then
      local item = line:match("^%s*%-%s*(.+)$")
      if item and list then
        list[#list + 1] = unquote(item)
      else
        local key, value = line:match("^%s+([^:]+):%s*(.*)$")
        list = nil
        if key and raw_keys[unquote(key)] then
          key = unquote(key)
          if value == "" then
            out[key] = {}
            list = out[key]
          else
            out[key] = unquote(value)
          end
        end
      end
    end
  end
  return out
end

local function read_sidecar(path)
  local fh = io.open(path)
  if not fh then
    return nil
  end
  local text = fh:read("a")
  fh:close()
  local ok, doc = pcall(pandoc.read, "---\n" .. text .. "\n---\n", "markdown")
  if not ok then
    warn("cannot parse " .. path .. ": " .. tostring(doc))
    return nil
  end
  if not doc.meta["filetree"] then
    warn(path .. ": no top-level 'filetree' key, config ignored")
    return nil
  end
  local config = read_raw_config(text)
  config.paths = doc.meta["filetree"].paths
  return config
end

-- YAML 1.1 coerces unquoted y/n/yes/no/on/off/true/false to booleans and `~` to
-- null, so an annotation can reach here as something Plain would reject.
local function to_inlines(key, value)
  local vtype = pandoc.utils.type(value)
  if vtype == "Inlines" then
    return value
  end
  if vtype == "string" then
    if value == "" then
      return nil
    end
    return { pandoc.Str(value) }
  end
  warn("paths key '" .. key .. "': annotation is a " .. vtype .. ", not text ; quote the value in the sidecar")
  return nil
end

local function read_annotations(config)
  local out = {}
  local paths = config["paths"]
  if not paths then
    return out
  end
  if pandoc.utils.type(paths) ~= "table" then
    warn(
      "paths must be a mapping of path to annotation, got a " .. pandoc.utils.type(paths) .. " ; annotations ignored"
    )
    return out
  end
  for key, value in pairs(paths) do
    local inlines = to_inlines(key, value)
    if inlines then
      out[strip_slash(key)] = inlines
    end
  end
  return out
end

local function keeps(name, relpath, opts)
  if not opts.hidden and name:sub(1, 1) == "." then
    return false
  end
  return not matches_any("exclude", relpath, opts.exclude)
end

local function has_visible_entry(dir, prefix, opts)
  local ok, names = pcall(pandoc.system.list_directory, dir)
  if not ok then
    return false
  end
  for _, name in ipairs(names) do
    if keeps(name, prefix .. name, opts) then
      return true
    end
  end
  return false
end

local function scan(dir, prefix, depth, opts)
  local ok, names = pcall(pandoc.system.list_directory, dir)
  if not ok then
    warn("cannot read directory " .. dir)
    return {}
  end

  local nodes = {}
  for _, name in ipairs(names) do
    local relpath = prefix .. name
    if keeps(name, relpath, opts) then
      local path = dir .. "/" .. name
      local kind = classify(path)
      if kind == "unreadable" then
        warn("cannot determine the kind of " .. relpath .. ", listing was denied ; shown as a directory")
      end
      nodes[#nodes + 1] = {
        name = name,
        relpath = relpath,
        dir = kind == "directory" or kind == "unreadable",
        unreadable = kind == "unreadable",
        path = path,
      }
      opts.rendered[relpath] = true
    end
  end

  table.sort(nodes, function(a, b)
    if a.dir ~= b.dir then
      return a.dir
    end
    return a.name:lower() < b.name:lower()
  end)

  for _, node in ipairs(nodes) do
    if node.dir and not node.unreadable then
      if depth > 1 then
        node.children = scan(node.path, node.relpath .. "/", depth - 1, opts)
        if #node.children == 0 then
          node.children = nil
        end
      else
        node.truncated = has_visible_entry(node.path, node.relpath .. "/", opts)
      end
    end
  end

  return nodes
end

local html_escapes = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;" }

local function esc(text)
  return (text:gsub('[&<>"]', html_escapes))
end

local function inlines_to_html(inlines)
  local doc = pandoc.Pandoc({ pandoc.Plain(inlines) })
  return (pandoc.write(doc, "html", { wrap_text = "none" }):gsub("%s+$", ""))
end

local function render_html(nodes, opts, buffer, level)
  level = level or 1
  buffer[#buffer + 1] = "<ul>"
  for _, node in ipairs(nodes) do
    local key = icon_key(node.name, node.dir)
    local classes = { node.dir and "ft-dir" or "ft-file" }
    classes[#classes + 1] = "ft-i-" .. key
    -- The class stays the override handle for consumers ; the custom property
    -- only carries the default, so a `background-image` rule in a consumer
    -- stylesheet still wins on the cascade.
    local uri = icon_uri(key)
    -- A childless folder gets no `<details>` : the disclosure widget would imply
    -- content it cannot reveal, so it renders flat like a file.
    local expandable = node.truncated or (node.children and #node.children > 0)
    local toggled = opts.dynamic and node.dir and expandable
    local props = {}
    if uri then
      props[#props + 1] = "--ft-icon:url(" .. uri .. ")"
    end
    -- A toggled folder swaps to its `-open` variant on expand ; both URIs ride on
    -- the same element so the CSS switch needs no second walk of the filesystem.
    if toggled then
      local open_uri = icon_uri(key .. "-open")
      if open_uri then
        props[#props + 1] = "--ft-icon-open:url(" .. open_uri .. ")"
      end
    end
    local style = #props > 0 and (' style="' .. table.concat(props, ";") .. '"') or ""
    local highlighted = matches_any("highlight", node.relpath, opts.highlight)
    if highlighted then
      classes[#classes + 1] = "ft-hl"
    end

    local label = node.dir and (node.name .. "/") or node.name
    -- The icon is a CSS background and the highlight a class, neither of which
    -- reaches a non-visual reader ; `strong` carries the emphasis that
    -- `render_list` expresses with `pandoc.Strong`.
    local name = esc(label)
    if highlighted then
      name = "<strong>" .. name .. "</strong>"
    end
    local head = '<span class="ft-name">' .. name .. "</span>"

    local desc = opts.annotations[node.relpath]
    if desc then
      head = head .. '<span class="ft-desc">' .. inlines_to_html(desc) .. "</span>"
    end

    buffer[#buffer + 1] = '<li class="' .. table.concat(classes, " ") .. '"' .. style .. ">"
    if toggled then
      -- `depth` is the level open on load ; deeper folders stay in the DOM but
      -- collapsed, and `<details>` carries the toggle without a script.
      local open = level <= opts.depth and " open" or ""
      buffer[#buffer + 1] = "<details" .. open .. "><summary>" .. head .. "</summary>"
    else
      buffer[#buffer + 1] = head
    end

    if node.truncated then
      buffer[#buffer + 1] = '<ul><li class="ft-more">'
        .. '<span class="ft-name" aria-hidden="true">…</span>'
        .. '<span class="ft-sr-only">further entries not shown</span></li></ul>'
    elseif node.children and #node.children > 0 then
      render_html(node.children, opts, buffer, level + 1)
    end

    if toggled then
      buffer[#buffer + 1] = "</details>"
    end
    buffer[#buffer + 1] = "</li>"
  end
  buffer[#buffer + 1] = "</ul>"
end

local function render_list(nodes, opts)
  local items = {}
  for _, node in ipairs(nodes) do
    local label = node.dir and (node.name .. "/") or node.name
    local inlines = matches_any("highlight", node.relpath, opts.highlight) and { pandoc.Strong({ pandoc.Str(label) }) }
      or { pandoc.Str(label) }

    local desc = opts.annotations[node.relpath]
    if desc then
      inlines[#inlines + 1] = pandoc.Space()
      inlines[#inlines + 1] = pandoc.Emph(desc)
    end

    local blocks = { pandoc.Plain(inlines) }
    if node.truncated then
      blocks[#blocks + 1] = pandoc.BulletList({ { pandoc.Plain({ pandoc.Str("…") }) } })
    elseif node.children and #node.children > 0 then
      blocks[#blocks + 1] = render_list(node.children, opts)
    end
    items[#items + 1] = blocks
  end
  return pandoc.BulletList(items)
end

-- An annotation is dead as soon as its key is absent from the rendered tree,
-- which existence on disk does not establish: `exclude`, `hidden` and `depth`
-- all drop paths that are perfectly real.
local function report_dead_keys(annotations, root, rendered)
  local absent, dropped = {}, {}
  for key in pairs(annotations) do
    if not rendered[key] then
      local path = root == "." and key or (root .. "/" .. key)
      local bucket = classify(path) ~= "absent" and dropped or absent
      bucket[#bucket + 1] = key
    end
  end
  table.sort(absent)
  table.sort(dropped)
  for _, key in ipairs(absent) do
    warn("annotation key does not match any path: " .. key)
  end
  for _, key in ipairs(dropped) do
    warn(
      "annotation key exists on disk but matches no rendered entry, so its description is never"
        .. " shown ; check exclude, hidden, depth and the key spelling: "
        .. key
    )
  end
end

return {
  ["filetree"] = function(args, kwargs, meta)
    if #args > 0 then
      local given = {}
      for _, arg in ipairs(args) do
        given[#given + 1] = pandoc.utils.stringify(arg)
      end
      warn("positional arguments are ignored, use attributes: " .. table.concat(given, " "))
    end

    local unknown = {}
    for name in pairs(kwargs) do
      if not known_kwargs[name] then
        unknown[#unknown + 1] = name
      end
    end
    table.sort(unknown)
    for _, name in ipairs(unknown) do
      warn("unknown attribute ignored: " .. name)
    end

    local sidecar = kw(kwargs, "annotations", "filetree.yml")
    local within_project = is_project_relative(sidecar)
    if not within_project then
      warn("annotations must be a path inside the project, config ignored: " .. sidecar)
    end
    local config = (within_project and read_sidecar(in_project(sidecar))) or {}

    local function opt(name, default)
      return kw(kwargs, name, config[name]) or default
    end

    local function patterns(name)
      local override = kw(kwargs, name, nil)
      local list = override and split(override) or to_patterns(config[name])
      return compile_patterns(name, list)
    end

    local root = opt("root", ".")
    local root_path = in_project(root)
    local raw_depth = opt("depth", "2")
    local depth = tonumber(raw_depth)
    if not depth then
      warn("depth is not a number, using 2: " .. raw_depth)
      depth = 2
    end

    local opts = {
      exclude = patterns("exclude"),
      highlight = patterns("highlight"),
      hidden = to_bool("hidden", opt("hidden", "false"), false),
      mode = to_mode(opt("mode", "static"), "static"),
      depth = depth,
      annotations = read_annotations(config),
      rendered = {},
    }

    local root_kind = classify(root_path)
    if root_kind ~= "directory" then
      warn("root " .. root_problem[root_kind] .. ": " .. root)
      return {}
    end

    -- The deep scan is gated on HTML, so a non-JS or non-HTML target keeps `depth`
    -- as a hard cut and never inherits the dynamic tree's full walk.
    local html = quarto.doc.is_format("html:js")
    opts.dynamic = opts.mode == "dynamic" and html
    local scan_depth = opts.dynamic and DYNAMIC_SCAN_MAX or depth

    local nodes = scan(root_path, "", scan_depth, opts)
    report_dead_keys(opts.annotations, root_path, opts.rendered)

    if #nodes == 0 then
      warn("no entry to show under " .. root .. " ; check exclude, hidden and depth")
    end

    if html then
      local buffer = {}
      render_html(nodes, opts, buffer)
      local classes = opts.dynamic and { "filetree", "filetree-dynamic" } or { "filetree" }
      return pandoc.Div({ pandoc.RawBlock("html", table.concat(buffer)) }, pandoc.Attr("", classes))
    end

    return pandoc.Div({ render_list(nodes, opts) }, pandoc.Attr("", { "filetree" }))
  end,
}
