local lang_from_ext = {
  r = "r",
  R = "r",
  Rprofile = "r",
  py = "python",
  python = "python",
  lua = "lua",
  js = "javascript",
  ts = "typescript",
  sh = "bash",
  bash = "bash",
  qmd = "markdown",
  md = "markdown",
  yml = "yaml",
  yaml = "yaml",
  sql = "sql",
  css = "css",
  scss = "scss",
  typ = "typst",
}

local function warn(msg)
  if quarto and quarto.log and quarto.log.warning then
    quarto.log.warning("script: " .. msg)
  else
    io.stderr:write("script: " .. msg .. "\n")
  end
end

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

local known_kwargs = {
  lang = true,
  filename = true,
  suffix = true,
  numbers = true,
  lines = true,
  dedent = true,
}

-- Attributes reach here as raw text, so a value that misses the documented form
-- would otherwise be absorbed silently: a rejected one is named instead.
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

local function parse_lines(spec)
  if not spec then
    return nil, nil
  end
  local s, e = spec:match("^(%d*)%-(%d*)$")
  if s == "" then
    s = nil
  end
  if e == "" then
    e = nil
  end
  if not s and not e then
    if spec:match("^%d+$") then
      return spec, nil
    end
    warn("lines is not a range, reading the whole file: " .. spec)
    return nil, nil
  end
  if s and e and tonumber(s) > tonumber(e) then
    warn("lines ends before it starts, reading the whole file: " .. spec)
    return nil, nil
  end
  return s, e
end

local function dedent(line, n)
  local indent = line:match("^ *")
  return line:sub(math.min(#indent, n) + 1)
end

local function read_file(filepath, start_line, end_line, dedent_n)
  local fh = io.open(filepath)
  if not fh then
    io.stderr:write("script shortcode: cannot open " .. filepath .. "\n")
    return nil
  end
  local chunks = {}
  local n = 1
  local start = start_line and tonumber(start_line) or 1
  local stop = end_line and tonumber(end_line) or nil
  for line in fh:lines("L") do
    if stop and n > stop then
      break
    end
    if n >= start then
      chunks[#chunks + 1] = dedent_n and dedent(line, dedent_n) or line
    end
    n = n + 1
  end
  fh:close()
  return table.concat(chunks)
end

local js_registered = false
local function ensure_js()
  if js_registered then
    return
  end
  quarto.doc.add_html_dependency({
    name = "add-code-files",
    version = "1.0.0",
    scripts = { { path = "add-code-files.js", afterBody = true } },
  })
  js_registered = true
end

return {
  ["script"] = function(args, kwargs)
    if #args < 1 then
      error("script shortcode: a path is required, e.g. {{< script path/to/file.R >}}")
    end
    local path = pandoc.utils.stringify(args[1])

    if #args > 1 then
      local extra = {}
      for i = 2, #args do
        extra[#extra + 1] = pandoc.utils.stringify(args[i])
      end
      warn("extra positional arguments are ignored, use attributes: " .. table.concat(extra, " "))
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

    local ext = (path:match("%.([^.]+)$") or "")
    local default_lang = lang_from_ext[ext] or lang_from_ext[ext:lower()] or ""

    local lang = kw(kwargs, "lang", default_lang)
    local filename = kw(kwargs, "filename", path)
    local numbers = to_bool("numbers", kw(kwargs, "numbers", "true"), true)
    local dedent_s = kw(kwargs, "dedent", nil)
    local suffix = kw(kwargs, "suffix", nil)
    local s, e = parse_lines(kw(kwargs, "lines", nil))

    local dedent_n = dedent_s and tonumber(dedent_s) or nil
    if dedent_s and not dedent_n then
      warn("dedent is not a number, ignoring: " .. dedent_s)
    end

    if suffix then
      filename = filename .. " " .. suffix
    end

    local content = read_file(path, s, e, dedent_n)
    if content == nil then
      return pandoc.Div({ pandoc.Para({ pandoc.Str("[script: file not found: " .. path .. "]") }) })
    end

    ensure_js()

    local classes = { "cell-code" }
    if lang ~= "" then
      table.insert(classes, 1, lang)
    end
    if numbers then
      table.insert(classes, "number-lines")
    end
    table.insert(classes, "cw-auto")

    local cb_attrs = {}
    if s then
      cb_attrs.startFrom = s
    end
    if lang ~= "" then
      cb_attrs.filename = lang
    end

    local code = pandoc.CodeBlock(content, pandoc.Attr("", classes, cb_attrs))

    return pandoc.Div({ code }, pandoc.Attr("", {}, { ["code-filename"] = filename }))
  end,
}
